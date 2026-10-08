# Eyesore — world, materials, lighting and level redesign research

Date: 3 October 2026. Author: world/level/lighting specialist. Status: researched design draft for director and peer critique. This document replaces the compact first-level concept as the creative target. It does not claim a playable implementation or validated timing. All proposed numbers require movement and combat review.

## Research and conclusions

**Doom: geometry carries gameplay and atmosphere.** The released source stores floor height, ceiling height, floor image, ceiling image, light level and special/tag data per sector. Wall sides have distinct upper, middle and lower textures and offsets. This gives elevation changes, door openings and material alignment explicit representation. Our inference: define materials on surfaces and brightness in areas; a generic wall bitmap and a camera lamp cannot communicate a place. [id Software: sector and side structures](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_defs.h)

**Doom: light and sky have distinct jobs.** Sector light functions include fire flicker, irregular flashes, strobes, glows and tagged light changes. Sky planes are treated specially and drawn fullbright; normal planes receive light/distance lookup. Our inference: use stable light masses for combat, restrained animation for machinery, and sky as a distant orientation layer. The proposed colored lighting, fog and emissive masks below are modern additions, not claims about vanilla Doom. [id Software: lighting](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_lights.c), [plane and sky renderer](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_plane.c)

**DUSK: a coherent world can come from deliberate constraints.** In a first-person creator interview, David Szymanski describes studying older games' walls, floors and model UVs to construct a purposeful visual identity. His opening combat gives ample health and space while immediately teaching movement and enemy behavior. Our inference: introduce one clearly staged fight inside an authored location, then change the spatial problem. Do not spend a level demonstrating a generic room. [Creator interview, Game Developer](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games)

