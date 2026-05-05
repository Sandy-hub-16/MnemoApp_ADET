const axios = require("axios");
const pdfParse = require("pdf-parse");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const groqKey = defineSecret("GROQ_API_KEY");
const openRouterKey = defineSecret("OPENROUTER_API_KEY");

// --- Groq (Primary) ---
async function generateWithGroq(text, key, count, questionType) {
    let typeInstruction;
    if (questionType === "identification") {
        typeInstruction = `Each card must have ONLY "question" and "answer" fields. Do NOT include "options".`;
    } else if (questionType === "multiple_choice") {
        typeInstruction = `Each card MUST have "question", "answer", and "options" fields. "options" MUST be an array of EXACTLY 4 strings. The correct answer must be one of the 4 options.`;
    } else {
        // both: explicit numbered split so the model cannot default to all-identification
        const mcCount = Math.ceil(count / 2);
        const idCount = count - mcCount;
        typeInstruction = `You MUST produce EXACTLY ${mcCount} multiple-choice cards followed by EXACTLY ${idCount} identification cards.
- Multiple-choice cards MUST have "question", "answer", and "options" fields. "options" MUST be an array of EXACTLY 4 strings. The correct answer must be one of the 4 options.
- Identification cards MUST have ONLY "question" and "answer" fields. Do NOT include "options" on identification cards.`;
    }

    const response = await axios.post(
        "https://api.groq.com/openai/v1/chat/completions",
        {
            model: "llama-3.1-8b-instant", // 14,400 RPD on free tier
            messages: [
                {
                    role: "user",
                    content: `Generate EXACTLY ${count} flashcards AND a short deck title based on the content.
${typeInstruction}
Return JSON ONLY, no markdown, no explanation:
{"title":"...","cards":[{"question":"...","answer":"...","options":["...","...","...","..."]}]}

Text:
${text}`
                }
            ],
            temperature: 0.7,
            max_tokens: 4096
        },
        {
            headers: {
                Authorization: `Bearer ${key}`,
                "Content-Type": "application/json"
            }
        }
    );

    let content = response.data.choices[0].message.content;
    content = content.replace(/```json|```/g, "").trim();
    return JSON.parse(content);
}

// --- OpenRouter (Fallback) ---
async function generateWithOpenRouter(text, key, count, questionType) {
    let typeInstruction;
    if (questionType === "identification") {
        typeInstruction = `Each card must have ONLY "question" and "answer" fields. Do NOT include "options".`;
    } else if (questionType === "multiple_choice") {
        typeInstruction = `Each card MUST have "question", "answer", and "options" fields. "options" MUST be an array of EXACTLY 4 strings. The correct answer must be one of the 4 options.`;
    } else {
        const mcCount = Math.ceil(count / 2);
        const idCount = count - mcCount;
        typeInstruction = `You MUST produce EXACTLY ${mcCount} multiple-choice cards followed by EXACTLY ${idCount} identification cards.
- Multiple-choice cards MUST have "question", "answer", and "options" fields. "options" MUST be an array of EXACTLY 4 strings. The correct answer must be one of the 4 options.
- Identification cards MUST have ONLY "question" and "answer" fields. Do NOT include "options" on identification cards.`;
    }

    const response = await axios.post(
        "https://openrouter.ai/api/v1/chat/completions",
        {
            model: "openai/gpt-oss-120b:free",
            messages: [
                {
                    role: "user",
                    content: `Generate EXACTLY ${count} flashcards AND a short deck title based on the content.
${typeInstruction}
Return JSON ONLY, no markdown, no explanation:
{"title":"...","cards":[{"question":"...","answer":"...","options":["...","...","...","..."]}]}


Text:
${text}`
                }
            ],
            max_tokens: 4096
        },
        {
            headers: {
                Authorization: `Bearer ${key}`,
                "Content-Type": "application/json",
                "HTTP-Referer": "https://mnemoapp.com"
            }
        }
    );

    let content = response.data.choices[0].message.content;
    content = content.replace(/```json|```/g, "").trim();
    return JSON.parse(content);
}

exports.generateDeck = onRequest(
    { secrets: [groqKey, openRouterKey], cors: true, timeoutSeconds: 300 },
    async (req, res) => {
    try {
        let text;

        if (req.body.fileType === "pdf" && req.body.fileBase64) {
            // Validate base64 payload is not empty
            if (!req.body.fileBase64 || req.body.fileBase64.trim().length === 0) {
                return res.status(400).json({ error: "PDF file data is empty. Please try uploading again." });
            }
            let buffer;
            try {
                buffer = Buffer.from(req.body.fileBase64, "base64");
            } catch (decodeErr) {
                return res.status(400).json({ error: "Could not decode the PDF file. The upload may be corrupted." });
            }
            if (buffer.length === 0) {
                return res.status(400).json({ error: "The uploaded PDF file is empty." });
            }
            let parsed;
            try {
                parsed = await pdfParse(buffer);
            } catch (parseErr) {
                console.error("pdf-parse error:", parseErr.message);
                return res.status(400).json({
                    error: "Could not read text from this PDF. It may be a scanned image, password-protected, or corrupted. Try a text-based PDF or paste the content as text instead.",
                });
            }
            text = parsed.text;
            // Truncate to 12,000 chars to stay within LLM context limits and avoid timeouts
            if (text.length > 12000) {
                text = text.slice(0, 12000);
            }
        } else {
            text = req.body.text;
            // Truncate plain text too
            if (text && text.length > 12000) {
                text = text.slice(0, 12000);
            }
        }

        if (!text || text.trim().length === 0) {
            return res.status(400).json({ error: "No text content could be extracted. Please provide a non-empty text or PDF file." });
        }

        const parsedCount = parseInt(req.body.questionCount, 10);
        const count = isNaN(parsedCount) ? 20 : Math.min(30, Math.max(1, parsedCount));

        // Normalise questionType — default to identification if absent/invalid
        const validTypes = ["identification", "multiple_choice", "both"];
        const questionType = validTypes.includes(req.body.questionType)
            ? req.body.questionType
            : "identification";

        let usedProvider;

        let result;
        try {
            result = await generateWithGroq(text, groqKey.value(), count, questionType);
            usedProvider = "groq";
        } catch (groqError) {
            console.warn("⚠️ Groq failed, switching to OpenRouter:", groqError?.response?.data || groqError.message);
            result = await generateWithOpenRouter(text, openRouterKey.value(), count, questionType);
            usedProvider = "openrouter";
        }

        const { title } = result;
        // Hard-cap: never return more cards than requested, regardless of what the LLM produced
        const cards = Array.isArray(result.cards) ? result.cards.slice(0, count) : [];
        return res.json({ title, cards, provider: usedProvider });

    } catch (error) {
        console.error("🔥 FULL ERROR:", error?.response?.data || error.message);
        return res.status(500).json({
            error: "AI generation failed",
            details: error?.response?.data || error.message
        });
    }
});