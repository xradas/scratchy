# Eyesore round-two weapon mechanics research

**Status:** research proposal only; no weapon direction is approved and no code, sprite, or audio was changed. **Date:** 3 October 2026. **This round launched on GPT-6 Luna / high, before the model update.** Numeric bands below are controlled-playtest starting points, not recovered commercial-game tuning values. This report intentionally challenges the current pistol/shotgun/arc trio instead of elaborating it.

## Decision summary

The current prototype has three labels but not three dependable weapon contracts. Standard play fires one slow, visible projectile for each of the pistol and shotgun; calibration silently swaps those weapons to immediate hitscan and changes shotgun into seven pellets. The arc cannon is also a projectile, but it has a separate path and damage event. Weapon cooldown, view animation and trigger event are separately timed; no weapon has ammunition or reload handling. This makes the calibration room unsuitable for deciding how the arsenal should feel.

The first decision is not “which Doom weapons should we reproduce?” It is: **what kind of combat decision should a player make repeatedly, and what fiction makes that decision distinct?** I recommend retaining no current weapon name or mechanic as a requirement. Compare three deliberately unusual ecosystems against one orthodox control set in the same neutral encounter, with visible hit timing and identical perceived loudness. A limited starting weapon set should make different decisions through trajectory, commitment, space control, target state, or resource use—not by attaching new names to a pistol, shotgun and blue projectile.

### Findings that affect every follow-on report

1. **Mode divergence:** pistol damage is 1.0 per single moving projectile in normal play, but calibration uses 3 damage hitscan. Shotgun is one 2.5 damage projectile normally, but seven 1.25 damage rays with spread in calibration. This is a measured code difference, not a playtest judgment.
2. **No ammunition decision:** all three player weapons are effectively unlimited. The only resource decision currently authored is whether to use a weapon at all; there is no magazine, reload, reserve, pickup, or shared-ammo pressure in firing code.
3. **Enemy health is not on a comparable player-facing scale:** the 14 authored enemy slots use 4–14 HP; there is no enemy HP display (the explicit health-bar constant is disabled), no player ammunition display, and no defined damage/material tiers to teach the implied values. The calibration HUD does display player health, so this is not a claim that all health UI is absent.
4. **The weapon-animation timeline is internally inconsistent:** shotgun/arc attacks may be ready again at 1.5 s while the view animation ends at 1.2 s; pistol is 0.5 s for both. The firing event happens immediately on input and there is no animation marker driving it.
5. **Earlier shotgun A/B/C sound work is rejected.** It varied post-processing/layers of gun recordings, not the weapon's mechanical behavior; it does not validate shotgun identity, cadence, or sound quality. Audio design must follow the approved shot event and animation markers after mechanics are settled.

## 1. Prototype audit: source facts and consequences

Inspected `linux-game/src/engine3d.cpp`, current weapon textures/audio names, and `public/audio-prototypes/shotgun/REVIEW.md`. The executable/build contains changes from the prior prototype attempt; this report does not treat that scene as accepted.

