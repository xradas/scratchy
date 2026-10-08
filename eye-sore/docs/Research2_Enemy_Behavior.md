# Eyesore round-two research: enemy behavior

**Status:** specialist research and design alternatives for critique. No AI code, enemy art, or production content was changed. **Model:** GPT-6 Luna / high. **Research date:** 3 October 2026.

## Decision summary

The prototype does not yet have four different enemy behaviors. It has one shared seek/attack loop with four numeric types, two marked ranged, and shared attack/pain/death timings. This is a useful harness, but awareness, navigation, attack commitment, and damage response are too coarse to validate authored encounters. Melee attacks do not require line of sight; enemies move through one another; there is no path graph; ranged releases can aim at the player's current position at the event frame; and enemies do not react to incoming player projectiles. Cross-type infighting exists in code but is not a tuned feature.

Preserve a small readable action grammar—inquire, approach, signal, commit, release, recover, react—while giving each enemy a different spatial decision. Do not create variety by multiplying health, projectile speed, or red particle effects.

Two distinct, unapproved systems are proposed:

1. **The Route Crew** (Red Mile, human-only possible): a linekeeper fires controlled lane bursts; a breaker commits to a straight rush and is punishable on a miss; a dispatcher visibly calls a staggered reposition/fire rhythm. Distinction comes from civic work habits and spatial timing, not elite military squad simulation.
2. **The Returned Routine** (Witness Works): hostile apparatus repeats a spatial routine learned from a prior event. A path-rusher traverses a visible recorded line, a lane-projector fires along one marked corridor, and a relay may repeat another unit's last announced action into an offset lane. The player solves sequence and safe space rather than tracking perfect aim. This makes the memory premise mechanical, but returns to the rejected/overused archive-echo cluster.

Neither is canon. Human roles are easier and lower risk; routine roles are more mechanically specific but need extra level/audio/animation work and might interrupt the shooter flow. A single-room test should precede a roster.

## 1. Project audit

### Existing runtime behavior (direct code observations)

Inspected linux-game/src/engine3d.cpp, combat_world.cpp, second-round engine/movement/art reports, current enemy sources, and the isolated Kiln Wretch concept. These describe source/assets, not a new playtest.

| System | What exists | Consequence |
|---|---|---|
| Actor/state | One Enemy struct has position, HP, facing, clip clocks, attack cooldown, roam timer/heading, alive/event/gib flags, one state, numeric type and target_enemy. States: Walk, Pain, Attack, Death, Gib, Corpse. | No explicit awareness, investigate, windup, release, recovery, stagger or target-confidence state. Several are folded into Walk/Attack. |
| Awareness | enemy_notices_player is a 2D distance check: 18 units for types 1/2, 12 otherwise. No facing, sight, hearing or door test. Ranged types separately check clear shot before release; melee may engage from distance alone. | Nearby melee enemies effectively know the player through walls. Replace with sight/stimulus and bounded last-known position. |
| Sound | Mixer/player noise never affects AI. | No sound-based awareness. Doom-style sector propagation is useful only if audio and level roles define a purpose for it. |
| Approach/navigation | All use ENEMY_SPEED=.58, same target-facing turn rate, axis-separated box movement. At ranged distance with blocked shot, enemy index chooses fixed left/right strafe. Idle roaming changes heading on a timer. No path graph or actor-vs-actor collision. | No authored flank, retreat, approach lane, stuck recovery, or role route. Box avoidance should not be described as pathfinding. |
| Aim/commit | Ranged actors face target while moving; Attack sets facing once, but launch_enemy_projectile calculates a fresh trajectory at the release event using the player's current position. | A pose can look committed while the shot still tracks. Snapshot target point/trajectory on commit. |
| Attack | Shared four-frame clip, 0.53 s total; frame 2 event at about 0.26 s. Ranged cooldown 1.15 s, melee .65 s. Melee horizontal range check <=1.40, shared for all. | Prototype values, not validated tuning. Melee can hit through walls because release has no sight/trace and uses no directional swept volume. |
| Pain/interrupt | Nonlethal hit outside Attack enters shared .28 s pain clip; hits during Attack do not interrupt. No damage threshold, directional flinch, poise, stun or stagger. | Brittle “always flinch unless attacking” rule. Weapon×role interrupt contract is missing. |
| Death/corpse | Death/Gib clips last .64/.55 s, then static corpse. AI stops. The pose-aware collider changes dimensions during death, but player movement and attacks skip dead actors and corpses are not solid movement obstacles. | Corpse obstruction/removal is not a designed rule. Decide per class before effects or dismemberment work. |
| Height/collision | Render and hitbox separate; pose-aware oriented 3D ellipse used for living-target traces/projectile checks. Melee is horizontal only. All four definitions exceed the fixed player camera anchor height. No multi-floor/grounded/flying contract. | Low or flying enemies require engine/movement decisions first. |
| Projectile avoidance | No reaction to player projectiles; movement ignores them. | Never add universal perfect dodge. Any specialist dodge needs cue, cooldown and bounded movement. |
| Infighting | damage allowed only across different numeric types; same type immune. Enemy projectiles hit living actors except owner. Victim records attacker as target. Self-test expects cross-type retaliation, same-type immunity. | Code rule has no story/faction basis. Use explicit team IDs; don't equate type variation with hostility. |
| Group pressure | Fourteen static enemy slots/waves, no threat budget, role caps, schedule or director. | Level design owns overlap currently; author pressure windows rather than HP inflation or global spawn AI. |

