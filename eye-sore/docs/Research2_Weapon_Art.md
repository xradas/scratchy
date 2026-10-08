# Eyesore round-two first-person weapon art research

Research role 11. 3 October 2026. GPT-6.1 Sol / medium. Research only: no game code, images, animation, sound, builds or gameplay tests changed or run. None of the visual directions below is approved.

## Recommendation and evidence boundary

First compare three neutral weapon shapes with a single shared attack timeline and a clear central sightline. Then compare **Service Instruments** and **Counterweight Arms**, two different visual grammars applied to the same mechanics. The first makes power legible through fast internal action and modest external movement; the second makes it legible through masses moving in opposition. Neither requires exotic combat mechanics, an infernal arsenal, or Doom gun silhouettes.

The current weapon problem is partly a coordination failure: simulation fires immediately, while the atlas first shows a rest frame for approximately 167 ms on the pistol and 300 ms on the shotgun/arc. The image already includes a flash, and additional overlays show launch effects. A new, more elaborate image would preserve that disagreement unless the event contract changes.

**Facts** below are directly observed code/asset/source properties. **Inferences** explain likely consequences and require captured play. **Proposals** include all new designs and numerical thresholds. No reference game's undocumented FOV, screen occupancy or frame timings are presented as measured facts.

## 1. Actual asset and renderer audit

Inspected `linux-game/src/engine3d.cpp`, `linux-game/tools/build_weapon_frames.sh`, `verify_weapon_assets.sh`, `public/infernal-weapon-models.png`, `public/infernal-firing-sheet.png`, standalone `public/weapons/weapon-1-frame-1.png`, and the role 03 mechanics report. ImageMagick metadata/pixel reads were read-only audit operations. The native first-person prototype is the working context; legacy browser presentation is not an accepted specification.

| Fact | Evidence | Consequence / inference |
|---|---|---|
| World camera uses a 60° **vertical** FOV and a 1280×720 viewport constant | `engine3d.cpp:15,510`; frustum top uses tan(60°/2), right multiplies W/H | Horizontal FOV is derived, approximately 91.5° at 16:9. Do not label this a 60° horizontal camera. |
| Weapon is a screen quad in `glOrtho(-1,1,-1,1,-1,1)` with depth and lighting disabled | `draw_weapon_model`, lines 229–232 | Its apparent size is independent of world FOV. It never clips on world geometry. It is always white-tinted, unlike world-lit threats. |
| Quad widths .54/.72/.90 and heights .58/.70/.82, bottom=-1 | Same function | Full texture rectangles occupy 27/36/45% of width and 29/35/41% of height. At 1280×720: 346×209, 461×252, 576×295 px, rounded. These are quad bounds, **not opaque silhouette coverage**. |
| Nonuniform scaling distorts texture aspect | Frames are 384×341, or 384×342 for middle row; fixed quad dimensions above | Source aspect is about 1.12; screen rectangle aspects are about 1.66/1.83/1.95 at 16:9. Art is horizontally stretched; wider displays exacerbate it if this scheme is retained. |
| Pistol uses source frames 0,1,3; others 0,1,2,3 | `WEAPON_FRAME_COUNTS`, `WEAPON_SOURCE_FRAMES`, lines 91–92 | Pistol omits the depicted kicked pose in source frame 2. Frames receive equal fractions of animation duration rather than authored holds. |
| Attack animation lasts .50/1.20/1.20 s; cooldown .50/1.50/1.50 s | Lines 89–90; `fire_player_weapon`, 466–473 | Shotgun/arc appear rested for .30 s while still unable to shoot. First rest frames take .167/.300/.300 s before firing art. Frame-step boundaries may shift visible transition by a render frame. |
| Normal/calibration mechanics differ | Role 03 audit; fire paths at 453–473 | Art comparisons must use one authoritative attack rule. A convincing projectile image cannot make calibration hitscan representative of normal play. |
| Source sheet includes glow, smoke, ejection, changing tool perspective | Visual inspection | Useful action ingredients exist, but pose/material continuity needs a proper mechanism model. Sheet mixes mechanism and additive effects into one layer. |
| Middle-row cut has cyan content at its bottom | Visible in shotgun firing frame; lower-center pixel (192,341)=(88,187,208, alpha .156863) | The next row's energy glow contaminates a shotgun asset. 1024 is not divisible by three; crops are 341/342/341 px. Unequal cuts alone do not prove contamination, but the viewed strip and pixel do. |
| Every weapon frame has min alpha 0; max alpha ~.992–.996 | ImageMagick audit of 12 PNGs | A single transparent pixel passes the runtime minimum-alpha check even when unwanted semi-transparent content exists. Reconstruction verification faithfully reproduces a sheet; it does not prove proper object isolation. |
| Current loader uses linear minification, nearest magnification and repeat wrapping for weapon textures | `texture_from_bmp`, 135–148, called without black-transparency argument | Shrinking can produce softened fringes; repeat wrapping can sample opposite edges. These are risks to inspect at actual size, not a measured runtime defect. |
| Draw order: world/impacts → first-person launch → weapon/reticle → arc muzzle flash → calibration HUD | Main render line 511 | Launch is partly hidden behind weapon; arc flash can cover reticle. The source firing frame and overlays can double the impression of a discharge. |
| Launch overlays are separate additive screen quads, unrelated to target distance | `draw_first_person_launch`, 236–247 | A target hit can coexist with an apparently still-departing shot. Shotgun launch rectangle can extend above the screen center late in its .22 s life. Depth-disabled launch can imply firing through nearby cover. |
| Arc world trail is withheld until 2.9 units travelled | Main render line 511 | At 20 units/s, about .145 s travel separates initial effect from trail; this may be intended as a handoff but needs a near-target/camera-turn test. |
| Number keys/pickups immediately assign weapon; shared animation timer remains | Main input/pickup logic; role 03 | Switching during a shot can display the incoming gun partway through the outgoing gun's timer. Launch has its own weapon ID, so outgoing overlay and incoming tool can disagree. |