| System | Current source behavior | Mechanical consequence / confidence |
|---|---|---|
| Slots and names | Index 0 `ember pistol`, 1 `rivet shotgun`, 2 `arc cannon`. Weapon selection is keys 1–3. The shotgun and arc are unlocked through wave/cache triggers; selecting a weapon changes the integer immediately. | Names suggest distinct weapons, but no explicit in-world functional identity exists. Switch is instantaneous in code. **Confirmed.** |
| Fire input | Held mouse or Space calls fire each frame. If `fire_timer <= 0`, one attack occurs, then cooldown is added. Timer is reduced later in the same update. | Auto-repeat is timer-gated, not animation-gated. A held trigger repeatedly fires. There is no press-only distinction, burst queue, reload interruption, or explicit cancel state. **Confirmed.** |
| Cadence / animation | Cooldowns: pistol 0.50 s, shotgun 1.50 s, arc 1.50 s. View animations: 0.50 / 1.20 / 1.20 s. Three/four atlas frames are distributed by normalized elapsed time. | As authored, this implies rates up to 2 shots/s, 0.67/s and 0.67/s when trigger remains held, before frame-step effects. It does not prove perceived cadence. Shotgun/arc anim returns 0.30 s before ready. **Code arithmetic; needs playtest.** |
| Normal pistol | One projectile at 18 units/s; 1 damage; radius .09. It ceases when blocked by a wall/floor/ceiling or enemy. No lifetime/range cap is visible in the update loop; it can persist until collision. | Time-to-target is distance/18 seconds plus frame/collision delay: e.g., 10 world units ≈ .56 s. Hit feedback arrives on collision, so the attack feels delayed and target can move before impact. Only 1/4 to 1/14 of current enemy HP per hit. **Confirmed values; example derived.** |
| Normal shotgun | One projectile at 14 units/s; 2.5 damage; radius .18. | Despite its name, it has neither pellet fan nor spread in standard play. Approx 10-unit flight takes .71 s. One slow projectile is mechanically unlike a close-range spread gun and may miss moving targets. **Confirmed values; implication.** |
| Calibration pistol/shotgun | Calibration mode uses `fire_hitscan`: pistol is one 3-damage ray; shotgun is 7 rays × 1.25 with .105 directional spread; 36-unit ray limit, nearest enemy/surface occludes. The spread generator is initialized once with a fixed seed and shared stream. | Calibration damage is 3× normal pistol, total ideal shotgun damage 8.75 (if all pellets hit one target); the seed makes the sequence repeat per run rather than visibly random across sessions. A room playtest cannot be transferred to standard mode. **Confirmed values; ideal pellet arithmetic.** |
| Arc cannon | Single global `Projectile`, speed 20, 4 damage, radius .13; 1.5 s fire cooldown. Swept/stepped collision detects wall and enemy hits. No ammunition or explicit expiry appears in this player-projectile update. | Its role is visually/kinematically projectiles but damage is only 4 against 4–14 HP; at 10 units travel time is .5 s. Single global projectile means only one active arc shot; firing is blocked by the 1.5 s timer regardless. **Confirmed.** |
| Enemy interaction | Damage is delivered on projectile/ray collision. The current hit helper and damage path apply HP, optional death/gib (with shotgun-specific conditions), hit cue/feedback, score. No armor, part target, stagger threshold, resistance, persistent wound, interrupt, or status interaction exists in this firing path. | Weapon roles can only differ by damage, area, speed, radius and spread; current normal weapons mostly collapse into “small/large slow orb.” **Confirmed within reviewed path.** |
| Ammo / pickup | Weapon caches unlock/select the weapon; no player ammo counter is read or consumed in firing. | Pickup is a one-time access gate, not a continuing economy. No opportunity cost between firing and later levels. **Confirmed.** |
| Switching | Number key directly assigns weapon index when unlocked; no raise/lower sequence or switch cooldown. Existing attack timer appears global, so it persists through a switch. | Player may instant-switch while attack timer remains; behavior depends on the shared timer. The outgoing attack is not cancelled or queued. Must decide whether cadence state belongs to weapon, player, or action. **Confirmed code structure; UX needs test.** |
| Capacity / failure cases | `visual_projectiles` has 12 entries; launcher silently returns if full. Arc uses a single `projectile` object and can overwrite if a new fire event occurs after cooldown while the prior projectile remains in flight. | Projectile pool exhaustion lacks player-facing failure feedback. A 1.5s cadence and 20 units/s imply arc can travel 30 units in one cooldown, but longer paths or blocked/slow cases can overlap; then older arc shot may be replaced. **Confirmed structure / derived risk.** |
| Rejected sound test | A/B/C shotgun clips share the same extracted firearm region per take and loudness matching; B adds generic foley, C adds filtering/saturation. Review explicitly calls them unapproved. | No weapon mechanic or real weapon action is compared. The prior pack should not be used to claim a sound direction or target sound quality. **Confirmed from review.** |

### Timeline audit (current code)

| Event | Ember pistol | Rivet shotgun | Arc cannon |
|---|---:|---:|---:|
| Trigger accepted if cooldown permits | t=0 | t=0 | t=0 |
| Projectile/rays spawned / ammo consumed | t=0 / no ammo | t=0 / no ammo | t=0 / no ammo |
| Viewmodel launch overlay | .17 s | .22 s | .15 s |
| Weapon sound started | t=0 | t=0 | t=0 |
| First possible target contact | distance / 18 | distance / 14 | distance / 20 |
| Cooldown permits next shot | .50 s | 1.50 s | 1.50 s |
| Fire animation ends | .50 s | 1.20 s | 1.20 s |
| Recovery marker / reload / reset | none | none | none |

**Interpretation:** sounds are triggered at attack acceptance. There is no source-level event tying shot transient to muzzle frame or projectile launch; they all happen same update by current call order. Contact/hit sounds only occur after collision. For an actual authored viewmodel, separate **input accepted**, **mechanism begins**, **muzzle event**, **ammo/energy commit**, **projectile/ray creation**, **hit**, **mechanism return**, **ready**. They need not all coincide, but they must be explicit and reviewable.

## 2. Reference research: transferable mechanics, not replicas

### Doom (1993): state sequence plus different combat reach/commitment

The released id source makes attacks explicit state actions. Pistol: the action consumes a clip round and performs one bullet attack; `info.c` exposes wind-up/fire/recovery frames. Shotgun consumes one shell and runs seven independently scattered bullet shots. Chaingun consumes ammo per shot and repeats its firing states while held. Rocket consumes one missile and spawns a moving rocket; plasma consumes cells and creates moving plasma. BFG consumes 40 cells at firing, then launches its projectile; the source distinguishes upfront cost from later projectile impact. Exact code action functions are in [p_pspr.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_pspr.c), and state frame/tic sequences are in [info.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/info.c).

**Source-supported claim:** the attacks are differentiated by state/timing, ammo cost, spread or travel and firing pattern, and those events are explicit. The base clock is 35 tics/s. For example, the classic shotgun attack sequence in `info.c` has an initial 3-tic state, a 7-tic firing state with the attack action, then successive recovery states; summing the listed firing/recovery state tics gives roughly 1.26 seconds from attack-state entry to `A_ReFire` (44 tics ÷ 35). This is source timing, not a statement about how long every player feels recovery to be. Pistol listed sequence sums 19 tics (~.54 s) before `A_ReFire`; chaingun repeats shorter 4-tic firing states (~.114 s each). Animation action placement is more informative than the old games’ raw damage integers.

