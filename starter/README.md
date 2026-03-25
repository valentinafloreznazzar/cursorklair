# Carpeta `starter/` (referencia del hackathon)

La web desplegable y la API Gemini viven en la **raíz del repositorio** (`index.html`, `style.css`, `api/gemini.js`, `vercel.json`) para que Vercel funcione **sin** configurar “Root Directory”.

- Instrucciones: [`../DEPLOY.md`](../DEPLOY.md)
- Desarrollo local con chat: desde la raíz del repo, `npm install` y `npm run dev` (http://127.0.0.1:3000; rellena `.env.local` con `GEMINI_API_KEY`). Para `vercel dev`, usa `npm run dev:vercel`.
