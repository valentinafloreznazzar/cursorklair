# Entregar Klair al jurado (app iOS completa)

La forma **más fácil y estándar** de que alguien con **iPhone** pruebe la app **sin Xcode** es **TestFlight** (Apple). No hay otra plataforma que instale una app nativa iOS de forma tan simple para muchas personas: un enlace + app TestFlight (gratis en el App Store).

## Requisitos (una vez)

- Cuenta del **Apple Developer Program** (de pago, [developer.apple.com](https://developer.apple.com)) asociada a tu Apple ID.
- **Xcode** en Mac con el proyecto `Klair.xcodeproj` abriendo y compilando bien.
- **Bundle ID** fijo (p. ej. `com.tuorg.klair`) registrado en el portal de desarrolladores y coincidente con el de Xcode (**Signing & Capabilities**).

## Pasos resumidos

### 1. Crear la ficha de la app (si no existe)

1. Entra en [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**.
2. Elige **iOS**, nombre visible (p. ej. Klair), idioma, el **Bundle ID** que usas en Xcode, SKU interno cualquiera.

### 2. Subir un build desde Xcode

1. Abre `Klair.xcodeproj`, esquema **Klair**, destino **Any iOS Device (arm64)** (no simulador).
2. Menú **Product → Archive** y espera a que termine el archivo.
3. En el organizador: **Distribute App** → **App Store Connect** → **Upload** (opciones por defecto suele bastar).
4. Cuando suba, en App Store Connect el build aparece en **TestFlight** tras procesarse (10–30 min, a veces más).

### 3. Habilitar TestFlight para el jurado

**Opción A — Enlace público (lo más cómodo para muchos jurados)**

1. En App Store Connect → tu app → **TestFlight**.
2. Crea un grupo de **External Testing** (prueba externa).
3. Añade el build al grupo. La **primera vez** con prueba externa Apple puede pedir **información de cumplimiento Beta** (preguntas cortas); envía y espera la revisión beta (suele ser rápida).
4. Activa **Public Link** para ese grupo y copia la URL (`https://testflight.apple.com/join/...`).

**Opción B — Invitación por email**

1. Mismo grupo externo, añade emails de jurados como testers. Reciben invitación en el correo.

### 4. Poner el enlace donde el jurado lo vea

1. Pega la URL en `testflight-config.js` en la raíz del repo:

   `window.KLAIR_TESTFLIGHT_URL = 'https://testflight.apple.com/join/XXXXXXXX';`

2. Haz commit, push y deploy en Vercel (o deja el enlace también en el Google Form del hackathon).

En la landing aparecerá el botón **Abrir en TestFlight** debajo del simulador web.

## Qué hace el jurado en el iPhone

1. Instalar **TestFlight** desde el App Store (si no la tiene).
2. Abrir tu enlace `testflight.apple.com/join/...` en Safari.
3. Aceptar la prueba e instalar **Klair**.

## Si no tienes cuenta de pago de desarrollador

- **No hay** una forma oficial de distribuir la `.ipa` a desconocidos sin TestFlight / App Store / dispositivos registrados (ad hoc).
- Plan B: jurado con **Mac** sigue [QUICKSTART.md](./QUICKSTART.md) (simulador) o un **vídeo** recorriendo la app.

## Alternativas (peor experiencia que TestFlight)

| Opción | Problema |
|--------|----------|
| **Ad hoc** | Necesitas el UDID de cada iPhone; no escala. |
| **Enlaces tipo “instalar IPA”** | Perfil de confianza, revocaciones, poco fiable para jurado. |
| **Solo web** | No es la app nativa; sirve como complemento, no sustituto. |

**Conclusión:** para “app iOS completa” que el jurado **use y juzgue** en su teléfono, **TestFlight + enlace público** es el camino más fácil.
