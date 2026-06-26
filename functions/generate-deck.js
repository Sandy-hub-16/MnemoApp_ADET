const axios = require("axios");
const pdfParse = require("pdf-parse");
const { PNG } = require("pngjs");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const admin = require("firebase-admin");
if (!admin.apps.length) admin.initializeApp();

const groqKey = defineSecret("GROQ_API_KEY");
const openRouterKey = defineSecret("OPENROUTER_API_KEY");

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

// A PDF page with fewer than this many extracted characters is treated as
// having no usable text layer → routed to the vision path automatically.
const MIN_CHARS_PER_PAGE = 100;

// Cap how many pages we render for the vision path to stay within token limits.
const MAX_VISION_PAGES = 5;

// Text models
const GROQ_TEXT_MODEL = "llama-3.1-8b-instant";
const OPENROUTER_TEXT_MODEL = "openai/gpt-oss-120b:free";

// Vision models (must support image input)
const GROQ_VISION_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct";
const OPENROUTER_VISION_MODEL = "meta-llama/llama-4-scout";

const GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions";
const OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";
const OPENROUTER_HEADERS = { "HTTP-Referer": "https://mnemoapp.com" };

// ── Rate limiting ──────────────────────────────────────────────────────────
const DAILY_LIMIT = 5;        // generations per user per window
const WINDOW_MS = 24 * 60 * 60 * 1000; // 24-hour rolling window

const JSON_SCHEMA = `{"title":"...","cards":[{"question":"...","answer":"...","options":["...","...","...","..."]}]}`;

