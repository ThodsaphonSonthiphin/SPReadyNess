# SPReadyNess design baseline

The minimal design language every SPReadyNess screen is built from. Tokens map to
Connect IQ constants wherever one exists — this is a watch app, not a web page, so
the baseline names what Monkey C can actually draw.

## Canvas

| Token | Value | Note |
|---|---|---|
| Screen | 390 × 390 | Forerunner 165 / 165 Music, identical |
| Shape | round | corners are not addressable |
| Safe inset | 12% of radius | keep text off the curve |

## Colour

**Background is pure black `#000000`.** Not near-black. On an AMOLED panel a black
pixel is an unlit pixel, so true black is both the highest-contrast choice and the
cheapest one for battery — the single most consequential token here.

### Status Band colours

| Band | Range | Colour |
|---|---|---|
| GO HARD | 80–100 | `#00E676` green |
| READY | 60–79 | `#C6D62B` lime |
| GO EASY | 40–59 | `#FF9500` amber |
| REST | 0–39 | `#FF3B30` red |

A Readiness Score is drawn in its own band's colour, so the number, the arc and the
band label always agree. The gradient bar and chart fills interpolate continuously
between these four anchors rather than stepping, matching how a score near a
boundary genuinely sits near a boundary.

### Neutrals

| Token | Value | Use |
|---|---|---|
| Primary text | `#FFFFFF` | headline numbers, band label |
| Secondary text | `#9E9E9E` | axis labels, dial captions, dates |
| Track | `#3A3A3C` | unfilled portion of any arc or ring |

## Type

Connect IQ font constants only — no pixel sizes, since the system picks the face.

| Role | Constant |
|---|---|
| Headline score | `FONT_NUMBER_THAI_HOT` |
| Band label | `FONT_MEDIUM` |
| Component Score in dial | `FONT_SMALL` |
| Dial caption, axis, date | `FONT_XTINY` |

## Components

- **Score arc** — 270° arc, opens at the bottom, filled clockwise in the band
  colour over the `Track` neutral.
- **Component dial** — small ring with the Component Score centred and a caption
  beneath. Ring fills proportionally in that component's own band colour.
- **Gradient bar** — horizontal red→green strip with a white position marker at the
  score. Used on the glance card, where an arc would not fit.
- **Chart** — line with gradient fill beneath, `Secondary text` axis labels, and a
  **break in the line** wherever a Daily Record is missing.

## Rules

- Never plot a missing day as zero; break the line (ADR 0006).
- Every score shown anywhere is coloured by its band — colour is never decorative.
- No screen scrolls; each is a fixed page reached by UP/DOWN.
