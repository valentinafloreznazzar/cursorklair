# Hackathon submission · Klair

## 1. GitHub repository

This project is meant to live in a **public GitHub repo** so organizers and judges can review the code.

**If you still need to create the repo**

1. On GitHub: **New repository** (empty, no README if you already have one locally).
2. In this folder on your machine:

```bash
cd /path/to/cursor-hackathon
git remote remove origin   # only if you need to point to a *new* repo
git remote add origin https://github.com/<TU_USUARIO>/<NOMBRE_REPO>.git
git branch -M main
git push -u origin main
```

**If the remote is already correct**, only run:

```bash
git push -u origin main
```

Fill in your real repo URL for the form:

**→ Repo:** `https://github.com/<TU_USUARIO>/<NOMBRE_REPO>`

---

## 2. Vercel (link for judges — web demo)

The hackathon expects a **live URL**. The repo root already has `index.html`, `api/gemini.js`, and `vercel.json` (no subcarpeta “starter”).

### Opción A — Desde la terminal (URL en ~1 minuto)

1. Crea un token: [vercel.com/account/tokens](https://vercel.com/account/tokens) → **Create**.
2. En la carpeta del repo:

```bash
export VERCEL_TOKEN='pega_el_token'
export GEMINI_API_KEY='tu_clave_gemini'
npm run deploy
```

3. Al terminar, la CLI imprime **`Production: https://…vercel.app`** — **ese es el enlace definitivo** para el formulario y los jurados.

*(Si no pasaste `GEMINI_API_KEY`, añádela en Vercel → tu proyecto → Settings → Environment Variables y vuelve a desplegar.)*

### Opción B — Desde la web

1. [vercel.com](https://vercel.com) → **Add New** → **Project** → importa el repo de GitHub.
2. **Root Directory** vacío (raíz del repo).
3. **Environment Variables** → `GEMINI_API_KEY` (Production y Preview) → **Deploy**.
4. Copia el dominio que muestra el deploy (p. ej. `https://<proyecto>.vercel.app`).

Más detalle: [DEPLOY.md](./DEPLOY.md).

---

## 3. iOS app (Klair)

The native app is in **`Klair/`** (open `Klair.xcodeproj` in Xcode). It is **not** hosted on Vercel; judges mainly use the **Vercel URL** for the live demo unless you share TestFlight or a video separately.

To run Klair on device/simulator, set **`GEMINI_API_KEY`** in the Xcode scheme environment variables.
