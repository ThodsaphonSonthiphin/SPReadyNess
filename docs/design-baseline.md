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
| Track | `#3A3A3C` | unfilled portion of any arc or ring, live states |
| Dim track | `#262628` | the same, in the uncoloured and empty states |

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
  colour over the `Track` neutral. Two variants:
  - **Solid** — a Morning Score. The authoritative daily number.
  - **Dashed** — a Now Score. Same geometry and band colour, dashed stroke, so a
    live reading can never be mistaken for the morning's at a glance (ADR 0010).
- **Component dial** — small ring with the Component Score centred and a caption
  beneath. Ring fills proportionally in that component's own band colour.
- **Gradient bar** — horizontal red→green strip with a white position marker at the
  score. Used on the glance card, where an arc would not fit.
- **Chart** — line with gradient fill beneath, `Secondary text` axis labels, and a
  **break in the line** wherever a Daily Record is missing.

## The uncoloured state

A score is drawn in `Secondary text` grey instead of its Status Band colour whenever
the app cannot stand behind it as advice:

| Condition | Why |
|---|---|
| Stale — no Daily Record for today (ADR 0009) | the number is a record, not today's advice |
| RHR absent, so the override could not run (ADR 0005) | the safety check did not happen |

In both cases the number is still shown, accompanied by its age or reason. Colour is
what carries the recommendation in this design, so withholding colour is how the app
says "here is the figure, but do not act on it."

## The empty state

A third state, distinct from both coloured and uncoloured: **no Daily Record has ever
existed**. There is no number, no arc fill and no colour — only the caption
`FIRST SCORE TOMORROW MORNING` (ADR 0015).

A zero or a placeholder is forbidden here. On a 0–100 scale coloured by band, a zero
is a legitimate REST morning, and the two must never look alike.

## Rules

- Never plot a missing day as zero; break the line (ADR 0006).
- A score is coloured by its band **unless** it is in the uncoloured state above.
  Colour is never decorative and never appears on a number the app cannot vouch for.
- No screen scrolls; each is a fixed page reached by UP/DOWN.
