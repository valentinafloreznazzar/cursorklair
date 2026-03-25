/**
 * Vercel Serverless: Google Gemini for Klair.
 * - Simple: POST { prompt } (hackathon legacy).
 * - Coach (iOS-parity): POST { mode: "klairCoach", conversation, contextJSON? }
 */

const fs = require('fs')
const path = require('path')

function loadDefaultKlairContext() {
  try {
    const p = path.join(__dirname, '..', 'klair-demo-context.json')
    return fs.readFileSync(p, 'utf8')
  } catch {
    return '{}'
  }
}

function buildKlairCoachSystemInstruction(contextJSON) {
  return `You are Klair — the in-app AI brain connected to Google Gemini. You receive a FULL JSON snapshot of Marta's health app: profile, Oura (14d), meals, activity, energy logs, labs, cycle symptoms, HealthKit workouts/cycle, computed alerts, and correlations. Answer ANY question she asks about this data (sleep, food, PCOS, iron, readiness, stress, training, etc.).

Rules:
- Your name is Klair only.
- Never diagnose or prescribe; encourage clinicians for medical decisions. Meal micronutrients are estimates.
- Ground every answer in the Context JSON when relevant; cite concrete numbers (readiness, HRV, sleep score, lab values, meal patterns).
- Reply in the same language the user writes in (Spanish or English).

REQUIRED response shape (markdown, bold headings):
**Summary:** 1–2 sentences.
**Insights:** 2–4 sentences tied to her actual metrics.
**Recommendations:** 1–3 numbered actions.

Context JSON (full app state):
${contextJSON}`
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')

  if (req.method === 'OPTIONS') {
    return res.status(204).end()
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  const apiKey = process.env.GEMINI_API_KEY
  if (!apiKey || !String(apiKey).trim()) {
    return res.status(503).json({
      error: 'GEMINI_API_KEY is not set. Add it in Vercel Environment Variables.',
    })
  }

  const model = process.env.GEMINI_MODEL || 'gemini-2.5-flash'
  const key = encodeURIComponent(String(apiKey).trim())
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {}

    const coachMode = body.mode === 'klairCoach'

    if (coachMode) {
      const conversation = body.conversation
      if (!Array.isArray(conversation) || conversation.length === 0) {
        return res.status(400).json({ error: 'klairCoach requires non-empty conversation array' })
      }

      let contextJSON = body.contextJSON
      if (!contextJSON || !String(contextJSON).trim()) {
        contextJSON = loadDefaultKlairContext()
      }

      const systemInstruction = buildKlairCoachSystemInstruction(String(contextJSON).trim())

      const contents = []
      for (const msg of conversation) {
        const role = msg.role === 'user' ? 'user' : 'model'
        const text = msg.content != null ? String(msg.content) : ''
        if (!text.trim()) continue
        contents.push({ role, parts: [{ text }] })
      }

      if (contents.length === 0) {
        return res.status(400).json({ error: 'No valid messages in conversation' })
      }

      // Some Gemini models expect the first content block to be from the user (iOS UI shows assistant first).
      if (contents[0].role === 'model') {
        contents.unshift({
          role: 'user',
          parts: [
            {
              text: '[The user is in the Klair app web demo. Assistant messages above were already shown in the UI. Continue naturally as Klair.]',
            },
          ],
        })
      }

      const payload = {
        systemInstruction: { parts: [{ text: systemInstruction }] },
        contents,
        generationConfig: {
          temperature: 0.65,
          maxOutputTokens: 4096,
        },
      }

      const geminiRes = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      const data = await geminiRes.json()

      if (!geminiRes.ok) {
        const msg = data?.error?.message || JSON.stringify(data)
        return res.status(geminiRes.status).json({ error: msg, details: data })
      }

      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text || ''
      if (!text) {
        return res.status(502).json({ error: 'Empty response from Gemini', details: data })
      }

      return res.status(200).json({ text })
    }

    /* Legacy single-turn */
    const prompt = body.prompt || body.message || ''
    if (!String(prompt).trim()) {
      return res.status(400).json({ error: 'Missing prompt or message' })
    }

    const systemInstruction =
      body.systemInstruction ||
      `You are Klair, a supportive health coach for the Klair / Cursor Hackathon demo.
Answer in the same language as the user (Spanish or English).
Be concise, warm, and practical. Do not diagnose; encourage professional care when needed.`

    const payload = {
      systemInstruction: { parts: [{ text: systemInstruction }] },
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.65,
        maxOutputTokens: 2048,
      },
    }

    const geminiRes = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })

    const data = await geminiRes.json()

    if (!geminiRes.ok) {
      const msg = data?.error?.message || JSON.stringify(data)
      return res.status(geminiRes.status).json({ error: msg, details: data })
    }

    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text || ''
    if (!text) {
      return res.status(502).json({ error: 'Empty response from Gemini', details: data })
    }

    return res.status(200).json({ text })
  } catch (e) {
    return res.status(500).json({ error: e?.message || 'Server error' })
  }
}