// ─────────────────────────────────────────────────────────────────────────────
// JSON EXTRACTION
//
// Finds the first complete JSON object in a model response string, handling
// prose preamble/postamble, markdown fences, and escaped characters.
// ─────────────────────────────────────────────────────────────────────────────
function extractJsonObject(raw) {
    const content = raw.replace(/```json|```/g, "").trim();
    const start = content.indexOf("{");
    if (start === -1) throw new Error("Model response contained no JSON object.");

    let depth = 0;
    let inString = false;
    let escape = false;

    for (let i = start; i < content.length; i++) {
        const ch = content[i];
        if (escape) { escape = false; continue; }
        if (ch === "\\" && inString) { escape = true; continue; }
        if (ch === '"') { inString = !inString; continue; }
        if (inString) continue;
        if (ch === "{") depth++;
        else if (ch === "}") {
            depth--;
            if (depth === 0) return JSON.parse(content.slice(start, i + 1));
        }
    }
    throw new Error("Model response contained no complete JSON object.");
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF → TEXT EXTRACTION (aggressive mode)
//
// Uses pdf-parse's internal page rendering pipeline to extract all text
// content including text inside image-heavy pages. Falls back to raw buffer
// extraction if the page render callback approach yields nothing.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Attempts deep text extraction from a PDF buffer.
 * Returns extracted text or empty string if none found.
 */
async function extractPdfText(buffer, pageLimit) {
    let extracted = "";

    // Method 1: page-by-page text extraction via getTextContent
    try {
        let pageCount = 0;
        const pageTexts = [];
        const parsed = await pdfParse(buffer, {
            pagerender: async (pageData) => {
                pageCount++;
                if (pageLimit > 0 && pageCount > pageLimit) return "";
                try {
                    const content = await pageData.getTextContent();
                    const t = content.items.map((i) => i.str).join(" ");
                    pageTexts.push(t);
                    return t;
                } catch (_) {
                    return "";
                }
            },
        });
        extracted = pageTexts.join("\n\n") || parsed.text || "";
    } catch (err) {
        console.warn("pdf-parse method 1 failed:", err.message);
    }

    // Method 2: fallback — plain pdf-parse without custom renderer
    if (!extracted.trim()) {
        try {
            const parsed = await pdfParse(buffer);
            extracted = parsed.text || "";
        } catch (err) {
            console.warn("pdf-parse method 2 failed:", err.message);
        }
    }

    return extracted;
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF → IMAGES via pdfjs-dist + pngjs (pure JS, no native binaries)
//
// Uses pdfjs NodeCanvasFactory interface with a full DOMMatrix stub so that
// pdfjs v2's internal transform tracking works correctly.
// ─────────────────────────────────────────────────────────────────────────────

let _pdfjsLib = null;
function _getPdfjsLib() {
    if (!_pdfjsLib) {
        _pdfjsLib = require("pdfjs-dist/build/pdf.js");
        _pdfjsLib.GlobalWorkerOptions.workerSrc = require.resolve("pdfjs-dist/build/pdf.worker.js");
    }
    return _pdfjsLib;
}

/** Full DOMMatrix-compatible stub — pdfjs v2 reads and mutates these. */
function _makeMatrix(a = 1, b = 0, c = 0, d = 1, e = 0, f = 0) {
    return {
        a, b, c, d, e, f,
        is2D: true, isIdentity: (a === 1 && b === 0 && c === 0 && d === 1 && e === 0 && f === 0),
        invertSelf() { return _makeMatrix(d, -b, -c, a, (c * f - d * e), (b * e - a * f)); },
        multiplySelf(m) { return Object.assign(this, _multiply(this, m)); },
        multiply(m) { return Object.assign(_makeMatrix(), _multiply(this, m)); },
        preMultiplySelf(m) { return Object.assign(this, _multiply(m, this)); },
        translateSelf(tx = 0, ty = 0) { this.e += tx; this.f += ty; return this; },
        scaleSelf(sx = 1, sy = sx) { this.a *= sx; this.d *= sy; return this; },
        rotateSelf(deg) {
            const r = deg * Math.PI / 180, cos = Math.cos(r), sin = Math.sin(r);
            return this.multiplySelf(_makeMatrix(cos, sin, -sin, cos, 0, 0));
        },
        transformPoint(p = { x: 0, y: 0 }) {
            return { x: this.a * p.x + this.c * p.y + this.e, y: this.b * p.x + this.d * p.y + this.f };
        },
        toFloat32Array() { return new Float32Array([this.a, this.b, 0, 0, this.c, this.d, 0, 0, 0, 0, 1, 0, this.e, this.f, 0, 1]); },
        toFloat64Array() { return new Float64Array([this.a, this.b, 0, 0, this.c, this.d, 0, 0, 0, 0, 1, 0, this.e, this.f, 0, 1]); },
    };
}
function _multiply(a, m) {
    return {
        a: a.a * m.a + a.c * m.b, b: a.b * m.a + a.d * m.b,
        c: a.a * m.c + a.c * m.d, d: a.b * m.c + a.d * m.d,
        e: a.a * m.e + a.c * m.f + a.e, f: a.b * m.e + a.d * m.f + a.f
    };
}

function _buildFakeContext(rgbaBuffer, width, height) {
    // White background
    for (let i = 0; i < rgbaBuffer.length; i += 4) {
        rgbaBuffer[i] = 255; rgbaBuffer[i + 1] = 255; rgbaBuffer[i + 2] = 255; rgbaBuffer[i + 3] = 255;
    }

    let _currentTransform = _makeMatrix();

    return {
        // ── ImageData ──────────────────────────────────────────────────────────
        createImageData: (w, h) => ({ data: new Uint8ClampedArray(w * h * 4), width: w, height: h }),
        putImageData: (imgData, dx, dy) => {
            for (let row = 0; row < imgData.height; row++) {
                const dstY = dy + row;
                if (dstY < 0 || dstY >= height) continue; // skip out-of-bounds rows
                const src = row * imgData.width * 4;
                const dst = (dstY * width + dx) * 4;
                // Clamp the copy width to what fits in the destination buffer.
                const copyPixels = Math.min(imgData.width, width - Math.max(0, dx));
                if (copyPixels <= 0) continue;
                const copyBytes = copyPixels * 4;
                if (dst < 0 || dst + copyBytes > rgbaBuffer.length) continue;
                rgbaBuffer.set(imgData.data.subarray(src, src + copyBytes), dst);
            }
        },
        getImageData: (x, y, w, h) => {
            const data = new Uint8ClampedArray(w * h * 4);
            for (let row = 0; row < h; row++) {
                const srcY = y + row;
                if (srcY < 0 || srcY >= height) continue;
                const src = (srcY * width + Math.max(0, x)) * 4;
                const copyPixels = Math.min(w, width - Math.max(0, x));
                if (copyPixels <= 0) continue;
                if (src + copyPixels * 4 > rgbaBuffer.length) continue;
                data.set(rgbaBuffer.subarray(src, src + copyPixels * 4), row * w * 4);
            }
            return { data, width: w, height: h };
        },
        // ── Transforms ────────────────────────────────────────────────────────
        save: () => { }, restore: () => { },
        scale: () => { }, rotate: () => { }, translate: () => { },
        transform: () => { }, setTransform: () => { }, resetTransform: () => {
            _currentTransform = _makeMatrix();
        },
        getTransform: () => Object.assign(Object.create(Object.getPrototypeOf(_currentTransform)), _currentTransform),
        // ── Drawing stubs ──────────────────────────────────────────────────────
        beginPath: () => { }, closePath: () => { }, moveTo: () => { }, lineTo: () => { },
        bezierCurveTo: () => { }, quadraticCurveTo: () => { }, arc: () => { }, arcTo: () => { },
        ellipse: () => { }, rect: () => { }, clip: () => { }, fill: () => { }, stroke: () => { },
        fillRect: () => { }, clearRect: () => { }, strokeRect: () => { },
        fillText: () => { }, strokeText: () => { },
        measureText: () => ({
            width: 0, actualBoundingBoxAscent: 0, actualBoundingBoxDescent: 0,
            fontBoundingBoxAscent: 0, fontBoundingBoxDescent: 0
        }),
        drawImage: () => { },
        createPattern: () => null,
        createLinearGradient: () => ({ addColorStop: () => { } }),
        createRadialGradient: () => ({ addColorStop: () => { } }),
        createConicGradient: () => ({ addColorStop: () => { } }),
        isPointInPath: () => false, isPointInStroke: () => false,
        // ── Settable props ─────────────────────────────────────────────────────
        set fillStyle(_) { }, set strokeStyle(_) { }, set lineWidth(_) { },
        set lineCap(_) { }, set lineJoin(_) { }, set miterLimit(_) { },
        set globalAlpha(_) { }, set globalCompositeOperation(_) { },
        set font(_) { }, set textBaseline(_) { }, set textAlign(_) { },
        set shadowColor(_) { }, set shadowBlur(_) { },
        set shadowOffsetX(_) { }, set shadowOffsetY(_) { },
        set imageSmoothingEnabled(_) { }, set imageSmoothingQuality(_) { },
        set lineDashOffset(_) { }, set direction(_) { }, set letterSpacing(_) { },
        set wordSpacing(_) { }, set fontKerning(_) { }, set fontStretch(_) { },
        set fontVariantCaps(_) { }, set textRendering(_) { },
        setLineDash: () => { }, getLineDash: () => [],
        get canvas() { return { width, height }; },
    };
}

async function renderPdfToImages(buffer, pageLimit) {
    const pdfjs = _getPdfjsLib();
    const doc = await pdfjs.getDocument({ data: new Uint8Array(buffer) }).promise;
    const totalPages = doc.numPages;
    const limit = Math.min(pageLimit > 0 ? pageLimit : totalPages, MAX_VISION_PAGES);
    const images = [];

    for (let pageNum = 1; pageNum <= limit; pageNum++) {
        const page = await doc.getPage(pageNum);
        const viewport = page.getViewport({ scale: 1.0 });
        const width = Math.floor(viewport.width);
        const height = Math.floor(viewport.height);
        const rgbaBuffer = new Uint8ClampedArray(width * height * 4);
        const ctx = _buildFakeContext(rgbaBuffer, width, height);

        await page.render({
            canvasContext: ctx,
            viewport,
            canvasFactory: {
                create: (w, h) => ({ canvas: { width: w, height: h }, context: ctx }),
                reset: (obj, w, h) => { obj.canvas.width = w; obj.canvas.height = h; },
                destroy: () => { },
            },
        }).promise;

        const png = new PNG({ width, height });
        png.data = Buffer.from(rgbaBuffer.buffer);
        images.push(PNG.sync.write(png).toString("base64"));
    }
    return images;
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT SUFFICIENCY CHECK
// ─────────────────────────────────────────────────────────────────────────────

function hasUsableTextLayer(text, pageCount) {
    const threshold = Math.max(MIN_CHARS_PER_PAGE, pageCount * MIN_CHARS_PER_PAGE);
    return text.trim().length >= threshold;
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED PROMPT HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function buildTypeInstruction(questionType, count) {
    if (questionType === "identification") {
        return `Each card must have ONLY "question" and "answer" fields. Do NOT include "options".`;
    }
    if (questionType === "multiple_choice") {
        return `Each card MUST have "question", "answer", and "options" fields. "options" MUST be an array of EXACTLY 4 strings. The correct answer must be one of the 4 options.`;
    }
    const mcCount = Math.ceil(count / 2);
    const idCount = count - mcCount;
    return `You MUST produce EXACTLY ${mcCount} multiple-choice cards followed by EXACTLY ${idCount} identification cards.
- Multiple-choice cards MUST have "question", "answer", and "options" fields. "options" MUST be an array of EXACTLY 4 strings. The correct answer must be one of the 4 options.
- Identification cards MUST have ONLY "question" and "answer" fields. Do NOT include "options".`;
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT PATH  —  text-based PDFs and plain-text uploads
// ─────────────────────────────────────────────────────────────────────────────

function _buildTextPrompt(text, count, questionType) {
    return `Generate EXACTLY ${count} flashcards AND a short deck title based on the content.
${buildTypeInstruction(questionType, count)}
Return JSON ONLY, no markdown, no explanation:
${JSON_SCHEMA}

Text:
${text}`;
}

async function _callTextModel(text, count, questionType, model, endpoint, apiKey, extraHeaders = {}) {
    const response = await axios.post(
        endpoint,
        {
            model,
            messages: [{ role: "user", content: _buildTextPrompt(text, count, questionType) }],
            temperature: 0.7,
            max_tokens: 4096,
        },
        { headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json", ...extraHeaders } }
    );
    return extractJsonObject(response.data.choices[0].message.content);
}

async function runTextGeneration(text, count, questionType) {
    try {
        const result = await _callTextModel(
            text, count, questionType,
            GROQ_TEXT_MODEL, GROQ_ENDPOINT, groqKey.value()
        );
        return { result, provider: "groq" };
    } catch (err) {
        console.warn("⚠️ Groq text failed, falling back to OpenRouter:", err?.response?.data || err.message);
        const result = await _callTextModel(
            text, count, questionType,
            OPENROUTER_TEXT_MODEL, OPENROUTER_ENDPOINT, openRouterKey.value(), OPENROUTER_HEADERS
        );
        return { result, provider: "openrouter" };
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISION PATH  —  scanned / image-based PDFs
//
// Each page is rendered to a PNG image and sent to the vision model.
// Vision models accept image/png via data URIs in the image_url content block.
// ─────────────────────────────────────────────────────────────────────────────

function _buildVisionMessages(images, count, questionType) {
    return [{
        role: "user",
        content: [
            // Send each rendered page as a separate image block.
            ...images.map(b64 => ({
                type: "image_url",
                image_url: { url: `data:image/png;base64,${b64}` },
            })),
            {
                type: "text",
                text: `Read all text visible in these ${images.length} PDF page image(s) and generate EXACTLY ${count} flashcards AND a short deck title.
${buildTypeInstruction(questionType, count)}
Return JSON ONLY, no markdown, no explanation:
${JSON_SCHEMA}`,
            },
        ],
    }];
}

async function _callVisionModel(images, count, questionType, model, endpoint, apiKey, extraHeaders = {}) {
    const response = await axios.post(
        endpoint,
        {
            model,
            messages: _buildVisionMessages(images, count, questionType),
            temperature: 0.7,
            max_tokens: 4096,
        },
        { headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json", ...extraHeaders } }
    );
    return extractJsonObject(response.data.choices[0].message.content);
}

async function runVisionGeneration(images, count, questionType) {
    try {
        const result = await _callVisionModel(
            images, count, questionType,
            GROQ_VISION_MODEL, GROQ_ENDPOINT, groqKey.value()
        );
        return { result, provider: "groq-vision" };
    } catch (err) {
        console.warn("⚠️ Groq vision failed, falling back to OpenRouter vision:", err?.response?.data || err.message);
        const result = await _callVisionModel(
            images, count, questionType,
            OPENROUTER_VISION_MODEL, OPENROUTER_ENDPOINT, openRouterKey.value(), OPENROUTER_HEADERS
        );
        return { result, provider: "openrouter-vision" };
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN HANDLER
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// RATE LIMIT CHECK
// Uses a Firestore transaction so concurrent requests can't race past the limit.
// Returns { allowed: bool, remaining: int, resetAt?: ISO string }
// ─────────────────────────────────────────────────────────────────────────────
async function checkAndIncrementRateLimit(uid) {
    const db = admin.firestore();
    const ref = db
        .collection("users")
        .doc(uid)
        .collection("rateLimits")
        .doc("aiGeneration");

    return db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const now = Date.now();

        if (!snap.exists) {
            tx.set(ref, {
                dailyCount: 1,
                windowStart: admin.firestore.Timestamp.fromMillis(now),
            });
            return { allowed: true, remaining: DAILY_LIMIT - 1 };
        }

        const data = snap.data();
        const windowStart = data.windowStart?.toMillis() ?? now;
        const count = data.dailyCount ?? 0;

        // Window expired — reset and allow
        if (now - windowStart >= WINDOW_MS) {
            tx.set(ref, {
                dailyCount: 1,
                windowStart: admin.firestore.Timestamp.fromMillis(now),
            });
            return { allowed: true, remaining: DAILY_LIMIT - 1 };
        }

        // Over limit — reject
        if (count >= DAILY_LIMIT) {
            const resetAt = new Date(windowStart + WINDOW_MS).toISOString();
            return { allowed: false, remaining: 0, resetAt };
        }

        // Within limit — increment
        tx.update(ref, { dailyCount: admin.firestore.FieldValue.increment(1) });
        return { allowed: true, remaining: DAILY_LIMIT - count - 1 };
    });
}

exports.generateDeck = onRequest(
    { secrets: [groqKey, openRouterKey], cors: true, timeoutSeconds: 300, memory: "512MiB" },
    async (req, res) => {
        try {

            // ── Auth: verify Firebase ID token ────────────────────────────────
            const authHeader = req.headers.authorization;
            if (!authHeader?.startsWith("Bearer ")) {
                return res.status(401).json({ error: "Missing authentication token." });
            }
            let uid;
            try {
                const decoded = await admin.auth().verifyIdToken(authHeader.slice(7));
                uid = decoded.uid;
            } catch {
                return res.status(401).json({ error: "Invalid or expired authentication token." });
            }

            // ── Rate limit: atomic check + increment ──────────────────────────
            const rateLimit = await checkAndIncrementRateLimit(uid);
            if (!rateLimit.allowed) {
                return res.status(429).json({
                    error: "Daily limit reached",
                    remaining: 0,
                    resetAt: rateLimit.resetAt,
                    dailyLimit: DAILY_LIMIT,
                });
            }
            
            const pageLimit = parseInt(req.body.pageLimit, 10) || 0;
            const parsedCount = parseInt(req.body.questionCount, 10);
            const count = isNaN(parsedCount) ? 20 : Math.min(30, Math.max(1, parsedCount));
            const validTypes = ["identification", "multiple_choice", "both"];
            const questionType = validTypes.includes(req.body.questionType)
                ? req.body.questionType
                : "identification";

            let generationResult;

            // ── PDF ───────────────────────────────────────────────────────────
            if (req.body.fileType === "pdf" && req.body.fileBase64) {
                if (!req.body.fileBase64?.trim()) {
                    return res.status(400).json({ error: "PDF file data is empty. Please try uploading again." });
                }

                let buffer;
                try {
                    buffer = Buffer.from(req.body.fileBase64, "base64");
                } catch {
                    return res.status(400).json({ error: "Could not decode the PDF. The upload may be corrupted." });
                }
                if (!buffer.length) {
                    return res.status(400).json({ error: "The uploaded PDF file is empty." });
                }

                // ── Step 1: Try text extraction ───────────────────────────────
                let pageCount = 1;
                try {
                    const parsed = await pdfParse(buffer);
                    pageCount = parsed.numpages || 1;
                } catch (_) { }

                const extractedText = await extractPdfText(buffer, pageLimit);

                // ── Step 2: Route to text or vision path ──────────────────────
                if (hasUsableTextLayer(extractedText, pageCount)) {
                    // Text-based PDF — fast text path.
                    const text = extractedText.length > 12000
                        ? extractedText.slice(0, 12000)
                        : extractedText;
                    generationResult = await runTextGeneration(text, count, questionType);
                } else {
                    // Scanned/image PDF — render pages to PNG then send to vision model.
                    console.log(
                        `Vision path: ${extractedText.trim().length} chars from ${pageCount} page(s) — rendering to images.`
                    );
                    let images;
                    try {
                        images = await renderPdfToImages(buffer, pageLimit);
                    } catch (err) {
                        console.error("renderPdfToImages failed:", err.message);
                        return res.status(400).json({
                            error: "Could not render this PDF. It may be password-protected or corrupted. Try pasting the text instead.",
                        });
                    }
                    if (!images.length) {
                        return res.status(400).json({ error: "No pages could be rendered from this PDF." });
                    }
                    generationResult = await runVisionGeneration(images, count, questionType);
                }

                // ── Plain text ─────────────────────────────────────────────────────
            } else {
                let text = req.body.text;
                if (!text?.trim()) {
                    return res.status(400).json({ error: "No text content provided." });
                }
                if (pageLimit > 0) text = text.substring(0, pageLimit * 3000);
                if (text.length > 12000) text = text.slice(0, 12000);
                generationResult = await runTextGeneration(text, count, questionType);
            }

            const { result, provider } = generationResult;
            const cards = Array.isArray(result.cards) ? result.cards.slice(0, count) : [];
            return res.json({ title: result.title, cards, provider });

        } catch (error) {
            console.error("🔥 FULL ERROR:", error?.response?.data || error.message);
            return res.status(500).json({
                error: "AI generation failed",
                details: error?.response?.data || error.message,
            });
        }
    }
);