**AMID EVIL: world variety includes enemies and layout.** Its official product description promises seven distinct settings with distinct enemies, sprawling nonlinear levels, secrets, and dynamic music. Our inference: a material family, enemy habitat, architectural silhouette and traversal motif should change together between districts and levels. Changing texture tint alone is not a new world. [Developer/publisher product description](https://store.steampowered.com/app/673130/AMID_EVIL/)

**Prodeus: old visual language can coexist with production tools and modern presentation.** Its official material describes modern rendering under retro aesthetic constraints, a handcrafted campaign and an integrated editor. Our inference: retain stylized pixels while investing in map authoring, controllable lighting and review tools. Visual crudeness is not a necessary consequence of a retro target. [Official site](https://www.prodeusgame.com/website/index.php), [official product description](https://store.steampowered.com/app/964800/Prodeus/)

These are source-supported observations followed by our own design deductions. No source establishes that the proposed layout below is fun. That must be shown in a complete traverse and combat review.

## Audit: what the new direction must replace

Inspected `linux-game/src/engine3d.cpp`, `combat_world.h`, `calibration_scene.cpp`, `docs/LEVEL1_DESIGN_BRIEF.md`, `CALIBRATION_SCENE_CONTRACT.md` and `EYESORE_TEAM_REVIEW.md`.

- The calibration scene is a 24 × 20 × 5 shell with one cover mass, one caster and floor brightness patches. It cannot serve as the first level or the visual reference for an expanded game.
- The legacy scene is a 72 × 60 rectangle subdivided with walls/pillars. It loads three world images: `infernal-wall.bmp`, `infernal-floor.bmp`, `infernal-ceiling.bmp`. No authored material catalogue maps surface intent to assets.
- Legacy lighting sets the light position with an identity model-view matrix before applying the camera transform. The resulting light is attached to view space. Warm ambient/diffuse choices and directional face multipliers do not establish individual rooms. Calibration disables that lighting but only offers a handful of floor zones.
- Player translation is X/Z only. `PLAYER_HEIGHT=1.42`, movement 2.85 units/s with 2× sprint. A larger map with the current vertical behavior cannot deliver real stairs, pits, lifts and overlook fights.
- `combat_world::World` contains one room box and solid boxes. This is a useful collision foundation, but it lacks explicit traversable floor surfaces, sector/room identities, materials, portals and dynamic doors.
- Fourteen fixed enemy slots and three global clear-to-cache waves organize the old experience. The old first-level brief repeats kill gates and raises same-role HP between rooms. The new level needs persistent actors and local triggers, stable archetype health and optional retreat.
- The old `EYESORE_TEAM_REVIEW.md` diagnoses several of these problems but narrows the deliverable to a reviewed slice. This redesign now specifies an actual level and a production content family.

## New world direction: The Witness Works

A storm coast observatory has been converted into a machine that records things beneath the sea. Its civic exterior uses chalk limestone, black tidal stone, heavy green copper and pale ceramic. Deeper inside, clean optical apparatus intersects fossil strata and translucent tissue. The first level occupies the waterworks beneath the observatory. The final view reveals a much larger city of lens towers offshore.

The first level is **Low Tide Observatory**. Its defining image is a broken circular lens suspended above a drained tidal court. The player sees it from below, through machinery, from a roof walk, then through its center on the way out. The lens gives recognizable orientation without requiring an objective marker. Repeated views must reveal new geometry or a changed state.

Palette hierarchy: pale stone midtones; nearly black structural silhouettes; copper green as material color; warm ivory work lamps; cold blue sky fill; small deep-red warning accents. Enemy projectiles own saturated attack colors. Avoid covering every surface with eyes, runes, rivets or noisy grime. Corruption appears at three specific breaches and becomes more prevalent in later levels.

## Spatial contract and level schedule

Initial design footprint: 96 × 84 world units, with shaped empty exterior space; roughly 2,700–3,300 units² traversable. The footprint is approximately 17× the calibration footprint, but area is not the quality measure. Target 14 named spaces, three secrets, two loops, three purposeful height strata, six combat situations, 40–46 normal-route enemies and 5–8 minutes on a first successful run. An experienced direct run should be shorter. A full secret sweep may exceed eight minutes.

Coordinates: X east, Y up, Z south. Heights are floor heights. Main route at Y=0; maintenance basin at Y=-2.4; galleries at Y=+2.4; exit overlook at Y=+4.8. Use 0.2-unit steps, 1.0-unit landings, and 3-unit clear combat stairs. No mandatory jumping. Main doors 2.4 units wide and 2.8 high; main combat circulation at least 3 wide, preferably 4–6. Human service corridors can narrow to 2.0 with no mandatory flanking combat. Major fighting ceilings 6–10; quiet ducts 2.4–3.2. These values assume current player eye height and require a movement-owner review before geometry is fixed.

| ID | Space / rough size | Floor / ceiling | Target seconds | Geometry, gameplay and forward view |
|---|---|---|---:|---|
| A | Storm Landing, 12×8 | 0 / sky | 15 | Crooked sea wall, one safe spawn nook; warm entrance offset left, broken lens tower ahead. Starter weapon visible immediately. |
| B | Weigh House, 12×12 | 0 / 4 | 25 | One weak guard, then two pressure enemies from a visible stair recess. Rectangular cover island supports movement both ways. Shotgun before leaving. |
| C | Lens Court, 24×22 | 0 and -2.4 / sky | 35 first visit | Main landmark and three readable exits. Basin walls break long shots; balcony visible above. Four enemies in two roles, no lock. |
| D | Copper Exchange, 16×12 | 0 / 5 | 30 | East branch: staggered machines, two lateral cover changes, window into E. Four mixed enemies. |
| E | Counterweight Stairs, 8×18 | 0→+2.4 / 6 | 20 | Switchback ascent wraps a moving counterweight. Threat visible through the structure before stair entry. One guard. |
| F | Survey Gallery, 20×8 | +2.4 / 4 | 25 | Gallery looks back into C; circular brass key on survey table. Two projectile enemies with mutually separated attack lanes. |
| G | Spillway Ramp, 8×18 | +2.4→0 / sky | 15 | Return to C by a new route; one pressure enemy, small ammo trail reinforces movement direction. Opens one-way latch from F side. |
| H | Pump Nave, 22×18 | 0 and +1.2 / 9 | 45 | West branch after brass key: tall triple piston silhouette, figure-eight circulation, six enemies including first durable anchor. Water switch visible across room before arrival. |
| I | Silt Basin, 20×14 | -2.4 / 4–7 | 35 | Draining water reveals stepped walkway beneath C, not a damage-floor slog. Five enemies emerge from opened maintenance doors with an audible warning. |
| J | Ossuary Cut, 16×10 | -2.4→0 / 5 | 25 | Natural fossil wall cuts through ceramic machinery. Four enemies, short range pressure. Two exits allow retreat to I or advance to K. |
| K | Prism Kiln, 20×18 | 0 and +2.4 / 8 | 45 | New combat tool before entry, two heavy cover wedges, six mixed enemies arriving from visible entrances; no teleport behind player. |
| L | Lantern Ramp, 6×18 | 0→+4.8 / sky | 20 | Quiet climb with safe health and a final vista; switchback/steps if slope support is unavailable. Preview M through slats. |
| M | Signal Crown, 24×18 | +4.8, ledges +6 / sky | 45 | Final seven-enemy mixed encounter; ring broken by two occluders and one risky central shortcut. Exit controls accessible during combat. |
| N | Departure Bridge, 14×5 | +4.8 / sky | 10 | Player activates a visible ferry mechanism and sees offshore lens towers. Deliberate use confirms exit; walking near it does not. |

Total planned beats: ~390 seconds, with exploration time variable. Travel and fights overlap; these are per-space elapsed targets, not extra time to add to pure path traversal. Expected main-route centerline length 280–340 units; mixed walking/sprinting contributes roughly 65–100 seconds of the target. If combat and navigation exceed target, reduce dead travel before removing a district.

### Path graph and route choices

```text
A → B → C ⇄ D → E → F → G → C
        │           │
        │           └─ S1 gallery cache → G
        │
        └─ brass key → H [drain switch]
                        │        └─ S2 pump balcony → H
                        ↓
                    I ⇄ C basin shortcut
                    │
                    J → K → L → M → N
                    └─ S3 fossil passage → K upper ledge
```

A/B is the teaching section. C/D/E/F/G is the first loop: preview from low court, climb, collect key, return with spatial knowledge. H/I/C is the second loop: change the world, then traverse a place formerly seen but inaccessible. J/K/L/M/N delivers a new visual family, bigger combat and a horizon reveal.

C must show the keyed H entrance before the player reaches F. Its heavy brass disk and circular socket match the key's silhouette as well as its color. D is initially the obvious available path: lit doorway, floor inlay and machinery audible beyond it. Neither branch requires a floating marker. The player can return to previous rooms, recover missed supplies and fight surviving enemies.

### Explicit switches, doors and state

| State | Action | Physical change | Feedback / persistence |
|---|---|---|---|
| `key_brass=false→true` | Take F survey key | H door becomes usable, remains shut until used | Key pickup motif; key appears in inventory; H door previewed before key |
| `gallery_latch=closed→open` | Use G lever from gallery side | Opens G→C return gate permanently | Gate motion visible through landing; metal release sound at gate |
| `pump_power=off→on` | Use H three-handle control | Drains I, opens H→I stair shutter and C basin access | Water drops over ~3 s; pump sound winds down; fixed path lamps turn on; state never reverses |
| `kiln_route=closed→open` | Cross I maintenance threshold | J door opens as counterweight settles | Local sound ahead; player cannot be crushed; open state persists |
| `ferry_ready=false→true` | Use M signal controls | Bridge extends to N | 4 s mechanical tell, lamp sequence towards exit, no full-screen flash |
| `exit` | Use N ferry console | Save completion and transition | Exit confirmation sound and results |

Final combat does not require killing every actor to make the level solvable. The signal interaction creates pressure, but skilled movement may escape it. If director wants one mandatory arena, M is the only candidate; it needs explicit fiction and a clear completion cue. Use held-open safety sensors for doors/lifts; never make corpse placement block a required state.

### Three secrets with different clue grammar

S1: from F see a narrow wind-bell balcony below the far parapet; G has an obviously dented hinged screen. Use opens a short stair to armor and a view of H's roof. The secret teaches that a seen location can be reached from elsewhere.

S2: H has a dark inactive piston while the others move. Starting the pump lifts that piston and exposes a ladder-shaped stair niche. Following the stopped mechanical sound leads to a balcony with special ammo and optional two-enemy fight. It re-enters H and cannot bypass the drain switch.

S3: J's fossil wall has one bright mineral seam that lines up with the gallery's surveying slit. A useable service hatch beside it leads to K's upper ledge. Reward is an advantageous opening angle and a resource cache, not just score. Never hide its clue beneath random damage decals.

## Encounters, resources and enemy habitats

Role vocabulary is provisional and should be mapped to the enemy agent's original roster: **guard** (weak ranged attrition), **skirmisher** (slow dodgeable shot), **runner** (melee space pressure), **anchor** (durable territorial threat), **floater** (vertical lane pressure). Use stable health per role across the level. Early normal difficulty uses at most two simultaneous attack roles; later encounters mix three. First floater in K, never hidden against the sky.

| Beat | Composition and placement | Player decision / supplies |
|---|---|---|
| B | 1 guard at far doorway; 2 runners visible before reaching player | Learn cover then movement; shotgun collected before first mixed room; 12 shells supplied |
| C | 2 skirmishers on ground at separated 35° lanes, 2 guards on low ledges | Move around basin, identify east route; 12 pistol units and 20 health in separate safe pockets |
| D–F | D: 2 runners, 1 guard, 1 skirmisher. E: 1 guard. F: 2 skirmishers with no unavoidable crossfire on arrival | Cover, elevation, ranged aim; 8 shells, key, 25 armor; no silent rear spawn |
| G–H | G: 1 runner. H: 1 anchor beside control, 2 skirmishers, 3 runners | Choose high ledge or low loop; 16 shells split on opposing sides, 20 health by retreat route |
| I–J | I: 2 guards, 3 runners. J: 2 guards, 1 runner, 1 skirmisher | Controlled close pressure, short recovery; 24 pistol units, 8 shells, 20 health |
| K | 1 anchor, 1 floater, 2 skirmishers, 2 runners | First explicit vertical mixed fight; new tool supplied outside entry, enough ammo for 4–6 useful shots; 20 health at far cover |
| M | 1 anchor, 2 skirmishers, 2 guards, 2 runners | Use full toolkit and decide when to activate ferry; 12 shells and tool ammo off safest route |

Normal route total is 43 enemies. Optional secret enemies are additional. These counts are a design budget, not a directive to enlarge fixed arrays without ownership/lifetime work. Difficulty should move enemies, change compositions and adjust supplies while preserving role timing; reserve HP changes for clearly different variants. Easy removes one pressure unit from each major encounter and adds ~30% health/ammo. Hard changes cover angles and includes one extra floater/anchor in late rooms after review.

Ammo budget needs the weapon lead's damage model: total reachable damage capacity should initially target 1.5× expected mandatory enemy effective health at realistic accuracy; secret reserves are excluded from that guarantee. A player missing secrets must be able to finish. Record intended shots-to-kill and median actual miss rates before fixing pickup values. Recovery supply follows difficult fights; supply placed in contested lanes is an explicit risk/reward decision.

## Material taxonomy and authoring schedule

Every surface has **usage**, **family**, **variant**, **state**, **texel density**, **physical response**, **light response** and **sound surface**. Floor, wall and sky are never inferred from a filename substring at runtime. Height belongs to geometry, not a painted fake ledge.

Naming: `es_<family>_<usage>_<motif>_<variant>_<state>`; e.g. `es_copper_wall_ribbed_a_dry`. Usages: `floor`, `wall`, `ceiling`, `trim`, `riser`, `door`, `switch`, `decal`, `liquid`, `sky`. Optional maps use `_albedo`, `_emit`, `_normal`, `_rough`. Author albedo without baked directional lamps so it can work across rooms. Start with albedo plus emission; additional maps depend on chosen renderer.

| Family | Main uses / motifs | Do not use it for | Base authoring count |
|---|---|---|---:|
| CHALK | Exterior ashlar walls, broad floor slabs, doorway voussoirs, coping and stair risers | High-frequency grit across target backgrounds | 12 |
| TIDE | Dark basalt foundations, worn steps, wet lower wall bands, basin floor | Unmarked lethal surfaces | 10 |
| COPPER | Riveted ribs, machinery panels, grates, pipe trim, heavy door leaves | Every wall in the level | 14 |
| CERAMIC | Pump and lens laboratory walls, pale floor tessellation, ceiling coffers, ceramic inlays | Unbroken mirror-like gloss | 10 |
| OSSUARY | Fossil strata, compressed shell floor, mineral seams, isolated tissue intrusion | Entire first-level exterior | 8 |
| SIGNAL | Key sockets, control panels, lamp housings, hazard trim, route identifiers | Noisy universal emissive stripes | 10 |
| SKY/LIQUID | Storm horizon, distant architecture layer, low cloud layer, tidal water, drained silt transition | Foreground target-shaped cloud details | 6 |

Initial world set: **70 authored base materials**, plus controlled wet/damaged variants, not 70 random texture prompts. Target 128 px/m equivalent at authored world scale for general surfaces; hero controls can use 256 px/m. Compare in game at target render resolution before locking density. Consistent visible texel size matters more than raw file dimensions. Wall modules typically 256×256 or 256×512; trims 128×512; floor repeats 256×256; sky panorama 2048×512. These are initial art targets, not fixed engine requirements.

Each family needs a clean primary surface, low-detail target backdrop, transition edge, trim, corner solution, floor, riser and damaged accent where appropriate. Use structural rhythm at large scale, wear at medium scale and sparse noise at small scale. Painted bolts must not become bright projectile-like points at 15–25 units. Floors are calmer than walls; combat floors clearly distinguish walkable paths, steps and basin drops. Doors use unique frames and thickness; a plain wall panel is never secretly a required door.

Elevation transitions: floor material wraps only onto a matching riser asset; never stretch a floor bitmap down a 2.4-unit cliff. Step noses receive a narrow value change. Basalt basin walls get a waterline trim at the old water height, so the drain event leaves evidence. Railings use a dark thick silhouette and a clear lower collision rule. Sky opening edges have coping/cornice geometry to avoid a box with its roof deleted.

## Lighting and atmosphere intertwined with architecture

Use authored area illumination plus a small number of localized accent lights. Start with sector/vertex color and occlusion-aware area boundaries; retain room for baked lightmaps or a modern shader pipeline if the engine lead chooses it. Dynamic lights are reserved for shots, mechanisms and a few narrative sources. Shadows cannot be represented by brightness patches on the floor while walls and creatures remain unrelated.

Values below are relative art-direction luminance targets (0–1), not physical lux or a prescribed GL color value. Final image should retain a readable dark body against its background and stable route information with muzzle flashes absent.

| District | Base / focal range | Color / light shape | Gameplay relationship and sound |
|---|---|---|---|
| A, C exterior | .35–.50 / .70 | Cold diffuse sky, warm doorway rectangles, black lens silhouette | Lens court exit hierarchy readable from entry; broad sea/wind bed, sparse metal cable groans |
| B weigh house | .40 / .70 | Warm overhead pool stops before enemy backdrop | First target crosses neutral midtone wall; short dry room response, latch and footsteps localize entry |
| D–G copper/galleries | .28–.42 / .65 | Tall slots across walls; cool return-window fill | Rising height has rising sky exposure; key table lit without glow cloud; repeated counterweight rhythm locates E |
| H pump nave | .25–.40 / .75 | Tall ivory light wells and shadowed outer bays | Control and two safe circulation arcs remain readable; low pump throb drops when switch completes |
| I–J basin/fossil | .22–.35 / .60 | Low lateral reflected water light; discrete mineral seam | Darkest area still shows threats and step edges; dripping space, dampened mechanical bed, no loop that resembles incoming fire |
| K prism kiln | .35 / .75 | One hot white slit, cold fill behind floater, restrained red machine status | Warm/cold separation identifies opposing lanes; resonant glass/stone tail, combat cue only after threats commit |
| L–N crown/exit | .40–.55 / .80 | Open cold sky, warm signal lamp grows along bridge | Finale silhouettes avoid busiest sky region; wind widens, ferry machinery becomes end-of-level audio landmark |

Sky: painted broken coastal clouds in broad horizontal bands with low-contrast offshore towers. Fix horizon at a consistent world level and rotate with camera orientation, not position. Use a continuous panorama initially; cube sky is optional. No obvious seam, hard zenith stretch, camera-attached landmark or clouds that look like enemies. Foreground tower silhouette is geometry. Slowly moving cloud layer can be a later improvement after clarity review.

Fog: light desaturation and blue-gray depth haze outdoors, strongest beyond ~35 units and unobtrusive inside 20. Interior fog is locally authored only for H/I; it must not blanket all rooms. Keep silhouettes and important shots readable beyond the longest planned attack distance. Disable volumetric beams if they turn into white curtains. Fog values are proposed starting points, not a benchmark result.

Visibility review: capture each combat entry at player eye height and the farthest useful weapon distance. Inspect grayscale, native render size, neutral brightness, and a scene with all dynamic lights off. Confirm enemy silhouette, attack tell, floor boundary and intended exit are distinguishable. Examine every stair from above and below, and each sky-facing enemy against three camera elevations. Reduced flashing mode keeps the same visibility floor. Flicker never controls whether a required route or enemy can be seen.

## Engine and production requirements

1. **A real authored level format.** Rooms/sectors, surfaces, material IDs, floor/ceiling heights, links, actor placements, lights, sound zones, triggers and persistent state should be data. A compiler/import step can turn that into draw meshes and collision. Avoid creating independent coordinates in renderer, movement, projectiles and AI.
2. **Vertical simulation.** Ground query, gravity or supported-height movement, step-up/down rules, ceiling clearance, ramps/stairs, lifts, projectile/LOS heights and enemy path links must agree. First level does not require overlapping room-over-room geometry; the gallery stays on the court perimeter, saving complexity without flattening it.
3. **Doors and movers.** Shared dynamic transform/state for visuals, collision, rays, enemy navigation and sound occlusion. Persistent one-way latches, key checks and switch tags. Level reload/reset restores all linked state.
4. **Material registry.** Validate legal usage, texture paths, dimensions, scale, UV origin, emission flags and footstep/impact family. Tiling previews and one family contact sheet before mass production. Record source/provenance per material.
5. **Lighting lookup for actors.** Sprite brightness/color samples its occupied area and blends at boundaries. Deliberate emission is restricted to attack effects or specific body details. Bodies should belong to the same illumination as architecture.
6. **Authoring support.** Orthographic map with room/height labels, material browser filters, sector/light overlay, collision overlay, encounter trigger overlay and fast reload. A plain JSON + importer is acceptable initially if the review overlay exposes the actual level data.
7. **Audio zones and events.** Each district has a room ID, reverb/send choice, ambient bed, occlusion links and event positions. Door state changes sound propagation. Named events include key taken, latch release, drain start/end, basin emergence, signal start, bridge ready and exit. Audio agent owns loudness and implementation; world data owns location and causality.
8. **Content scale.** Persistent actor list replaces fourteen hard-coded slots; deterministic encounters and authored active bounds prevent waking the whole map. Separate renderer visibility from simulation activation so looking away never freezes a damaging projectile.
9. **Acceptance evidence.** Complete map traverse, all gate states, secrets, two route alternatives, clean restart, pause/reload consistency, collision/ray alignment at heights, and measured pacing. These checks are a future implementation requirement, not a claim they were run for this document.

## Major forks for director critique

| Decision | Preferred | Viable alternative | Why it matters |
|---|---|---|---|
| World identity | Coastal observatory/waterworks | Flooded civic archive of black paper and brass sorting towers | Both depart from generic infernal rooms; observatory supports stronger sky/elevation landmarks |
| Main layout | Two interlocking loops around lens court | Two freely ordered wings, each with a control, returning to central court | Wing choice gives more agency but doubles encounter/resource order review |
| World transformation | Drain basin to reveal route | Rotate giant lens bridge to connect galleries | Draining ties surfaces, sound and traversal together; rotation needs more moving collision |
| Lighting method | Authored sector/vertex baseline + accents | Baked lightmaps + restrained dynamic lights | First suits current engine; second improves spatial grounding but requires mesh/UV/bake pipeline |
| Finale | Control under pressure; escape allowed | One announced lockdown, defeated anchor releases exit | Choose desired combat philosophy explicitly; avoid accidentally making every room a lockdown |
| Spatial scope | 96×84 level, 14 spaces | 112×96, 18 spaces with alternate workshop and roof loop | Larger option is useful only if encounters, landmark views and travel time remain varied |

## Expansion beyond the first level

The initial production library should support five following levels with distinct spatial rules: **The Bell Canal** (street/canal loops and lift locks), **The White Archive** (stacked reading courts with movable shelves), **The Negative Garden** (outdoor mineral growth and long sightlines), **The Listening Quarry** (terraces, conveyors and cave mouths), **The Inner Lens** (abstract optical architecture and corrupted matter). Each requires its own landmark, dominant height rhythm, enemy habitat, texture extensions, light plan and acoustic identity. Plan 12–18 authored spaces per level, for roughly 80–100 across the first episode. Do not advertise these counts as finished content.

The first production review should compare three fully composed views from Low Tide Observatory—C court, H nave, J fossil cut—with an annotated map, material family contact sheet and district sound mockups. A representative view must include final-scale enemies, pickups and weapon framing. The director and specialist owners should critique those together, then carry the approved language across all fourteen spaces. A single polished rectangle does not satisfy this design.

## Questions for the director and peers

- Does the observatory direction achieve a sufficiently strong visual departure, or should the archive alternative become the main world?
- Can the movement/engine design commit to Y=-2.4/0/+2.4/+4.8 traversal now, and which light pipeline can carry the whole level?
- Which enemy roles and attack colors conflict with the district palettes, and which attacks need wider/different room geometry?
- Should M reward escape under pressure or require clearing one explicit arena?
- Can the sound lead make the pump shutdown, open coast and fossil interior audibly distinct while preserving attack tells?

The requested next step is director/peer critique of this concrete design before production geometry or bulk texture generation.

## Spatial alternatives for review

The following are planning drawings, not build-ready polygons. North is upward (−Z). Adjacencies, openings and sightlines must be checked when converted into an editor. Block dimensions come from the room schedule; the ASCII grid is schematic rather than a covert scale claim. Neither option is approved solely by inclusion here.

### Option A — court and waterworks, two interlocking loops

```text
                          NORTH / OFFSHORE LENS TOWERS
              ┌──────────────────┐  ┌───────────────┐
              │ M SIGNAL CROWN   ├──┤ N FERRY       │   +4.8
              │ open broken ring │  └───────────────┘
              └─────────┬────────┘
                        │ L ramp / long sky slot
       ┌──────────────┐ │   ┌──────────────────────┐
       │ K PRISM KILN ├─┘   │ F SURVEY GALLERY     │   +2.4 perimeter
       │ wedges + loft│     │ [BRASS] [S1]        │
       └────┬─────────┘     └─┬────────────────┬──┘
     S3→ ┌──┴─────────────┐    │ G ramp         │ E switchback
         │ J OSSUARY CUT  │    ↓                │
         └──┬────────────┘  ┌────────────────┐  │
            │               │ C LENS COURT   ├──┤ D COPPER
       ┌────┴─────────┐     │ raised rim  0  │  │ EXCHANGE
       │ I SILT BASIN ├─────┤ basin    −2.4 │  └──────┐
       │ drain route  │     │ broken lens   │         │
       └────┬─────────┘     └──┬─────────┬──┘         │
       ┌────┴─────────┐        │         └─────────────┘
       │ H PUMP NAVE  ├─[KEY]──┤
       │ [DRAIN] [S2] │        │ B WEIGH HOUSE
       └──────────────┘        │ cover island
                               └─────┬────────┐
                                     │ A STORM LANDING
                                     └───────────────┘
                                           SOUTH / START
```

The F gallery is along C's north/east perimeter, not placed directly over a required traversable tunnel. I connects laterally to the drained court basin. A sight window from F to H previews the next district without allowing a shot through a closed physical wall. Every view window requires explicit render/ray/collision behavior, especially decorative grates.

**Changes from the old concept:** two materially distinct loops, a physical world transformation, mandatory real elevation, an exterior orientation landmark, four stages of landmark views, local encounters independent of global clears, playable exit, persistent resources, and three secrets with distinct clues. The old 24×20 room and rectangular arena are not source geometry for this layout.

### Option B — split works, wings in either order

This is a different topology, not the same map with changed colors. Initial footprint 112×96; 18 spaces. Keep entry A/B, but split the two controls between an elevated **Optical Wing** and a sunken **Tidal Wing**. Both are accessible from C immediately. Either completed wing opens a shortcut and supplies one complementary tool. Completing both enables the final climb. Room art can use the same families while pacing must work in both orders.

```text
                        ┌─────────────┐
                        │ EXIT FERRY  │ +4.8
                        └──────┬──────┘
                       ┌───────┴─────────┐
                       │ SIGNAL CROWN    │
                       └───────┬─────────┘
                        [BOTH CONTROLS]
                  ┌────────────┴────────────┐
                  │ CENTRAL LENS ASCENT     │
                  └───────┬────────┬────────┘
           return ↓       │        │        ↓ return
  ┌────────────────────┐  │        │  ┌────────────────────┐
  │ OPTICAL CONTROL  ◆ ├──┘        └──┤ ◆ TIDAL CONTROL    │
  │ +2.4 / survey table│             │ −2.4 / pump switch  │
  └─────────┬──────────┘             └──────────┬─────────┘
  ┌─────────┴──────────┐             ┌──────────┴─────────┐
  │ PRISM KILN / LOFT  │             │ OSSUARY / CHANNEL   │
  │ crossing lanes    │             │ close cover lanes   │
  └─────┬────────┬─────┘             └────┬───────────┬─────┘
        │ roof   │ lens workshop           │ drains   │ store
        │ route  │ lower route             │ route    │ stairs
  ┌─────┴────────┴─────┐             ┌─────┴───────────┴─────┐
  │ OPTICAL FORECOURT ├──────┐ ┌─────┤ TIDAL FORECOURT      │
  └───────────────────┘      │ │     └─────────────────────┘
                         ┌───┴─┴────────┐
                         │ C LENS COURT │
                         │ two previews │
                         └──────┬───────┘
                             A / B ENTRY
```

First visit to either forecourt receives a universally useful weapon/supply package; second receives complementary ammunition/armor, not a required weapon that can be missed by choosing the wrong order. Both wing control rooms reveal a direct return route to C. Ambushes may respond to which wing was first, but do not reskin same-role enemies with different health. Controls have unique silhouettes (lens wheel versus pump handles), distinct sounds and two visible progress indicators on the final ascent mechanism.

Target 7–9 minutes unless the wing lengths are reduced. This is a genuine tradeoff: extra choice requires order-independent resource budgets and encounter validation. Do not claim the 5–8 minute target applies unchanged to the full 18-space version. A compact 16-space cut removes one optional route room per wing to restore that target.

### Vertical section A — court, gallery and drained route

```text
              SKY    broken lens silhouette, top ~+10
                       ╱          ╲
   +5.2  ───── gallery ceiling ──────────────   parapet frames sky
   +2.4  F/G gallery floor ═════╗
                               ║ stairs 12 × 0.2, two landings
    0.0  C court rim ════════╗  ╚═════ D floor ═════════ H pump floor
                            ║ basin wall         │ H controlled stairs
   −2.4  C basin ════════════╩══════ I silt path ══╧════════ J entrance
             old waterline at −0.3 is visible after drain
```

Before pumping, nonwalkable deep water has a physical boundary and visible guard/coping; the route is not simply an invisible wall over a blue floor. Water drains to below walkway height and exposes the H stairs/C access. Engine fallback is a mechanical shutter opening onto an already dry lower walkway, preserving the elevation and route graph. Do not implement cosmetic draining while leaving the player on Y=0.

### Vertical section B — kiln to signal crown

```text
  +10.0                              open sky / signal mast
   +7.6   kiln upper ceiling         ┌── M shelter roof
   +6.0                             ├── threat ledge, accessible stair return
   +4.8                     ┌═══════╧══ M/N main floor ═══════
   +2.4  K tactical loft ═══╗│ L landing / view back to lens
    0.0  K entry ══════════╩╧═══ L bottom
                      two flights, each +2.4 with resting landing
```

Threat ledges cannot let a melee enemy attack across unreachable vertical distance. Enemy agent owns attack height checks. Player route to each important firing position must be explicit unless the actor is a floater. Falling from optional low ledges returns to a traversable area; irreversible drops must have a visible onward route and should not discard required resources.

## District material assignments and prop grammar

This is the initial assignment manifest for Option A. The IDs follow the earlier schema; abbreviated names below are exact logical IDs without file extension or map suffix. Texture scale means world metres/units per full repeat, assuming 1 unit ≈ 1 metre for art planning. A separate texel-density review must confirm that convention against the existing player proportions.

| District / rooms | Floor IDs and scale | Walls / ceiling or sky | Trims, doors, props | Height and light transition |
|---|---|---|---|---|
| Storm precinct A/C/G/L/M/N | `es_chalk_floor_slab_a_dry` 2×2; `es_tide_floor_step_a_wet` 1×1 at sea edge | `es_chalk_wall_ashlar_a_dry` 2×2; `es_tide_wall_foundation_a_wet` 2×2; `es_sky_sky_coast_a_storm` one panorama | `es_chalk_trim_coping_a_dry` 2-unit run; `es_signal_door_circle_a_locked` one full leaf; lens ring, cable anchors, ferry bollards | Rim 0, gallery +2.4, crown +4.8; sky fill grows on ascent, warm entry/control lamps remain stable |
| Weigh house B | `es_ceramic_floor_checker_a_worn` 2×2, broad low-contrast checks | `es_chalk_wall_plaster_a_dry` 2×2; `es_copper_ceiling_beam_a_dry` 2×2 | `es_copper_trim_jamb_a_dry` 2.8 high; `es_copper_door_service_a_dry` full leaf; scale bed, inspection desk, one hanging lamp | 0 floor, 4 ceiling; outside cool fill gives way to warm pool, target backdrop remains .4–.5 |
| Copper ascent D/E/F | `es_copper_floor_plate_a_dry` 2×2; `es_copper_floor_grate_a_dry` 1×1 only where actual underlying geometry exists | `es_copper_wall_ribbed_a_dry` 2×2; `es_ceramic_wall_plain_a_dry` 2×2 behind targets; `es_copper_ceiling_truss_a_dry` 2×2 | `es_copper_riser_tread_a_dry` 1×0.2; `es_signal_switch_latch_a_off` full panel; counterweight cage, survey table, pipe bundles | 0→2.4; slot light illuminates side walls and stair noses, gallery gains cool court fill |
| Pump nave H | `es_ceramic_floor_inlay_a_dry` 2×2; `es_copper_floor_plate_b_dry` 2×2 around machines | `es_ceramic_wall_panel_a_dry` 2×2; `es_copper_wall_ribbed_b_dry` 2×4 on tall bays; `es_ceramic_ceiling_coffer_a_dry` 2×2 | `es_signal_switch_pump_a_off/on` full panel; `es_signal_trim_circle_a_brass` 1-unit run; pistons, pressure tanks, pipe elbows, caged lamps | Floor 0/1.2, ceiling 9; vertical light wells distinguish tall center from low circulation bays; drain completion adds static stair lamps |
| Basin I / C lower | `es_tide_floor_silt_a_wet` 2×2; `es_tide_liquid_water_a_tidal` 4×4 animated under path | `es_tide_wall_basalt_a_wet` 2×2; `es_tide_wall_waterline_a_wet` 2×2 band; `es_copper_ceiling_utility_a_wet` 2×2 in I | `es_tide_trim_waterline_a_wet` 2×0.25; `es_tide_riser_cut_a_wet` 1×0.2; drains, sluice wheel, low lamps, hanging chain | −2.4; revealed route gains warm low lamps, water luminance recedes, upper court remains visible for orientation |
| Fossil cut J / S3 | `es_ossuary_floor_shell_a_dry` 2×2, calm central path | `es_ossuary_wall_strata_a_dry` 4×2; `es_ossuary_wall_seam_a_dry` unique 2×2 clue; `es_ossuary_ceiling_arch_a_dry` 2×2 | `es_ossuary_trim_fracture_a_dry` 2-unit run; `es_copper_door_hatch_a_dry` full leaf; core drill, specimen racks, a single tissue breach | −2.4→0; broad subdued bounce, seam accent stays below projectile intensity; transition illuminated from K ahead |
| Prism kiln K | `es_ceramic_floor_radial_a_dry` unique center, 4×4; `es_copper_floor_plate_a_dry` 2×2 side paths | `es_ceramic_wall_plain_b_dry` 2×2; `es_ossuary_wall_intrusion_a_dry` unique breach; `es_copper_ceiling_truss_b_dry` 2×2 | `es_signal_trim_edge_a_ivory` 2×0.15; shutter panels, prism frames, kiln wedges, one broken observation pane | Floor 0/+2.4, ceiling 8; white slit focal source, dark cover wedges, cool floater backdrop and upper ledge fill |

The gallery's secret balcony uses an existing precinct family with a unique wind-bell prop; the pump secret uses COPPER/SIGNAL; the fossil secret uses OSSUARY/COPPER. Secrets do not demand entire new material families. Switch off/on IDs require identical frame/shape and a clear status change. Material IDs describe logical assets, not assets already present on disk.

Prop hierarchy for every room: one landmark prop or mass; two to four functional secondary elements; sparse small dressing. Keep floor combat routes clear. Collision classes are `solid`, `walkable`, `ray_blocker`, `nonblocking`, `interactable`; art lead and engine lead must agree on each. A thin painted pipe does not warrant invisible full-width collision. Large cover props need readable solid bases and consistent projectile blocking. Glass/grates require explicit destructibility/shot-through design, not guesses from alpha pixels.

Every room record should specify: floor/ceiling bounds; all surface material IDs and UV scale; entry reveal pose; exit clue; landmark; encounter ID; enemy sightlines; pickups; acoustic zone; light plan; traversal and door state; optional route; and required camera review positions. The schedule above plus this assignment table defines the starting data for all 14 rooms; geometry author must expand individual records during layout construction.

## Episode foundations and content ownership

These are candidates within the broader Witness Works visual identity. The director must select/cohere them with art and enemy designs before treating them as a fixed campaign.

| Level candidate | Spatial problem / likely graph | Elevation and material extensions | Light / sound identity | Required new enemy or interaction decision |
|---|---|---|---|---|
| Low Tide Observatory | Two loops or freely ordered wings, final ascent | Three strata; CHALK/TIDE/COPPER/CERAMIC/OSSUARY | Sky fill, work pools, draining water | Basic guard/runner/skirmisher/anchor/floater roles; keys and pump |
| Bell Canal | Parallel towpaths with three crossing choices and revisited lock basin | Canal floor, street and bridge decks; wet brick, tarred timber, painted steel | Horizontal water reflections, warm window rectangles; bells and lock gates | Long-range threat versus close ambusher; timed crossing must not become wait tax |
| White Archive | Central reading court, two stack wings, upper return routes | Basement stacks to high gallery; paper, ivory plaster, dark oak, brass rails | Narrow skylights and desk pools; dry paper/wood acoustic signature | Suppression/support role; movable shelving with fail-safe navigation |
| Negative Garden | Several outdoor route islands around visible central objective | Terraces and root bridges; pale mineral foliage, black soil, cracked glass | Pale diffuse exterior with deep structural shade; insect-like glass ticks | Flying/melee combinations; route hazards need explicit readable timing |
| Listening Quarry | Spiral descent with lateral shortcuts and conveyor crossings | Highest vertical range; cut stone, iron track, dust, wet cave mouth | Harsh daylight to isolated lamp silhouettes; long impacts/industrial beds | Durable artillery/area denial role; lifts and sound occlusion |
| Inner Lens | Familiar circulation progressively reorganizes, final convergent routes | Inverted visual motifs but stable gravity path; glass, tissue, ceramic fragments | Sharp controlled light planes and dark void; authored silence/re-entry | Elite combinations and boss role; changing geometry must stay fair and navigable |

World agent owns route meaning and space proposals. **Art direction** owns final world identity, palette, density, material and prop language. **Movement/engine** owns units, player envelope, valid steps/slopes, moving geometry and renderer commitments. **Enemy/sprite** owns physical size, silhouettes, attack tells/colors, movement classes and vertical attack rules. **Encounter/weapons** owns actual damage/ammo/HP budgets and timing; the count tables are input to that review. **Audio** owns source design, mix, spatial behavior and reverberation; world agent supplies causal events/areas. **Interaction/HUD** owns key/status presentation, use distance, door affordances, exit feedback and accessibility behavior. No specialist may approve another discipline's requirement by silently baking a guess into assets.

The necessary discussion is concrete: review C entry and H control encounter with all leads; let enemy lead reject unreadable backdrops, audio lead reject cluttered masking, movement lead reject stair/circle dimensions, and interaction lead reject ambiguous gates. Record the chosen revision and its effects on the whole route. Repeat at K's vertical encounter and M's exit. That conversation is part of producing the design, not a permission checkpoint for routine work.

## Added reference analysis: Wolfenstein 3D and Warhammer 40,000: Boltgun

Added following the user's requested reference expansion. These sources broaden the design criteria; they do not make the observatory option an approved direction.

### Wolfenstein 3D — simplicity that still creates decisions

The original source represents walls and occupancy on tile grids, with explicit door objects. Door opening connects neighboring areas, has local sound, and clears actor occupancy only when fully open; closing checks occupants. Keys gate door operation. This gives a door physical, acoustic and navigation significance. Eyesore should transfer that consistency: B's entrance, H's keyed door and G's return latch must each behave as one shared object across systems. [id Software grid/state definitions](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_DEF.H), [door implementation](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_ACT1.C)

Treasure pickups have distinct point values and sound cues, while health, ammo and keys have separate effects. Our design inference is to give exploration rewards a clear identity and a cadence between danger and recovery. Secrets can yield relics/records plus useful supplies, rather than every small detour being mandatory ammo. Do not transplant Wolfenstein's score/lives economy before the interaction and progression leads decide Eyesore's reward system. [id Software pickup behavior](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_AGENT.C)

Visual inspection of the publisher's Wolfenstein 3D store image shows strong blue/green doorway bands against stone and a broad quiet floor; characters remain distinct despite low resolution. This particular promotional image supports a contrast/material observation, not a reconstruction of a specific episode map. [Official store image](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2270/0000002413.1920x1080.jpg)

Transfer the clear orthogonal corner reveal, recognizable door frame, contained sightline and room reward. A short grid-like service wing can create tension by varying where doors fall relative to cover and corners. Do not transfer repeated identical corridors, flat-height world restrictions or constant plane shading into the whole game: they would defeat the user's elevation and lighting request. The reference renderer's floor/ceiling treatment is a historical constraint, not the recommended lighting pipeline. [id Software renderer](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_DRAW.C)

**Concrete design revision from this reference:** D gets three deliberate threshold views: first see a harmless machine corner, then a guard beside a contrasting frame, then the stair light beyond. Place an optional inspection office off D with a visible record/relic on its desk and enough supply to justify the detour. This can occupy an alcove within D's existing dimensions; no need to lengthen the map. Its door is clearly optional and does not use the brass lock shape reserved for H.

### Boltgun — observed environment and lighting language

Auroch's lead designer describes both hand-placed enemies and authored arena encounters with spawn points and movement zones. This is a useful distinction: a room can contain a deliberate local pressure sequence without making the entire map a single global wave. He also documents 3D-authored enemies rendered from eight directions into flipbooks with animation sound/damage events. That production method is directly relevant to keeping sprites coherent under our new level views. [Grant Stewart, Auroch Digital, developer article](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/)

The following observations come from direct inspection of official store screenshots. They are visual analysis, not assertions about unseen map connectivity or the game's exact shaders.

| Examined official image | Observation | Transfer to Eyesore |
|---|---|---|
| [Snowy bridge and industrial tower](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2005010/ss_83f34505acd4c35bcd1a9546ea791fc3ba3195b7.1920x1080.jpg) | Pale exterior haze separates dark bridge structure and a large central building; doorway warning trim and a small green indicator survive the gray mass. Height is visible through bridge supports and lower void. | Exterior reveals need a recognizable mass, a framed entry and real vertical construction; fog should simplify distant scenery while preserving threats. C and M require this compositional clarity. |
| [Purple chamber with upper walkway](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2005010/ss_c410a71484fae0f6790b963f3a4fe10fb5a5ccb0.1920x1080.jpg) | Threats occupy floor and upper walk; thick edge trim exposes the elevation. Small warm vertical lights contrast with cool/purple structural fill. | K's high threat needs a visible ledge edge, readable access and different background value; local light accents should identify a room's structure. |
| [Amber machinery hall](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2005010/ss_c63362eea757a43cba85898c25dab3f6761420b7.1920x1080.jpg) | Repeated luminous machine cylinders establish rhythm, vertical scale and warm light; floor plates and grates occupy separate zones. Dark teal enemy masses contrast with the warm room. | H's machine rhythm and circulation should be planned together. Material assignment distinguishes walkways from machinery footprints. Enemy palette review must happen before lights are fixed. |
| [Green containment corridor](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2005010/ss_1c70e938e3bdb5755310d29c090f3f9a3da0f6a3.1920x1080.jpg) | Bright container bands form a strong corridor identity and repeated depth cue; small enemies sit much closer to the environment's hue. | One dominant luminous prop family can name a district, but Eyesore must check small-enemy separation in grayscale and at distance rather than assuming color alone solves it. |
| [Tall ceremonial hall](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2005010/ss_7f0facaf577a9fd812e85dce54eb6a7bd6fdd3f8.1920x1080.jpg) | A monumental framed destination, tall columns, purple depth and warm small lamps create scale. Foreground creatures have stronger bright colors than most architecture. | Build memorable exit framing and keep the background calmer than combat silhouettes; giant rooms need landmarks and cover, not empty size. |

The exterior/interior contrast across these images is substantial: cold open rock/bridge space versus dense colored machinery or tall ceremonial interiors. Images alone do not establish the transition sequence between these particular rooms. The transferable design is **a change in enclosure, material, silhouette and illumination as one event**. In our candidate level A→B, C→H, I→J and K→L each receive that treatment, with an audible transition too.

Do not copy Warhammer architecture symbols, faction motifs, marine proportions or its material names. Do not assume its arena pacing, particle density or high viewpoint automatically suits Eyesore. The broad transfer is monumental industrial scale grounded in actual floor/upper-walk geometry, controlled district colors, clear material classes and a consistent sprite-production pipeline.

**Concrete revisions after the visual analysis:** H's three pistons each sit on a raised, edged machine plinth, leaving two unmistakable loops on a calmer floor; K gets an upper ledge face with a unique broad trim and contrasting backdrop; M's exit has a single large architectural frame that remains recognizable during combat. Keep isolated warm status lights as navigation accents, while the coast stays cool and the deep fossil district becomes neutral/cold. These proposals remain subject to the art lead's final palette and the enemy lead's tell colors.

### Cross-reference transfer matrix

| Reference | Keep in design reasoning | Explicitly avoid making a default |
|---|---|---|
| Wolfenstein 3D | Doors, corners, reward clarity, strong simple material bands | Whole-game flat corridor maze or required wall-humping secrets |
| Doom | Sector heights/lights, upper/lower surface distinctions, role combinations, route mechanisms | Copying commercial maps/assets or treating one texture as every surface |
| DUSK | Coherent authored identity, immediate playable teaching, distinct place-based atmosphere | Using roughness as an excuse for unreviewed assets |
| AMID EVIL | World identity changes along with inhabitants and spatial motifs | Color swap presented as a complete new district |
| Prodeus | Modern content tools and controllable presentation under retro constraints | Noise/particles filling every readability gap |
| Boltgun | Industrial/exterior contrasts, thick readable height edges, controlled room palette, event-authored sprite work | Imported franchise imagery or assuming arena waves solve all pacing |
