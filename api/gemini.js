/**
 * Vercel Serverless (Node): Google Gemini generateContent.
 * Configure GEMINI_API_KEY in Vercel → Project → Settings → Environment Variables.
 */

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
