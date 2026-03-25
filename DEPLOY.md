# Deploy en Vercel (sin configurar Root Directory)

El sitio y `api/gemini.js` están en la **raíz del repositorio**. Al importar el repo en [vercel.com](https://vercel.com), deja **Root Directory vacío** (o `.`).

1. **Importar** el repositorio desde GitHub/GitLab y desplegar con los valores por defecto.
2. **Environment Variables** (Settings → Environment Variables), para *Production* y *Preview*:
   - `GEMINI_API_KEY` — clave de Google AI Studio / Gemini API.
   - Opcional: `GEMINI_MODEL` — por defecto `gemini-2.5-flash`.
3. **Redeploy** el último deployment si añadiste la variable después del primer deploy.

**No subas la clave al repositorio.** Usa solo Vercel o `.env.local` en local.

## Probar en local

```bash
cp .env.example .env.local
# Edita .env.local: GEMINI_API_KEY=...
npm run dev
```

Abre **http://127.0.0.1:3000/** y prueba el chat. (`npm run dev` usa un servidor local; para el flujo oficial de Vercel CLI usa `npm run dev:vercel`.)

## Deploy desde CLI

```bash
npx vercel
```

La primera vez enlaza el proyecto; las variables de entorno siguen gestionándose en el dashboard de Vercel (o con `vercel env add`).
