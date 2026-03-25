/**
 * Local dev: static files + POST /api/gemini (same handler as Vercel).
 * Loads .env.local into process.env — no Vercel login required.
 */

const http = require('http')
const fs = require('fs')
const path = require('path')
const geminiHandler = require('../api/gemini.js')

const ROOT = path.join(__dirname, '..')
const PORT = Number(process.env.PORT) || 3000

function loadDotEnvLocal() {
  const p = path.join(ROOT, '.env.local')
  if (!fs.existsSync(p)) return
  const text = fs.readFileSync(p, 'utf8')
  for (const line of text.split('\n')) {
    const t = line.trim()
    if (!t || t.startsWith('#')) continue
    const i = t.indexOf('=')
    if (i === -1) continue
    const key = t.slice(0, i).trim()
    let val = t.slice(i + 1).trim()
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1)
    }
    if (key) process.env[key] = val
  }
}

function mime(filePath) {
  const ext = path.extname(filePath).toLowerCase()
  const map = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json',
    '.png': 'image/png',
    '.ico': 'image/x-icon',
    '.svg': 'image/svg+xml',
  }
  return map[ext] || 'application/octet-stream'
}

function createVercelStyleRes(nodeRes) {
  const self = {
    _headers: Object.create(null),
    statusCode: 200,
    setHeader(name, value) {
      self._headers[name.toLowerCase()] = String(value)
    },
    status(code) {
      self.statusCode = code
      return self
    },
    json(obj) {
      const body = JSON.stringify(obj)
      const h = { ...self._headers, 'content-type': 'application/json; charset=utf-8' }
      nodeRes.writeHead(self.statusCode, h)
      nodeRes.end(body)
    },
    end(chunk) {
      if (!nodeRes.headersSent) {
        nodeRes.writeHead(self.statusCode, self._headers)
      }
      nodeRes.end(chunk !== undefined ? chunk : '')
    },
  }
  return self
}

loadDotEnvLocal()

const server = http.createServer(async (nodeReq, nodeRes) => {
  const url = new URL(nodeReq.url || '/', `http://127.0.0.1:${PORT}`)

  if (url.pathname === '/api/gemini') {
    const chunks = []
    for await (const c of nodeReq) chunks.push(c)
    const raw = Buffer.concat(chunks).toString('utf8')
    let body = {}
    if (raw) {
      try {
        body = JSON.parse(raw)
      } catch {
        body = {}
      }
    }
    const mockReq = {
      method: nodeReq.method,
      headers: nodeReq.headers,
      body,
    }
    const mockRes = createVercelStyleRes(nodeRes)
    try {
      await geminiHandler(mockReq, mockRes)
    } catch (e) {
      if (!nodeRes.headersSent) {
        nodeRes.writeHead(500, { 'content-type': 'application/json' })
        nodeRes.end(JSON.stringify({ error: e.message || 'Server error' }))
      }
    }
    return
  }

  const seg = url.pathname === '/' ? 'index.html' : url.pathname.slice(1)
  const filePath = path.resolve(ROOT, seg)
  if (!filePath.startsWith(ROOT + path.sep) && filePath !== ROOT) {
    nodeRes.writeHead(403).end()
    return
  }
  fs.readFile(filePath, (err, data) => {
    if (err) {
      nodeRes.writeHead(404, { 'content-type': 'text/plain' })
      nodeRes.end('Not found')
      return
    }
    nodeRes.writeHead(200, { 'content-type': mime(filePath) })
    nodeRes.end(data)
  })
})

server.listen(PORT, () => {
  console.log(`Klair local: http://127.0.0.1:${PORT}/  (POST /api/gemini · .env.local)`)
})
