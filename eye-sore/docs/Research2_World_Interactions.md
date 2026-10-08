# Eyesore interaction systems: second research pass

**Role:** 07 — World interactions  
**Status:** research and design alternatives only. This report does not approve canon, author a level, or change code.  
**Model:** GPT-6 Luna / high, as requested for this research round.  
**Inspected:** native prototype, prior briefs, Doom and Wolfenstein source, developer/publisher material for the named references, 3 October 2026.

## Decision summary

Eyesore currently has no general “world interaction” system. It has a proximity check for two weapon caches in the native prototype, one proximity-triggered pickup in calibration mode, a kill-count phase gate for the default arena, and a tiny 2D prototype with a proximity key and coordinate-based win condition. There is no player use/interact input, map-authored door, key requirement, switch, mover, secret, exit transition, or saved progression. Those features appear in briefs, not the canonical runtime. [Observed native code: `engine3d.cpp`](../linux-game/src/engine3d.cpp), [`main.c`](../linux-game/src/main.c); proposed key/door/secret chain: [`LEVEL1_DESIGN_BRIEF.md`](LEVEL1_DESIGN_BRIEF.md).

The useful Doom lesson is not “add colored keys.” It is that a player can act on map boundaries in several consistent ways—cross, use, shoot—or enter a sector, and those events operate typed world actions. A door, lift, floor, light, teleport, secret, and exit are map-authored effects with different repeat and reset rules. Wolfenstein 3D adds a very legible grid-door/key/pushwall grammar. Dead Space demonstrates a different scale: physical service interactions and story clues can make a space feel authored, while its own developers describe the danger of packing too many terror peaks together. Those are reference observations, not reasons to add a generic simulation framework.

**Proposal:** develop two interaction grammars, and keep them independent of story and art direction:

1. **Route logic:** the classic grammar of approach, cross/use/shoot, key/state check, gate/mover response, short feedback. It supports fast maze navigation and optional loops.
2. **Infrastructure causality:** the same simple action verbs act on visible machines, signals, barriers and authored evidence; a world change has a visible, spatially legible result. It supports environmental narrative without requiring text, dialogue or a specific setting.

The recommendation is a small shared interaction contract containing `trigger`, `condition`, `effect`, `feedback`, and `persistence_scope`. Each map entity references stable IDs; a single authoritative state controls its rendered pose, actor collision, weapon/AI traces, navigation, audio occlusion, HUD hints, and restart/save behavior. Do not begin with a node-graph scripting product, inventory/crafting, physics grab system, universal “use” prompt on every prop, or Dead Space-like intensity director. Validate the contract on one simple door, one optional loop, and one world-change mechanism after engine/level decisions.

### Small first-slice core vs optional extensions

**Core for the first reviewed FPS slice:**

1. **Ordinary doors:** one familiar use action, one clear door frame/handle, a brief accepted/blocked response, and reliable open/closed collision. A prompt is optional; teach the input once in a safe spot and let the physical door communicate the rest. Keep an already-open route traversable without repeated input.
2. **Pickups:** weapons, ammo/health and credential items collected by touch when appropriate. Feedback identifies the result; state and resource inventory update once. No dialog box or interaction prompt for ordinary pickups.
3. **Use target:** one explicit input for switches/locked doors that cannot reasonably be touch-activated. Context prompts may be enabled by the interface/accessibility owner, but are not a dependency of the interaction system or map readability.
4. **Keys/credentials:** one or a few named requirement IDs, persistent for the level by default, with redundant shape/icon/text cues. A wrong credential fails clearly and never consumes the key. Avoid committing to classic red/blue/yellow colors or expanding into a key taxonomy before a level proves it needs one.
5. **Switches:** a single one-shot switch that changes one visible, useful route state. It has a direct cause/result, does not ask for timing or combination input, and can be reactivated if the target was blocked before commitment.
6. **Secrets:** optional discovery through a consistent physical clue and simple use/shoot/cross action; reveals an optional route or reward and never gates completion. No pixel hunting as the required language.
7. **Exit:** a visible exit boundary or target with one consistent rule (cross or use), readable ready/dormant feedback, and a recoverable transition. Do not require total enemy kills unless an authored set piece explicitly says so.

