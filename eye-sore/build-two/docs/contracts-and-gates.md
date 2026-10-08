# Pending production contracts and acceptance gates

These describe future implementation requirements. They are not claims that combat or production levels exist.

## Identity selection — required first

The selected identity must establish the visual language, premise, mood, combat vocabulary and asset direction. User selection is pending. Do not use neutral calibration geometry as approval of any creative identity.

## Single-event contracts — pending implementation

- One accepted fire input creates one authoritative shot event carrying a unique shot ID, weapon ID, origin/direction, timestamp and relevant deterministic seed. Muzzle flash, recoil, weapon sound and damage resolution subscribe to that event; they do not independently create a second shot.
- One shotgun firing event releases exactly seven pellets. Each pellet has a stable index in that shot; one shell is consumed for the whole event.
- Resolve damage either by aggregating the seven pellet hits per target and applying one shot/target damage event, or by using unique shot/pellet/target damage IDs. Do not deduplicate solely by shot/target if pellets apply damage individually, because that would discard valid pellet hits. Damage feedback and hit sound respond to resolved damage rather than issuing a second raycast.
- One transition from alive to dead creates one death event carrying the target ID and cause. Death effects, sound, cleanup and progression respond once; repeated damage after death must not produce repeated deaths.
- Enemy attacks have one authoritative windup/release/recovery timeline. Release creates melee damage or a projectile exactly once. Pain interruption and death invalidate an unreleased attack; a dead enemy cannot issue any new release. Visual frame changes and audio subscribe to this timeline.
- One authoritative encounter transition creates one state event. HUD, music and spawning subscribe to that state rather than deriving incompatible states separately.
- Pause controls processing and stream time; mute controls audibility only. Do not let audio callbacks generate gameplay events.

## Later acceptance — all pending

1. User selects identity before combat, level or full asset production.
2. Assets and room/level composition express that selection consistently at the 640×360 world resolution while native HUD remains legible.
3. Fast grounded movement feels correct under real mouse/keyboard play, with no jumping or dashing. Verify walls, corners and geometry prevent escape.
4. Weapon input, damage, deaths and round transitions satisfy the single-event contracts, including repeated input and repeated damage edge cases.
5. Future enemy definitions and AI behave coherently and show readable attack/death feedback.
6. Gameplay audio routes to the specified buses; pausing freezes ongoing gameplay streams and resumes at the same stream time. Muting keeps simulation and stream time advancing. UI feedback remains usable while paused.
7. Settings persistence is manually verified across restarts and invalid settings values clamp safely.
8. Linux portable release runs from outside the project on a target machine without the editor; graphics, input, window resize and native HUD are manually assessed there.

The current smoke verifies scene construction, fixed world viewport, applied settings, six named buses, stable player position across paused frames, and that Master mute permits an unpaused tree. It does not replace playtesting, inspect future assets, test combat, or validate audible pause/resume of sound that does not yet exist.
