# Eyesore engine architecture: second research pass

**Status:** research and recommendation for review; no engine or game direction is approved by this document. **Scope:** role 01, engine architecture and simulation. Source repository and briefs inspected 3 October 2026. No code was changed, built, or tested during this pass.

## Decision summary

The conversation history establishes the current creative target as a native first-person boomer shooter: the user asked to preserve Doom's original FPS layout, playtest the game as the assistant team builds it, and then repeatedly directed deep work on FPS levels, weapons, enemies, audio, sprites, lighting, story and retro-shooter references. **Treat native FPS as the working product direction.** The repository's README still calls Eyesore a browser-based isometric neon arena shooter, and `components/arena.tsx` implements that earlier prototype; those are stale project records that must be reconciled during an approved implementation pass, not equal evidence that the user remains undecided. A final project checkpoint can identify whether to archive or replace the browser slice.

If native FPS is confirmed, **do not keep extending the present room-and-box world model into a game engine, and do not adopt GZDoom as the game runtime by default.** First write a narrow playable-slice requirements contract, then compare a small custom sector/portal layer against a Godot 4.6.x 3D prototype. Godot 4.6.3 is the current stable release found in official releases and is MIT-licensed. It offers editor, rendering, collision, import, audio, and packaging foundations; its scene/physics model does not directly provide Doom-style sector geometry, so Eyesore would still need a purpose-built room/portal representation and retro renderer/material conventions. [Official Godot release list](https://github.com/godotengine/godot/releases), [Godot license](https://godotengine.org/license/).

GZDoom is technically the quickest way to explore sector maps, doors, dynamic geometry, scripting and Doom-family editing tools. The official releases show GZDoom g4.14.2 as current; the repository identifies its source as GPL-3.0 and as a Doom-family source port. That brings a real distribution/source-compliance decision and inherits an opinionated game/runtime/content model. A permissive license is not a proxy for engineering quality, nor does GPL make commercial distribution impossible, but this license and base-game separation need an explicit legal/product decision before selection. [GZDoom release list](https://github.com/ZDoom/gzdoom/releases), [GZDoom repository/license](https://github.com/ZDoom/gzdoom).

**Recommendation:** use a vertical slice to decide between a custom C++ sector/portal runtime and Godot 3D. Keep the slice representation engine-neutral. Evaluate GZDoom as a technical/reference path only if the game is intended to be a Doom-engine mod or the team accepts its runtime/license terms. Do not copy Doom source just because it is inspectable: the id repository carries Doom-specific licensing notices and the project’s identity is original.

## What Doom actually provides—and what is useful to borrow

The released `linuxdoom-1.10` source is a concrete architecture study, not a ready-made requirements list. Its world is authored as vertices, linedefs, sidedefs, sectors, subsectors and BSP nodes. A sector owns a floor and ceiling height, flat names, light level, special and tag; sidedefs carry upper/middle/lower texture choices and offsets. BSP subsectors refer to sector and line segments. This makes adjacency, openings, texture alignment, lighting and moving-sector behavior central shared data rather than unrelated hard-coded boxes. [Doom `r_defs.h`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_defs.h).

For collision and movement, a two-sided line creates an opening from neighboring sector floors/ceilings. Actors can cross only when the shared opening accommodates their floor height, step constraints and body height; floor/ceiling clipping and lines also define projectile/trace traversal. `P_TryMove` checks the candidate move against map lines/actors and updates the actor’s sector membership; wall sliding tries a clipped move, then a secondary axis/stairstep. `P_LineAttack` traverses line geometry and height-aware targets. [Doom `p_map.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_map.c).

The simulation uses a fixed 35-tic-per-second game clock, distinct from drawing. `P_Ticker` runs player thinkers, the thinker list, special-sector updates and respawn logic once per game tic; paused simulation returns early. Door/floor movers are thinkers with explicit states, speed, destination, waits, and blocking behavior. This is a useful lesson in deterministic authored events and bounded updates, not a command to inherit 35 Hz or Doom's exact timing. Eyesore can use a fixed 60 Hz or another measured simulation rate and interpolate rendering. [Doom `doomdef.h`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/doomdef.h), [Doom `p_tick.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_tick.c), [Doom `p_doors.c`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_doors.c).

Doom is a 2.5D world: the floor and ceiling are horizontal per sector, with vertical height changes and connected openings, but it does not provide arbitrary stacked room-over-room 3D in the original map model. BSP is principally a spatial partition/visibility ordering structure for this 2.5D scene. The reusable design ideas are shared map topology, sector heights, portals/openings, height-aware traversal, simple predictable movers, a map compiler/editor workflow and fixed-step thinker updates. Eyesore need not reproduce vanilla visplanes, fixed-point arithmetic, renderer limits, WAD lumps, quirks, 35 Hz, or binary-compatible behavior. Those are implementation-specific costs unless the game deliberately chooses Doom-format mod compatibility.

Borrow the model of **areas and boundaries**, not necessarily the exact file format. A boundary/portal can describe: neighboring area IDs, visual surfaces on each side, lower/upper/middle material assignments, floor and ceiling differences, door/mover association, collision passability, hitscan/projectile visibility, enemy navigation cost, and sound transmission. An area can describe its floor/ceiling surface and height, palette/material set, baseline light/acoustic values, tags and persistent state. This is sufficient to support the first two proposed level alternatives while retaining room for authored special geometry. If production mapping later needs sloped floors or multiple stacked spaces, extend deliberately after a demonstrated level requires them.

## Eyesore audit: current architecture and responsibilities

### Product and content mismatch

`README.md` calls the project an original browser-based isometric neon arena shooter; `components/arena.tsx` implements a tile grid, 2D raycaster and chasing enemies. `linux-game/src/engine3d.cpp` instead builds a native 3D FPS with mouse look, sprites, projectiles and fixed function OpenGL 2.1. The native executable is thus a prototype branch of the experience, not simply a renderer replacement for the browser game. This needs resolving before future platform, control, content, save, or release decisions.

### Current native prototype

Observed directly in `engine3d.cpp`, `combat_world.*`, Makefile and related briefs:

- `engine3d.cpp` owns SDL setup, OpenGL drawing, input, almost all simulation, enemy AI, damage, projectiles, audio dispatch, pickups, stage unlocks and reset in one large translation unit. Its main loop clamps variable `dt` at .05 seconds and updates/render in the same loop, rather than consuming fixed simulation ticks. A slow frame therefore drops simulated wall-clock time, and simulation behaviour can vary with frame delivery.
- Main world geometry is one `World` room AABB plus vector of solid AABBs. `descent_world()` hard-codes 8 pillars and 12 wall boxes; draw functions separately recreate room/wall/block geometry. Renderer and collision already have duplicated geometric descriptions. Calibration translates another list of solid boxes into the same collision form. Neither form defines multiple floor heights, a connected sector graph, surfaces/material IDs per boundary, actual door state, or portals.
- Player collision samples independent X and Z moves and checks room containment/box overlap. It is not an actor sweep against a connected map; step/ground/support/floor query/ceiling fit are absent. AI, clear-shot checks, visual room layout and collision each have geometry-dependent logic. A new level feature would need agreement across all these call sites.
- Enemy and projectile ownership is partly fixed capacity (`Enemy enemies[ENEMY_COUNT]`, 16 hostile projectiles, 12 visual projectiles) with `ENEMY_COUNT=14`, while a separate special arc projectile is singleton. Level positions/health/types are arrays and wave progression is hard-coded around cache proximity and group indexes. Renderer visibility does not govern enemy updates today, but no path graph/navigation or room activation exists.
- `calibration_mode` introduces an alternate rendering/simulation path and special HUD behavior. The working tree also contains recently rejected calibration scene/HUD/audio prototype changes and audition WAVs. Their compilation does not establish accepted architecture or content. Treat them as a separate experiment; do not let their headers/API become the architecture contract.
- `README.md`/React prototype and native build both need to be identified as production vs reference. The existing source-control status at inspection included many uncommitted prototype and research artifacts. Before future implementation, checkpoint accepted sources separately and identify rejected files; this report does not edit or remove any.

### High-risk mismatches with the specialist requirements

The existing role roster and recent world, story, creature, audio and reference briefs imply the same core needs:

1. **Level design:** connected route graph, explicit areas, multiple elevation strata, sightline windows, loops/secrets, surfaces on floor/wall/ceiling, keys/switches/exits, and one water/drain or mechanical world transformation. Layout must be inspectable and adjustable without rewriting renderer code.
2. **Interactions/story:** persistent world states and triggered audio/lighting/navigation cues need a causal event bus. Story alternatives should be representable without locking the runtime to the coast/observatory draft.
3. **Lighting/materials:** authored area baselines plus local accents, material identity per surface, sky and outdoor views, moving-light and visual feedback with readable combat. Current fixed-function light is positioned before camera rotation and therefore view-relative; enemies render with lighting disabled. This does not meet the material/actor co-lighting requirement.
4. **Creatures/combat:** body floor/support and target height must match movement, traces and damage; animation events trigger sound/effects/attack on shared timestamps. A discrete state/event model is needed; current AI update is an in-line if/else loop and attack frame event is hard-coded.
5. **Audio/music:** event has source location, area, priority, occlusion/door transmission, category/gain, variation and source identity; music and SFX controls remain separate. Dead Space is a reference only for authored pacing/intensity orchestration if the story/encounter lead demonstrates it serves Eyesore; it does not justify procedural attack spam, randomized narrative attacks, or a game-wide intensity subsystem now.
6. **Content/pipeline/release:** asset manifests, provenance, level import/validation, surface naming, encounter lists, build data, configuration and reliable restart/transition. Bulk art/audio production is premature until data ownership and source directories are clear.

The engine agent should define seams and requirements—not make narrative canon, prescribe enemy names, decide audio aesthetics, or pre-author a level. Story, level, combat, art, audio, UI, and quality leads own their design content and feed technical constraints into the contract.

## Capability matrix

| Capability | Current native FPS prototype | Specialist/level requirement | Critical gap |
|---|---|---|---|
| Level/world representation | One room box plus independent solid boxes; arrays in C++ | Reusable areas, adjacency, floor/ceiling heights, distinct face materials, triggers and authored entity records | No canonical level data or authoring workflow |
| Elevation | 3D coordinates for actors/projectiles; world floor essentially y=0 | Walkable steps/stairs/lifts and low/high floor regions; no compulsory jump | No ground/support query, step-up/down, slope, falling/landing contract |
| Openings and doors | Physical wall gaps are baked into boxes | Actual dynamic doors/latches with collision, render, trace, navigation, audio and persistence in sync | No boundary/portal or dynamic blocking interface |
| Rendering | Immediate-mode OpenGL 2.1 fixed function; box room; three large textures; billboard actors | Environment/material classes, coherent dynamic/area light, sky, sprite/light integration, depth/surface impact feedback | Renderer duplicates hand-authored world geometry; lighting currently not world-authored |
| Collision/traces | AABB/swept sphere utilities in `combat_world.cpp`; player move separately sampled per axis | Actor movement and weapon/AI traces through openings with correct height, doors, actors and surfaces | Collision, visibility and render have different world definitions |
| AI/navigation | Seek player/nearest attacker; clear line check against present room geometry; roam by turning from boxes | Enemy roles use cover/ledges/retreat paths, no stuck pathing, authored ambush/state; simulation independent of camera | No graph/path or area connectivity; box-only avoidance |
| Simulation | variable dt, capped .05; events/AI all in monolithic frame loop | stable combat timing, pause/reset, shared animation/weapon/AI event semantics | no fixed-step or explicit world/entity scheduler |
| Interaction/state | proximity pickups, wave gates and calibration flags | tagged switches, key requirements, door/lift state, secret discovery, world changes, save/reset | state is local boolean and positional logic; no validated progression graph |
| Sound/world link | listener orientation and audio mixer exist; most effects dispatched from code branches | event origin/area, propagation through boundaries, ambient zones, cue priorities and door occlusion | no acoustic areas/portals; content/event logic tightly coupled |
| Content authoring | hard-coded C++ arrays, BMP/WAV path conventions and scripts | designer-readable maps, manifests, validators, previews and error reports | any layout tweak needs code/rebuild; no reliable ID validation |
| Performance/content scale | small fixed enemy/projectile counts and one room | at least the first 5–8 min map, secrets, district changes, persistent actors and reasonable view range | capacities and activation strategy not based on content profile |
| Platform | SDL2/Linux/OpenGL executable; parallel Next.js browser app | chosen target, input/UI/accessibility and repeatable package | target platform and authoritative build are undecided |

## What the modern reference games do—and what can be verified

These games are useful quality targets, but their internal engines are proprietary. Their public developer material supports product/design observations, not claims that they use a particular renderer, data model, pathfinding system, or audio middleware. Do not choose Eyesore's architecture by guessing at their implementation.

| Reference | Public evidence from creator/publisher | Architecture implication for Eyesore | Do not infer |
|---|---|---|---|
| DUSK | Creator David Szymanski says he studied old games' walls, floors and texture mapping/UV behavior to develop purposeful identity; a separate developer interview says level design was central to what defined the retro FPS category for him. [Game Developer interview](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games), [developer interview](https://steamcommunity.com/app/519860/discussions/0/1644295067084039768/) | Need editable geometry/material scale and repeated in-game room review: world identity is authored through spaces and surfaces, not by swapping an overall color grade. Include texture orientation/scale and landmark shots in authoring feedback. | DUSK is not open source; public comments do not specify the exact engine architecture or justify copying DUSK's world themes. |
| Prodeus | Its official description explicitly presents a classic-FPS foundation reimagined with modern rendering while keeping older-hardware aesthetic limits; official marketing emphasizes editor/community maps and dynamic music. [Official Prodeus site](https://www.prodeusgame.com/website/index.php), [publisher product page](https://store.steampowered.com/app/964800/Prodeus/) | Supports separating aesthetic limits from renderer capability: low-resolution/pixelated presentation can coexist with modern lighting/effects if authored as controlled options. If Eyesore wants user-authored maps later, level data and validation should be designed to grow—but the current slice does not need a public editor. | No source evidence here for its renderer code, scene format, lighting implementation, or proof that dynamic music needs an engine-wide intensity director in Eyesore. |
| Warhammer 40,000: Boltgun | Auroch/Focus describe the game around sprites, pixels, blood, fast action and 90s-shooter styling; Auroch's public material emphasizes its Warhammer IP expertise. [Steam product page](https://store.steampowered.com/app/2005010/Warhammer_40000_Boltgun/), [Auroch studio page](https://aurochdigital.com/about) | Plan a renderer/content path that can combine 2D actors and effects with 3D spaces and preserve strong target silhouettes; source art/state events should support gore feedback and weapon impact families without baking every effect into one image. | Marketing does not establish that all geometry is 2D/3D, nor reveal its tools, runtime, material system, or exact gore implementation. |
| Dead Space | EA describes its Intensity Director as coordinating ambient audio, enemies and environmental changes to sustain authored tension. [EA technical overview](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director) | Represent authored story/encounter state changes and audio/light events cleanly; keep event systems deterministic and inspectable. Consider a reusable intensity director only after level/story/audio leads specify a repeated need and show a concrete beat graph. | Dead Space's horror orchestration should not be imported into a movement-first shooter as a generic always-on spawner or unsupervised sound randomizer. |

The practical takeaway is an **authoring and review capability**, not a copied engine: each candidate must make it quick to revise a connected playable space, inspect camera views and material scale, and synchronize changes across visibility, collision, attack events, lights, and sound. The user should decide artistic direction by playing the same authored slice across engine candidates, rather than by reading claims about an engine's feature list.

## Architecture paths considered

### A. Continue current engine as-is

**Cost now:** low. **Cost by first real level:** very high and compounding. Every feature grows another array or duplicated collision/render check. A vertically varied 14-space map would make the renderer's AABB room assumptions, ground collision, traces, AI checks, audio location and transforms disagree. Further work might still prove weapon feel, but do not mistake this for a scalable base.

**Use only for:** short isolated movement/weapon feel captures, then retire or freeze. Do not use it for the level-design agent's authoritative map.

### B. Refactor into a custom C++ sector/portal runtime on SDL/OpenGL

**Fit:** highest control over classic FPS movement, low-level sprite/sector lighting, file formats and fixed-step simulation; can preserve C++ and SDL2. A polygonal area graph plus boundary portals is a manageable first world model and directly addresses the reviewed level concept. Author levels in an external editor or a simple text schema with a generated debug overlay.

**Cost/risk:** team must build and own the editor/importer, render surfaces/UVs, geometry collision, height movement, nav, UI, resource loading, packaging, audio acoustics, save/reset and cross-platform handling. This could become engine work rather than game work. The current OpenGL immediate-mode approach is not a suitable long-term material/light renderer. Portals and height transitions are nontrivial; “rooms” alone cannot silently stand in for valid polygon intersections.

**Use only if:** Godot prototype fails a clear retro-rendering or deterministic sector workflow criterion, or implementation skills/support make custom runtime demonstrably cheaper. Reuse current code selectively behind replacement contracts (input/audio helpers or math may be candidates); do not preserve an unsuitable renderer just because it already exists.

### C. Godot 4.6.3 stable, custom 2.5D/sector level representation

**Fit:** official current stable found is 4.6.3; engine is MIT; editor, scene/material tools, import, audio buses, input, collision, UI, signals/resources, export tooling and platform support reduce general engine work. Godot can render textured sector meshes and actors while a custom map resource/importer owns area adjacency and door state. One can use Godot's physics for actor movement or custom collision queries, but must not have two competing truths for floor/portal geometry. [Godot releases](https://github.com/godotengine/godot/releases), [official license](https://godotengine.org/license/).

**Cost/risk:** need learn/use GDScript or C#, adapt C++ work rather than mechanically port it, define a custom map import and debug visualization, and make deliberate renderer decisions. Default 3D lighting/materials can look generic, physically realistic, or too smooth without authored controls; pixelated sprites/materials need controlled texture filtering and palette/light response. Physics bodies do not by themselves supply Doom sector connectivity, Doom-like wall clipping, deterministic custom AI, sound propagation or exact hitscan semantics. Migration abandons current native code except useful design/math/assets and a few source utilities.

**Use if:** initial Godot vertical slice gets a 5-minute connected level with height, portal doors, sprite-based actor visibility, original art/material/light hooks, responsive combat, audio zones, and rapid room iteration to quality at lower total effort than custom route. “The editor is nice” alone is not evidence.

### D. Build on GZDoom

**Fit:** map/editor ecosystem, sectors and linedef specials, moving floors/ceilings/doors, scripts, compatibility with classic Doom WAD content workflows, mature FPS handling. Current official release list shows g4.14.2 (3 May release date as represented at research time); source repository calls it an OpenGL/Vulkan Doom-family source port. This is valuable as a study and an option when mod-like content is the product. [GZDoom releases](https://github.com/ZDoom/gzdoom/releases), [official repository](https://github.com/ZDoom/gzdoom).

**Cost/risk:** it is not a neutral library or an MIT/Apache-style drop-in. GPL-3.0 governs GZDoom source; distribution architecture, modifications, bundled sources/attribution and relationship to separately authored game/data require specific counsel/review before choosing. It imposes WAD/map concepts, scripting APIs and Doom-derived assumptions, may make engine work/tuning less straightforward than a modern general engine, and could pull the game towards “Doom mod with renamed enemies” rather than a distinct experience. Releasing game assets separately does not automatically answer every licensing question. [GZDoom `LICENSE`](https://github.com/ZDoom/gzdoom/blob/master/LICENSE).

**Use if:** legal/release terms are acceptable and the team wants the Doom map/mod runtime as a conscious product choice. Prototype one original room and one dynamic geometry event before commitment.

### E. Embed/adapt id Doom source directly

**Fit:** maximal source-level fidelity to 1993 behavior and a transparent learning resource.

**Cost/risk:** wrong objective if game assets, maps, network, renderer, editor, input and code are meant to be original. Doom code license is not “copyright over”; research/reading and reuse/distribution rights are separate questions. Doom source itself has id's copyright/license headers; the repository has been re-released under GPL-2-or-later, but verify exact source provenance and license before any reuse. [Official id repository](https://github.com/id-Software/DOOM).

**Recommendation:** no source code transplant. Borrow documented mechanics and validate our implementation against an authored original level. It avoids legal uncertainty and preserves original project ownership.

## Decision scorecard for an assistant-built, user-playtested game

The workflow changes the ranking: the user should be able to launch, play, report what feels/looks wrong, and receive the next build. Assistants need a reliable authoring path that turns level/design revisions into reviewable data without asking the user to hand-edit C++, engine scripts, or raw map syntax. An editor is useful only if it exposes Eyesore's real gameplay data and stays in sync with collision, lighting, sound and rendering.

Scores are a **discussion aid, not meaningful precision or benchmark results**. Each is 1 (poor for this project) to 5 (strong). “Migration” is scored as ease/low disruption. Because the established direction is native FPS, the browser implementation is an earlier artifact to reconcile, rather than a competing product target. Weighted judgment assumes authoring workflow is especially important: authoring 30%, feature fit 25%, migration 15%, license/distribution freedom 15%, ongoing maintenance 15%. License score assumes we want to keep the option of proprietary game code/content; if GPL is acceptable, GZDoom's score improves.

| Path | Authoring workflow | Feature fit | Migration / sunk cost | License / distribution | Realistic maintenance | Weighted view |
|---|---:|---:|---:|---:|---:|---:|
| Custom C++ sector refactor | **2** — today 1: hard-coded arrays and no map editor; an assistant can edit a declarative map, but we must first build/import/debug that schema and an in-game overlay | **4** — tailored control over retro movement, sector/portal rules, events and rendering; team owns every missing subsystem | **3** — preserves SDL/C++ utilities, but renderer/world/simulation need major redesign; current prototype is limited sunk cost | **5** — no engine copyleft commitment if dependencies are separately respected; custom code remains ours | **2** — small team owns renderer, map tools, collision, navigation, content import and packaging indefinitely | **3.1 / 5** |
| Godot 4.6.3 stable | **4** — editor/resources/import/reload support team-authored iteration; **3** until an Eyesore area/portal inspector and debug overlay exist, since default 3D scenes don't encode our sector contract | **4** — strong rendering, input, physics, UI, audio buses and export foundations; custom sector queries/retro render behavior still need implementation | **2** — existing C++ gameplay is not a drop-in; browser/native split still unresolved; porting raises short-term work | **5** — MIT engine license; must retain notices and inventory third-party licenses | **4** — broad editor/tooling and fewer low-level systems to maintain, balanced against Godot expertise and custom sector plugin upkeep | **3.85 / 5** |
| GZDoom 4.14.2 | **5** — mature Doom map/editor ecosystem can move room/door edits out of source; assistants still need to handle WAD/UDMF and project-specific scripting carefully | **4** — doors, sectors, events and FPS conventions fit strongly; modern rendering and scripting exist, but game may inherit a Doom-shaped workflow and constraints | **2** — discards current native prototype and would require translation into GZDoom's data/scripts; the browser product still requires a product decision | **2*** — GPL-3.0 source has distribution duties; evaluate engine/game/data packaging and source obligations before selection | **3** — mature engine reduces core systems work, but custom behavior, engine updates, scripts, packaging and license compliance remain team responsibilities | **3.55 / 5** |

\* If a GPL-compatible/open-source distribution is chosen and the user values map-editor leverage, score license/distribution **4**, making GZDoom roughly **3.85 / 5** under these weights. This is a product/legal preference, not a technical weakness. Godot current stable/version and MIT status are verified from the [official releases](https://github.com/godotengine/godot/releases) and [license page](https://godotengine.org/license/); GZDoom current release and GPL-3.0 status from its [official releases](https://github.com/ZDoom/gzdoom/releases) and [repository](https://github.com/ZDoom/gzdoom). These can change; recheck before selection and release.

The scorecard exposes a missing term in the first recommendation: a custom C++ path must be judged **after accounting for the editor that the team has to make**, not just after comparing runtime features. Without a geometry/portal inspector, material picker, encounter placement, collision/light overlays, reload and validation, C++ scores much worse for this collaboration model. A minimal editor may be a 2D map canvas plus properties and a 3D live view; it need not be a full commercial tool. Godot's built-in scene editor is not itself the desired sector editor; its score assumes we implement an Eyesore-specific editor/plugin or a reliable import workflow.

### Weight sensitivity

If migration and ongoing maintenance together matter more than authoring, Godot still leads under this illustrative alternative, but by less: authoring 10%, feature fit 10%, migration 40%, license 10%, maintenance 30%. Rounded weighted scores are custom C++ **2.9**, Godot **3.3**, GZDoom **2.8** (or **3.0** if GPL is acceptable). A more balanced shift that weights maintenance highly (authoring 15%, fit 10%, migration 25%, license 10%, maintenance 40%) also leaves Godot ahead: C++ **2.8**, Godot **3.6**, GZDoom **3.1** (or **3.3** with GPL acceptance). Both outcomes are just arithmetic over uncertain subjective inputs. The conclusion worth carrying forward is not a decimal: Godot leads when the team values lower tool/runtime upkeep, while GZDoom gains when its editor fit and GPL-compatible release model are accepted; custom C++ needs an unusually high value placed on the code already written or on direct runtime control to offset editor and maintenance costs.

## Counterfactual: when staying native C++ wins

The C++ sector refactor becomes the better choice if all of these are true:

- The user confirms native Linux FPS as the product and does not expect browser/mobile parity or broad multi-platform export.
- The approved scope is one compact game/episode with mostly 2.5D areas, stairs/lifts/balconies and simple movers; no room-over-room, advanced physics, mod SDK or campaign-scale tools are required.
- The user values exact control of movement, pixel presentation, sprite lighting and sound/encounter timing more than a general-purpose editor; the assistants can author map data and rebuilds while the user only launches/playtests.
- The team can define and build the small map schema/preview/validator once, then use it repeatedly. A few days of editor work that pays back on every level is preferable to integrating a larger engine if Godot's physics/rendering scene model needs equally large custom work.
- Existing C++/SDL code can be isolated into useful low-level components without keeping the current duplicated room geometry, fixed-function renderer, variable-time monolithic update, calibration branch, or rejected audio prototypes as permanent scaffolding.
- A small maintained custom runtime is expected product work, and its source, dependencies and Linux package can be owned with a documented handoff.

Under those conditions, staying C++ avoids migration overhead and gives the team one coherent, inspectable simulation. It would win only after the assistant team demonstrates the editor/data workflow against a representative map; “we already wrote C++” and a successful compile are not sufficient evidence.

**Revised decision recommendation:** put authoring workflow into the first gate. If only one slice can be built, prototype the C++ portal map format/editor loop and Godot editor/portal workflow on the same small level, with assistant-led content changes and user playtest as part of the test. GZDoom remains a serious third option if its GPL model is acceptable and its existing editor workflow can express Eyesore's original interaction/story/material needs without constant engine-specific work.

## Proposed engine-neutral runtime contracts

The eventual engine decision should receive this minimum list of interfaces from specialist leads:

- `Level`: stable ID/version; world coordinate scale; named areas, boundaries/portal connections, geometry/material assignments, entity placements, audio/light regions, start/exit, objective/secret metadata.
- `Area`: floor and ceiling query/surface, area tags, baseline brightness/acoustics, neighbor list, walkability/state. A first release can constrain walkable floor to horizontal polygons with explicit stairs/lifts/ramps represented by authored connectors; don't pretend to support arbitrary slopes until needed.
- `Boundary`: shared edge/poly boundary with sided materials (lower/middle/upper for step differences), min open height, blocking state/controller ID, traces/sound flags, navigation cost. It is the single truth consumed by renderer, actor movement, weapon/AI traces, sound occlusion and editor overlays.
- `Mover`: stable ID, target state/height/transform, velocity/easing, wait, blockers, crush/safety rule, sound/visual events and reset policy. Door visuals and collision derive from same state.
- `Actor`: stable content type/state/position/area, dimensions, grounded/floor state, movement constraints, health, animation events and AI state. Animation events dispatch named events; animation frame count does not determine collision profile unless the enemy lead asks for a gameplay-significant stance change.
- `Trace`: origin, endpoint, vertical aim/slope, collision channel (`weapon`, `projectile`, `sight`, `interaction`, `sound`), result hit type/material/actor/distance. Use one map query source for the common geometry; semantics can vary by trace channel.
- `Event`: typed name plus causal entity/area/position, world time, priority/category, payload and deterministic order. Weapons, enemies, story interaction, audio, lighting, VFX and HUD subscribe through explicit system interfaces; game narrative does not depend on sound asset file names.
- `Clock`: fixed simulation step (start candidate 60 Hz, measure); accumulated time with catch-up cap; render interpolation; deterministic ordering for input, actors, projectiles, movers and triggers; explicit pause/restart. Avoid unbounded catch-up or dropped gameplay time from dt clamping.
- `Level validation`: missing material/entity/audio IDs, duplicate IDs, disconnected required path, unreachable required keys/exit, door with mismatched collider/surface/area, invalid step/clearance, unowned map entity, texture usage errors, missing cue sources, progression softlocks and unsupported geometry all produce location-rich errors before play.

Potential area graph data could be authored as JSON/YAML or a compact custom text schema and imported into engine resources. Choose based on editor and diff usability, not familiarity. Make source map canonical, generated meshes/cache disposable. The game should not hand-maintain parallel renderer and collision coordinates.

## Incremental decision and migration plan

This is a decision plan, not authorization or a claim that anything has been implemented.

1. **Resolve product target.** Confirm native FPS vs browser/isometric, first target platform, intended distribution model (including whether source must be public), must-have classic traits, and whether the current browser toy is kept, replaced, or archived. Ask leads to revise dependencies against this single decision.
2. **Freeze an architecture-neutral slice contract.** One room graph and one encounter authored in files; identify exact dependencies from movement, level design, interactions, lighting/materials, enemy, weapon, effects, audio programming, story and QA leads. Keep story proposals plural until user review.
3. **Prototype two thin alternatives, not two games.** Same graybox, same movement/weapons/enemy, same door, light, material and ambience: current C++ sector refactor prototype vs Godot 4.6.x. Timebox each after estimates and preserve results. GZDoom gets a third option only if license/product fit is plausible. No bulk art/music or campaign content.
4. **Evaluate concrete criteria:** first-person movement consistency; working floor/height query and step rules; connected-door open/close traversability; ray and projectile occlusion agree with visibility/collision; 3D sprite scale/facing/fullbright/area light; door state drives movement and audio attenuation; edit a room without code recompilation; restart restores deterministic state; HUD/input/comfort; Linux package/launch; developer effort and performance on the user's actual hardware. Record user playtest impressions separately from measurable facts.
5. **Choose from observed total effort.** If Godot authoring and rendering support let the level/world/material/lighting/audio agents iterate at quality, continue it. If custom sector architecture materially reduces design friction and delivers better FPS control without an editor/renderer tarpit, retain C++. If GZDoom wins on mapping and runtime, make the GPL/product commitment explicit. If none wins, revise the feature list instead of stretching a prototype.
6. **Migrate accepted content only.** Export current original art/audio sources, naming manifests and design notes; do not treat rejected placeholder/calibration compositions as canonical. Translate one accepted encounter with provenance. Keep browser prototype as archived historical record or remove it only after product choice and source-control checkpoint. Maintain a clean acceptance baseline before deleting experiments.
7. **Scale tools with map need.** First authoring need is top-down area/boundary graph plus height/light/collision/encounter/audio overlays and a live camera, not a complete Doom editor. Add bespoke tooling only to resolve repeated authoring pain.

## Prototype gates and benchmark evidence

These criteria should be applied after engine selection is approved; this report does not run them.

| Gate | Minimum proof | Fail signal |
|---|---|---|
| World consistency | Walk, enemy path, hitscan, moving projectile, visual occlusion and sound occlusion agree across a wall, doorway, raised platform, lowered platform and door at intermediate/open/closed states | Any subsystem uses an independent wall/door/height list |
| Movement | Same input and elapsed simulation time produce same distance at 30/60/120/uncapped rendering rates; stairs, stops, walls and ceiling clearance reviewed at gameplay speed | frame-rate changes control feel or player floats/clips through height transitions |
| Level iteration | Edit room width, material, enemy position, door link, item, light/acoustic region and reset state through source map/editor without modifying C++ or recompiling game logic | designer needs hand-coordinated changes in renderer and collision code |
| Combat read | sprites have correct floor, height, silhouette/light response; muzzle/attack/recovery events align; two elevation bands allow fair enemy/projectile/hitscan interactions | attacks pass through wrong floors/walls or visual and acoustic tells disagree |
| Authored transition | a drain/lift/door changes traversal and its geometry/audio/light state coherently and persists/resets as specified | event is cosmetic while collision/nav/audio disagree |
| Slice scale | one continuous level meeting the currently proposed 5–8 minute scale and multiple routes/secrets, without fixed counts or hard-coded wave gate logic | implementation requires unreviewed refactoring before first level can grow |
| Performance/stability | instrumentation under a stressed representative room shows stable simulation budget and drawing; no overflow at chosen actor/projectile ceiling | need to cap believable content at current arrays or unstable timestep |
| Creator workflow | actor/material/audio/interaction IDs validated with source paths and clear, actionable error locations; can preview room/height/collision and restart | invalid/duplicate/missing content is only discovered in playtest |

Benchmark real hardware after target chosen. Performance limits should be set from desired visuals and the user's machine, not imported from 1993 or guessed from current 14-enemy test.

## What should stay out until a slice proves the need

- Full Doom-format/WAD compatibility, demo determinism, netplay, mods, rollback, scripting VM and source-level fidelity.
- A general-purpose 3D editor, arbitrary stacked room-over-room sectors, continuous sloped terrain, dynamic soft-body physics, destructible geometry, dynamic global illumination, complex navigation mesh baking or AI perception framework.
- A campaign-wide procedurally generated intensity director. Dead Space's authored tension pacing may inform story/encounter timing, but the current Eyesore materials do not yet show a need for a persistent cross-level intensity service. Start with explicitly authored calm/combat/story event beats and actual audio/lighting channels; only promote to an engine system when encounter leads show repeated control/quality needs.
- ECS conversion, multithreading, network replication or optimization based on current code size. Choose entity/data organization to match measured actor count and programmer familiarity.
- Large content import pipeline, workshop/mod SDK or player level editor before a reviewed first map exists.
- Decorative complexity that erodes target silhouette and surface readability.

## Counterargument to this recommendation

Godot can be a poor fit if its 3D scene and physics defaults fight the compact sector grammar, editor overhead slows every map revision, or vintage sprite/light rendering needs more custom code than expected. A focused custom runtime might be simpler, easier to inspect and more controllable for one small game; abandoning already-authoritative browser mechanics might waste work if player feedback still favors that direction. Conversely, a C++ sector engine may sink the team into tools, collision and rendering before it has one genuinely good room. GZDoom may be the most direct route if the actual artistic aim remains Doom-adjacent map authorship and the license distribution model is acceptable. Therefore the runtime cannot be responsibly selected from feature checklists alone: the same representative room, honest time estimates and user's hands-on feel are the deciding evidence.

## Decision questions for the director

1. The established direction is native FPS. During implementation, should the browser/isometric slice be archived as history or retained as a separate experiment?
2. Is an open-source/GPL engine or runtime acceptable for planned distribution, or is a permissive engine license preferred?
3. What is non-negotiable from Doom: sector/room authoring, 2.5D silhouettes, movement/combat pacing, mod compatibility, or source architecture? These have very different implementation costs.
4. Does Eyesore need true room-over-room geometry and jumping, or do authored floors, lifts, stairs, balconies and explicit height transitions cover the intended design?
5. What is the first target platform and the development machine baseline for performance/editor decisions?
6. Should the story intensity pacing stay as authored level/encounter choreography until more evidence exists, with a reusable intensity service deferred?

## Source trail and factual boundaries

- Observed implementation claims above come from local files: `README.md`, `components/arena.tsx`, `linux-game/src/engine3d.cpp`, `linux-game/src/combat_world.h/.cpp`, `linux-game/src/calibration_scene.*`, `linux-game/Makefile`, and the role/world/story/audio/creature briefs. References describe inspected code, not a fresh runtime test.
- Doom behavior claims refer to id Software's released Linux Doom source `linuxdoom-1.10`; that repository is not the exact 1993 DOS executable and the source contains Linux Doom 1.10 behavior. Cite individual files when comparing behavior.
- Godot latest stable and license facts come from the official release list and official license page at research time. Version numbers can change.
- GZDoom version, technical scope and source license come from the official release listing and source repository at research time. This document flags license implications for review, not legal advice or a final legal interpretation.
- Architecture ratings, requirements, risks and recommendations are engineering inferences for Eyesore. Only a matched prototype, authoring exercise and user review can validate them.
