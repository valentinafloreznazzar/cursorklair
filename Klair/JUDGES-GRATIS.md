# Jurado sin pagar Apple Developer (0 €)

Apple **no ofrece** una forma oficial de colocar tu app en el iPhone de **muchas personas** sin el **Apple Developer Program** de pago (~99 USD/año). TestFlight externo, subir builds y App Store **requieren** esa cuenta.

Lo que **sí puedes hacer gratis**:

---

## 1. Jurado con Mac (app nativa completa) — lo mejor si no pagas

- **Xcode** es gratis (Mac App Store).
- El jurado clona el repo, abre `Klair.xcodeproj`, elige un **simulador** iPhone y pulsa **Run**.
- La app corre **completa** en el simulador con datos mock (sin Oura/APIs reales si no configuran claves).

**Guía:** [QUICKSTART.md](./QUICKSTART.md)

*Ideal para jurado técnico o con Mac en la universidad.*

---

## 2. Demo web (navegador, cualquier ordenador)

- La URL de **Vercel** del repo: mismas pestañas que la app, datos demo, **Ask Klair** con Gemini.
- No es el binario iOS, pero el jurado **usa** el producto sin Mac ni Apple de pago.

**Enlace:** el que tengáis en `SUBMISSION.md` / deploy del proyecto.

---

## 3. Vídeo o llamada en vivo (gratis)

- **YouTube** (no listado), **Loom** (plan gratuito con límites), **QuickTime** en Mac grabando el simulador.
- En la presentación enseñáis flujos reales en **simulador** o en **vuestro** iPhone con cable.

---

## 4. Un solo iPhone físico sin cuenta de pago (muy limitado)

Con **Apple ID gratis** en Xcode (**Personal Team**) podéis instalar la app en **vuestro** iPhone conectado por USB, pero:

- La app **caduca** al cabo de **unos días** y hay que reinstalar desde Xcode.
- **No** podéis dar un enlace para que 10 jurados instalen solos en su iPhone.

Sirve para enseñar en mano en la presentación, no para “dejarla instalada al jurado” a distancia.

---

## 5. Cosas que parecen “gratis” pero no sirven bien al jurado

| Idea | Problema |
|------|----------|
| Enviar el `.ipa` por Telegram/Drive | Sin firma de Apple adecuada, el iPhone del jurado no lo instala de forma normal. |
| AltStore / sideload | Cuenta gratis = **7 días** de validez por instalación; el jurado necesita flujo técnico; poco fiable para evaluación. |

---

## Resumen

| Objetivo | Opción gratis |
|----------|----------------|
| Que prueben la **app iOS real** | Mac + **Xcode** + simulador → [QUICKSTART.md](./QUICKSTART.md) |
| Que prueben **funcionalidad** sin Mac | **Web Vercel** del proyecto |
| Presentación / storytelling | **Vídeo** o demo en vivo con **tu** iPhone |

Si el hackathon **subvenciona** o **agrupa** una cuenta de desarrollador, entonces **TestFlight** sigue siendo lo más cómodo para jurado solo con iPhone: [TESTFLIGHT-JUDGES.md](./TESTFLIGHT-JUDGES.md).