**Keep as optional extensions until a map demands them:** linked banks of doors/lifts/lights; multi-target world-state changes; multiple route-order puzzles; elevators, bridges and floor movers beyond one narrow test; destructible/rotatable/pushable architecture; remote shooting chains; teleports; moving-object physics; inventory capacity/key consumption puzzles; contextual prompt systems; dialogue terminals; broad Dead Space-like tool verbs (Kinesis/Stasis); and dynamic event/intensity directors. These multiply art, navigation, sound, lighting, HUD, save and test dependencies. They are not part of the minimum classic FPS vocabulary.

**Do not turn interaction into a minigame by default.** Use one action, one requirement check and one world response. Timing, multi-step sequencing, hold-to-charge, repeated button presses, aimed microscopic targets and explicit prompt UI need a demonstrated gameplay reason and a skip/accessibility plan. Story can come from where the switch is, what it changes and the traces around it, not an obligatory text-reading stop.

**Multi-effect fail-safe:** before consuming a key or accepting a one-shot switch, preflight every required target ID, condition, mover endpoint and route safety constraint. If any mandatory target is invalid or cannot begin, leave all targets and inventory unchanged and emit one clear fault response. Once accepted, mark one transaction ID and apply its logical state changes deterministically together; animations/audio may complete over time. If an actor obstructs a mover after commitment, pause the affected motion in a safe, non-crushing state and resume when clear; do not roll back a committed one-way route or restore consumed items because someone crossed the doorway. Roll back only a pre-commit transaction. If a later failure cannot safely resolve, the action must remain retryable from a stable state and level validation should report the faulty setup. This avoids partial “lights changed, door stayed locked” outcomes without making post-commit physical animation brittle.

## Evidence boundaries and current project state

### Confirmed project behavior (read from source; not a new runtime test)

| Evidence | What source currently does | What it does not establish |
|---|---|---|
| Native FPS setup/reset | `setup_first_level()` instantiates first three enemies and sets `level_wave=0`; `reset_combat()` reinitializes player, weapon/projectile state, enemies, caches and mixer. | No map state is serialized or restored by ID. |
| Default mode gate | Waves advance when every indexed enemy in the current group is dead. The shotgun/arc caches become available at wave transitions; proximity to hard-coded positions consumes a cache, unlocks and equips a weapon, then spawns the next enemy group. (`engine3d.cpp`, ~431–438, 502–504) | No door collider/render state, route graph, generic trigger, or way to open a route without clearing a wave. |
| Calibration mode | One ranged target is placed at a fixed coordinate; getting it to die sets `calibration_complete`. The shotgun cache is collected by distance from a fixed pickup position (`engine3d.cpp`, ~433, 500, 506–507). | The separate box scene and light rectangles are not an authored level/interactions format. |
| Combat world | `combat_world::World` is one interior room plus solid AABBs. Actor blocking and segment traces query those boxes; a dynamic gate does not exist in this structure (`combat_world.h/.cpp`). | No boundary portals, linked-area graph, door/mover state, or interaction trace channel. |
| Earlier 2D toy | `main.c` uses a 16×9 character grid. Medkit/ammo/key pickups are distance checks; the exit is a player coordinate check requiring key + all four enemies dead. Enter resets only after win/death. | It is not evidence for the intended native FPS grammar, nor a tested route design. |
| Proposed content | The older `LEVEL1_DESIGN_BRIEF.md` describes keys, doors, a secret switch, exit lift, encounter clear gates, and a route. The world design draft proposes keys, switches, movers, drains, secrets, return routes, etc. | These are proposal text only; do not describe them as existing behavior or canon. |

**Observed problem:** pickup logic is embedded in per-frame branches with fixed coordinates and local booleans. Gate unlock, activation, one-shot consumption, persistence and feedback are inconsistent by construction. A future map with two key doors or a switch that affects both lights and a lift would require more coupled branches. This is an implementation observation and an engineering inference—not evidence that any one interaction design is already selected.

### Earlier proposal collisions and novelty risk

- `LEVEL1_DESIGN_BRIEF.md` already contains a conventional blue-key/door-like chain, kill gate, shotgun cache, optional secret and exit lift. Repeating this as a more detailed map would not be a new result.
- `World_Design_Redesign_Research.md` proposes the coast observatory, waterworks, a drain route, pump controls, lens bridge, persistent loops, named districts, three secrets, keys and doors. The story draft also has two options, including an inland rail hub, but its sample beats again rely on keys, a weapon in a booth, a switch/barrier, a tower exit and a false route sign. Interaction work should serve either world and should not quietly ratify either one.
- The engine architecture report calls for typed events, a single shared dynamic boundary/mover state and level validation. This report operationalizes the interaction data contract and failure cases; it does not choose engine, serialization format, editor, sound design, colors, story, exact key count, or map topology.
- Rejected calibration/audition artifacts are not interaction UX references. “It compiled” is not proof the pickup or phase gate communicates well.

