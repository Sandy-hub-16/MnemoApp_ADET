const axios = require("axios");
const pdfParse = require("pdf-parse");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const groqKey = defineSecret("GROQ_API_KEY");
const openRouterKey = defineSecret("OPENROUTER_API_KEY");

// --- Groq (Primary) ---
async function generateWithGroq(text, key, count) {
    const response = await axios.post(
        "https://api.groq.com/openai/v1/chat/completions",
        {
            model: "llama-3.1-8b-instant", // 14,400 RPD on free tier
            messages: [
                {
                    role: "user",
                    content: `Generate EXACTLY ${count} flashcards AND a short deck title based on the content.
Return JSON ONLY, no markdown, no explanation:
{"title":"...","cards":[{"question":"...","answer":"..."}]}

Text:
${text}`
                }
            ],
            temperature: 0.7,
            max_tokens: 2048
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
async function generateWithOpenRouter(text, key, count) {
    const response = await axios.post(
        "https://openrouter.ai/api/v1/chat/completions",
        {
            model: "openai/gpt-oss-120b:free",
            messages: [
                {
                    role: "user",
                    content: `Generate EXACTLY ${count} flashcards AND a short deck title based on the content.
Return JSON ONLY, no markdown, no explanation:
{"title":"...","cards":[{"question":"...","answer":"..."}]}


Text:
${text}`
                }
            ],
            max_tokens: 2048
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
    { secrets: [groqKey, openRouterKey], cors: true },
    async (req, res) => {
    try {
        let text;

        if (req.body.fileType === "pdf" && req.body.fileBase64) {
            const buffer = Buffer.from(req.body.fileBase64, "base64");
            const parsed = await pdfParse(buffer);
            text = parsed.text;
        } else {
            text = req.body.text;
        }

        if (!text || text.trim().length === 0) {
            return res.status(400).json({ error: "No text content could be extracted. Please provide a non-empty text or PDF file." });
        }

        const parsedCount = parseInt(req.body.questionCount, 10);
        const count = isNaN(parsedCount) ? 20 : Math.min(30, Math.max(1, parsedCount));

        let usedProvider;

        let result;
        try {
            result = await generateWithGroq(text, groqKey.value(), count);
            usedProvider = "groq";
        } catch (groqError) {
            console.warn("⚠️ Groq failed, switching to OpenRouter:", groqError?.response?.data || groqError.message);
            result = await generateWithOpenRouter(text, openRouterKey.value(), count);
            usedProvider = "openrouter";
        }

        const { title, cards } = result;
        return res.json({ title, cards, provider: usedProvider });

    } catch (error) {
        console.error("🔥 FULL ERROR:", error?.response?.data || error.message);
        return res.status(500).json({
            error: "AI generation failed",
            details: error?.response?.data || error.message
        });
    }
});