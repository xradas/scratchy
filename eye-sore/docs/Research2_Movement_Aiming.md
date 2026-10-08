# Eyesore second-round research: movement and aiming

**Status:** research and tuning proposal for review, 3 October 2026. No movement changes or tests were made. Numeric ranges below are proposed experiment bands, not measurements from Doom, DUSK, Prodeus, Boltgun, Dead Space, or the current build.

**Working assumption:** Eyesore is being developed as a native Doom-inspired first-person shooter. That matches the user's recent direction, current native prototype, and intended playtest workflow. The older browser/isometric README is a project-hygiene conflict to resolve separately; it is not an input-control design question for this report.

## Decision summary

The prototype does not yet have a movement model to tune. It teleports the player directly to each frame's requested horizontal position at a fixed speed, keeps the viewpoint at one height, and uses a mouse-look camera with free pitch. Its two usable choices are current direct movement versus a real velocity model; the important first experiment is not “which Doom number?” but whether Eyesore should make direction changes and stops immediate, or let speed carry through them.

I recommend provisionally testing **Policy A: quick, direct arena movement with continuous run**, plus an optional walk speed. Preserve mouse free look, add a mild classic-style vertical assist option for mouse/keyboard players, and make any aim magnetism independently switchable. This should best support readable connected spaces without forcing sprint stamina or jumping into level design. It is a test hypothesis, not a final decision. Test **Policy B: deliberate momentum and traversal** in the same gauntlet so the current camera/code does not decide the game's identity by default.

Do not approve a movement contract until engine/level designers settle world units, actual player collision height/radius, floors and stairs, vertical sight, door clearance, and whether a jump is part of ordinary combat. The current fixed-height room cannot answer those questions.

## 1. What the current prototype demonstrably does

Read the native Linux prototype source and README. These observations describe code and documentation, not a recent subjective playtest:

| Area | Observed behavior | Consequence / missing information |
|---|---|---|
| Horizontal input | WASD vectors are combined and normalized, then multiplied by 2.85 units/s; Shift multiplies that by 2.0. Translation is applied directly as speed times delta-time. | No acceleration, stored horizontal velocity, inertia, or deceleration. Releasing input stops translation in the next simulation update. Sprint is a binary multiplier; it does not consume stamina. Diagonal speed is normalized to cardinal speed. |
| Collision | Player X and Z are tested separately through blocked(). Y is not moved by player controls. | Axis separation permits wall sliding, but there is no player body radius, step up, slope, floor transition, fall, jump, crouch, lift, or moving-floor behavior in this loop. Collision dimensions and corners need a shared player capsule/cylinder contract. |
| Height and camera | PLAYER_HEIGHT=1.42 is the player viewpoint's fixed Y coordinate in the room; pitch changes the view direction. The value is not evidence of a complete body height. | No camera reaction to steps, falls, landing, crouch, or jumping. A fixed height is incompatible with real vertical navigation. |
| Look | Relative mouse X changes yaw by 0.0026 radians per reported mouse count; relative mouse Y changes pitch with the opposite sign. Pitch is clamped to ±1.2 radians (about ±68.8°). | Sensitivity is a raw-count multiplier; there is no settings menu, normalization by display DPI, smoothing toggle, invert-Y, or stored preference. The source does not establish whether SDL is receiving raw mouse motion. |
| Keyboard turning | Left/right keys turn at 1.8 radians/second (about 103°/s) independent of mouse input. | No turn acceleration or controller curve; keyboard turn speed differs from mouse semantics. |
| Aiming | The renderer uses camera yaw and pitch. Calibration pistol/shotgun use a camera-aligned ray cone; standard-mode pistol/shotgun and the arc cannon are moving projectiles. | Hitscan/projectile rules are mode-dependent. Vertical aim policy and enemy height validation need to be coherent across weapons/modes. Current enemies mostly occupy floor level; a real elevation test does not exist. |
| Input / play comfort | WASD, Shift, mouse, number keys and mouse/Space fire are documented. Escape quits. F1 is calibration pause. | No visible control remapping, gamepad path, toggle/hold choices, accessibility options, or reliable focus-loss contract is described. Sprint has no alternate binding. |
| Speed scale | README says 2.85 units/s, 1.42 fixed camera height, and a 72 by 60-unit room complex. | If one uses the camera anchor purely as a rough proxy, current walking speed is ~2.0 anchor-heights/s and sprint ~4.0. This is a ratio for comparison only, not a real anthropometric scale. A 10-unit lane takes 3.51 s walking / 1.75 s sprinting before collision/path effects. |