**Transfer:** each weapon earns its place by creating distinct range, timing or resource decisions; show a shot commitment and a recognizable recovery. **Do not transfer:** exact Doom arsenal, frame timings, damage, sound, sprite, pickup silhouettes, or enemy counter relationships. Doom’s simple nomenclature cannot by itself make Eyesore original.

### Wolfenstein 3D

The original [id Software source release](https://github.com/id-Software/wolf3d) shows a more constrained raycast shooter with pistol, machine gun and chaingun as a short family of conventional ranged tools. For this brief its useful contrast is that weapon distinction can be read through firing cadence and ammunition rather than fancy alt-fire. This is a **qualitative source observation**; I did not derive a comprehensive weapon balance table from its code. Transfer simple cue clarity and compact handling. Do not copy its three-gun progression or locked grid/line-of-sight constraints.

### DUSK

The developer describes DUSK as a fast, movement-led retro FPS with many weapons and distinct levels in [New Blood’s DUSK page](https://newblood.games/dusk); the detailed campaign/product description is also available from the [official Steam listing](https://store.steampowered.com/app/519860/DUSK/). DUSK’s specific arsenal spans conventional firearms and unusual tools, but the sources reviewed here do not provide frame-accurate firing/cadence values. **Qualitative transfer:** very different visual/fictional weapon forms can coexist when movement and hit readability stay immediate. Risk: the “rural cult” or surreal arsenal can become a surface-level skin over conventional slots if every tool resolves to hitscan damage.

### Prodeus

The [official store description](https://store.steampowered.com/app/964800/Prodeus/) calls out fast/frantic classic FPS play, over-the-top weapons, modern rendering and a level editor; it does not disclose weapon damage/timing tables. **Qualitative transfer:** weapon readability must survive high-speed movement, effects and user-made map variation. Don’t equate dismemberment count, visual particle density or an enormous catalog with good tactical differentiation.

### Boltgun

The [publisher’s official page](https://www.focus-entmt.com/en/games/warhammer-40000-boltgun) emphasizes heavy weapon firepower and fluid modern FPS play. Its [launch article](https://community.focus-entmt.com/focus-entertainment/boltgun/blogs/7-play-boltgun-now) confirms the game connects weapon use to aggressive melee/Chainsword combat. The official description does **not** establish exact weapon damage/cadence, so none is asserted. **Qualitative transfer:** visible mechanical mass plus a linked impact/reaction supports weapon weight; swift player control can coexist with a deliberately forceful attack. **Risk:** simply reproducing a heavy boltgun, chainsword, Space Marine scale or blood response is licensed-franchise imitation and insufficiently original.

### Dead Space

Creative director Bret Robbins describes dismemberment as a core combat mechanic that shaped creature behavior, weapon design and player ability in [Game Informer’s interview with the original/remake creative directors](https://gameinformer.com/interview/2023/02/22/dead-spaces-new-and-original-creative-directors-reflect-on-the-remake). That is direct developer testimony for a whole-loop linkage, not just guns with alternate fire. EA Motive’s weapon engineering discussion was reported in [GamingBolt’s developer interview](https://gamingbolt.com/dead-space-remake-developers-talk-about-changes-to-the-plasma-cutter-force-gun-and-pulse-rifle); the interview describes defining how the tools would move/behave as physical objects and needing to make alternate fire work against walls and ceilings. The source is secondary but quotes the developers; use it as a qualitative note only.

**Transfer:** decide what target state a weapon changes and what feedback proves that change; physical weapon operation should inform animation, not be ornamental. **Do not transfer:** strategic limb dismemberment as a mandatory layer (may conflict with fast kills), a shoulder-aimed third-person UI, or the Plasma Cutter’s iconic orientation mechanic.

## 3. Three distinct exotic weapon ecosystems to compare

These options are intentionally not “pistol, shotgun, arc gun” with new labels. All need to be evaluated with the same movement, encounter and sound slice. None commits the story or names. Proposed stats below are deliberately normalized, see §4.

### A — Red Mile: Evidence tools that change the firing lane

**World/story:** a landlocked freight city whose automated evacuation routed people into sealed districts; player is a former route courier carrying the switch ledger. Distinct from the coast/archive/body-horror proposals. Visual materials: enamel signs, painted steel, soot concrete, hard white daylight and safety markings; antagonists include human security and clearly signaled municipal machinery (story direction remains only a candidate).

| Tool identity (working names) | Input/event contract | Combat role / decision |
|---|---|---|
| **Index driver** | One fast, accurate, modest-impact dart; on precision hit leaves a brief route-index mark on enemy. A follow-up hit from a different angle gains a clear interrupt bonus only if enemy is winding up. | Reliable initiator and aim-skill tool. Do I spend time for a marked interrupt or keep moving? Mark is a tactical state, not a wallhack or permanent weak-point. |
| **Switch ram** | Heavy short fan of several low-travel bolts with low damage per bolt; full hit creates a brief stance break/knockback on light roles. | Close-range rescue against pressure. Need to enter danger range and commit to recovery; spreads are visibly deterministic and bounded. Not a regular high-damage shotgun replacement. |
| **Route puck** | A slow, lobbed puck sticks to a surface or heavy target and creates a short-lived, visible ricochet/deflection plane or line that changes incoming and outgoing projectile paths. Limited charges. | Geometry tool for lane reversal, exposes player to learning the resulting route; can help or harm. A special interaction, not free area damage. Requires advanced projectile/world support and may be too scope-heavy. |

**Why it is distinct:** evidence/route language controls lanes, target interruption and geometry; it is not an arsenal of louder conventional guns. It supports the map-conspiracy clue system in the story. **Main risks:** mechanics and art may overuse tiny route glyphs; marker/collision complexity; the puck can dominate encounters and burden levels with bespoke interaction. Do not select A unless a plain room can explain puck behavior without tutorial text.

### B — Civic Daylight: Resonance and rebound, an arena toolset

**World/story:** a public civic structure after an inexplicable failure in its directional acoustics and crowd guidance. No rail hub/false evacuation and no organic invader are required. The original story hook is being revised: public spaces are physically reconfiguring acoustic routes, so the player follows reflected sound and visible architecture to find who is controlling it. Visual direction fits but does not require the existing Civic Daylight art brief.

| Tool identity (working names) | Input/event contract | Combat role / decision |
|---|---|---|
| **Phase pin** | Single quick projectile ray that embeds in surfaces; second press discharges a narrow, visible pulse from the last embedded pin. Pin itself deals minimal damage. | Aim and location setup; asks player to pre-place a return route before a fight. It may be cumbersome without very clear reticle feedback. |
| **Return disc** | A disc bounces a bounded number of times from authored hard surfaces, then returns along a visibly previewed line. A hit on a surface is valuable only when player positions enemies on the return path. | Rewards route reading and mobility; low output if spammed without alignment. Clear path silhouette and predictable bounce are essential. |
| **Pressure bell** | Short-radius radial impulse, charged by close near-misses or enemy attacks (not by idle holding), knocks projectiles away and staggers light enemies, low lethal damage. | Defensive timing and space clearance. Creates a close-range skill choice without mapping directly onto melee weapon damage. May be accessibility/readability risk with many overlapping enemy shots. |

**Why it is distinct:** attacks operate through room acoustics/returns and threat management, not simple bullet damage. It takes from Doom’s clear lanes and Dead Space’s sound/space authorship without duplicating either arsenal. **Main risks:** heavily bespoke simulation, confusing “why did the shot bounce?” failures, and visual implementation beyond the current box/arena engine. Reduce the scope to one demonstrator before adopting.

### C — The Last Projection: Aim as exposure management

**World/story:** an indoor civic theatre/museum of mass persuasion where projections are being used to hide an evacuation of their own audience. No coast, lens archive, memory replay, rail yard or cult. Player is a stage-maintenance runner who has to expose physical contradictions between projected directions and actual door states. Environment/material palette: painted canvas, plaster, timber, blackened rigging, stark footlights; enemies are deliberately theatrical silhouettes, not demons/organic choir.

| Tool identity (working names) | Input/event contract | Combat role / decision |
|---|---|---|
| **Cue cutter** | Sustained thin line which cuts a narrow projection-mask seam while trigger held; energy builds heat until pause or release. Damage starts low and rises only while a readable seam stays on one target. | Tracking/commitment; can hit a blocker and reveal the real route behind it. Break line of sight to cool, so movement matters. Risk of generic beam gun. |
| **Flyweight** | Fires one physical weight that swings from an overhead anchor for a fixed short arc, damaging/staggering enemies it crosses. Player does not reel it in or swing from it. | Area denial and timing; turns ceiling/rigger geometry into a weapon. Needs roof/anchor support, limits use in open exterior spaces. |
| **Blackout charge** | Small thrown canister temporarily suppresses projection lights and UI-marked phantom enemy copies, while exposing actual threat silhouettes in backlight. It deals almost no direct damage. | Information-control resource; deploy before committing to the wrong image. Must never obscure real threat tells or accessibility colors. |

**Why it is distinct:** player chooses what to illuminate/erase from perception; each weapon has an embodied relationship to a lit stage and overhead rigging. **Main risks:** mechanic/fiction mismatch, screen distortion harming aim, spectacle overriding combat. High originality potential but requires a rigorous mock-up and could be an art-driven dead end.

### Comparative assessment (first-pass proposal, low confidence)

| Criterion | A — Red Mile | B — Civic acoustics | C — Last Projection |
|---|---|---|---|
| Core repeated decision | Mark, interrupt, redirect lanes | Place/rebound attacks, defend timing | Track an exposed seam; manage true/false visibility |
| Novelty vs repo so far | Medium-high; story draft exists, mechanics do not | High; not represented in current briefs | High, but high risk of an unplayable gimmick |
| Readability risk | Route marks might be too small | Reflection path ambiguity | Real/false silhouettes and blackout can confuse |
| Engine cost | Medium-high (surface/target marks, projectile plane) | High (bounce/reflection logic) | High (view-dependent effects, anchors, projection state) |
| Art/sound dependency | signage grammar, human voice / mechanism sound | impulse shape, room acoustic response | projection readability, theatrical material cues |
| Scale / easiest experiment | Low: test mark interrupt + existing simple fan | Medium: one fixed bounce on plain planes | High: projection/true-state test before combat |
| Similarity danger | Generic firearm/utility weapon set | “magic sound gun” with abstract sci-fi skin | Generic neon illusion shooter; avoid visual trope |
| Current status | Candidate, not approved | Candidate, not approved | Candidate, not approved |

I cannot recommend a production path until a short playable comparison verifies that the signature actually changes a decision. A no-combat silhouette render alone cannot answer that.

## 3A. Fourth candidate — conventional combat roles, original physical signature

The three candidates above all ask the player to configure or read the room before getting the main value from a shot. That shared bias is a serious risk: the game could become a set of geometry puzzles with guns attached. Add a deliberately orthodox control candidate whose first use is obvious and satisfying within one trigger pull, while its asset/sound identity comes from Eyesore’s own material behavior.

### D — Witness-mark arsenal (working handle only)

This candidate is story-agnostic. It can fit an emergency response team, an urban courier, or another grounded role without forcing any of those into canon. The player carries compact, function-built tools whose impact leaves a **brief, high-contrast physical witness** in the struck material: a chalk-white punch, a comb of ceramic scoring, or a branching pressure fracture. Those marks communicate where/how the shot landed and then decay; they are not weak-point symbols, damage stacks, hit-combo currency, or puzzle switches. Enemy reactions and sound change according to exposed material (shell, soft tissue, hard plate), not franchise-specific gore.

| Role | Immediate one-pull contract | Arena decision |
|---|---|---|
| **Punch driver** — precision | Immediate, tight hitscan/single trace; modest damage per hit, high repeatability; no charge or lock-on. A clean hit cuts one narrow witness notch and gives crisp target response. | Safely tag a distant wind-up, finish a light role, or keep moving. Aim correction and uninterrupted cadence are its value. |
| **Comb projector** — close spread | One fast burst of a fan of independently traced shards. Cone and per-shard damage are authored against target width and test distance, not inherited from Doom’s seven-shot formula. A tight cluster gives strong close stopping power; edges still punish crowds lightly. | Commit into close range to break a pressure role or finish multiple weak enemies. A miss costs a clear recovery interval. |
| **Breach capsule** — area / line pressure | One visible, self-propelled capsule; impact on wall or target immediately produces one bounded radial burst plus a short, fixed ground line of fragments. Direct hit is best, splash/line can clear a lane. No remote trigger, surface reflection, mark setup, charge, or alt-fire. | Spend scarce heavy charge on a clustered threat or hold it for a blocked route. Dodging/spacing still solves the threat if ammo is saved. |

**Eyesore-specific twist:** shot consequence is represented as a material “witness”—distinct mark shape, surface fracture and target response—not numbers or franchise gore. Weapon action sounds derive from three unrelated real mechanical gestures (punch, comb release, capsule strike) recorded/performed for this fiction. The hook is sensory and editorial; it does not add a new player-facing setup rule. Mechanical roles remain familiar, but their authored event, material reaction, silhouettes, handling, and language must be original. If the marks feel like decals or obscure aim, drop them and keep only their value as hit-feedback art.

**Self-critique:** D is less mechanically surprising than A–C and risks being described as “just three classic guns.” The witness marks could be mere decoration; the exact iconography may accidentally evoke Doom’s wall hits or Dead Space damage. An arena shooter also needs excellent cadence, hit feedback and enemy reactions for conventional roles to feel fresh; that quality cannot be supplied by nomenclature. D earns inclusion only if identical mechanics with original material/animation/sound still feel coherent and unmistakably Eyesore. A classic role set is a comparison baseline, not an accepted direction.

### Four-way comparison

| Criterion | A — Red Mile routes | B — Civic acoustics | C — Last Projection | D — Witness-mark baseline |
|---|---|---|---|---|
| **First-shot readability** | Medium: mark and interrupt timing need a quick teach; puck changes path. | Low-medium: return path and reflected impulse must be previewed. | Low-medium: projected and real target states may be confused. | High: aim, fire, hit or miss are familiar; witness mark confirms contact. |
| **Feel / weight** | Medium-high potential if mark interrupt is tied to a distinct physical hit, but setup can delay payoff. | High expressive potential; lowest confidence because return/bell effects may feel magical. | High theatrical potential; risk that screen tricks obscure impact. | High, testable at low scope: individual mechanism action, mechanical recovery and different material impact responses; avoid making every attack louder/heavier. |
| **Implementation scope** | Medium-high: target tags, alternate-angle check, movable/deflection plane. | High: bounce path, impulse interactions, room geometry support. | High: projection/true-state visibility and overhead anchor rules. | Low-medium: shared authoritative hitscan, bounded pellet fan, projectile plus simple radial/line collision. Current code already contains ray, projectile, hit feedback and world collision primitives, but they are split across modes and need unification; area damage and asset feedback still need implementation. |
| **Distinct art/audio burden** | High: route-index state, persistent mark UX, readable alternate angle/puck path, separate target state and associated mechanism/confirm cues. | Very high: authored bounce indicators, reflection surfaces, pressure ring, directional/return sound cues and room-specific surface behavior. | Very high: true/false projection layers, safe blackout contrast, anchor silhouettes, sound cues that distinguish actual threats from images. | Medium after mechanics: three original viewmodels, distinct material-specific hit traces/reactions and performed mechanisms/impacts. **These are bespoke art/audio costs, but none is needed for the first neutral control test.** |
| **Pickup decision** | Pick up if player wants setup and planned lane control; puck charges may be too conditional. | Pick up if player wants geometry reading and defensive timing; likely highest explanation burden. | Pick up if player likes perception control; unclear whether it competes with straightforward combat. | Pick up because role is immediately legible; tactical choice is range/commitment/ammo. Easy to compare against another tool. |
| **Fast arena fit** | Medium: mark interruption supports motion; puck can interrupt flow if setup required. | Medium-low: room surfaces matter more than target movement; risk of stopping to aim bounces. | Medium-low: highly authored space and stable view required; blackout may slow or confuse a fight. | High: clear instant shot, close pressure, or area response; no weapon requires a prior setup. |
| **Originality risk** | Low as a route fiction, medium as “status-mark firearm + gadget.” | High overlap with generic energy/ricochet powers. | High overlap with illusion/neon powers. | High if only reskinned pistol/shotgun/rocket; reduced only through original weapon construction, physical action language, enemy material response, and art/sound values. |
| **Best role in comparison** | One novelty challenger. | High-risk novelty challenger. | High-risk visual/narrative challenger. | Control condition and probable first playable prototype. |

### What should be prototyped first

**GO: first neutral mechanics test loadout = D’s three orthodox roles, stripped of its proposed identity layer.**

- One immediate, accurate, repeatable precision trace with modest damage.
- One bounded close-range fan with independently traced pellets and one clear recovery interval.
- One visible, slow area projectile with a simple direct-hit and bounded splash result.
- One shared test enemy set, consistent world scale/movement, fixed test distance, no weapon-specific armor, no setup state, no ammo scarcity in the very first pass. Then run a second pass with a small heavy-ammo budget to test pickup decisions.
- Neutral gray weapons/enemies and simple color-coded debug impact markers. No witness marks, bespoke viewmodels, authored weapon recordings, music, story pickups, or lore. If sound is enabled, use the same low-key placeholder class across all three so it cannot determine the result. This first pass is a mechanics comparison, not an art/audio approval.

This is a **go for a neutral prototype only**, not a go for D as the final weapon identity. D has the least bespoke mechanics because it uses familiar hit trace, fan and projectile patterns; radial splash is a small new collision rule and standard/calibration paths still need one common authority. D nevertheless retains medium custom visual/audio production burden if the “witness” response is kept. Defer that material identity until the mechanics survive review; it can be removed entirely if it adds clutter rather than recognition.

**No-go for A, B or C as the first playable loadout.** A adds target marks, alternate-angle checks and deflection-path interaction; B adds rebound/impulse geometry; C adds rendered state substitution plus ceiling-anchor behavior. In addition to code, each requires dedicated state/tutorial/art/audio to teach intent, the active effect, failure, and hit. Those costs contaminate a first mechanics baseline and each has less certain fast-combat readability. A alone can return later as a *single challenger*—mark and interrupt only, no route puck—once D has supplied a fair timing/hit counterfactual.

After D’s neutral test, and only if the roles prove legible, add the original material/animation/audio layer in a separate matched pass. Keep run speed, enemy HP, target distance, firing cadence and mix output controlled. Ask whether material responses and weapon actions improve recognition and weight without masking enemy tells or delaying time-to-hit. The current split fire paths must be unified conceptually before implementing the test; calibration must not remain a higher-damage alternate mode.

Only after D produces a reliable 30-second loop should a single exotic alternative be mocked up against it. Start with A’s **mark-and-interrupt only**, with the route puck disabled, as the cheapest novelty challenger; it tests whether a new target-state decision improves play without making every attack a geometry puzzle. Test B and C in paper/visual prototypes first; full engine support is not justified yet. If none of the exotic differences is noticed or preferred without explanation, keep their fiction research separate and refine D’s combat identity. If the control feels flat even with clear timing and meaningful counters, reject D rather than adding fancier effects to hide it.

**First prototype pass/fail observations:** after 90 seconds, blind players can identify which tool is reliable at range, which is worth spending recovery to use close, and which clears a threatened space; weapon choice is visible in recordings; misses and impacts are distinguishable; no weapon hides enemy wind-up; player never reports having to stop and solve the room before a basic fight. This is qualitative screening, not a statistical claim.

## 4. Normalized mechanics bands (experiment matrix only)

Unitless normalization prevents false precision from Doom world units, prototype units, or undocumented commercial tuning. Let **T** be the time from input accepted to visible hit feedback at a chosen reference target; **P** is player movement distance during T at chosen run speed. These values are proposals for tuning, not targets copied from any reference.

| Measure | Initial experimental band | Why it is a useful controlled variable |
|---|---:|---|
| Instant/direct hit confirmation | 0–0.08 s | Establishes the immediate-aim baseline. |
| Ordinary projectile at 8m reference | T = 0.10–0.35 s | Enough flight for dodge/read without long empty travel. Record actual speed once world units and map scale are signed off. |
| Slow/utility projectile | T = 0.35–0.70 s | Only if visible path, larger effect or route setup makes it predictable. |
| Light enemy kill budget | 1–3 accurate primary hits or 1 committed close attack | Compare per-weapon roles; not a mandate for health inflation. |
| Standard threat budget | 3–6 primary hits, or one successful setup plus 1–3 follow-ups | Allows weak-spot/interrupt mechanic test without making target spongey. |
| Heavy threat budget | 6–10 hits or deliberate multi-tool sequence | Only for a distinct behavior/tell and resource decision; don't create a bigger same-role HP sponge. |
| Quick repeat gap | 0.12–0.25 s | Test controlled bursts and sound/event overlap. Higher cyclic rate requires reduced per-hit effect or scarce ammo. |
| Commitment/recovery gap | 0.45–0.90 s | Enough to make launch/timing legible while movement/dodge remains available. Evaluate ready-state and weapon switch. |
| Switching | 0.15–0.35 s for ready-to-fire, test immediate versus interruptible | Prevents free instantaneous role-juggling while preserving responsiveness. Test with attack release and held fire. |
| Hit-stagger window | 0.08–0.22 s for light role; zero for some heavy roles | Distinguish shot flinch from action interrupt. Must never erase a threat tell silently. |
| Shared ammo economy | Each heavy tool capacity 2–6 meaningful uses before likely refill; test reserve 2×–4× capacity | Forces selective use without leading to empty-hand deadlock. This is a test range only. |
| Spread / precision | At standard distance, plot hit probability against target width; test tight, medium, broad cones | Better than copying Doom’s seven pellets or assigning arbitrary radians before scale/target dimensions exist. |
| Feedback latency | shot onset at event; target feedback by collision; no sound/hit preceding actual effect | Coupled to audio/animation. Measure input-to-contact on screen capture with frame/event marker. |

**Normalization protocol:** lock run speed, player collision, enemy width, target distance and camera FOV before comparing weapons. Record target width in reticle angular degrees or as fraction of view height. Report T plus player path length P; do not compare raw projectile speed across unlike unit systems. In proposals, describe DPS only as a derived ceiling, then also report accuracy, travel time, cooldown, miss cost and enemy response.

## 5. Counterplay and example encounter utility

### Test encounter (shared across ecosystems)

One rectangular room with two side loops and a visible exit; one medium-range “caller” that telegraphs a straight, dodgeable shot; one close, low-profile flanker entering through a visible side door; one stationary/anchored heavy target that periodically exposes a frontal weak state; a single waist-height cover block and a clear back wall. No repeated spawns. The room supports both strafe routes and a safe initial firing lane. All three weapon options are tested on the exact same composition and run speed.

| Threat | Enemy counterplay required | A — Red Mile utility | B — Civic acoustic utility | C — Last Projection utility |
|---|---|---|---|---|
| Caller | Winding attack is visible and audible; strafe or break line before release. Player may interrupt only before the tell completes. | Index driver can stagger during visible windup; otherwise side-loop to break line. | Place pin/return disc to cross caller lane; bell can reflect one shot when correctly timed. | Cutter breaks projected targeting seam; blackout reveals real firing posture, but player still dodges release. |
| Flanker | Visible movement entry and distinct close lunge; no spawn behind player. | Ram is strong up close but its recovery means route puck setup may be safer. | Bell pushes a lunge off route, but using it charges a small resource; disc can hit on return if timed. | Flyweight can cross the entry path; cutter tracks but risks being pinned; blackout shows actual body, not decoy. |
| Anchored heavy | Clear open/exposed pose changes its damage susceptibility; resists flinch during closed/armored pose. | Mark then follow-up from offset lane. Two-angle requirement encourages movement. | Pin and return path through the exposed state; reflection can include cover but cannot hit unseen through solid geometry. | Cut the exposed projection seam to suppress armor state; position under rig anchor for flyweight choice. |

**Counterplay fairness requirements:** enemy telegraphs must remain visible while player's attack is active; on-hit feedback must not suppress or replace a warning. A weapon cannot require exact enemy-specific bespoke logic across the whole roster. Heavy target state must be understandable from animation/material first; HUD should not be the only clue. Every weapon choice needs a fallback use when its special interaction is unavailable.

### Sample use / ammunition questions

- If the caller is already winding up, does player keep the reliable attack or spend a scarce mark/interrupt to prevent the shot?
- Does the player hold a heavy hit for the anchored enemy's exposed cycle or use it now to clear the flanker?
- Can one weapon answer at close and distant range, but with clearly different risk/effectiveness, rather than making other slots dead?
- Are ammo pickup positions visible before the fight or placed after it? Players must have the information needed to decide whether a commitment is worth it.
- Do a missed shot, blocked shot, late projectile or wrong target state give distinct, immediate evidence? Silence and absent feedback are ambiguous.

## 6. Staged test and review plan (no tests run in this research task)

1. **Contract mock-up:** one event timeline diagram for each of three ecosystems; no art detail. Mark accepted input, windup, effect frame, ammo commit, target contact, feedback, recovery, cancel and switch windows.
2. **Neutral mechanics prototype:** use debug-color shapes only, with same enemy geometry and run speed. Implement the minimum engine primitives needed for each candidate, all under flags. Log fire timestamps, projectile path, collisions, ammo, target HP/state and switch.
3. **Blind-rule player session:** 5–8 players from the team/volunteers; no one reads the names/mechanics first. Give identical 90-second encounter loops. Counterbalance order. Record misses, hits, damage taken, weapon switch, time in target range, chosen route, interrupts, ammo remaining, and player-described shot purpose. Do not overinterpret this small sample statistically; use it to expose confusion.
4. **Audio review only after mechanics gate:** fire one event on each weapon at the same comfortable monitoring position. Do not loudness-match by normalizing source RMS; instead match *perceived attack level* across the scene with a human. First test dry sound with no music, then full encounter with warnings. Include calibrated source, timing marker, playback capture and simple waveform envelope for investigation.
5. **Repeated-use review:** 30 identical attacks in 60 seconds, then a mixed combat scene at low comfortable volume. Ask whether shots remain distinguishable and whether high priority threat cues survive. Mark previous A/B/C shotgun audition rejected and keep it out of this comparison.
6. **Decision review:** choose the ecosystem with the clearest distinctive player decision, readable miss/hit feedback and lowest bespoke scope for its identity; retain a second option only if it tests a genuinely different experience. Revisit after movement/enemy/encounter reports, before production audio/art.

**Originality check:** test with temporarily generic shapes/sounds. If the option only feels distinctive after adding a franchise-like name, sprite or sound, reject it. Also ask independent reviewers to identify which decision they made differently than a standard aim-and-fire weapon. If they answer “none,” the mechanics have not earned the new identity.

## 7. Cross-role contracts and blocking decisions

| Role | Required coordination |
|---|---|
| Engine / simulation | Standard and calibration modes need identical authoritative weapon rules. Decide fixed/variable simulation, projectile sweep/substeps, pools and max active projectiles; no silent dropped shot. Define world scale and trace geometry. |
| Movement / aiming | Set movement speed, aim mode, vertical aim, target dimensions and reference distance before spread/flight-time tuning. Preserve aiming through weapon recovery; test strafing and switching during sprint. |
| Enemy behavior | Agree what constitutes hit reaction vs attack interrupt; which roles resist stagger; weak/exposed state animation and guaranteed tell duration. Avoid weapon-only states that every enemy requires. |
| Encounters / resources | Place ammo with sightline, route and planned threat sequence; decide kill requirement vs optional threats; measure resource sufficiency across both perfect and miss-heavy runs. Stable archetype HP; vary role/composition, not unexplained same-role HP. |
| Level design / interactions | A weapon that manipulates bounce surfaces, route pucks or anchor points adds geometry authoring requirements. Use the first slice to show that affordance before it becomes required. Decide object persistence and reset. |
| Weapon art / animation | All fire and reload/switch event markers are authored in simulation ticks. Show windup, projectile departure, device return and usable pose; silhouettes and active muzzle must not block threats. Don't align sounds to arbitrary animation frame counts. |
| Combat feedback / sprite art | Define hit normals, material response, interrupt and exposed-state signal together. At far test distance show the distinction at actual renderer pixel size. Visual flash cannot hide the enemy attack tell. |
| Weapon/world audio | Stable event IDs with attack, mechanism, failure/miss, impact surface and recovery separate. Fire transient triggers at shot event; hit confirmation at collision; use one authored impact family per target material. Sound does not serve as the only proof of hit. |
| Story / art direction | Verify tools arise from player role/world function, while combat usefulness is still clear without lore. Do not lock mechanics to Red Mile, Civic Daylight, or theatre story until user review. |
| Quality / accessibility | Remap fire/switch; ensure hold/press control option; reduced flash; avoid color-only weak-state signal; test audio-subtitles/captions for priority effects if audio cues are required. |

### Assumptions challenged / unresolved

- The last story draft gives Red Mile a slight lean; this report does not assume that choice. Weapon premise could expose weaknesses in all three candidate stories.
- Prior leads leaned into an observatory, industrial pressure, Glass Choir and a coast setting. None is imported here as canon. Civic acoustics/theatre may still be perceived as effects-heavy atmosphere rather than a compelling shooter.
- There is a strong temptation to call any exotic projectile mechanic original. The actual bar is that players can describe the decision and enemy counterplay after play, not merely the VFX.
- Doom/Boltgun are used for role readability and event synchrony, not ammunition tables or weapon silhouette. Wolfenstein/DUSK/Prodeus/Dead Space are not reliable sources for numeric values without explicit source material.
- **Doom commercial source license caveat:** source availability is not a game-asset license. Read the DOOM source license for code permissions and do not lift executable code, art, sounds or data into Eyesore. This report’s timing arithmetic describes the released source behavior only.

## Sources

- id Software, *DOOM* source [`p_pspr.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_pspr.c) and [`info.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/info.c): weapon action functions, ammo commit and state timing.
- id Software, [*Wolfenstein 3D* source release](https://github.com/id-Software/wolf3d): qualitative weapon/system context.
- New Blood, [*DUSK*](https://newblood.games/dusk), and [official Steam page](https://store.steampowered.com/app/519860/DUSK/): product/developer description; not frame-accurate mechanics data.
- Bounding Box/official listing, [*Prodeus* on Steam](https://store.steampowered.com/app/964800/Prodeus/): qualitative design/product claims only.
- Focus Entertainment, [*Boltgun* official page](https://www.focus-entmt.com/en/games/warhammer-40000-boltgun) and [launch article](https://community.focus-entmt.com/focus-entertainment/boltgun/blogs/7-play-boltgun-now): qualitative gameplay/arsenal description only.
- Game Informer, [interview with Dead Space creative directors](https://gameinformer.com/interview/2023/02/22/dead-spaces-new-and-original-creative-directors-reflect-on-the-remake): developer-attributed design pillars.
- GamingBolt, [Dead Space remake weapons interview](https://gamingbolt.com/dead-space-remake-developers-talk-about-changes-to-the-plasma-cutter-force-gun-and-pulse-rifle): secondary report quoting Motive developers; used qualitatively.

**Lead critique requested:** Does A's index mark feel like an evidence-themed hitscan gun with a renamed debuff? Is B still just a magic ricochet/force gun? Is C too dependent on special projection geometry? Which can produce a distinct 30-second combat loop with the fewest bespoke engine features? Please challenge before adding production material.