Round-two Engine Architecture identifies variable-delta monolithic update, fixed capacities, no connected nav graph/area activation and box-only movement/visibility. Its recommendations include explicit actor/event contracts, fixed step, shared traces and authored areas. Movement report says collision/height/jump unresolved. These constrain claims but do not prevent testing a bounded encounter.

### Sprite and rejected-proposal review

- Current enemy-1 directional sheet: red-armored torch-bearing upright humanoid, skull-like face. enemy-2: hovering, flame-surrounded armored figure with bright red/orange centre. Their shared red/black armor, mask/bright-centre and flame language weakens role separation at gameplay scale.
- Isolated Kiln Wretch sheet: low hunched horned mask, bright orange core/cinder mantle. Its own README says review-only generated concept with no combat states and similar walk poses. Not approved; this report does not extend it.
- The prior Glass Choir/Suture/Stapler/Prism Tender list is not canon. Keep its useful role verbs/telegraph focus, but reject it as default because it returns to the already-overused optical/tissue direction.
- Research2_Art_Direction confirms current combat poses are not directional, all types share attack/pain/death clips, and computed sprite tint is overwritten. New AI needs unique pose timing, directional attacks and collider/pivot contracts; those do not exist yet.

## 2. Reference research

### Doom

**Source facts.** Monsters are actor/state definitions; A_Chase handles target validity, movement direction, melee and missile tests. P_CheckMissileRange needs sight, respects reaction delay, varies choice by range/type, and allows a just-hit actor to counterattack. Ordinary chase prevents consecutive missile attacks before moving again outside fast/Nightmare settings. P_NoiseAlert propagates an alert through adjacent open sectors, respecting closed doors and one sound-block limit. P_DamageMobj can trigger per-type pain chance, clear reaction time and change target under ownership/threshold rules. A missile can hit another monster and provoke retaliation. Sources: [p_enemy.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_enemy.c), [p_inter.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_inter.c), [info.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/info.c).

**Inference.** The roster creates different spatial choices—clear lane, dodge projectile, escape approach, stop support—rather than one universally smart enemy. Keep state/actions authored. Sound can wake an area without wallhack tracking. Infighting emerges from damage-source/target rules, not a friendly-fire toggle.

**Limit.** Doom's 2.5D sectors and old simulation conventions do not validate modern vertical combat; do not copy quirks or numbers as design requirements.

