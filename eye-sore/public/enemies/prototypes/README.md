# Sprite prototype: Kiln Wretch

This folder contains a review-only original concept for a low-tier fire-caster enemy. The generated source sheet is preserved as received. It is deliberately isolated from the production `sources/`, `directional/`, and native `linux-game/assets/` directories; nothing here is loaded by the game.

## Files

- `kiln-wretch-directional-concept-source.png` — untouched generated source, 1774×887 RGBA.
- `kiln-wretch-contact-sheet.png` — labeled preview of that sheet, 1740×900. The preview has an opaque dark backing for readability; use the source file to inspect transparency.

## Frame key

The source is intended to read as an 8-column × 4-row sheet. Directions run left to right:

| Column | View |
| --- | --- |
| 0 | Front |
| 1 | Front-right |
| 2 | Right |
| 3 | Back-right |
| 4 | Back |
| 5 | Back-left |
| 6 | Left |
| 7 | Front-left |

Rows top to bottom are intended as: 0 neutral/contact pose, 1 stride A, 2 passing/low stride, 3 stride B. This is only a reading key, not a verified animation specification. Inspect the actual frames before deciding how to remap them.

## Art direction

The creature is a compact ash-and-ceramic fire-caster with a horned kiln mask, ember eye slits, a cracked pale shell, ragged cinder mantle, and an ember core. Its hunched outline and warm focal points should make it readable at distance as a lightweight ranged threat. It is an original Eye Sore concept; it must not be traced over Doom artwork or treated as a reproduction of a Doom character.

## Production frame guide

The native renderer currently expects each production enemy frame on a **384×256 px transparent canvas**, with the foot baseline anchored to the bottom. Preserve a fixed apparent scale across all directions and states. Keep the sprite centered on a consistent ground-contact point; do not independently auto-center poses. Keep alpha clean around horns, shoulder fragments, and fire. A future approved production set should include 8 views × 4 visibly distinct walk poses, then separate 4-frame pain, attack, death, and gib sequences. Record actual clip timing, attack event frame, world height, baseline, and hitbox alongside the reviewed art.

## Not production-ready

- The generated sheet is **1774×887**, so nominal cells are 221.75×221.75 px. The grid does not divide into integer-sized cells; automated equal-grid crops may drift by a pixel between rows/columns. Do not feed this file directly to the existing `8x4@` asset builder.
- The rendering is painterly/high-detail rather than crisp clustered pixel art. It needs a deliberate pixel-art cleanup or a redraw to match the intended retro game style.
- Rows 1–3 are similar hunched strides with limited, hard-to-read leg/arm changes. The sheet does not yet prove four distinct, smoothly cycling poses. No frame should be considered a final walk frame until reviewed at gameplay scale.
- Directional consistency, silhouette scale, foot alignment, and left/right profile consistency are unverified. Back-facing frames show a different amount of visible facial glow and horn profile; decide if that is intentional.
- The generated output contains no attack, pain, death, gib, or casting event poses. It is only a walk-sheet concept.
- Transparency exists in the preserved source, but inspect alpha edges for colored fringe and stray pixels before any sprite extraction. The labeled contact sheet is opaque by design.
- There are no production crops in this folder. Do not copy the source or contact sheet into the engine asset path as if it were a finished atlas.

## Review checklist

1. Approve or revise the creature silhouette and material palette at native gameplay scale.
2. Redraw or clean the poses into an exact integer-grid master and keep the 384×256 destination canvas/foot baseline fixed.
3. Review all 32 walk frames as a looping contact sheet before export; reject repeated or directionally inconsistent poses.
4. Create and review the combat states as separate sequences.
5. Only after review, export frames and run the project validators; then tune world dimensions and collision profiles to the reviewed art.
