# Eyesore build two

Target: a new standalone Linux game in Godot 4.7.2, GDScript, Compatibility renderer. One polished 5–8 minute level with classic Doom-inspired combat and exploration, mouse free look, original hand-authored pixel artwork, recorded physical gun sounds, and aggressive library music.

## Review gates

1. **Identity selection (completed 9 October: The Pale Ward).** Compare equally scoped corrupted biotech, war-torn occult fortress, and invaded civic megastructure packets. Each includes a 640×360 combat composition, palette, material probes, two creature designs, pistol/shotgun designs, HUD thumbnail, and short licensed audio/music auditions. User selects or revises the identity before complete animation sets or level production.
2. **Complete combat exchange.** Use representative production assets in a calibration room. Review fast grounded movement, repeated firing, enemy animation commitments, impacts and actual mixed audio together. No level expansion until this exchange is accepted.
3. **Level and complete assets.** Produce eight-direction creature movement and attacks, pain and death with persistent corpses; idle/fire/recovery/switch weapon animations; pickups, effects, HUD and interfaces. Build connected rooms with retreat routes, a key-return loop, shortcut, optional secret, height changes, working doors/lift and clear exit.
4. **Release review.** Complete route without secret supplies; verify retry restores all state; capture gameplay with actual stereo game mix; export and play outside the development directory. Deliver Linux package, source, credits and known issues. Push accepted milestones and verify remote IDs.

The foundation preview proves boot/export, rendering, movement and settings only. It is not the combat calibration acceptance or finished game. Concept compositions are static artwork, not captured gameplay. Concept audio masking mixes are auditions, not the game mix. The revised visual screenshots were positively reviewed. The user explicitly selected The Pale Ward/corrupted biotech on 9 October. Abelian is menu music; level scores are separate. Wet damage cues were rejected and dry Doom/Quake-inspired replacements are in review. Complete calibration listening and gameplay approval remain pending.

## Fixed scope

- World renders at 640×360 using nearest-neighbour scaling; HUD/menu text uses window resolution.
- Pistol, shotgun and melee fallback. Finite ammunition, health and armor. Pistol/shotgun hitscan; shotgun releases seven pellets in one firing event.
- One melee pursuer and one projectile attacker, stable health, readable attack commitments.
- No jumping, dashing, glory kills, reloads or enemy health bars.
- Definitions are Godot Resources; levels are authored scenes. Shared physics geometry governs movement, visibility, hitscan, projectiles, doors and lifts.
- Main menu, settings, pause, death/retry, completion, credits and visited-area automap. Settings persist. Campaign saves and additional levels remain later milestones.
- Weapons, Creatures, World, Music, UI and Master audio buses. Stereo music remains stereo; world emitters use positional playback. Pause freezes gameplay audio. Mute changes audibility only. Restart clears prior voices.
- Original CC0 and credited CC BY library downloads only. Preserve source files and a creator/URL/license/edit/export ledger.

## Ownership and staffing

The coordinator owns shared contracts, integration, provenance and Git checkpoints. At most three specialists work alongside the coordinator. Use GPT-6.1 Sol/high for substantial design and integration, Sol/medium for bounded implementation. Astra is excluded by the recorded user preference. Project-local specialist briefs are in `specialists/`.

## Acceptance evidence still required after identity selection

- Movement and weapon timing remain consistent at 30, 60 and 120 rendering FPS.
- Walls and moving doors block actors, visibility, hitscan and projectiles consistently.
- Animation, shot release, damage and sound agree. Interrupted and dead enemies cannot release attacks.
- Required assets/provenance validate; directional sprites retain foot pivots, anatomy, transparency and readable silhouettes at gameplay distance.
- Compare dry sources, designed cues and actual game playback at comfortable matched levels. Hear repeated shots, warnings under music, spatial movement, pause/resume and restart. Loudness measurements support listening; they do not establish appeal.
- Main route can be completed without secret supplies. Retry restores doors, lift, enemies, corpses, pickups, resources, keys, automap, projectiles and audio voices.
- Portable Linux export contains every required asset and survives a sustained playtest outside its development directory.

## Preservation

Six divergent original Eyesore worktrees were preserved before build two. Exact local snapshots include build artifacts, uncommitted files, original patches and a Git bundle. New work is isolated in branch `codex/eyesore-build-two`, worktree `/home/rikki/Projects/eyesore-build-two`, project `eye-sore/build-two/`.

Local snapshot manifest: `/home/rikki/Projects/eyesore-preservation/2026-10-08/manifest.json`. Archive branch names: `archive/eyesore-2026-10-08/{coordinator,audio,combat,hud,mixer,sound}` in `xradas/scratchy`. Remote verification is recorded separately from the snapshots. Original worktrees and their staging indexes are left intact.
