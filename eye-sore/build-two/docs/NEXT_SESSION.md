# Resume checkpoint — Pale Ward sprite review, 9 October 2026

Latest user feedback: the approved earlier 2D concept art should have been used; rough procedural 3D studies lost the look and seemed a waste. The correction is implemented in source and a separate Linux package. Do not restart preservation or Git authentication; both are complete.

Current identity: **The Pale Ward / corrupted biotech**, explicitly selected by the user on 9 October. Ash Citadel remains a future direction. The approved generated board is the quality target; visual/gameplay acceptance of this new pass is still pending.

## Current playable art

assets/combat_art.json now selects transparent sprite adaptations of the exact approved board. Two generated eight-pose frontal atlases represent Unsealed/Vessel idle, walk, committed attack, recovery, pain, falling death and persistent corpse. Three generated four-pose view-weapon atlases represent pistol, shotgun and black-glove melee. Main menu uses the byte-original approved scene above its static concept HUD; Abelian remains menu-only.

All PNGs are unchanged built-in ImageGen edit outputs. Exact prompts, original results, hashes and source material are under concepts/sprite-art-v1. Runtime authored atlas regions/scales/markers and per-frame foot pivots register them without Python image editing. Older 3D studies and all prior binaries remain preserved.

Sprite visuals and query-only alpha triangles share a camera-facing pivot. Opaque organic regions route flesh; conservative manually traced Vessel collar/rib strips route armor. Transparent gaps miss even where a movement capsule exists. Corpses disable all hurt geometry. Bounded 128×192 raster approximates finer source detail. Resource-path keyed caches remain at 16 pose entries/two images across scene retries; pre-cache uses the same pixel scale as Sprite3D rendering.

## Earlier gameplay fixes retained

Doorway floor gap closed; exact visible/physical ramp replaces mismatched stairs. Grounded bidirectional portal/ramp traversal and wall/door blocking were verified. Mouse uses unscaled screen-relative motion, fixed aiming camera, cosmetic weapon recoil and exact crosshair. Default 90 now means 90 horizontal degrees.

Pistol20/.32s, shotgun16×7=112/.85s with center pellet and ring spread, melee30/.5s; enemy80/160HP. Actual integrated sprite close-range kill counts: pistol4/8, shotgun1/2, melee3/6. 30/60/120 rendering caps retain 6 shots/30 ammo over 120 fixed physics ticks with live AI/projectiles. One firing event drives pose/flash/audio; flash reaches one render before decrement.

Audio sources/cues unchanged: dry contacts, short hurt, longer 1.55/1.89s deaths. Actual native sound fixture passes all six weapon/material contacts, separate pain/death, title-only Abelian, pause freeze, mute advancement, death/retry and title reset. New isolated stereo game output board-sprite-driver-mix.wav is unnormalized, measured -24.77 LUFS / -6.65 dBTP. Level soundtrack remains provisional.

## Delivery/evidence

Newest package directory: /home/rikki/Builds/eyesore-pale-ward-sprites-2026-10-09. Executable eyesore-pale-ward-sprite-review.x86_64; portable archive, visual/audio credits and pinned engine licenses included. Exact hashes/bytes in verification/INTEGRATION.json. Standard-template native export smoke launched from /tmp passes without errors/warnings.

Actual integrated screenshots: verification/combat/board-sprite-{title,pistol,shotgun,shotgun-fire,melee,windup,corpses}.png. Controlled enemy placement/frozen AI aids visual comparison; these are real game renders, not concept overlays or a complete-level playtest. Core evidence: board-sprite-aim-balance.log, board-sprite-combat.log, board-sprite-timing.json, actual-atlas-contacts.json, board-sprite-sound-scene.log, board-sprite-provenance.json.

## Remaining work

Review this actual art/combat pass before expanding the level. One frontal enemy direction only; full eight-direction production remains pending. Generated claw/vent/anatomy and weapon perspective details drift; these remain representative animation poses. Movement capsule narrower than extended arms; direct-pursuit AI only. Full authored 5–8 minute route, key return, shortcut/secret, doors/lift, automap and sustained Linux release playtest are incomplete. Current user task is fulfilled as a concrete playable reuse of approved art, not acceptance of a finished game.