## Reference study: what the source actually says

### Doom (released Linux Doom 1.10 source)

`P_spec.c` describes events as operations triggered by **using, crossing, shooting special lines, or timed thinkers**. `P_CrossSpecialLine` is called when an object origin is about to cross a nonzero-special line; `P_UseSpecialLine` controls front-side line use, with exceptions and restrictions for non-player actors. Cross-line cases include door/floor/platform actions, teleport, and level exits; special sector handling separately covers effects such as damaging/slippery/environment sectors. This is a compact trigger vocabulary, not a universal point-and-click object system. [Doom `p_spec.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_spec.c), [Doom `p_spec.h`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_spec.h).

The door source confirms motion is a stateful thinker: direction, speed, target height, wait, countdown, and type. A manual raise door can reverse/reopen if used while closing; a one-time open door clears its line special; an occupied sector can already have a mover and the use behavior is handled explicitly. Key checks accept either a matching card or skull. Locked attempts communicate through a player message and a feedback sound, not a silent dead input. These are useful state/failure properties to analyze; Eyesore does not need Doom's door types or color key taxonomy. [Doom `p_doors.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_doors.c).

`p_switch.c` associates switch types with world actions. A switch texture changes only when an action actually starts successfully; a one-use switch changes its face, while a button can return after a timer. Thus a visual “on” state is tied to accepted effect, rather than blindly toggled on every input. Doom also treats secret exits as a distinct route outcome. [Doom `p_switch.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_switch.c), [Doom `g_game.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/g_game.c).

