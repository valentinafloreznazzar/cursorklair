# Klair design tokens (Fuel / Chef / Luna)

## No-line rule

Prefer **fills, corner radius, and soft shadow** over visible strokes. Avoid `stroke` / hairline borders on cards and primary actions unless required for accessibility.

## Primary actions

- **Soft Slate** `#4E5E6D` — `KlairTheme.softSlate` for primary buttons (Save, Generate Recipes).
- **Electric Cyan** `#00D4FF` — `KlairTheme.cyan` for active segment states, focused field labels, and emphasis accents.

## Surfaces

- Cards: `KlairTheme.card` + `cloudShadow`.
- Inputs: `KlairTheme.surfaceHigh` at reduced opacity inside rounded rectangles (no border).