**Observed visual character:** all three tools share black/rust plates, circular cross motifs, many small bolts, a centered symmetrical pose and orange/cyan internal light. The shotgun's paired barrels distinguish it at large size; ornate construction gives the other tools similar visual density. **Inference:** reduced to combat size, surface noise competes with mechanism motion. Repeating a bright central core makes color do too much identity work.

No runtime clip was recorded in this task; draw-order/timing consequences are predicted from source. Claims about perceived weight remain unvalidated.

## 2. Reference findings and what they can support

### Doom: separate presentation tracks with authored state events

**Fact:** `P_SetPsprite` changes state, installs tic duration, and calls an action on state entry. `A_WeaponReady`, `A_Lower`, `A_Raise` and `A_ReFire` provide ready/switch/refire behavior; the flash is a separate player-sprite slot following weapon coordinates. Weapon actions associate ammo, sound and attack with a defined state. **Inference:** recognisable action phases matter more than a high frame count. **Proposal:** borrow explicit event/state discipline while making Eyesore simulation, rather than render callbacks, authoritative. [id source: p_pspr.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_pspr.c).

**Fact:** `R_DrawPSprite` uses patch offsets, screen placement and the frame's first sprite orientation, with local-light/fullbright handling. **Inference:** a first-person weapon image is not an enemy's eight-angle sheet. **Proposal:** preserve authored pivots and a separate flash/light policy rather than stretching the entire rectangle. [id source: r_things.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_things.c). The state table records individual frame holds and actions, which supports authored holds rather than equal subdivisions. [id source: info.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/info.c).

### Wolfenstein 3D: compact and explicit

**Fact:** `attackinfo` records duration, action and frame separately; `T_Attack` advances that sequence. `DrawPlayerWeapon` selects a weapon-base shape plus weapon frame and centers the scaled image. **Inference:** a small frame vocabulary can clearly communicate repeated fire if events and poses agree. **Proposal:** begin with ready/commit/kick/return poses instead of creating large incoherent sheets. This is not a requirement to copy centered firearms. [WL_AGENT.C](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_AGENT.C), [WL_DRAW.C](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_DRAW.C).

### DUSK: identity variety within rapid action