Current movement is **direct velocity assignment**, not a validated “Doom-like” movement system. The source constants are near the top of engine3d.cpp; mouse events are around line 476; movement is around line 489. The latest working tree contains uncommitted changes from earlier work; this brief inspected them but did not modify them.

## 2. Reference research: lessons and limits

### Doom (1993 baseline)

The released Linux Doom source is useful because it makes the distinction between input intent and motion explicit: P_MovePlayer applies forward and side thrust only while grounded; P_Thrust adds momentum; movement/friction are then handled by the thinker/physics path. The view-height routine derives bob from momentum and interpolates view height after damage, while airborne height bypasses ordinary floor bob. These are structural observations from source, not a claim that every player perceives them as desirable today. [id Software Doom source: p_user.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_user.c), [p_mobj.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_mobj.c).

Original Doom's central aiming trade is also useful: mouse look is not required for the original horizontal plane; attacks use target selection/aim slope rather than today's universal free-pitch ray. Reproducing that exactly would conflict with a modern full-look camera and elevated/flying enemies. Eyesore should copy the *design question*—whether to make elevation aim forgiving—not raw constants, assets, source behavior, or old input limitations. See the player thrust/view code above and line-attack helpers in [Doom p_map.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_map.c).

**Transfer:** readable strafing, momentum-informed but restrained view response, and clear locomotion/combat separation. Do not assume Doom's same turn mode, view bob, or autoaim is automatically best for contemporary mouse and controller play.

### Wolfenstein 3D

id's original source is a useful contrast for a grid-raycaster built around horizontal position and facing; it has no modern vertical traversal loop. Its source is available from id Software. [id Software Wolfenstein 3D source](https://github.com/id-Software/wolf3d).

**Transfer:** use orthogonal movement lanes, tight door clearances, and explicit “can I pass?” affordances as a level-design stress test. Do not inherit fixed-grid control constraints or test movement only in wide open arenas. Movement requires usable door/corner clearance even in a fast game. This source is not evidence for modern mouse sensitivity or controller feel.

### DUSK

Creator David Szymanski describes DUSK's opening as a “fake deep end”: health and room to kite give players space to learn movement speed and enemy behavior in play, rather than stopping for a long tutorial. That is a level-teaching method, not an exact movement formula. [Game Developer interview with Szymanski](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games).

**Transfer:** validate movement in a first room with enough width to make a meaningful dodge, recognizable enemy tells, and a forgiving retry. Avoid relying on a text tutorial or empty speed-test corridor. DUSK also demonstrates that a deliberate individual aesthetic can make a retro shooter distinct; its gravity/rotation tricks are optional design territory, not requirements for Eyesore.

### Prodeus

Prodeus presents fast, old-school movement within a modern-rendering and community-level framework. The game's official listing explicitly describes fast, frantic play and a level editor/community browser; official updates discuss decoupling physics update behavior from render-frame issues. These establish movement responsiveness and broad user-made geometry as priorities, but do not document exact character-control values. [Prodeus official game page](https://store.steampowered.com/app/964800/Prodeus/), [official Steam update archive](https://store.steampowered.com/news/?appgroupname=Prodeus&appids=964800).

**Transfer:** movement physics must remain stable under frame-rate variation, and a strong movement contract benefits every map maker. Avoid claiming specific speed values were researched if developers have not exposed them.

### Warhammer 40,000: Boltgun