Teleporters are more than position assignment: the player crossing direction matters, missiles are excluded, destination actor collision is checked, momentum/angle can be transformed, and visual/sound fog feedback appears. This is a useful warning: any nonlocal transition must define valid destination, actor eligibility, facing, momentum, obstruction, and feedback together. [Doom `p_telept.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_telept.c).

**Transfer:** retain typed activation modes, reusable stateful movers, feedback on rejected actions, and clear retry/reversal rules. **Do not transfer:** 100+ magic integer line-special IDs, one global lock-color scheme, hidden special semantics that depend on editor conventions, or unexamined quirks of a 1990s engine. The Linux Doom 1.10 source is a study, not the exact original DOS binary.

### Wolfenstein 3D

The source uses a tile map plus a separate bounded door-object list. Door entries record tile position, orientation, lock class and state (`closed/opening/open/closing`). The operation checks keys before changing direction. A moving push wall checks its state, direction, map occupancy and destination before it starts; it temporarily owns a world tile and advances in discrete steps. This makes a secret reveal a change in route topology, not merely an “interact” prompt. [Wolfenstein `WL_DEF.H`](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_DEF.H), [door/pushwall implementation `WL_ACT1.C`](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_ACT1.C).

**Transfer:** clear door state and affordance, bounded mover behavior, physical route revelation, and a key attempt that either acts or gives feedback. **Counterpoint:** tile-granularity, four near-identical key slots, treasure scoring and wall-hunt secrets are not automatically suitable for a 3D boomer shooter with vertical routes and a user asking for rich worlds.

### DUSK, Prodeus, Boltgun, and Dead Space

Evidence strength differs. For DUSK and Prodeus, publicly accessible developer/publisher material is stronger on level-making than it is on a complete interaction API. The DUSK developer has described studying wall/floor/UV behavior and level design as a deliberate source of identity; Prodeus’s official material emphasizes classic-FPS map making/community maps and modern rendering around a constrained retro look. Use those as evidence for *authored legibility and map workflow*, not for undocumented runtime semantics. [DUSK developer interview](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games), [Prodeus official site](https://www.prodeusgame.com/website/index.php).

Auroch describes Boltgun’s level content as hand-made levels with changing environments and enemy combinations; its official update notes record practical navigation-guide work and bugs where a player could get stuck, a lift could be fallen through, or an enemy could become unreachable. That is unusually concrete evidence for QA: every gate, lift, secret and moving obstacle needs explicit clearance, actor reachability, and route completion checks. [Auroch Boltgun DLC/level update](https://aurochdigital.com/blog/2024/6/5/boltgun-dlc-launches-steam-xbox-playstation), [Auroch Boltgun patch notes](https://www.aurochdigital.com/warhammer-40000-boltgun-forges-of-corruption-patch-notes).

Dead Space’s remake developers explain that an otherwise empty first room was reworked to teach opening doors while making the area feel like a customs checkpoint, and that physical setting, signs and lived-in props carry world meaning. The updated zero-G movement also created new traversable areas and alternate routes, so its authored interaction changes the space, not just a HUD objective. Official control/gameplay settings list Kinesis, Stasis and a “Show World Input Prompts” option for doors, openable containers, and zero-G landing. For Eyesore, borrow the deliberate teaching and the player's choice to show prompts; do not assume the game needs Kinesis/Stasis or a puzzle-tool layer—the extra verbs add animation, collision, HUD, audio, tutorial and QA scope and could slow a boomer shooter. Dead Space developers also describe an authored intensity system coordinating encounters, light and sound while intentionally leaving peaks and valleys. Transfer the authored cause/effect and breathing room, not a campaign-wide dynamic scare generator. [EA Motive, “Aboard the Ishimura”](https://www.ea.com/ea-originals/news/inside-dead-space-3-aboard-the-ishimura), [EA PC gameplay settings](https://www.ea.com/able/resources/dead-space/dead-space/pc/gameplay), [EA Intensity Director](https://www.ea.com/playtesting/news/inside-dead-space-4-the-intensity-director).

## Two interaction grammars

These are alternatives for review, not locked product choices. Both must sit on shared world data and support original story identities.

| Grammar | Player-facing rule | Strength | Main risk | Story fit |
|---|---|---|---|---|
| **A. Route logic** | Doors, keyed thresholds, switches, movers, cross-lines, secrets and exits. Use / cross / shoot are explicit activation classes. A required action has one obvious landmark and an understandable condition. | Rapid movement, classic map loops, backtracking and clear combat routes. Easy to draw, read and validate as a progression graph. | Can become generic colored-key maze; overuse creates stopping and kill-locks. Secrets can turn into wall pixel-hunting. | Works in either the observatory or rail-city options; labels, lock forms and mover semantics remain art/story-agnostic. |
| **B. Infrastructure causality** | A physical control changes a visible connected system: route barrier, lift, lighting circuit, alarm, bridge, machinery, signage or signal. The player learns a small action on a meaningful object, then notices a resulting world state. | World feels coherent; enables environmental storytelling and Dead Space-like “this place was used” detail without mandatory dialogue. Lets one action alter sightline/audio/navigation at once. | Realistic prop detail becomes visual noise; asking for multiple hidden sub-steps can slow the shooter. A story clue may masquerade as a gameplay switch. | Supports both options: lens/water machinery or rail signaling/dispatch infrastructure, without baking their lore into engine code. |

### Suggested shared interaction contract

One map-authored interaction record should express **what can activate, under which condition, which state transition occurs, how it responds, and what happens on restart**. Exact syntax belongs to engine/content-pipeline roles.

```text
id: gate.service_east
kind: door | lift | barrier | switch | pickup | secret | exit | world_state
activation: use | cross_front | shoot | touch | auto_pickup | timed
condition: all | any | none              # stable requirement IDs / world flags
effects: [target_id -> requested_state]   # one atomic transaction or explicit sequence
feedback: [visual_event, sound_event, ui_event, optional_message]
failure_feedback: missing_requirement | blocked | invalid_target | already_done
repeat: one_shot | toggle | hold | retrigger | repeat_after_reset
persistence: frame | encounter | level | checkpoint | campaign
on_reset: initial_state | checkpoint_state | saved_state
```

Minimum design rules:

1. **Behavior is not a texture name.** `kind`, activation and state live in authored data; the visible design communicates them but does not define logic by pixel color or filename.
2. **One authority per target state.** Render pose, collision, use trace, weapon/projectile trace, enemy navigation, sound obstruction and HUD feedback read the same door/mover/world-state value. A sound/animation may lag visually but cannot lie about passability.
3. **Conditions resolve before effects.** An action is accepted only if requirements are met and all mandatory targets can transition safely. For a multieffect switch, specify if effects are atomic or sequenced; default to fail closed without consuming a one-shot switch if a required effect cannot start.
4. **Feedback says what happened.** Accepted input receives immediate local response; motion completion receives a separate event. Rejected input gives an actionable reason without long UI dwell. If the player lacks a credential, name/signal the needed item/system, not a generic buzzer alone.
5. **Use more than color.** Lock class can pair shape/icon/text, material boundary, placement, mechanism silhouette, sound motif, accessibility text/contrast options. Optional colored channel is redundant. A key's door face and inventory affordance share a pattern, not a hue alone.
6. **Separate critical path from reward.** A required node has a dependable clue and cannot be made permanently unreachable by optional state changes. Secret discovery is explicitly optional, separately recorded, and never required for the normal exit.
7. **Interaction and combat coexist safely.** Define whether enemies can activate it, whether player fire can activate it, if attacks can pass through it, how actors block it, whether a door reverses on obstruction, and where the player stands while using. Do not silently ignore use because a projectile or enemy owns the target.

## State diagrams and transition contracts

State graphs below are recommendations, not a commitment to implementation details. “Blocked” is a transition result / feedback event, not a permanent door state unless the level author explicitly marks it sealed.

### Door / keyed boundary

```text
LOCKED --valid credential + use--> OPENING --clear travel--> OPEN
  |                                 |                         |
  +--invalid credential--> LOCKED   +--obstruction--> OPENING | optional timed close
                                                              v
SEALED (no player action)       OPEN <--use/reopen-- CLOSING --clear travel--> CLOSED
                                  ^                       |                     |
                                  +------obstruction-------+                     +--use valid--> OPENING
```

- Model `sealed` separately from `locked`: sealed cannot be solved with a key; locked has a known requirement.
- Valid key may consume, remain as a persistent credential, or unlock permanently; per-map record says which. Do not infer that all keys are consumed.
- A door on the critical route must have a reachable credential path or a reachable alternate opening. An actor wedged in its volume cannot crush/block the only route indefinitely. Choose and test a rule: pause/reopen, safely push/relocate actors, or never close on actors. Avoid opaque damage.
- For movement sound/trace occlusion, use actual aperture progress; specify the threshold at which an actor can fit. Projectiles/hitscan have their own explicitly authored partial-aperture policy.

### Switch / control / multi-target world change

```text
READY --input + requirements met + effects admissible--> ACTIVATING --> COMPLETE
  |                                                       |                  |
  +--requirements fail--> READY + failure cue             +--target fails--> READY
  +--effects unsafe/target absent--> READY + fault cue                       |
                                                                            +--if retriggerable--> READY / ACTIVATING
```

- A switch's accepted state changes only after the effect has begun/committed according to its record. Doom's button texture changes upon successful effect initiation; this avoids “looks on, did nothing.”
- Multi-target changes such as a lift and paired doors need authored ordering and interruption policy. Prefer one map transaction on the next simulation tick: validate all target IDs/states, mark event accepted, then apply deterministically. If staged motion is part of the design, the switch is `ACTIVATING` until its completion event.
- A damaging hazard is not the default failure cue. Use clear mechanical feedback and a safe retry unless the player could anticipate and dodge the consequence.

### Pickup / key / one-time clue

```text
AVAILABLE --touch/use + inventory capacity/condition ok--> ACQUIRED --> HIDDEN or spent
    |                                                                      |
    +--inventory full / invalid target--> AVAILABLE + local explanation    +--reset policy restores if specified
```

- For ammo/health, cap overflow policy must be deliberate: leave partial pickup in world, consume and grant the amount possible, or state that it is a non-resource key item. Avoid wasting the object silently.
- Do not give a weapon at full ammo in a way that causes no visible inventory change; distinct first unlock and repeat ammo supplies can share art only if the cue text/feedback names the result.
- Persist unique keys/records separately from ephemeral pickups. When recording nonverbal clue discovery, do not interrupt motion by forcing text unless deliberately authored.

### Exit / level transition

```text
DORMANT --required objective state(s) complete--> READY
  |                                                    |
  +--premature use/touch--> DORMANT + useful cue       +--enter/use--> TRANSITION
                                                        |
                                                        +--load success--> NEXT_LEVEL
                                                        +--load failure--> READY + recoverable error
```

- Define if the player needs to stand within a marked exit, press use, or cross the threshold. Must be consistent across maps.
- Transition can be explicit and short; never require invisible precise coordinate overlap. Before transition, commit checkpoint stats/items according to campaign rules. A failed map load must not destroy the current state.

### Secret / optional route

```text
UNDISCOVERED --hinted use/shoot/cross rule satisfied--> REVEALED --> ENTERED --> REWARDED
      |                                                                                 |
      +--ordinary passage elsewhere--> remains hidden                                     +--no critical path dependency
```

- `revealed`, `entered`, and `rewarded` are distinct analytics/gameplay states. If a wall moves away, returning to its old position must not retrigger or block the player.
- The clue grammar needs at least two independent signals for an intended secret (e.g. a repeated construction seam plus a nearby in-world trace) and should not depend on color alone. Hidden pixel shooting can be a rare exception, never a map's main secret language.

## State ownership, restart and persistence

Do not make a persistent campaign database before the save/checkpoint role decides the campaign loop. Specify scope per entity now so reset semantics are deterministic:

| Scope | Examples | Death/restart behavior |
|---|---|---|
| `frame` | momentary input, use trace result, actor overlap | discarded immediately |
| `encounter` | temporary arena barrier, spawn sequence, temporary lift | returns to encounter-entry snapshot unless checkpoint says otherwise |
| `level` | one-way door latch, discovered secret, level key, opened shortcut | reset on entering a fresh level; preserved only if checkpoint/save requires |
| `checkpoint` | saved route branch, persistent key, cleared encounter | restore exact saved state, including door and world-change targets |
| `campaign` | only explicit campaign flag or permanent unlock | owned by session/release role; do not overload map flags |

Every actor, mover, switch, resource and world-state target has a stable ID, declared initial value and reset owner. Inputs are idempotent where reasonable: double-use during a door transition cannot spawn a duplicate mover, add two credentials, or consume multiple pickups. Event dispatch is deterministic by simulation tick and author order or stable-ID ordering; avoid race-dependent outcomes when several actors overlap a trigger.

**Failure/restart contract:** on restart, clear in-flight movers/events, restore the right snapshot, recompute derived geometry/audio/navigation/UI state from stable state, move the player to a valid spawn, restore required inventory/weapon state, and avoid stale one-shot flags. A map validator should reject any state with no possible completion or no reset path if a one-way event is required.

## Route, access-order and affordance language

### Required and optional access graph

Represent the map as areas `V`, traversable boundaries `E`, and interaction requirements `R`. A required path from spawn to exit must be satisfiable; required keys or world flags have a witness route from spawn without using the target gate they unlock. For alternative wings, either each branch contains equivalent mandatory capability/reward or the level author explicitly models asymmetric budgets and validates both orders. Do not use a global “kill all” flag as a proxy for door state.

The validator should calculate at least:

- Initial reachable area set with all initial states.
- Reachable pickup/credential set for each required locked boundary.
- Exit reachability after required conditions, and exit unreachability when it is intentionally dormant.
- Reachability under every mutually exclusive branch/route order, not one assumed order.
- Optional nodes never required by exit dependencies, and no optional action can remove the only critical route.
- Door passability and actor radius/height at every stable and intermediate mover state; no intended landing/drop ends in a sealed/unreachable cell.
- Use traces and interaction volumes fit their physical mounting and do not activate the wrong control across a thin wall or in combat through an unintended gate.

### Affordance with and without color

Each interactable should be classified as one of:

1. **Traverse now:** visible opening, doorway, stair, dropped bridge, open lift. The physical silhouette communicates passability.
2. **Use now:** hand-height control/handle, repeated panel shape, reliable interaction range, contextual prompt only when close and aim-valid (if chosen by interface lead).
3. **Conditional:** visibly distinct receiver/lock plus a plainly named requirement (shape/icon/text; color is secondary). Communicate locked vs sealed vs temporarily busy distinctly.
4. **Shootable:** robust target silhouette/animation and visible shot reaction. Never mark required progress only with a small point hidden in combat clutter.
5. **Crossing trigger:** conspicuous threshold or floor/wall marker aligns with route; one-time threshold cannot accidentally fire from the back side unless declared bidirectional.
6. **Secret clue:** subtle but repeated construction irregularity, contextual evidence, and consistent response to a known action. Optional clues can be subtle; required paths cannot.

Input mapping is open with movement/accessibility roles. A strict classic grammar can auto-open a normal door on use and auto-pickup items on touch, limiting explicit button burden. Infrastructure interactions can use a single context-use action. Do not require both high-precision looking and a pixel-sized hitbox. Interaction range, aim cone, occlusion rule, input buffering, prompt hide/show delay and controller mapping need one shared interface specification.

## Actor blocking, combat and error cases

Interactions need rules per object; these are not safe to assume at art time:

- **Doorway occupied by player/ally/enemy:** mover pauses or safely reverses; it cannot crush a critical-route actor without a clear authored lethal hazard. Collision opening, visible gap, audio path and enemy path update from the same progress/state.
- **Enemy in a locked door:** decide if enemies can pass/use it, and if attacks pass. Default safe design: enemies may not activate key requirements or close a unique escape route. If an enemy can open it, the action is declared in the archetype/interaction data and telegraphed. Otherwise NPC attacks cannot imply it is traversable.
- **Projectile/weapon activation:** use a separate activation channel (`shoot`) and collision layer. A bullet hitting a physical locked door gives authored material impact/denial feedback; it should not silently act as use. If shootable switch, feedback should be immediate and the effect state is committed only if conditions succeed.
- **Multiple activators:** deterministic target claim; one state transition only. Nearby use priority should be nearest valid actor-facing candidate with a tie-break. Simultaneous player/AI touch of a one-time pickup has one atomic winner and no duplicate grant.
- **Paused / dead / transitioning:** input cannot start world events, audio events, or pickup commits while paused/dead/loading unless specifically authored; on unpause, held button must not inadvertently fire/activate.
- **Use while aiming through bars/glass:** trace through only surfaces whose interaction mask permits it; matching render/collision/interaction opacity. If control is intended to be reachable across a grate, show the mechanism and document the exception.
- **Input while mover busy:** feedback distinguishes “in motion” from locked; then ignore, queue once, or reverse. Repeated held input cannot jitter/restart the mover or bury sound in repeated spam.
- **Missing/unloaded target ID, bad key ID, full inventory, blocked mover endpoint, invalid transition target:** level validation reports the source entity/location and fails the level authoring build, not the player session.
- **Reacquiring after death/checkpoint:** no key is visually missing while world flags say it exists; no door looks open while collision is closed. UI/object world state derive from same serialized value.

## Story-independent example configurations

Examples intentionally keep semantic IDs generic; they demonstrate interchangeability, not canon.

| Interaction behavior | Possible in coast / archive / rail / entirely new world |
|---|---|
| Two route branches satisfy two separate interlocks; either order powers a third return route | Pump valves; archive stack lifts; signal relays; greenhouse air curtains |
| A one-time route opens onto already safe floor at another height; it never seals behind player | Dry spillway hatch; freight ramp; book-delivery lift; quarry conveyor |
| An optional wall/panel moves and exposes a useful resource + one clue | Weather station panel; archive false wall; rail maintenance locker; chapel plinth |
| A `READY` exit has a world-facing visible cue; it does not require total kill count | Ferry/airlock lights green; tower signal succeeds; map marker flips; gate releases |

None require an organism, flooded coast, false evacuation, magic red/blue keys, central machine intelligence, civilians, or voiced protagonist. The interaction system must remain mechanically meaningful if all story text is removed.

## Map/runtime data contract and authoring checks

Engine architecture report proposes a `Boundary`, `Mover`, `Event`, collision channels and validation. Interaction owns semantics while engine owns geometry/event guarantees; content pipeline owns schema/editor and validators; level design owns route and activation choice; HUD owns prompts/locked messages; audio and effects own assets/timing; art owns visual affordance. Use stable IDs and explicitly connect ownership.

**Map-file acceptance criteria (before any production map):**

1. Schema rejects duplicate IDs, unknown condition/effect targets, invalid enum values, missing initial/reset state, bad resource quantity, missing feedback event, invalid activation target geometry and undeclared persistence scope.
2. Required route/credential/exit graph passes reachability for every authored branch order and declared difficulty setup; secret graph is separate.
3. One shared runtime state drives render/collision/movement/projectile/sight/sound/navigation/UI queries; toggling one test door visibly and physically agrees at closed, moving, open, blocked and invalid-use states.
4. Mover endpoints are traversable/resolvable: actor widths/heights and margin checked; if blocked, explicit pause/reverse behavior; no map leaves actor between closed collision slabs.
5. Unlock condition failure has immediate actionable feedback; failed attempt does not consume item or change target; accepted action and completion have distinguishable cues; all cues have a non-color visual signifier and captions/accessibility names where appropriate.
6. Restart, death, fresh level, checkpoint restore and fresh campaign each reproduce the specified interaction state exactly; reset clears pending events and motion safely.
7. Door/use/secret interactions are testable through a declarative test harness: submit action at expected position/state, assert target state, derived passability, effect events, and inventory; invalid actions assert no side effects.
8. A human route review can identify which doors are locked/sealed/open, main vs optional path, and the reason for a required lock without reading dev docs or memorizing color coding.
9. The implementation has authored scale limits: max simultaneous movers/triggers, max event chain length, cycle validation, and defined handling for cascades; no unbounded recursive event graph.
10. Save data migration has explicit behavior if entity IDs change. Until campaign saves exist, stable IDs and a migration note suffice; do not invent an unsupported save system to meet this item.

**Runtime interaction playtest acceptance criteria:**

- A first-time player learns normal-door interaction, a key/state-gated door, a switch-result change, an optional secret clue, and the exit rule through play without repeatedly guessing inputs.
- Players can maneuver and fight continuously through the essential path; interaction moments have safe position, sightline and retreat route except where a combat interaction is explicitly authored.
- No required event depends on hearing a cue or seeing one hue; sound, geometry, text/icon reinforce each other.
- There are zero softlocks from missed, misordered, blocked, repeated or retriggered interactions across a complete run and fresh restart.
- Player can explain at least one world change through what they observed (e.g. they caused route X to open), not only that “the button worked.”

## Novelty guard and counterargument

**Counterargument:** designing a generic interaction schema before the route and chosen engine are approved risks building abstractions for invented needs. Doom maps often get their clarity from compact conventions, and an authored `use` prompt or event graph can be slower than a visible open door. A small game may need only 5 interaction types. Therefore treat this report as a contract checklist and candidate grammar, not a class hierarchy or an implementation mandate. The first slice should test only the interaction types the chosen map truly uses.

To prevent repeated outcomes, require every next interaction pitch to state:

- Which previous proposal it differs from (e.g. no simple colored-key chain, no kill-everyone exit gate, no coast-specific drain).
- What player decision changes because of it.
- What visible/physical state changes, and which systems share that state.
- What happens on failure, obstruction, death, restart, optional order and bypass.
- Which part comes from source facts, which is inference, and which is new proposal.
- What playtest would make the team remove it.

Do not call counts (`20 switches`, `8 doors`, `3 key colors`) novelty. Novelty comes from the consequences of a legible, purposeful action and a distinct world that uses it.

## References

### Primary / developer sources

- id Software, Doom source, [special lines and sector effects](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_spec.c), [door thinkers and locks](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_doors.c), [switches/buttons](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_switch.c), [teleports](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_telept.c), [level-state/exit handling](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/g_game.c). Source studied is Linux Doom 1.10, not the original DOS executable.
- id Software, Wolfenstein 3D, [world/door structures](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_DEF.H), [door and pushwall behavior](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_ACT1.C).
- DUSK creator interview on intentionally authored FPS space/material language: [Game Developer](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games).
- Prodeus official product/editor information: [Prodeus](https://www.prodeusgame.com/website/index.php).
- Auroch Digital, Boltgun content/navigation updates and defects: [Forges of Corruption and navigation guide](https://aurochdigital.com/blog/2024/6/5/boltgun-dlc-launches-steam-xbox-playstation), [official patch notes](https://www.aurochdigital.com/warhammer-40000-boltgun-forges-of-corruption-patch-notes).
- EA Motive, Dead Space remake setting/interactions: [Aboard the Ishimura](https://www.ea.com/ea-originals/news/inside-dead-space-3-aboard-the-ishimura); authored tension event/quiet interval discussion: [Intensity Director](https://www.ea.com/playtesting/news/inside-dead-space-4-the-intensity-director).

### Local project sources

- [`linux-game/src/engine3d.cpp`](../linux-game/src/engine3d.cpp)
- [`linux-game/src/main.c`](../linux-game/src/main.c)
- [`linux-game/src/combat_world.h`](../linux-game/src/combat_world.h), [`combat_world.cpp`](../linux-game/src/combat_world.cpp)
- [`linux-game/src/calibration_scene.cpp`](../linux-game/src/calibration_scene.cpp)
- [`docs/Research2_Engine_Architecture.md`](Research2_Engine_Architecture.md)
- [`docs/LEVEL1_DESIGN_BRIEF.md`](LEVEL1_DESIGN_BRIEF.md)
- [`docs/World_Design_Redesign_Research.md`](World_Design_Redesign_Research.md)
- [`docs/Story_Integration_Research.md`](Story_Integration_Research.md)
