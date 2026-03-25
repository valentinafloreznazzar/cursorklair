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

The hackathon expects a **live URL**. For this repo, deploy from the **repository root** (not a subfolder): `index.html`, `api/gemini.js`, `vercel.json`.

1. [vercel.com](https://vercel.com) → **Add New** → **Project** → import your GitHub repo.
2. Leave **Root Directory** empty (default = repo root).
3. **Environment Variables** → add **`GEMINI_API_KEY`** (your Google AI / Gemini key) for Production and Preview.
4. Deploy.

After the first successful deployment, Vercel shows the production URL. It usually looks like:

**→ Judges’ live link:** `https://<nombre-del-proyecto>.vercel.app`

*(That exact URL appears in Vercel → your project → **Domains** / the deployment summary. Copy it into the Google Form.)*

Local details: see [DEPLOY.md](./DEPLOY.md).

---

## 3. iOS app (Klair)

The native app is in **`Klair/`** (open `Klair.xcodeproj` in Xcode). It is **not** hosted on Vercel; judges mainly use the **Vercel URL** for the live demo unless you share TestFlight or a video separately.

To run Klair on device/simulator, set **`GEMINI_API_KEY`** in the Xcode scheme environment variables.