**Fact:** the developer/publisher description lists sickles, swords, crossbows, rifles, dual weapons and heavy launchers in a fast retro FPS. It does not publish weapon screen budgets or animation timing. **Inference:** a single decorative shell for the entire arsenal is unnecessary; silhouette/action can vary widely while player movement stays direct. **Proposal:** compare tools with distinct action axes under rapid tracking. No claim is made about DUSK's exact recoil, viewmodel rig or dimensions. [Official Steam description](https://store.steampowered.com/app/519860/DUSK/), [New Blood](https://newblood.games/dusk).

### Prodeus: effects are a stress condition

**Fact:** its official description combines modern 3D technology with retro visuals, particle effects, explosions, fast action and exaggerated weapons. **Inference:** visual consistency is compatible with modern production; effect density still has to survive an authored combat test. **Proposal:** test Eyesore weapon recognition under particles, enemy tells and lighting changes. This source does not establish that its weapon sprites are rendered at runtime or provide an asset pipeline; no such assertion is used. [Official Steam description](https://store.steampowered.com/app/964800/Prodeus/).

### Boltgun: credible production process, limited weapon evidence

**Fact:** Auroch lead designer Grant Stewart describes sculpted, rigged, animated enemy models rendered from eight directions into flipbooks, with animation data specifying damage/sound/fireball moments. **Inference:** a reusable physical source model can prevent perspective drift across frames. **Proposal:** use that production principle for a single camera-relative weapon view, with event declarations exported to the simulation timeline. The article documents **enemy** production; it does not prove Boltgun's viewmodels use the same method or need eight views. [Developer account on PlayStation Blog](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/). The publisher's heavy arsenal/fast FPS description supports a desired contrast between rapid player control and forceful attacks, but not numeric recoil values. [Focus page](https://www.focus-entmt.com/en/games/warhammer-40000-boltgun).

### Dead Space: operation and target response belong together

**Fact:** Motive describes layered enemy damage communicating progress without an HP bar and supporting different cutting/non-cutting weapons. **Inference:** weight comes from credible consequences as well as hand movement and sound. **Proposal:** Eyesore needs clearly different miss, surface impact, target hit and interrupted-target responses, coordinated with role 12. It does not need Dead Space's peeling system, shoulder camera or iconic cutter orientation. [Motive developer interview](https://www.ea.com/able/news/inside-dead-space-2-new-necromorph-nightmare). EA also presents Isaac's engineering tools as part of his character premise; that supports choosing a player occupation before detailed tool construction. [EA game page](https://www.ea.com/nl-nl/games/dead-space/dead-space/narrative).

## 3. Compare three presentation grammars on identical mechanics

Use role 03's immediate precision / close fan / visible area projectile as **test roles**, without assuming final weapon names, witness effects or lore. No direction requires setup, marks, bounce puzzles or additional input. Story/art leads can reject these tool premises without invalidating the presentation experiment.

### Neutral control — exposed gray mechanisms

Three blockouts: a narrow spine with a sliding rear block; a wide comb-shaped mouth with a side return handle; a round cradle holding a visible capsule. Matte gray, one broad dark break, identical plain glove/cuff. Precision sits low-right, fan low-center, area lower-left-to-center. Those positions are trials, not mandatory handedness changes: right hand remains firing hand and left hand is support in all three.

Show ready, discharge, kick, return and ready again. Use one small white muzzle accent, a short mechanism movement and no smoke/gore embellishment. No labels, faction symbols or color-dependent identity. This controls whether the foundational cadence and silhouette are understandable.

### A — Service Instruments

**Premise:** human-scale emergency maintenance equipment adapted for direct defensive use. Visible purpose, durable polymer/enamel guards, replaceable working heads, substantial fasteners only where assembly requires them. This can fit Civic Daylight or a freight-world story, but is not an assertion that either is canon. It differs from the previous forge trio through asymmetry, light outer surfaces, limited glow and readable moving internals.

| Role | Form and hands | Action grammar | Distinctive evidence |
|---|---|---|---|
| Precision | Slim offset spine, right-hand grip, left hand normally offscreen; broad rear slider | Rear slider strikes forward at shot then snaps a short distance back; body barely rotates | One hard axial event; narrow profile survives monochrome |
| Close fan | Shallow rectangular array, right trigger hand, left support under guarded return bar | Array plate recoils down/back as one mass; left hand returns the bar later in recovery | Wide horizontal mouth and secondary deliberate hand action, not paired Doom barrels |
| Area | Cradle with single exposed capsule and low support palm | Capsule visibly leaves; cradle tilts down, rear loading gate indexes a replacement only if ammo exists | Real disappearance at shot; open cradle signals remaining recovery |

**Ready/rest:** quiet mechanism, stable muzzle aligned to aim; optional movement bob kept low. **Wind-up:** zero forced delay for precision/fan control; any apparent preparation is already in the ready pose. Area may get a mechanically justified short anticipation only if role 03 approves that same delay. **Recoil:** internal mass takes most travel, tool moves down/out of central lane, hand compresses without changing anatomical grip. **Recovery:** return action shows commitment but aim/control remain responsive. **Switch:** short lower/raise with no showcase flourish; the left support acquires its grip before ready. **Optional reload:** replaceable head/capsule rack handled at side/bottom; never add reload just because a drawing contains a magazine. If mechanics has no reload, depict automatic indexing within cooldown. **Pickup:** world prop clearly shows the same working head and grip, with fewer tiny markings and a pickup silhouette independent of the in-hand camera.

**Risk:** ordinary industrial tools can look harmless or interchangeable; a mechanism that visibly strikes internally needs convincing impact/audio so firing does not resemble a stapler. Bright casing may appear detached from a dark level. Kill this direction if silhouette tests or force perception fail; avoid compensating with more glow.

### B — Counterweight Arms

**Premise:** manually stabilised devices built around opposing masses, spring housings and stout articulated frames. Not magical relics, pressure-forge guns, Warhammer bodies, or elaborate spinning machines. Distinction is kinetic: the tool makes one visible opposing movement at each attack, then re-latches. Surfaces are broad dark cloth/leather grips and satin mineral composite, with light edge faces rather than ornate rust. Fiction remains a candidate.

| Role | Form and hands | Action grammar | Distinctive evidence |
|---|---|---|---|
| Precision | Offset fork and a dense rear counterweight; right hand fires, left supports lower rail | Small front striker advances as rear weight moves back; settle has one audible latch | Angular open fork vs thin A spine; two opposing motions but one shot |
| Close fan | Low crescent shield around a straight working edge; left hand braces a pivot | Working edge pulls back, side balancing arm moves down; recovery returns both | Broad curved outline and one lateral action, no double-barrel break-open imitation |
| Area | Squared frame with open center and a suspended projectile carrier | Carrier opens on discharge; counterweight drops only below sightline; then frame closes | Empty center remains visible; mass change is communicated without screen shake |

**Ready/rest:** restrained spring tension, no constant twitching. **Wind-up:** same shot latency as control; loaded pose already contains anticipation. **Muzzle:** tightly bounded vent/departure at actual outlet, not a giant aura. **Recoil:** opposing masses create weight while tool's aim axis remains steady; the camera is not mechanically yanked. **Recovery:** one latch sequence, with no oscillating overshoot after ready. **Switch:** hands retain common firing/support sides; tool lowers below the bottom, new support grip raises with incoming tool. **Reload:** optional manual carrier replacement below center after an authoritative ammo commit; not included in the first comparison. **Pickup:** folded/stowed counterweight is allowed but shares a recognizable open-frame motif; picking it up is not a mandatory inspection animation during danger.

**Risk:** visually busy movement can look like mechanical theatre unrelated to damage. Strong side movement may hide close flankers; the player may mistake carrier opening for a charge state. If the opposed motion cannot be read at target display pixels, reduce moving components rather than enlarge the entire viewmodel.

### What stays controlled and what actually differs

**Matched comparison:** mechanics, complete authoritative attack timeline, shot latency, cooldown, switch/cancel policy, hit rules, enemy response and perceived attack level are identical across control/A/B for each role. Role-specific screen anchors, uniform scale, bounding-envelope limit, muzzle aim alignment, maximum recoil envelope, protected HUD margins and sway settings are also identical. A/B differ only in silhouette within that envelope, internal pose/motion distribution, surface construction and mechanism sound character. The control's role placement (precision low-right, fan low-center, area low-left-to-center, with the same firing/support hands) applies to all three. Choose one common size inside each budget band before comparison; do not give B a larger tool by default. Compare motion muted before the full mix and sound with an identical control image before claiming animation improved sound.

**Later composition exploration:** only after that matched comparison, vary anchor/scale or recoil envelope one at a time, including an A-small/B-medium option. Label these as separate ergonomic experiments; their results cannot prove the visual grammar alone won. A change to the attack/switch timeline invalidates the matched comparison and must be applied to all conditions before repeating it. No comparisons have been run.

## 4. Projection, pixel and occlusion budget hypotheses

Use a bottom anchor and **height-relative uniform scale**, with explicit art pivot/muzzle/support-hand coordinates. Viewmodel scale may be independently adjustable from world FOV. For a sprite, do not vary art perspective when world FOV changes; test its relation to distant targets. For a 3D viewmodel, use a separately specified viewmodel projection and test matching aim axis, never assume world FOV is suitable for hands.

All budgets are initial hypotheses. Texture rectangle, alpha silhouette, effect footprint and actual blocked target pixels are different measures.

| Role | Full tool rectangle, fraction of view height | At 1280×720 | Rest opaque screen area starting ceiling | Motion at strongest kick |
|---|---|---|---|---|
| Precision | width .30–.42 H, height .24–.30 H | 216–302 × 173–216 px | 5% | internal or down/back travel 1–2% H |
| Fan | width .46–.60 H, height .28–.34 H | 331–432 × 202–245 px | 8% | 2–3% H; no ascent across reticle |
| Area | width .48–.64 H, height .30–.36 H | 346–461 × 216–259 px | 9% | 2–4% H toward bottom; motion under central lane |

Use one matched size per role for control/A/B, initially near the middle of its band; the bands support later one-variable composition exploration. Upper bands are rejection boundaries to investigate, not production entitlements. Do not shrink only height or widen only width to achieve them. Every frame needs fixed canvas/pivots with enough transparent room for recoil; crop from metadata instead of equal divisions of a loosely arranged illustration.

**Initial protected region:** central x=.40–.60 W and y=.30–.58 H is a composition aid, not proof of visibility. Measure the actual projected weapon alpha against target and reticle masks through every displayed pose. For the first supported **flat-floor, fixed-player-Y** test, use a lower-profile threat with authored tell height and a lateral flanker at 2–4 reference distance units after scale is agreed. Measure low pickups on that same floor. Lower screen position is produced by target form/distance and supported pitch, not unvalidated stairs or jumping. Sample projected target centers at .50/.65/.80 H where achievable without changing camera/movement rules.

**Projected mask protocol (proposal, not executed):** render a weapon-only alpha mask W per displayed pose using actual projection, scale, sway, recoil and filtering. Define opaque body mask O where W≥.95; separately retain W for alpha-weighted obstruction, so .90-alpha hands cannot evade the check. Render the identical world/camera frame without weapon/FX to produce masks for the reticle clearance zone R, whole target T and crucial wind-up feature Q (head, raised limb or outlet agreed with enemy art/behavior). Compute opaque obstruction |O∩T|/|T| and |O∩Q|/|Q|; weighted obstruction is sum(W over T)/|T| and likewise for Q. Report absolute covered pixels, target mask pixel count, fractions, worst contiguous obscuration duration and per-phase maximum; tiny targets make percentages unstable, so retain their images/pixel counts. Reticle clearance zone is a fixed 12×12 reference pixels at 720p, scaled by height; report any overlap, with a proposed zero opaque-body overlap gate. Do not mix reticle/HUD alpha into weapon W.

Run ready, discharge, kick, recovery, lower/raise and supported optional reload at lateral target offsets -.25/0/+.25 W relative to center, then capture a continuous left/right strafe plus mouse-track pass. Use the current 1280×720/16:9 path first; 4:3 and 21:9 are offline projected composition checks until renderer/aspect handling is validated, followed by actual viewport captures. Keep vertical FOV, target distance, camera path and role anchors matched across art conditions at each aspect. Initial rejection hypotheses: >5% weighted coverage of a crucial tell for more than one displayed frame, any sustained opaque blockage of that tell, or >15% weighted whole-target coverage during its wind-up. These conservative bands need player review; passing them does not prove readability. Log muzzle/smoke FX obstruction separately with the same masks and a combined final layer pass. Center-clear art can still fail the lower flanker, strafe edge or close-range mask tests.

**Screen variants:** 640×360, 1280×720, 1920×1080, 2560×1440; 4:3, 16:9 and 21:9. World vertical FOV 50°,60°,75° (not comparisons at inconsistent horizontal/vertical definitions); show derived horizontal FOV in captures. Preserve height-relative weapon proportions on every aspect. Verify safe margins against the actual HUD area and window drawable size. Pixel art test: render at 640×360 and scale by integers, then compare against direct native render. Do not independently pixelate weapon/HUD/world to incompatible densities.

At the smallest mode, identity should rely on working head/action silhouette, not a 1 px label. Optional initial effective sprite canvases 256–384 px high, with mechanism changes visible across at least 3 display pixels at 360p; this is a starting production hypothesis, not a reference-game metric. Detail can be hand-painted or rendered down, but no source resolution compensates for tiny projected features.

**Rapid tracking, supported baseline:** sweep across a same-floor caller, lower-profile threat and side flanker while strafing, firing, changing weapon and reversing mouse direction; keep the player camera Y fixed as in the present movement audit. Weapon sway follows a damped presentation-only signal and the measured mask gates above. Shot direction follows simulation aim regardless of decorative sway. Offer zero bob/sway and reduced flash with identical mechanics. Reduce/reposition excessive occlusion before using a transparent gun as its remedy.

**Later vertical capability check:** once engine/movement roles validate player elevation, collision, aim and supported map transitions, repeat the mask/tracking protocol for an enemy one elevation step below/above, ascent/descent and edge traversal. Until then, elevated-target compositions can only flag future art risks in offline images; failure cannot be attributed to weapon art rather than unsupported camera, collision or aim. Keep this separate from the first visual-grammar verdict.

## 5. Animation production and alpha policy

Two feasible pipelines: (1) hand-authored key sprites from a locked construction/perspective guide, with shared hand drawings and explicit anchors; (2) one simple physical rig, fixed camera, rendered key frames and manual cleanup. A rig improves mechanism consistency and repeatable exports; it costs up-front modelling and can produce sterile smooth renders. Key sprites are cheap for the neutral test; frame consistency becomes costly when more complex reload/switch states are added. Decide after one tool sample, not by a full arsenal commitment.

First-person tool has **one player-relative view**, not eight world directions. An alternate left-handed option needs a mirrored rig/camera or carefully authored variant: mirroring text, ejection, asymmetrical controls and right glove is not automatically valid. World pickup/third-person tool views are separate deliverables. Eight-view enemy rendering in Boltgun does not justify multiplying first-person frames by eight.

Neutral sample budget: 1 ready, 1 discharge, 2 kick, 2 recovery, 1 settled; lower/raise can use the ready image and transform; optional reload adds 4–6 genuinely different key poses only after ammo rules. A/B may need 8–12 key poses for one complete cycle. Numbers are workload estimates, not an animation quality bar. Frame hold times are authored per phase, never equal divisions by frame count. Interpolation is suitable for uniform tool translation; morphing unrelated sprite poses can produce extra fingers or soft anatomy and should be avoided.

Asset manifest should include tool ID, clip/action ID, canvas dimensions, art pivot, bottom anchor, muzzle coordinates by pose, hand identity, alpha mode, intended filtering, event references and frame durations. Supply source construction/rig, separate opaque tool and transparent FX, neutral alpha preview and light/dark checker previews. Handedness, glove seams, grip/thumb anatomy, outlet and support position remain consistent through every pose. No changing barrel count, fresh ornaments or hand swaps mid-cycle.

Use straight alpha or premultiplied alpha consistently with matching blend state. Separate opaque/cutout body edges from soft additive smoke/glow; preserve deliberate dark pixels, do not key black out of the gun. Pad atlas borders and clamp sampling. Assess semi-transparent edge contamination against white, near-black and saturated backgrounds. Check opaque silhouette and FX separately; alpha-min=0 is insufficient. Confirm no neighboring-row features, clipped recoil, filled gaps, and unwanted ground shadows. Nearest or linear sampling choice is deliberate at actual target size; min/mag mismatch needs a captured review.

## 6. Shared concrete attack timeline contract

This proposal is a **neutral close-fan** sample, not final balance: cooldown 600 ms, instant ray fan at acceptance, no mandatory reload. Role 03 bands allow it; gameplay designer owns changes. Everyone uses the same timestamped event packet. Renderer evaluates pose from simulation action age; it never commits ammo/damage from a frame callback. Artist event markers propose where an action belongs; a reviewed simulation schedule determines actual firing. A missed render frame still fires once, never twice.

| Simulation time | Authoritative event | Weapon art | Sound / lighting / feedback |
|---:|---|---|---|
| 0 ms | Input accepted; action ID created; ammo committed; rays resolved; `ShotEmitted` | Discharge pose on next displayed frame; mouth vents once | Dry attack transient scheduled from shot timestamp; one bounded light pulse; impacts use separately resolved contact events |
| 0–40 ms | No repeated damage | Muzzle accent 1–2 displayed frames as available; weapon begins down/back kick | Do not stretch flash to compensate for slow FPS; reduced-flash setting replaces broad glow with small outlet accent |
| 40–100 ms | Recovery phase | Maximum kick, sightline still clear | Early mechanical recoil component; enemy hit/miss/surface cues remain distinct |
| 100–350 ms | Locked recovery; movement/aim remain available | Return bar/weight handled below reticle | Mechanism movement/latch accents reference recovery markers; tails should not imply another shot |
| 350 ms | Proposed switch-safe phase | Outgoing lower may begin | Outgoing recovery sound cancels or tails according to event policy, never firing sound cancellation |
| 350–550 ms | Still in recovery if not switching | Return toward ready | No false ready click at 350ms if weapon is still locked |
| 550–600 ms | Ready anticipation | Stable loaded pose | Optional final latch at actual ready boundary, not from arbitrary frame number |
| 600 ms | `WeaponReady`; held trigger can start a new action | Ready, or immediate discharge for next accepted attack | Next attack uses a new event ID; no repeated old marker |

**Switch sample:** request at 200 ms queues until allowed at 350; 100 ms lower + 100 ms raise gives incoming ready at 550, if mechanics approves switch cancelling remaining old recovery. Alternative is preserving old recovery until 600 and raising afterward. These policies change throughput and require a role 03 decision; animation must not choose one accidentally. Before a real commitment event, cancellation is possible; after discharge, projectile/damage persists regardless of switch. Never retroactively refund ammo from a canceled cosmetic clip.

**Projectile variant:** same event relationship, but `ShotEmitted` creates the actual projectile and contact comes later. Visible trace begins at authored muzzle and blends toward actual simulation position without inventing a second projectile. At point-blank obstruction, show local surface impact; no long departure overlay continuing through a wall. Precision hitscan may have a very short tracer or none; avoid a drifting orb that lies about immediate contact.

**Shared test:** stationary shot at open range, close wall, moving target; then strafe/fire/switch at 30/60/120 rendered FPS and a deliberate frame hitch. Log action ID, input, shot, contact, ready and displayed pose; capture audio/video with a visual event marker. Proposed acceptance: first visible discharge within one displayed frame of its authoritative event, no duplicated shot, no missed event after hitch, contact never predicted before collision, held fire respects selected weapon rule. Audio hardware latency is measured separately; do not claim arbitrary audiovisual millisecond precision from video alone. No test has run here.

## 7. Cross-role agreements and performance

| Partner | Agreement needed |
|---|---|
| Weapon mechanics | Common mode authority; commitment/cancel/refire/switch/reload rules; no final art until action schedule survives neutral play |
| Combat feedback | Target hit vs armor/surface miss vs interrupt vs kill; damage event owns reaction; weapon recovery must not suppress threat tells |
| Weapon sound | Separate discharge, mechanism, ready, dry-fire, reload and projectile-contact IDs; source sound matched to visible action; one discharge transient per action |
| World sound/music | Weapon tails/mechanisms leave warning sounds audible; music intensity cannot conceal ready timing; low-volume and repeated-fire tests |
| HUD | One reticle owner; neutral shape/position independent of gun animation; ammo information remains accurate while tool is hidden; minimal-hud and expanded-hud layouts |
| Lighting | Tool base illumination matches scene family but has readability floor; emissive outlet vs body separated; muzzle pulse does not globally repaint all threats orange/cyan |
| Movement/aim | Aim is stable through kick; camera recoil optional and independently adjustable; all presentation settings preserve projectile direction/damage |
| Story/art/pickups | Tools match player role; world pickup has same identity; story-specific motifs wait for direction review |

Initial GPU policy: one body quad/rig plus one muzzle overlay and one optional local smoke component; no full-screen blur, dynamic soft shadow or additive sheet stack in the neutral test. Transparent overdraw, not polygon count alone, is a risk: report actual screen coverage and frame time in busiest sustained firefight. Example uncompressed 12×384×384 RGBA frames use about 6.75 MiB per tool before mipmaps, around 20.25 MiB for three; optional reloads/duplicates increase it. This is arithmetic, not a measured resident-memory figure. A packed atlas can reduce binds but needs padding and sane clip metadata. Budget a small active effect count and reuse pools; overflow removes low-priority cosmetic particles, never hides a committed shot's core cue or changes damage.

## 8. Review gates, failure cases and self-critique

1. **Construction review:** monochrome silhouette and seven key poses, annotated hand/pivot/muzzle. Fail on hand swaps, varying mechanism topology, no readable working head or clone-like iconic outline.
2. **Isolation/projection review:** checker/white/black assets, actual target pixel sizes, all aspect variants. Fail on row contamination, halo, stretching, clipped hand/recoil or mismatched pixel density.
3. **Timeline review:** shared logged neutral shot above. Fail on delayed muzzle picture, doubled flashes, false ready, wrong weapon recovery after switch or an impact occurring before authoritative contact.
4. **Threat review:** supported flat-floor caller/lower-profile threat/side-flanker test with projected masks, reduced effects and full effects. Fail on obscured enemy wind-up, low target hidden by tool, tracer falsely passing through cover, or tool sway stealing aim. Assess elevated targets later after engine/movement capability validation, in a separately labelled check.
5. **Weight/identity review:** 2–3 early reviewers identify role without label/color and describe the action; then a small counterbalanced play session if promising. Match cadence/damage/perceived shot level. Weight rating is subjective; retain recordings and descriptions, not invented certainty. Fail if sound louder alone explains preference or if mechanism complexity distracts from hitting targets.
6. **Repetition/mix review:** 30 shots, weapon switching, quiet headphones/speakers, full warning sounds and music. Fail on repetitive tiring glow, unrecognisable recovery at low volume, sustained overdraw spikes or warning cues masked by mechanism tails.

**Self-critique:** these are presentation grammars, not a complete original arsenal. Neutral precision/fan/area remains conventional by design, and A risks generic maintenance-tool fiction while B risks visible machinery for its own sake. Neither proves the game's identity or corrects weak encounters. The test isolates presentation so that failed core gunplay cannot be hidden by bespoke artwork. A protected-center rule underestimates low/lateral threats; projected masks and flat-floor tracking are required. Vertical movement is not validated and its later failures must not contaminate the first art verdict. Mask thresholds measure obstruction rather than perceptual recognition and need player corroboration. More frames can improve action but also multiply alignment mistakes and memory; pose clarity takes priority. Modern primary sources reviewed provide production principles and broad goals; frame-by-frame commercial weapon analysis would require owned game captures or developer footage timing, which was not done here.

**Licensing boundary:** the referenced commercial images, sounds, silhouettes, logos and franchise devices are study material, not Eyesore production assets. The id Doom repository supplies GPL-2.0 code licensing; that is not a blanket license for Doom game data/art/sound. The Wolf source readme has its own conditions. Any actual code reuse requires engine/license review; this report reproduces no code. [Doom license](https://github.com/id-Software/DOOM/blob/master/LICENSE.TXT), [Wolf readme](https://github.com/id-Software/wolf3d/blob/master/README.rst). Maintain provenance and terms for every purchased/generated/commissioned production asset; reference age alone is not permission to import it.

**Lead critique requested:** Is A sufficiently unlike generic utilitarian sci-fi to deserve a first sample? Does B's counterweight movement show real mass or merely clutter? Do the lower-center and low-left tests threaten flanker visibility even when the center remains clear? Resolve these with role 03/12/17 before committing an arsenal. The recommended immediate deliverable after approval is one neutral fan timeline sample plus one A/B silhouette comparison, not dozens of final sprites.
