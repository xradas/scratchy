# Eye Sore — Furnace Descent enemy redesign

Original infernal creatures, authored with the built-in image_gen tool. Final sources,
original pre-repair sources and all four prompts are retained here. No old demon,
White Hunger creature or Starling prop image was used as a generation/edit input.

The inspected existing enemy art is glossy stocky red/black horned armor and a flame-ringed
humanoid caster. These two additions retain the descent's crimson/soot/bone value vocabulary
while changing anatomy, silhouette and action. Reference-direction lessons applied:
visible dangerous function, different movement pressure, broad value masses, decisive tells.

## Families and the exact keys

**Hookrunner:** crooked grounded red-sinew biped with two enormous pale rake forearms.
Its lean leg/core mass reads as a quick melee pursuer. Both arms rising above the shoulders
make a wide open M-shaped held tell; the release projects them forward and recovery plants
them low. Raised claws are attack reach imagery, not a wider permanent body collider.

**Soot Bellower:** broad nonhumanoid bell trunk on three grounded support feet. Paired bone
fans fold down in approach and unfold horizontally for the ranged preparation. The forward
throat opens for release, then closes. Rear views communicate preparation through fan
expansion; the erroneous backward-facing aperture was repaired. Fans are anatomical vents,
not wings authorizing flight. A visible fire pellet can provide lane pressure; persistent
area fire, spreads and homing are separate mechanics, not implied by the sprite.

`<family>/<family>-dir-<direction>-<pose>.png` and matching `.bmp`.

| Pose index | Filename key | Intended mapping |
|---|---|---|
| 0 | `approach-a` | First grounded contact/weight key |
| 1 | `approach-b` | Different contact/weight key |
| 2 | `tell` | Hold this pose for the real preparation window |
| 3 | `release` | Actual slash or projectile event belongs here |
| 4 | `recovery` | Grounded unloading/arms or fans folding back |
| 5 | `corpse` | Final inert floor-aligned death image |

Direction order is native **front, front-right, right, back-right, back, back-left, left,
front-left** for indices 0–7. The sheets contain six authored keys per facing, 48 per family.
Generated views approximate the intended eight-way projection; the corrected front-left
quarter is relatively shallow and is not a mathematically certified 45-degree rig render.

Only **two approach/contact keys** are delivered. They support a deliberately coarse two-key
pose rhythm or stop/set movement; they do not establish a complete gait or additional unique
stride frames. Soot's A/B difference is small, suitable for weight/brace changes.
There is one final corpse pose and no authored falling sequence, pain sequence or gib sequence.
Do not describe reused recovery/approach keys as newly authored pain/death animation.
Direction/state selection must retain the actual facing through preparation and release.

## Fixed canvas and alpha contract

- 96 PNG/BMP frame pairs, **384×256** for every state/view, fixed 1.5:1 render canvas.
- Shared source scale: 181 authored pixels → 256 imported pixels horizontally; no per-pose
  or per-direction enlargement. Pale fans/arms may extend beyond the body targeting shape.
- Ground contact pixel **255**, engine bottom-origin pivot **(.5,0)**, baseline zero.
  Horizontal placement stays authored. Final ground alignment follows the actual body mask.
- Masters are exact 1448×1086 eight-by-six grids. A 12-pixel vertical overscan recovers actual
  toe tips that cross a row gutter. The largest connected body component removes neighboring
  row fragments. The mask does not infer anatomy, erase palette colors or generate poses.
- RGBA alpha is a binary cutout from source alpha at 128; dark flesh and outlines stay opaque.
  Transparent RGB is cleared. Use nearest filtering and **disable RGB-near-black keying**.
- The 32-bit BMPs contain real alpha masks. `check_sdl_alpha.py` checks the same SDL decoder
  used by the native game against each PNG, including every RGBA pixel.
- Keep body targeting and attack reach separate. Cosmetic fan deployment is not an armor
  break, new weak point or expanded damage volume. Mouth/body glow is not a visibility floor.
- Render scale is not body scale: most idle body mass occupies about 80% of canvas height.
  A canvas near 2.45 world units is a starting integration estimate, not selected balance.
  Review body/camera/targeting and actual contact position together in the later wave.

## Readability and combat limits

Tactical sheets show both families/state sequences at **32, 48 and 64 pixels of canvas height**
against dark descent-compatible and pale warm backgrounds. At 32 the pale arm/fan silhouette
and large held-pose changes remain distinct; small flesh/head details are lost. **48 pixels
is the recommended minimum active-combat canvas height**, with 64 for close tell/release
assessment. This is static art judgment, not a measured player-recognition threshold.

Hookrunner's narrow red torso and Soot's soot-black rear body need broad fill/quiet backdrops;
their pale external masses provide shape continuity from rear views. Fire FX should remain
compact around release and clear before the next tell, and the combined viewmodel/effect
mask must retain the raised arms or fan spread. Neither sprite includes baked projectile,
flash cloud or a persistent flame halo.

The two poses are not evidence that a fast run feels good, a bounded rush has a legal dodge
window, or a projectile is fairly timed. Integration owns speed, target commitment, LOS,
event timing, interruption and damage. Avoid tracking after the held preparation or damage
through cover. Corpse is inert; active tell/throat emission ends on terminal state.

`manifest.json` records every file, pose/view, source component/offset, bounds and alpha.
`extract_frames.py` reproducibly formats the sources; `check_sdl_alpha.py` validates the
native decoder. Contact sheets are `hookrunner-contact-sheet.png`,
`soot-bellower-contact-sheet.png`, and `tactical-{32,48,64}-{dark,light}.png`.

No old sprites, engine source, build rules or executable were changed by this asset task.
