# Starling's Last Lap — original enemy art

Two new mechanical enemy families for the orbital roller rink/night racecourse.
Neither reuses the old infernal silhouettes or the unintegrated White Hunger sheets.
Made with the built-in image_gen tool; exact original and repair prompts are in `PROMPTS.json`.

## Delivered frames

Each family has **48 authored RGBA frame PNGs and 48 matching 32-bit alpha BMPs**.
The BMP headers have a 124-byte DIB with explicit channel masks; SDL's real decoder
was checked against every PNG and preserved every RGBA pixel exactly.

`<family>/<family>-dir-<0..7>-<pose>.png` and `.bmp`.

| Direction | View |
|---|---|
| 0 | Front |
| 1 | Front-right |
| 2 | Right |
| 3 | Back-right |
| 4 | Back |
| 5 | Back-left |
| 6 | Left |
| 7 | Front-left |

| Pose | Lap Counter | Bumper Hound |
|---|---|---|
| `approach-a` | Open fork, relaxed score panel and folded token pod | Relaxed foam ring on separated skates |
| `approach-b` | Small panel/wing rock, base grounded | Different pad wobble, base grounded |
| `tell` | Coral flag rises, 888 readout, token slot aligns | Bumpers open, dark front gap, brake flags rise |
| `release` | Panel and pod recoil, active flag retracts | Pads thrust together forward, flags retract |
| `recovery` | Panel drops/rocks, pod folds down | Skates turn into brake stance, flags lower sideways |
| `corpse` | Frame/panel collapsed low on inert cart | Foam/chassis settles with skates splayed inert |

These are **six deliberate pose keys**, with only two approach keys. Do not describe
them as a four-stride/full motion animation. A restrained A/B/A/B approach loop
repeats the two real keys; it does not supply additional unique poses. Pain,
interruption and multi-stage death have no separately authored images yet.
If an initial integration uses recovery as a short mechanical recoil, document it
as reuse of that pose and preserve the actual behavior/event outcome.

## Import contract

- Every final frame is 384×256, with a shared 256×256 source-image scale on a 1.5:1 canvas.
- All frames have the same grounded contact at pixel y255 and engine bottom-origin pivot `(0.5,0)`.
- Import uses exact 181×181 source cells from 1448×1086 eight-by-six sheets. It does not trim
  body width or independently resize poses. Per-cell vertical offset aligns floor contact;
  lateral layout stays authored.
- Source alpha is converted to a binary cutout at 128; dark internal colors stay opaque.
  Transparent RGB is cleared. **Disable the native RGB-near-black transparency key.**
  The current `texture_from_bmp(..., true)` path destroys dark interiors and is unsuitable.
- Use nearest filtering and explicit alpha cutout. No baked emissive body or flash is present.
- Keep facings for tell, release, recovery and corpse. The current native combat importer
  ignores direction, so routing all attacks to its old front-facing combat atlas loses
  these delivered views.
- Lap Counter's broad empty fork window is genuinely transparent. Its token pod is separated
  by negative space. Targeting geometry should declare how panel/posts/launcher receive hits;
  a generic solid ellipse through the empty center is a visual/trace mismatch.
- Hold maps to Lap Counter: anchored set, held committed aim, one token shot, recovery.
  Cross maps to Bumper Hound: direct grounded approach, bounded committed rush, stopped recovery.
  The art does not authorize homing, pathfinding, bouncing, jumping or steering after commitment.
- Numeral 888 is a preparation graphic, not a live gameplay score/health display.

## Visibility review and limits

Contact sheets show every direction/state at 32- and 64-pixel **canvas height**, on dark
plum and pale rink-compatible backgrounds. The silhouettes clearly differ in footprint:
open tall fork versus broad low foam ring. The low bumper body occupies about half the
canvas height, so its actual body pixels are fewer than a tall target at the same distance.
Its raised tell flags retain a distinct two-post outline; front pad gaps carry the same cue.

Lap Counter's thin exact side profile and detached launcher become small at 32 pixels;
the score digits are not readable there. Treat flag/launcher pose and silhouette as the
cue, reserve the numeral detail for closer views, and review supported engagement distance
in-game. The generator's exact side wheel/anatomical projection is an authored approximation,
not a rig-derived physical turnaround. Its rear panel is visibly a reverse mechanism;
the rear and front-left direction errors in the first sheet were repaired before import.

These inspections are static asset checks, not a claim of player cue-recognition rates or
final in-game visibility. World fill, viewmodel/FX masking, perspective, canvas world size,
colliders and event timing still need the integrating game's actual review. Preserve the
body/tell under combined weapon and effect masks, especially lower bumper threats.

`manifest.json` records dimensions, directions, source offsets and frame alpha/bounding data.
`extract_frames.py` reproducibly imports the two sheets. `check_sdl_alpha.py` checks the
actual SDL loading path. No renderer, old asset, build rule or executable was changed here.
