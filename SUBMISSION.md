# Hackathon submission · Klair

## Listo para el formulario (copiar y pegar)

**Tu solución principal es la app iOS (Klair).** El jurado puede revisar el código en GitHub y, si les das un enlace o instrucciones, instalarla o verla en vivo.

| Campo (según lo que pida el Google Form) | Qué poner |
|------------------------------------------|-----------|
| **Repositorio GitHub** | https://github.com/valentinafloreznazzar/cursorklair — el proyecto iOS está en la carpeta **`Klair/`** (abrir `Klair.xcodeproj` en Xcode). Guía rápida: [Klair/QUICKSTART.md](./Klair/QUICKSTART.md). |
| **Enlace “deployed” / URL del proyecto** | https://cursor-hackathon-two.vercel.app — **demo web interactiva para el jurado**: las **6 pestañas** como en la app iOS (Pulse, Fuel, Sleep, Move, Klair, Vault), datos demo en `klair-demo-context.json`, y **Ask Klair** con el mismo **modo coach** que iOS (`klairAgentReply`: contexto JSON + conversación vía `POST /api/gemini` con `mode: "klairCoach"`). La app nativa sigue en `Klair/` (HealthKit, cámara, SwiftData). |
| **App iOS para el jurado (recomendado)** | **TestFlight:** pega el enlace en `testflight-config.js` (`window.KLAIR_TESTFLIGHT_URL`) y redespliega Vercel — el botón aparece en la landing. Copia la misma URL en el formulario si hay campo libre. Alternativa: **vídeo** (Loom/YouTube) o compilar con [QUICKSTART](./Klair/QUICKSTART.md). |

Cuando tengas el enlace de Apple, actualiza `testflight-config.js` y vuelve a hacer `git push` + deploy (o Actions si configuraste secretos).

**Opcional (GitHub Actions → Vercel):** en **Settings → Secrets → Actions** añade `VERCEL_TOKEN` y `GEMINI_API_KEY` si quieres deploy automático en cada push; si no, `npm run deploy` desde tu máquina sigue valiendo.

---

## 1. GitHub repository

This project is meant to live in a **public GitHub repo** so organizers and judges can review the code.

**Este fork ya está publicado:**

**→ Repo:** https://github.com/valentinafloreznazzar/cursorklair

Si clonas en otra máquina:

```bash
git clone https://github.com/valentinafloreznazzar/cursorklair.git
cd cursorklair
```

---

## 2. Vercel (página del proyecto Klair + enlace del formulario)

El hackathon pide una **URL en vivo**. En la **raíz del repo** hay `index.html` (centrada en la app iOS), `api/gemini.js` y `vercel.json` — sin subcarpeta “starter”. Esa URL es la cara pública del mismo proyecto que vive en **`Klair/`**.

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

**Producción actual de este proyecto:** https://cursor-hackathon-two.vercel.app

Más detalle: [DEPLOY.md](./DEPLOY.md).

---

## 3. iOS app (Klair) — lo que realmente entregas

La app nativa vive en **`Klair/`**. **Vercel no sirve para “instalar” la app iOS**; solo sirve para el enlace web que muchos formularios exigen.

**Cómo puede probarla el jurado (elige al menos una vía):**

1. **TestFlight (mejor para iPhone real):** en App Store Connect sube un build, activa **External Testing** (o Internal) y copia el **enlace público de invitación**. Pégalo en el formulario o en el README del repo.
2. **Código + Xcode:** con el repo público, quien tenga Mac puede seguir [Klair/QUICKSTART.md](./Klair/QUICKSTART.md), firmar con su equipo y ejecutar en simulador o dispositivo.
3. **Vídeo demo:** si no hay TestFlight a tiempo, un enlace a un vídeo de 1–2 min mostrando flujos clave (dashboard, comida, Ask AI) ayuda mucho al jurado.

**Claves en Xcode (modo real, no mock):** en el scheme de Klair, variables de entorno **`GEMINI_API_KEY`** (y las que uses de OpenAI/Oura según [Klair/README.md](./Klair/README.md)). Con **`DemoMode.useMockRemoteServices = true`** (por defecto) la app funciona sin APIs para una demo rápida.
