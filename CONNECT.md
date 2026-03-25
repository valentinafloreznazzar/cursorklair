# Conectar GitHub + Vercel (hazlo una vez)

Desde esta máquina **no se puede** hacer push ni deploy sin tu login. Sigue estos pasos en orden.

## 1. GitHub — subir el código (`git push`)

**Opción A — Cursor**  
Source Control (icono ramas) → **Publish Branch** / **Sync** → inicia sesión con GitHub cuando lo pida.

**Opción B — Terminal** (ya tienes `gh` instalado con Homebrew):

```bash
cd /Users/GustavoFlorez/Documents/GitHub/cursor-hackathon
gh auth login
# Elige GitHub.com → HTTPS → Login with a web browser
git push -u origin main
```

Si el remoto no es tu repo, cámbialo:

```bash
git remote set-url origin https://github.com/TU_USUARIO/TU_REPO.git
git push -u origin main
```

## 2. Secrets en GitHub (para Vercel automático)

En **GitHub** → tu repositorio → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Nombre | Valor |
|--------|--------|
| `VERCEL_TOKEN` | [vercel.com/account/tokens](https://vercel.com/account/tokens) → Create |
| `GEMINI_API_KEY` | Tu clave de la API Gemini |

## 3. Deploy

- Haz **push a `main`** (o en **Actions** → workflow **Deploy to Vercel** → **Run workflow**).
- Cuando termine el job, abre el enlace en los **logs** del paso *Deploy to Vercel* (busca `https://` y `.vercel.app`), o entra en [vercel.com](https://vercel.com) → tu proyecto → **Deployments** → dominio **Production**.

Ese `https://….vercel.app` es el que van los jurados.

## Alternativa sin Actions

En [vercel.com](https://vercel.com) → **Add Project** → importa el repo de GitHub, raíz vacía, añade `GEMINI_API_KEY` en **Environment Variables** y **Deploy**. Vercel desplegará en cada push sin usar el workflow.