Auroch describes Boltgun as a frenetic retro-shooter homage and explains its modern production under the retro presentation; public material emphasizes cohesive animation/gameplay presentation, not precise movement constants. [Auroch's developer-authored release/gameplay note](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/), [Auroch Boltgun FAQ](https://www.aurochdigital.com/boltgun).

**Transfer:** weight can come from the combined viewmodel, firing animation, impact and sound while keeping player movement fast. Avoid “heavy” camera acceleration, exaggerated bob, or slow turn as a shortcut to weight; these can make aim and dodge response feel unresponsive. A source-based figure for Boltgun's exact movement or dash behavior was not verified in this pass, so none is specified here.

### Dead Space

Dead Space is a tonal/mechanical counterpoint, not a speed benchmark. EA describes the remake's Intensity Director coordinating authored encounter, lighting and audio changes, with peaks and calmer intervals. The movement lesson is indirect: intense moments can be composed with quiet recovery windows, so every corridor need not maximize threat. [EA: Intensity Director](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director).

**Transfer:** use tense walking or reduced movement pressure as a deliberate transition, then return to open combat spaces with room to dodge. Do not force the entire game into Dead Space's survival-horror pacing or treat cinematic camera motion as a substitute for player control.

## 3. Two genuinely different movement policies

Both policies should use a shared engine foundation: fixed simulation time-step or bounded substeps; collision shape independent of artwork; configurable look input; documented units; and a test harness. Bands below are starting points for controlled comparison, scaled to final collision body height H after engine architecture defines it. They must be measured in the test map before choosing.

| | A. Direct arena control (provisional lead) | B. Inertial traversal |
|---|---|---|
| Player promise | “I press a direction and the character answers now.” Prioritize target correction, evasive strafing, quick reversals. | “I build and manage momentum.” Prioritize carrying speed, route lines, jumps and expressive air correction. |
| Horizontal speed | Run continuously; tune roughly 6–8 H/s as an initial experiment band. Optional walk at 35–50% run for exploration. No stamina sprint by default. | Ground top speed roughly 7–9 H/s; reach top speed over ~0.25–0.45 s. Airborne momentum retained. This policy only makes sense once the engine supports jumping/falls. |
| Acceleration / release | 90% requested speed within 0.10–0.18 s; stop to 10% within 0.12–0.22 s. Air control disabled if no jump; with jump, air control is modest (20–35% of ground steering). | 90% within 0.30–0.50 s; coast to 10% over 0.35–0.65 s. Air steering 45–70%; braking should remain an intentional input, not hidden friction. |
| Direction / diagonal | Normalize diagonals; forward, back, and strafe nominal speed equal. Running is normal combat state; walk is optional. | Preserve total speed under diagonal input; allow skilled route shaping through acceleration/air steering, not faster diagonal speed. Run is always active. |
| Jump / vertical | No mandatory jump. Prefer no jump unless broader movement tests make it clearly valuable; no route requires a precision jump in this policy. Implement proper steps/falls/lifts regardless. | Jump is core and routes/encounters deliberately use it. Initial jump airtime 0.55–0.80 s and apex 0.7–1.1 H are test bands, not design promises. Include coyote/buffer options only if testing demonstrates missed-input frustration. |
| Camera | Stable eye position; step/landing transitions are brief and small. Optional low-amplitude bob only. | Mild acceleration and landing response conveys speed, but visual camera motion is bounded independently from physics. Offer separate bob/landing-shake controls. |
| Learning / risk | Accessible and easy to judge; danger comes primarily from enemy timing, geometry, and weapon commitments. Easier to tune encounters. Risk: movement may feel generic unless enemy/weapon interaction is excellent. | Deep movement mastery and more expressive combat. Risk: skill gap widens; jump and momentum affect every space, enemy aim, weapon timing and pickup placement. |
| Reference blend | Doom spatial combat readability + DUSK room-to-learn + Prodeus responsiveness; Boltgun weight comes from feedback. | A modern movement-shooter branch; selectively borrows DUSK's movement-first openness, while explicitly departing from Doom's grounded constraint. |

**Recommendation:** tune A first because every other design discipline currently assumes arena movement and Doom-like floor combat, and no verified design has justified jump routes. Keep B as a tested alternative. Do not ship a hybrid with sprint, momentum, jump, dodge, and stamina all layered together before each mechanic has a clear purpose.

## 4. Shared movement, collision, and camera contract to measure

Use normalized ratios until the engine defines the real player collision envelope. Here H means final standing body height, R horizontal radius, and S selected run speed. Keep these distinct from camera pivot.

| Question | Proposed first-pass measurement / acceptance target | Ownership / reason |
|---|---|---|
| Simulation stability | Compare 30, 60, 120, and uncapped render rate while physics is fixed or substepped. Traversal time and landing position vary by <2%; no tunneling at tested max speed. | Engine. Current variable delta-time integrates direct movement, with no fixed-step contract visible. |
| Speed and room scale | At selected run speed, a clear 20 H combat lane crosses in 2.5–3.5 s. A 90° direction switch under Policy A reaches new direction within 0.25 s. | Movement + level layout. Lane time is more useful than copying Doom map-unit speed. |
| Acceleration and brake | Log time and distance to 50%, 90%, full speed, then 10% after release. Policy A provisional target: 10–90% under 0.18 s; stopping distance under 0.8 H. Policy B deliberately tests wider bands above. | Movement. Explicitly compare drift against dodge-space size. |
| Reversal / dodge | In a 2 H-wide lane, start at S, command reverse. No wall penetration; show lateral/reversal distance and time until movement points opposite. Repeat with left/right target tracking while moving. | Movement + enemy/weapon. Player should be able to break a committed attack lane. |
| Wall slide / corners | Sweep into straight wall at 0°, 30°, 45°, 60°, and 90°. Tangential input should continue smoothly; no sticky corner or sudden speed jump. Repeat around concave and convex corners at walk/run. | Engine + level. Existing X then Z collision can produce different corner behavior based on movement ordering. |
| Player body / door | Player radius R should fit ordinary route doors with at least 0.25 R clearance per side at authored minimum. A collision/debug overlay must show feet, head, and radius. | Engine + world design. Use body clearance independent of weapon sprite. |
| Steps / slopes | Test steps at 0.10, 0.20, 0.30, 0.45 H; slopes 5°, 10°, 15°, and landings. Select one max step and max walkable slope; give clear collision failure and no camera pop. | Engine + level. No vertical collision path currently exists. |
| Falls / jump | If A: define survivable fall heights and landing recovery; no movement drop is hidden by fake height. If B: measure apex/time, horizontal carry, air control, ceiling head bump, landing friction, ledge/coyote/buffer behavior, then test at low/high frame rate. | Engine + encounter + map. Decision cannot be made by camera feel alone. |
| View height | Measure eye pivot as percentage of H; separate camera pivot from collider. Step and landing camera displacement ≤0.03 H in normal preset; optional reduced-motion setting removes it. | Engine + camera/comfort. Current 1.42 is fixed and not body height. |
| Bob / shake | Start with bob off in aiming baseline. Then compare 0, 0.5%, 1.0%, 1.5% of frame height at S. Damage and landing shake separately toggled/slid; no shake changes projectile direction. | Camera + accessibility. Camera must never make movement physics or hit location ambiguous. |
| Field of view | Test 80°, 90°, 100°, and 110° horizontal-equivalent presets on 16:9 plus ultrawide; avoid changing world speed to simulate visual speed. Measure edge distortion and pickup/foe readability. | Camera + art + quality. State whether settings describe vertical or horizontal FOV. |
| Mouse look | Record counts-to-turn and cm/360 for 400/800/1600 DPI, pointer-speed changes, multiple frame rates and window focus. Sensitivity should be linear and consistent; no hidden smoothing/acceleration. Offer sensitivity and invert Y, plus raw-input mode only if SDL/platform supports it reliably. | Input/engine. Existing sensitivity 0.0026 rad/count cannot be interpreted without device DPI/path. |
| Pitch | Start free-look at ±75° to ±85° and compare with ±60° classic-like option. Clamp must prevent over/under-rotation and vertical snap. Test ceiling, sky, tall enemies, jumping and stairs. | Aim + art + engine. Camera and weapon trace must share one authoritative forward vector. |
| Keyboard / controller | Key rebinding; separate strafe and turn bindings; adjustable keyboard turn rate. Gamepad needs left-stick deadzone/curve, right-stick sensitivity, separate horizontal/vertical response, and optional aim help; compare controller and mouse on identical target courses. | Input + quality. No gamepad implementation described. |
| Sprint / walk | If sprint retained, test against continuous run. Sprint should not hide 2× combat advantage or make walk feel broken. Prefer one walk toggle/hold option and a single full-speed combat run. | Movement + encounter. Current Shift is 2×. |
| Controls and comfort | Remappable bindings, hold/toggle options, invert look, sensitivity, FOV, bob/shake, reticle, aim assist, reduced flash, and accessibility preset saved across relaunch. Comfort options preserve hit/physics results except chosen assist. | Input/interface/QA. These are normal settings, not special-mode cheats. |

### Aim policy options

Make assistance independent of movement policy and input device. Keep damage and projectile speed identical when comparing aim settings so results reflect control assistance, not hidden weapon buffs.

1. **Classic vertical assist (recommended option, off by default until tested):** player freely aims horizontally; a hitscan trace may select a visible target close to centerline and adjust only the vertical slope within a small documented angle window. Never bend through solid geometry; never rotate aim horizontally toward a target. Offer Off / Subtle / Classic presets and a crosshair. This recreates the convenience function of classic vertical target selection without copying its no-pitch camera.
2. **True-ray aim:** shot fires exactly along camera center. No correction. Most transparent for mouse players; punishes pitch error and may make floor/ceiling separation more demanding.
3. **Controller-only magnetism (optional):** small reticle slowdown window and weaker vertical correction; no camera snaps. Keep separately adjustable from autoaim. Do not silently enable on mouse/keyboard.

For projectile weapons, do not aim the projectile at a target the player cannot see or through cover. Any assistance must be weapon-specific: hitscan correction can be plausible; ballistic/slow projectiles need visible trajectory/reticle preview or no correction. A target behind the reticle but occluded should never receive assistance. No enemy health bars are needed to test aim.

## 5. Movement gauntlet and test criteria

Make one flat gray-box movement lab only after selecting a collision/player-height contract. It is a test instrument, not a proposed campaign level and not another combat calibration-room concept. Include seven repeatable lanes:

1. **Straight run timing:** 10 H and 20 H lanes with floor marks each 1 H; start from rest, hold forward, stop at line. Capture speed, acceleration and stopping distance.
2. **Direction change:** opposing 90°/180° turns at rest and at speed, with and without strafing. Put targets at fixed angles and record time-to-center.
3. **Dodge clock:** dodge a visible enemy projectile with three tell/release delays (0.5, 0.8, 1.1 s) crossing at two distances. Score hit rate, dodge distance, and whether misses were input, collision, or unreadable tell.
4. **Geometry:** 1.2R / 1.5R / 2R doors, L corners, narrow columns, wall slide, step/ramp sizes, one moving door. Record blocked attempts and unintended catches.
5. **Vertical route:** optional jump pit, low lintel, one raised firing position and one drop. Run in both movement policies; if A cannot perform this, record it as unsupported rather than inventing a workaround.
6. **Aim while moving:** hit a 1 H, 2 H, and 3 H target at 5 H, 10 H, and 20 H while strafing, reversing, and crossing a doorway. Repeat true-ray/vertical-assist and mouse/controller presets.
7. **Comfort/focus:** 3 minutes of repeated lateral turns/strafe, then repeat with bob/shake on/off, narrow/wide FOV, and focus loss/reacquire. Ask about discomfort immediately; do not make players complete a setting that causes symptoms.

### Participants and difficulty presets

- **New FPS player:** start in accessible preset, then normal. Assume no prior shooter training. Provide readable directions and a forgiving first room; no long text explanation.
- **Experienced mouse player:** standard plus classic-like control preset; include high turn rates and a reproducible target course.
- **Controller player:** deadzone, curve, separate X/Y, aim-help presets. Do not compare using mouse expectations alone.
- **Accessibility/comfort reviewer:** test reduced bob/shake, FOV, remapping, toggle run, hold/press options, contrast-independent cues, and UI size. Ask whether any required movement causes discomfort or loss of control.
- **Low-motion/low-dexterity configuration:** accessible difficulty can extend tells and reduce projectile pressure; movement settings can reduce precision demands. Avoid solving accessibility by silently slowing enemies or removing required route skill.

### Staged decision gates (proposed)

**Gate 1: first feel comparison.** After engine and level teams establish a stable collision body and a tiny test space, compare only Policy A and Policy B on the straight-run, direction-change, dodge, and moving-aim lanes. Use two or three people, alternating which policy goes first. Each person gets a short familiarization, then three to five repetitions per lane per policy. Record route time, stopping/reversal distance, hits taken, aim time, and one plain-language preference/reason. This stage answers whether the policies feel different in the intended direction and surfaces blocking bugs; it is not a quality or accessibility claim. If jump is not supported by the current engine, leave the vertical lane out and record that dependency.

Proceed only if one policy has no blocking collision/input defect and at least two participants can explain a clear preference tied to a game action (for example, reversing while tracking a caster, or carrying speed through a jump). If preferences split or neither feels distinctly better, adjust one variable at a time and repeat this small comparison. Do not add extra movement abilities to rescue an inconclusive test.

**Gate 2: broader validation.** Only after Gate 1 identifies a promising direction, take that candidate through 10 repeated trials per lane and then a broader group of at least five players across novice, experienced mouse, and controller users. Include the accessibility/comfort review before considering the movement contract stable. This larger pass can expose distribution and device problems; it still cannot prove universal comfort.

Every number below is an **initial hypothesis for a decision threshold**, not a researched industry standard or a result. Relax or replace thresholds if the test reveals the measure is poorly matched to the intended feel.

Candidate movement hypotheses:

- 90% of novice and experienced runs finish basic geometry and target lanes without unintended collision/control failure;
- at least 80% of participants dodge the 0.8 s attack tell after one demonstrated encounter, with cause-coded failures showing no systematic collision/body-radius issue;
- target-acquisition time under lateral movement worsens by no more than 25% versus stationary baseline for mouse, and 40% for controller with chosen assist;
- measured path timing changes by <2% across supported render rates;
- no Gate 2 participant reports “must leave this setting” discomfort under default camera; treat even zero reports as a small-sample result, not proof of universal comfort;
- direction change and stop metrics match selected policy band; no untracked diagonal speed increase;
- maps using selected speed communicate a useful dodge lane and traversable door using the world team's grid scale.

Report distributions and failures, not only averages. Record input device, DPI/controller, FOV, sensitivity, assistance, framerate, build and collision visualization. Do not make a final recommendation from an unplayed agent judgement.

## 6. Dependencies and unanswered decisions

| Question still open | Needed from | Why movement cannot decide alone |
|---|---|---|
| Real collision height/radius, floor heights, door model, slopes, step and moving geometry | Engine + level/world | Current player has no vertical movement or body contract. |
| Should levels require jumping? Is there run/sprint/dash? | Creative direction + level + encounter | This determines every gap, pickup reach, enemy aim, camera reaction, tutorial, and controller binding. |
| Hitscan or projectile per weapon? Can foes fly or stand above player? | Weapon + enemy behavior | Determines vertical pitch limits and whether aim assistance can be fair. Current modes disagree about hitscan versus projectile. |
| Distinct default and accessible difficulty settings | Encounter + accessibility/QA | Assist and tell windows change successful dodge rate and level pressure. |
| Camera style, FOV, bob, reticle and comfort defaults | Art direction + interface + accessibility | Weapon/art framing, enemy screen scale, and color/light contrast depend on it. |
| Controller support scope and Linux input APIs | Engine/session + user | Requires deadzone/curve/rebind/persistence and platform testing not present in current README. |
| Exact speed, acceleration, friction, airtime | Movement + player playtests | Values before geometry and human trials are guesses. |

## 7. Bias and limits

- I inspected source/docs, not the running movement by live play. Code establishes immediate-stop math, but not perceived smoothness, motion sickness, or player preference.
- Public reference descriptions and interviews do not expose all games' movement constants. No exact DUSK, Prodeus, Boltgun, Wolfenstein, or Dead Space speeds are claimed.
- Doom's source is Linux Doom 1.10; repository contains code from more than one release history. This brief only relies on cited player thrust/view behavior and classic aiming contrast, not every later mode.
- PLAYER_HEIGHT is treated as a camera anchor because that is how this code uses it; it is not confirmed standing collider height.
- Existing rectangular rooms and camera may bias toward horizontal, arena-only tests. Hence the separate vertical policy test and requirement that engine/level teams make the jump decision explicitly.
- Numeric target bands favor a legible responsive arena-shooter hypothesis. The gauntlet should be allowed to reject them. They are not findings from benchmark playthroughs.
- The native-FPS working assumption follows the user's recent project direction. The root README still presents browser/isometric gameplay; project ownership should archive or update that stale branch/documentation separately, rather than holding first-person control research open.

## Sources

- id Software, [Doom Linux source p_user.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_user.c), [movement/friction source p_mobj.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_mobj.c), and [aim/line attack source p_map.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_map.c).
- id Software, [original Wolfenstein 3D source release](https://github.com/id-Software/wolf3d).
- David Szymanski interview, [“More than a throwback: How Dusk nails the best parts of 90s FPS games”](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games), Game Developer, 10 Jan 2019.
- [Prodeus official Steam page](https://store.steampowered.com/app/964800/Prodeus/) and [official Steam announcements](https://store.steampowered.com/news/?appgroupname=Prodeus&appids=964800).
- Auroch Digital, [Boltgun gameplay and production note](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/) and [Boltgun FAQ](https://www.aurochdigital.com/boltgun).
- Electronic Arts, [Dead Space Intensity Director overview](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director).
- Project artifacts inspected: [native Linux README](../linux-game/README.md), [engine3d.cpp](../linux-game/src/engine3d.cpp), and [first team review](EYESORE_TEAM_REVIEW.md).
