const axios = require("axios");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const groqKey = defineSecret("GROQ_API_KEY");
const openRouterKey = defineSecret("OPENROUTER_API_KEY");

// --- Groq (Primary) ---
async function generateWithGroq(text, key) {
    const response = await axios.post(
        "https://api.groq.com/openai/v1/chat/completions",
        {
            model: "llama-3.1-8b-instant", // 14,400 RPD on free tier
            messages: [
                {
                    role: "user",
                    content: `Generate EXACTLY 20 flashcards AND a short deck title based on the content.
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
async function generateWithOpenRouter(text, key) {
    const response = await axios.post(
        "https://openrouter.ai/api/v1/chat/completions",
        {
            model: "meta-llama/llama-3.1-8b-instruct:free",
            messages: [
                {
                    role: "user",
                    content: `Generate EXACTLY 20 flashcards AND a short deck title based on the content.
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

exports.generateDeck = onRequest({ secrets: [groqKey, openRouterKey] }, async (req, res) => {

    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
        return res.status(204).send("");
    }

    try {
        const text = req.body.text;
        let usedProvider;

        let result;
        try {
            result = await generateWithGroq(text, groqKey.value());
            usedProvider = "groq";
        } catch (groqError) {
            console.warn("⚠️ Groq failed, switching to OpenRouter:", groqError?.response?.data || groqError.message);
            result = await generateWithOpenRouter(text, openRouterKey.value());
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