### Wolfenstein 3D

**Source facts.** Guard states include stand/path/chase/shoot/pain/death. Path uses tile movement. In T_Chase, clear line permits a distance-dependent chance to shoot; T_Shoot separately checks line/area and adjusts hit chance for distance, player movement speed and visibility. [id Software WL_ACT2.C](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_ACT2.C).

**Inference.** Simple behavior can feel alive if the exposure contract and attack pose are readable. Do not transfer probabilistic hitscan into free movement; random direct damage can feel arbitrary, and grid pathing doesn't solve our navigation gap.

### DUSK

Creator David Szymanski called the opening a “fake deep end”: room to kite and enough survivability for players to learn movement/enemy behavior through play. He also discussed varying encounters through enemy placement and connected spaces. [Game Developer interview](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games).

**Inference.** Teach one role in a generous first exposure, then recombine it in altered geometry. Judge player movement decisions, not an asset sheet.

### Prodeus

The official page describes fast, frantic combat, hordes, a hand-crafted campaign and community editor. It does **not** disclose enemy AI internals or attack timings. [Prodeus official page](https://store.steampowered.com/app/964800/Prodeus/).

**Limit.** No claims about Prodeus awareness, pathing, enemy states or balance figures are made here.

### Boltgun

Auroch explains its FSM: states include aware, unaware, attack, flinch, dead and overkill. Enemy animation data can time damage, sound and projectile events. Encounters use spawn points and zones that enemies move toward; its art pipeline renders rigs into eight-direction sprites. [Auroch developer article](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/).

**Inference.** Authored zones and synchronized attacks matter more than complex AI. Current engine has no encounter-zone/nav model, so start with one bounded arena. Do not import 40K silhouettes/factions/actions/icons.

### Dead Space

Motive describes visible damage layers that communicate enemy weakening without a health bar; dismemberment is tactical. The team notes Leapers can be easy to lose track of when several are present and they climb across walls/ceilings. Its Intensity Director combines authored sound, lighting, fog/steam and enemy events. Sources: [Necromorph design](https://www.ea.com/able/news/inside-dead-space-2-new-necromorph-nightmare), [Intensity Director](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director).

**Inference.** Damage response can communicate tactical change, but surprise has a tracking cost. Use role-specific posture/state feedback if useful; do not copy dismemberment, limbs, or concealment. A ceiling enemy is a poor first class while height, aim, collision and sound occlusion are unsettled. Use authored intensity, not wallhack spawners.

## 3. Shared behavior contract

State flow proposal:

~~~text
Dormant --sight/noise/authored wake--> Investigate(last cue)
  ^                                      | cue reacquired/expires
  |                                      v
  +--return to anchor <-- Search <-- Approach
                                  | range/lane valid
                                  v
                         Telegraph / Commit
                           | event tick
                    hit/interruption?  Release
                           |              | completion
                           v              v
                         Flinch      Recovery --> Approach/Choose
                           ________________/
                                  |
                         lethal damage -> Death -> Corpse/cleanup
~~~

| Contract | Proposal | Fairness reason |
|---|---|---|
| Perception | Sight uses map trace and authored cone/peripheral rule. Hearing gets tagged source point/propagation class and gives investigate point, not exact live player position. On lost sight, bounded last-known search. Pre-awareness needs cue. | Fixes current wall awareness. Audio/world roles choose propagation model. |
| Target/allegiance | Store target ID, last point/age, team, attacker. Filter friends by team, not numeric enemy type. Projectile collision and AI provocation are separate rules. | Variants should not alter friendship. |
| Approach | Role owns distance band and route preference: close, hold lane, approach named point. Bound steering/stuck retries. Without nav graph, label true flanking unsupported. | Prevents box avoidance being misdescribed as pathfinding. |
| Commit | Validate range, LOS, floor/height and target. Snapshot aim/trajectory; no correction beyond advertised turn envelope. Target switch during wind-up cancels explicitly. | Prevents present release-time correction. |
| Attack events | Stable attack ID and named tell/commit/release/active_end/recovery events, tick, trace/damage rule, source/target/cue IDs. One release per ID. | Avoids double/missing events as art changes. |
| Interrupt | Role defines interruptible, armor-window or threshold-stagger. Damage and attack cancel are separate. Collider changes are not arbitrary frame side effects. | Makes weapon impact meaningful without universal flinch/perma-lock. |
| Damage/corpse | Authored visible posture/material damage state; few readable states. Per class choose pass/fade, solid, or temporary body collision; revalidate navigation/shot occlusion. | Uses Dead Space's information lesson, not its gore/simulation cost. |
| Space/height | Collider, support point, target height, clearance, reach and swept attack volume independent of sprite. Area attacks visibly mark actual area. Melee uses sweep/LOS. | Fixes current horizontal-only melee hit. |
| Avoidance | No universal projectile dodge. One role may react visibly with cooldown; no perfect hitscan evasion or mid-flight homing. | Preserves player prediction and explainable misses. |
| Difficulty/groups | Prefer composition, authored attack schedule and tested bounded recovery/damage. Keep health/speed stable at first. Limit simultaneous high-commit threats; visible/announced entrances only. | Supports learning; no blind behind spawns or bullet sponge tuning. |
| Determinism | Stable simulation tick/order and logged seed. Record transition reason, target, attack event times, collision, hits, interruption, stuck count. | Needed for reproducible review; current variable-delta loop obscures timing. |

### Timing hypotheses only (not measured commercial values)

| Event | Experiment band | Test question |
|---|---|---|
| Human cue to ranged damage | 0.65–1.0 s | Can a new player identify/dodge while aiming after one exposure? |
| Rush tell to contact | 0.55–0.8 s plus travel; no homing | Can they sidestep based on direction? |
| Nonlethal flinch | 0.12–0.30 s by role/weapon | Does pistol register without shotgun-locking heavies? |
| Recovery after committed miss | 0.45–0.9 s | Is there a readable punish window? |
| Search after LOS break | 2–5 s before search/return | Can the player predict where it moves? |
| Concurrent high-risk releases | 1 at solo teaching, 2 in combinations | Does pressure create choices rather than unavoidable damage? |

These are hypotheses. Current .26 s release, .28 s pain, .65/1.15 cooldown and distances are source facts, not validated targets.

## 4. Ecology A — The Route Crew (Red Mile, human-only variant)

**Premise:** People follow conflicting emergency/maintenance orders during a sealed civil emergency. A human-only slice is possible: automated barriers remain authored level hazards, not AI enemies.

| Role | Behavior promise and tell | Player answer | Scope/risk |
|---|---|---|---|
| **Linekeeper** | Holds a lane and fires short, cadence-limited bursts from a station. Lost sight means cease fire; may move only to another authored station. Audible call and weapon set; aim point fixed at burst start; reload exposes it. | Break LOS/cross during burst, punish reload. | Low-medium with trace and stations; high generic-gunman risk without a specific tool/stance/job. |
| **Breaker** | Leaves slot and commits to one straight charge with heavy work tool. No steering after commit. Miss embeds/clatters tool; blocked path stops/recoils. | Step perpendicular; fire during recovery. | Medium; needs committed move/sweep. Avoid becoming standard armored charger. |
| **Dispatcher** | No hidden accuracy/HP buffs. Calls one order for at most two allies to reposition/act on staggered cadence; then a weak sidearm/retreat role. Cannot spawn support. Baton/route paddle + two-part whistle; visibly staggered responders. Kill/interrupt before release cancels order. | Target caller or move with the announced sequence. | Medium-high. Remove from first slice if it becomes a required boss-helper. |

Teach each alone, then one Linekeeper + Breaker from a visible doorway; later the Dispatcher changes order/timing, not stats. One faction should not target itself. Physical friendly fire, if allowed, is distinct from AI retargeting. If multiple hostile groups exist, define explicit team IDs, not costume-based rules.

The signature is human enemies coordinating through public-address/work-call cadence and route tools. This is not unprecedented; drop it if audio/poses don't make the call readable or the duties still feel like generic guards.

## 5. Ecology B — The Returned Routine (Witness Works, replay-world)

**Premise:** Avoid a cult/organism faction. Threats enact short physical routines left by a catastrophe; the committed sequence is visible and separate from the player's live position. The player fights the routine, not an all-knowing monster.

| Role | Behavior promise and tell | Player answer | Scope/risk |
|---|---|---|---|
| **Returner** | Repeats a short route, then makes one straight close pass; retreats/ends at route anchor instead of steering after commit. Segmented path strip and ascending mechanical/human cue reveal line. | Leave lane at right angle; shoot across it and punish recovery. | Medium-high; needs path IDs. Risks “echo double” cliché or decal/actor confusion. |
| **Line Imprinter** | Fires one projectile along a fixed mark-to-mark lane after cue; no tracking after commit. Moves only after recovery. A thin line builds to endpoint plus distinct sound. | Leave marked line and attack reset. | Low-medium with authored marks; can read as ordinary turret with archive paint. |
| **Relay** | Repeats another active unit's last announced action into offset lane after delay; cannot relay a relay or copy an unannounced action. Source death before release cancels. Mirrored cue, one copy maximum. | Choose gap between original/offset, shoot relay during setup. | High and optional; cue overload / threat-processing risk. Drop unless immediately legible. |

Teach Line Imprinter alone, then add Returner whose route crosses but doesn't stack with the lane. Relay stays late/paper-only pending test. Signature is visible committed afterimage routes, not eye/glass/tissue. But it depends on replay story and does not solve its conceptual repetition. A physical attack may hurt an actor it crosses; that collision does not silently change allegiance/target.

## 6. Story-neutral control ecology: Hold / Cross

The two story-linked ecologies above should not be the first comparison if story itself is still open. Add a deliberately plain control with only two behaviors. Its purpose is to prove whether weapon cadence, dodge space, and attack commitment are fun before fiction, elite coordination, or a novel system can influence the result. Working labels only; not a proposed final roster.

| Behavior | Rules using current primitives | Player decision | Scope and limitation |
|---|---|---|---|
| **Hold** | Remain at an authored spawn/anchor. Use the existing clear-shot trace against the player and other actors. When attack begins, snapshot the target point; release a visible, slow projectile toward that point only if the trace is clear. Do not chase or correct aim after commitment. | Break sight, cross the lane after the tell, or use the recovery interval to attack. | Low. Uses current Vec3 positions, trace/LOS and projectile collision. The target snapshot and explicit event tell are small additions to behavior logic, not a new engine feature. The current shared attack clip is not yet a good class-specific tell. |
| **Cross** | Use current distance-based awareness/direct seek and the existing world-block test to move toward the player. Once within a fixed range with clear LOS, commit to a short, direct movement/attack along the observed heading, then stop for recovery. No flank path, actor avoidance, homing, or vertical movement. Use bounded substeps on this specific move to reduce tunneling against current box geometry. | Move out of a visible line/approach; punish the predictable stop/recovery or use the room's cover to divide the roles. | Low-medium. Uses existing X/Z move and blocked/trace primitives, but current variable-delta update and point-tested movement do not guarantee a safe high-speed sweep. Keep the first comparison slow enough to avoid relying on a claimed swept collision; defer fast charge until engine collision is upgraded. |

**Same-room comparison.** Use a compact rectangular room with a visible entrance, one waist-height solid box, one wide lateral lane, and a visible exit. Start with one Hold actor alone, then one Cross actor alone, then one of each. Place the Hold actor across the room and Cross actor at a visible side entrance. Keep health, damage, player weapon, player speed, aim point and room unchanged between variants. No spawn behind the player, pickups, story clue, order call, replay, or dynamically changing geometry. The only question is whether reading two attack verbs creates a clear movement/target-priority choice.

| Variant | Expected decision | Evidence to collect |
|---|---|---|
| Hold only | Read aim tell, break LOS, choose when to cross | Tell identified before first hit; shot point matches committed lane; shots correctly blocked by cover; player can punish recovery. |
| Cross only | Keep enough room, leave direct approach line, exploit recovery | Player sees approach before contact; movement does not clip through box; player can dodge laterally; no melee hit through wall. |
| Hold + Cross | Break the ranged lane without retreating into the approaching actor; choose which threat to interrupt first | Distinct threat priority language in post-play question; no simultaneous unavoidable hits; one role doesn't occlude the other's tell; result differs from merely increasing enemy HP/count. |

This control does not claim newness as fiction or as an unprecedented enemy design. It gives the project a low-cost, story-neutral combat baseline. If it is not enjoyable/readable, the bespoke systems cannot rescue that core. If it is enjoyable, add only one extra verb at a time and compare it against this baseline.

## 7. Comparison and recommendation

| Criterion | Route Crew | Returned Routine |
|---|---|---|
| Originality vs rejected designs | More distinct than infernal cultists/Glass Choir, but rail guards risk generic dystopia. | Mechanically specific, but directly inherits memory/replay theme and risks outcome repetition. |
| Role diversity | Lane, displacement, call cadence. | Path traversal, fixed lane, delayed relay. |
| Readability/surprise | Concrete pose/tool/call cues; lower surprise. | Geometry gives lane prediction; overlapping cues can confuse. |
| Human-only | Yes. | No. |
| Current engine fit | Best in static authored stations; pathfinding absent. | Line Imprinter fits; route/relay require path markers and fixed-step scheduling. |
| Sprite readiness | Human basis exists but red-robed cultist is not approved; new poses needed. | Needs directional path/relay frames; combat atlas lacks facing. |
| Main risk | Whistle unit is conventional support enemy dressed in premise. | Theme-as-mechanic is not proof of fun; echo lanes can become a puzzle interruption. |

**Recommendation:** validate Hold/Cross first in the same room because story, audio motif, and bespoke team mechanics cannot hide weak baseline combat. Then compare a story-linked role against it, changing one variable at a time. Trial Route Crew Linekeeper + Breaker if human-only direction is wanted; trial Line Imprinter first if Witness Works is selected. Relay and Dispatcher remain deferred ideas. No roster is approved; don't scale current enemy HP.

### Three-way comparison in the common room

| Dimension | Hold/Cross baseline | Route Crew | Returned Routine |
|---|---|---|---|
| Behavior changes being tested | Lane hold + direct approach/commit. | Lane hold + direct approach with job identity; Dispatcher is held out. | Marked lane + fixed path pass; Relay is held out. |
| Story influence | None. | Human emergency crew context and route tools. | Replay event context and path marks. |
| Current primitive fit | Best: LOS trace, existing projectile, X/Z blocking. Fast Cross remains limited by point/variable-delta collision. | Linekeeper fits; Breaker uses bounded direct move. Dispatcher requires coordination and is excluded. | Line Imprinter fits; Returner requires fixed authored path. Relay excluded. |
| Primary question | Is two-verb spatial pressure itself fun and readable? | Does job/call identity add meaningful decision or only decoration? | Does visible repetition add meaningful route prediction or only thematic effect? |
| Extra work over baseline | Minimal behavior data and clear event cues. | New human sprites/sounds and role identity; no extra AI system for first pair. | New markers, path authoring, directional poses and route cue integration. |
| Main falsifier | Player sees it as generic/trivial or attacks overlap unfairly. | Player describes both as generic soldiers; coordination cues don't read. | Player cannot state why the attack will repeat or calls it random/puzzle-like. |

### Explicit engine deferrals

- **Pathfinding, true flank/reposition, and authored multi-room stations:** current code has no connected nav graph, actor route validation or stuck recovery. Requires map areas/portals, path/slot rules and common actor collision before it can be called robust.
- **Fast charge or lunge with guaranteed collision:** current actor movement uses variable delta plus point-like X/Z blocked checks; no continuous swept actor body. A bounded low-speed Cross test is possible, but a fast charge requires fixed/substep simulation and swept collision/stop response.
- **Vertical/flying/climbing enemies or floor-separated attacks:** no authored ground/support query, multi-floor actor traversal, step/landing/fall rule or complete vertical hit/LOS contract exists.
- **Dispatcher order coordination:** needs stable simulation timing, group/team IDs, explicit ally command/cancel state, deterministic event scheduling, and simultaneous-threat budgets. Keep out of the control ecology.
- **Returned Routine paths and Relay duplication:** need authorable route IDs/marks, deterministic fixed-tick replay, event ownership/cancellation, multi-cue timeline and navigation-aware geometry. Repeating attacks without these would be fragile or unfair.
- **Infighting as a designed tactic:** current cross-numeric-type rule must become explicit faction/team and provocation behavior; otherwise different variants accidentally determine alliances.
- **Role-specific damage/body dismemberment and corpse blocking:** current implementation has no wound-state/limb contract and corpses are non-solid. Requires weapon damage-location, sprite/effect states and collider/cleanup rules. Dead Space dismemberment is not a baseline requirement.
- **Sound-based awareness across doors/areas:** no gameplay audio stimulus or connected sector/acoustic graph. Requires tagged events and level-defined propagation; do not fake hearing by global alert.

## 8. Matched encounter trial (hypothesis)

Hold player speed, weapon, geometry and sight distance constant. Use one wide room, one visible side door, waist-height cover, visible exit, no blind spawn and no pickup in first exposure.

| Beat | Route Crew | Returned Routine | Record |
|---|---|---|---|
| Wake | One visible/calling Linekeeper. | One Line Imprinter activates and draws one lane. | Cue seen before damage? |
| Dodge | First burst after call/posture. | Projectile commits to endpoint. | Cue-based dodge or random motion? Tell-to-hit? |
| Punish | Reload/reposition window. | Visible reset window. | Shoot versus retreat choice? |
| Combine | Add Breaker from visible doorway. | Add crossing Returner route. | Role cue interference? Route change? |
| Learn | Swap positions without stat changes. | Rotate lane/path, same timings. | Can player predict rule instead of memorizing map? |

Use the Hold/Cross same-room baseline immediately before those story variants. Keep player speed, first weapon and geometry fixed. For each comparison, add only one authored role change; don't compare a two-enemy baseline to a five-enemy candidate.

Ask world/QA roles to review before art/code. Test two roles at same player/weapons/room; no roster from prose.

## 9. Cross-role contracts

| Partner | Required agreement |
|---|---|
| Engine | Stable states/attack IDs, simulation tick/order, team IDs, sight/sweep/area traces, support/target height, pose collider, projectile source, corpse policy, reset. Render code cannot own damage. Current variable-delta loop requires engine review. |
| Movement | Run speed/body dimensions, pitch/trace, dodge time/space, input latency, projectile visibility. Tell fairness accounts for wall/collision limits. |
| Weapons | Cadence, damage, stopping power/stagger, ammo, splash, hit channel. Stagger thresholds as weapon×role table. |
| Creature art | Per-role body plan, pivot, directional tells/pain/death, visible contact/recovery poses, clearance/collider. No color-only tell. Animation markers describe events; engine is timing authority. |
| Effects | Attack area/radius/duration/obstruction, visible projectile path, impacts, stagger/death/corpse footprint. Don't cover target/follow-up cue. |
| Audio | Awareness/investigate/commit/release/reload/recovery/pain/death/order cues, priority/distance/door path. Cue cannot be sole dodge channel. |
| Lighting/art direction | Threat, route, interaction and world values stay separate under flicker, muzzle flash, low brightness/color vision/compression. Pose/motion also cues attacks. |
| Level/encounter | First appearance has space and visible approach; no blind rear spawn; cap simultaneous damage windows; allow an escape/counter route. Compose behavior, don't add HP. |
| Story | Job/faction/allegiance and plausibility. Clues work during fast play, no dialogue requirement. |
| QA/accessibility | Deterministic seed/config; first-time/repeat trials; mono/color-vision/reduced-flash/subtitle/loudness checks; reports outrank telemetry. |

## 10. Instrumentation and playtest questions

Record seed/build/config, each state transition/reason, target/age, LOS and heard cue, route/slot, stuck/repath, attack ID/tell/commit/release/recovery, target point at commit/release, collision, hit/damage source, interrupt, death/corpse, concurrent threat count, and player HP/ammo/position/speed/facing. Cause-code hits: missed tell, occlusion, post-commit tracking, blocked dodge, dogpile, unexpected LOS, unheard cue, height mismatch, corpse obstruction, other. Record shots blocked by allies/geometry.

Ask players:
1. What did this enemy seem to want to do?
2. What warned you, and where would the attack land?
3. Did it change aim after warning? Fair or unfair?
4. Could you tell it had taken damage/been interrupted? Did that alter your next shot?
5. Did another enemy block/distract/damage it? Useful or random?
6. Did you change route? Did collision stop your expected answer?
7. What surprised you fairly? What hit with no response chance?
8. Describe each role without prompt. If two labels/answers match, cues or behavior are not distinct enough.

Report distributions: cue recognition, dodge reaction, failure causes, aim acquisition, time-to-kill by weapon, stagger-lock, hits/window, stuck duration, top simultaneous threat count. Compare first and repeated exposure and placements. A small sample is directional evidence, not validation.

## 11. Self-critique and limits

Unresolved: human faction vs anomalous process/creatures; native FPS commitment versus stale browser README; whether replay is selected; how attacks should be interruptible.

**Direct critique:** shared state loop is a prototype, not a roster; expanding it to 14 types scales the wrong abstraction. Route Crew risks “generic soldier with whistle.” Returned Routine may merely turn a narrative motif into an effect. Neither has player evidence. One humanoid and one non-humanoid with different space-control verbs may be better after level design supplies a real map contract. This challenges both proposals.

I inspected source/assets, not a live playtest. Doom/Wolf facts are from source; DUSK/Boltgun from developer material; Prodeus internals remain undocumented by sources cited here; Dead Space is a survival-horror comparison, not a fast-shooter baseline. No commercial HP, damage, windup, recovery, projectile speed or spawn values are claimed. Timings above are explicit experiment bands. Do not copy reference assets.

## Sources

- id Software: [Doom p_enemy.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_enemy.c), [p_inter.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_inter.c), [info.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/info.c).
- id Software: [Wolfenstein 3D WL_ACT2.C](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_ACT2.C).
- David Szymanski: [DUSK design interview](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games).
- [Prodeus official page](https://store.steampowered.com/app/964800/Prodeus/).
- Auroch Digital: [Boltgun enemy FSM, attack/animation events, spawn zones and sprite pipeline](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/).
- EA/Motive: [Dead Space damage/behavior](https://www.ea.com/able/news/inside-dead-space-2-new-necromorph-nightmare), [Intensity Director](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director).
- Project: [engine3d.cpp](../linux-game/src/engine3d.cpp), [combat_world.cpp](../linux-game/src/combat_world.cpp), [round-two engine](Research2_Engine_Architecture.md), [round-two movement](Research2_Movement_Aiming.md), [round-two art](Research2_Art_Direction.md), [creature redesign](Creature_Redesign_Research.md), [story integration](Story_Integration_Research.md), [enemy-1 source art](../public/enemies/sources/enemy-1-directional-source.png), [review-only Kiln Wretch](../public/enemies/prototypes/kiln-wretch-contact-sheet.png).
