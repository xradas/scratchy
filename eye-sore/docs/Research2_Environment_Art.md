# Eyesore round 2: environment materials, textures and props

**Role 09 · GPT-6.1 Sol / medium · 3 October 2026.** Research and design proposals only. No production assets, renderer changes, map edits, builds or gameplay tests. Neither art direction nor engine is selected.

## Recommendation

Build a surface language before a large texture library. Compare a neutral material control with two small systems: **A, assembly and wear**, whose surfaces communicate construction, support and use; **B, layer and cut**, whose surfaces communicate solid mass, recess and reachable edges through graphic planes. Their distinction should survive a palette swap. A tiled stone wall recolored purple is not a second direction.

First validate floor/wall/ceiling separation, true cover, traversable elevation, ordinary versus locked doors and sky versus reachable space in one identical room. Keep enemy, projectile and interaction tells readable while moving. Expand only the winning grammar into level districts. A could support Civic Daylight and B could support Painted Eclipse, but these are conditional fit relationships, not approved setting decisions. Both can accommodate either story draft. The neutral control remains the benchmark for whether decorative material actually helps.

## Evidence notation and audit

**PF:** project fact inspected directly. **RF:** reference fact supported by the linked primary/developer source. **I:** inference. **P:** untested Eyesore proposal. All dimensions, pixel budgets and thresholds below are P starting hypotheses, not measurements from reference games. No current executable was launched. Image inspection used an audit contact sheet derived from existing files outside the repo; no deliverable artwork was made.

Read with [art direction](Research2_Art_Direction.md), [engine architecture](Research2_Engine_Architecture.md), [level design](Research2_Level_Design.md), [world interactions](Research2_World_Interactions.md), [movement](Research2_Movement_Aiming.md), and [reference direction](REFERENCE_DIRECTION.md). The initial audit preceded lighting’s report; the revision now incorporates [lighting](Research2_Lighting.md), including its uniform C, broad architectural A and graphic plane B comparisons. The contracts remain proposals for cross-review, not implemented light systems.

| PF: source | What actually exists | I: implication |
|---|---|---|
| `public/infernal-floor.png`, `infernal-wall.png`, `infernal-ceiling.png`; native BMP counterparts | All three images are 1254×1254. Visually, floor is a 3×3 arrangement of dark riveted plates, wall a framed cracked-rock arrangement with orange branching seams, ceiling a grid of riveted plates and recessed orange vents. | They are distinct images, not literally one texture. They nevertheless repeat dark grids, orange seams and dense wear; filenames alone do not provide a gameplay taxonomy. |
| `engine3d.cpp:135–149,415` | Fixed three BMP names; converted to RGBA and uploaded with `GL_RGBA`. Non-sprite surfaces use linear minification, nearest magnification, repeat wrapping, one base level. No material manifest, authored normal/roughness/emission inputs, mip generation or explicit sRGB upload in this path. | Large detailed source art is being minified without a documented pixel contract. Orange painted highlights are visual data, not proven realtime emission. Color behavior depends on the wider renderer/output path; do not claim a measured gamma defect from this call alone. |
| `engine3d.cpp:258–262,295–325` | Quad UVs reset to zero on each face. Standard floor and ceiling span 72×60 world units with repeats 36×30, so one full 1254-pixel tile spans 2 units: 627 source texels/unit. Outer walls span 72 or 60 units with repeats 36 or 30; their 5-unit height repeats 4 times, yielding 1003.2 source texels/unit vertically. Internal wall faces use width repeats equal to world width, and height repeats 4. Pillar faces of width 1.14 and height 4.55 use repeats 1×4. | Horizontal and vertical density are unequal; one material's visible features change proportions between floor, perimeter, divider and pillar. For the floor's 3×3 pictured plate motif, each plate is only about 0.667 world unit wide. These calculations describe source mapping, not the much lower displayed screen pixel density. |
| `engine3d.cpp:318–327`; `combat_world.cpp:68–77` | One containment floor at 0 and ceiling at 5; full-height dividers and 4.55-high pillars; same wall texture on all block faces, including tops. Renderer and collision define related geometry separately. | Cover has no dedicated material/cap/edge grammar; no real navigable height composition is established by these materials. A box top cannot be sold as reachable elevation while movement stays at fixed floor. |
| `engine3d.cpp:330–353`; `calibration_scene.cpp` | Calibration uses box faces, floor patches with brightness values and one ceiling. Floor patches are drawn over the main floor at Y=.002; floor mapping differs from standard room. Lighting is disabled during this draw. | This can isolate some graphic plane/value questions, but it is not a portable sector material/light implementation. Patch and base UV origins must align if seams are to look intentional. |
| `engine3d.cpp:510–511` | Standard mode sets orange-biased diffuse/ambient light. Sprite lighting uses a separate path; effects can disable lighting and use additive blend. | Materials must be reviewed both unlit and under intended light, with actor/effect response separately. Near-black render criticism in the art audit is a captured scene observation, not proof every state has that appearance. |
| `combat_world.h`; `engine3d.cpp` | Trace/collider surface enum supports geometry categories, but does not provide an authored material catalogue. No ordinary mover door, sky render function, surface damage material/decal system or general environment prop catalogue appears in this renderer. Pickup is a procedural bright cache. | Future material semantics need IDs and explicit collision/interaction ownership. A texture is not a working door, damaging floor, breakable object or secret. |
| `linux-game/src/main.c` | Separate 2D raycast toy tiles floor/ceiling on screen through `tile_material` at 192-pixel increments. Native C++ FPS uses 3D UV mapping. | Do not use this toy's floor appearance or key logic as evidence for the C++ game's capability. |

Existing assets have no inspected provenance manifest tying each surface master to production method, source rights, semantic class and export settings. That gap must be closed before bulk asset import. The earlier observatory/coastal and infernal proposals remain proposals; none should silently become the environment backlog.

## Reference findings

**Doom RF:** `r_data.c` composes wall textures from patches, stores floor/ceiling flat references separately and handles sky texture specially. `r_draw.c` samples 64×64 flat coordinates and maps indexed pixels through a lighting colormap. `r_defs.h` distinguishes floor/ceiling height and material and sided upper/middle/lower textures. [id: data](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_data.c), [drawing](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_draw.c), [definitions](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_defs.h).

**I:** The transferable benefit is separate roles for horizontal surfaces, boundaries, step risers and distant sky, plus an intentional lighting/pixel relationship. **P:** Separate catalogue classes and map assignments even if the same base material can appear in several roles. Do not mandate Doom's storage constraints or assert every original wall is 64×64. Doom's wall sizes vary; its flat sampling limitation is a specific implementation fact.

**Wolfenstein RF:** `WL_DRAW.C` has distinct wall/door drawing paths, door texture choices and horizontal/vertical wall handling; its `VGAClearScreen` fills ceiling/floor view areas with colors in this DOS source. [id: Wolf renderer](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_DRAW.C). **I:** Quiet horizontal planes can make walls and doors conspicuous without high detail. **P:** Start Eyesore's floor and ceiling with broad calm values and use threshold silhouette to differentiate ordinary, credential and service openings. A maze or blank floor is not required.

**Code/assets boundary RF:** Doom's release README requires separately owned game data and records GPL 2.0 licensing for this repository. The Wolf repository publishes a limited-use licence and also requires released game data. [Doom README](https://github.com/id-Software/DOOM/blob/master/README.TXT), [Wolf release/license](https://github.com/id-Software/wolf3d). **P:** Study mechanisms and inspect lawfully available reference media; create Eyesore textures, props, symbols and sky artwork independently. A source-code licence is not an asset licence. Do not assume the games' age grants permission to ship original textures or a near-identical asset pack; any actual code reuse requires the engine lead's separate licence review. This report does not resolve copyright term by jurisdiction.

**DUSK RF:** David Szymanski describes building his own assets while studying old walls, floors and UVs, pursuing a coherent low-poly aesthetic; he acknowledges weaknesses in tiling/detail but values the overall identity. [Creator interview, Game Developer](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games). **I:** Coherence and authored geometry can matter more than isolated texture polish. **P:** Review our library only on a moving room capture plus edge/UV checks; each district changes construction, spatial silhouette and wear logic, not only hue. This is an adaptation, not a claim about DUSK's exact texel density.

**Prodeus RF:** Developer-authored listing combines modern rendering and retro visuals, describes particle effects and an integrated editor. [Developer listing](https://store.steampowered.com/app/964800/Prodeus/). **I:** Pixel presentation can coexist with modern tools, but more effects are not evidence of better readability. **P:** Keep material preview, collision overlay and light preview in the same authoring workflow; evaluate gore/decal accumulation against navigation surfaces. Exact Prodeus material formats or shader costs were not verified here.

**Boltgun RF:** Auroch lead designer explains that modern models are rendered into directional sprite flipbooks; technical director describes collaboration with art on normal, AO and emissive channels and artist tooling. [Grant Stewart](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/), [Stefan Richings](https://stefanrichings.com/warhammer-40000-boltgun/). **I:** Sprite/environment consistency is an art-rendering pipeline decision, not a filter applied after unrelated assets arrive. **P:** If Eyesore later uses separate lighting channels, define them for both actors and surfaces, with a matched material preview rig. These sources describe sprite production; they do not establish Boltgun's environment texture resolution or justify importing its symbols/models.

**Dead Space RF:** Motive describes changing light, audio, fog/steam and spawns in authored event combinations to control stress. [EA: Intensity Director](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director). **I:** Environment mood should vary through coordinated state, not permanent texture darkness. **P:** Use subtle wear, a damaged lamp and quiet distant motion in a recovery passage; ensure the same surface's navigability and cover remain legible at every supported combat light state. Eyesore needs no survival pace, 1200-event library or complex director for this test.

## Common semantics before palette

A **material** is physical/graphic construction and response. A **surface role** is map use (floor, riser, boundary, cover cap, door face). A **state** is gameplay authority (locked, open, hazardous, broken). A **theme/palette** is how those are styled. Neither hue nor image filename owns damage, traversal or interaction logic.

| Role | Always communicate | Never accidentally communicate |
|---|---|---|
| Navigable floor | A continuous support plane, route width, contact and real edge/drop | Cracks that imply pits; bright seams that imply damage without hazard state |
| Wall | Solid boundary and useful orientation datum | A black painted rectangle that resembles a passable opening |
| Ceiling | Enclosure/height through underside rhythm | A vent suggesting reachable crawl access when it is decorative |
| Distant backdrop/sky | Beyond-play extent and landmark silhouette | A flat skyline door or false reachable balcony |
| Gameplay elevation | Real tread/riser, reachable landing, collision edge and clearance | Texture stairs drawn on a flat wall/floor |
| Cover | A solid mass with understandable footprint and top/side | Thin billboard clutter that looks like dependable cover |
| Door/control | Consistent frame, moving seam, reachable action, visible state | Decoration that has the same button/switch silhouette as functional controls |
| Damage/decal | Local impact response and authored physical wear | Permanent attack tell, erased lock symbol or hidden step edge |
| Props | Place function, scale, silhouette, defined collision | Tiny snagging objects or visually solid objects that shots pass through without explanation |

Support neutral/civic/night treatments with the same semantic rules. Hazards need a broad boundary and redundant motion/shape cue; not every red paint stripe is hazardous. Exact damage is still gameplay data. A secret repeats a small taught anomaly—misaligned lower rail or a visibly shallow panel seam—and responds consistently to use. Required routes never depend on finding it. No “press every wall” protocol.

## Three comparable surface systems

### Control C: quiet construction graybox

Flat floor mid-gray, wall light-gray, ceiling dark-gray, cover one distinct middle value and a readable cap. One world-scale checker strip on a calibration wall establishes density, not an all-room checkerboard. Door frame is recessed rectangle with broad vertical center seam; locked version has a raised paired-notch escutcheon, key carries the same shape. Switch changes lever/tab pose. Sky/backdrop is one desaturated middle value with a coarse unique skyline. Optional-secret panel is offset at its bottom rail. These choices have enough affordance to function; the control is not deliberately confusing.

### A: assembly and wear

Meaning comes from **how things join and are used**. Wide slab walking surfaces, vertical wall modules, horizontal ceiling beams, thick load-bearing cover masses and door assemblies each have a distinct joint rhythm. Detail concentrates at contact, fastening and threshold wear. Ordinary materials remain matte. The original signature is an asymmetric construction datum: a long recessed joint that steps around openings and reveals their support geometry. It is architecture, not a logo pasted onto every texture.

Quiet manufactured surfaces fit Civic Daylight, but can be lowered into dusk using lighting without changing support/threshold language. Site history can appear through filled repairs, differing aggregate sizes and clean wear channels. No pipes/reactor props are required. Concrete, glazed tile, rubberised flooring and coated sheet are material options, not lore commitments.

### B: layer and cut

Meaning comes from **thickness and subtraction**. Walkable planes are broad uninterrupted sheets, blocked boundaries overlap as solid slabs, genuine recesses have a visible stepped edge, and usable openings cut all the way through. Texture shading uses restrained coarse brush clusters. Cover is read by full opaque side plane plus contrasting cut cap. Door seam is a broad offset split whose two leaves reveal thickness when opening. The original signature is a repeating double-cut edge with one shallow notch; it links wall cross-sections, landing rims and functional frames without repeating luminous cracks.

This supports Painted Eclipse's staged lighting. It does not require unrealistic impossible space or camouflage/puzzle doors. Material wear follows chipped edges, exposed underlayers and dragged brush marks; background stays lower frequency than actors. No stage-prop story or observatory identity is implied.

### Material/palette matrix (P)

Hex values below are **source swatches**, not promised final display values. Review actual output in neutral and intended light. Accent permissions follow function and must be reconciled with enemy/HUD/lighting leads; art's current enemy yellow/coral proposals can conflict with route swatches, so do not ship these without that review. Values and silhouette remain the first cue.

| Role | Control | A: assembly/wear | B: layer/cut | Size/detail rule |
|---|---|---|---|---|
| Floor | `#73777A`, no grain | Warm aggregate `#999C91`; broad paving joint `#656D69` | Muted plum sheet `#67586F`; one darker seam `#443D52` | Floor detail broad and low contrast; no repeating bright cross-lines in dodge region |
| Wall | `#B0B4B6` | Chalk `#B8B6A7`, recessed joint blue-gray `#526774` | Mid indigo `#4D526F`, exposed cut edge `#8D8094` | Main wall field calm behind targets; no fake hole silhouettes |
| Ceiling | `#555B60` | Underbeam slate `#727F85`, pale beam `#A0A7A2` | Deep navy `#2C344D`, underside band `#59627A` | Few large beam/layer intervals; limited tiny vent pattern |
| Sky/distance | `#89939C` | Dust blue `#90ACBA`, chalk horizon `#C6C2B5` | Dusk lavender `#81799A`, charcoal skyline `#38415D` | Coarse original skyline, low motion, orientation landmark independent of compass |
| Elevation | Floor + contrasting riser | Floor tread; wall-colored riser and light nosing | Floor sheet; clearly thicker pale cut rim | True geometric tread/riser; rim continuous around real landing |
| Cover | `#82898D` cap `#C0C4C5` | Broad blue-gray body `#65757B`, worn chalk cap | Opaque indigo body `#404967`, contrasting cut cap `#91899D` | Largest mass, not microtexture, denotes reliable collision |
| Door/usable | gray + white notch | Neutral coated metal `#70858A`; cobalt `#416EB3` on tab only | Plum leaf `#65576E`; acid `#C6C76A` on tab only | Frame, seam and state pose remain distinguishable without accent |
| Hostile/hazard reservation | black/white striped boundary | Vermilion `#B9584B`, never random rust hue as tell | Coral `#CA718D`, never ambient bloom throughout room | Actual hazard boundary/hostile state uses coarse signal; keep away from decorative repeats |
| Damage/decal | charcoal short marks | Chip pale aggregate; dull maroon stain `#794D4C` | Exposed subdued underlayer; coarse dark brush stain | Decal contrast subordinate to tell/route; surface-state glyph protected |
| Props | role-gray | Rubber `#4F5E64`, glazed pale ceramic, restrained original paper notices | Thick folded forms, matte ceramic `#92908A`, coarse layered cuts | 2–3 dominant values; preserve target-size silhouettes behind combat |

The two systems can be rendered with the other's palette for a diagnostic pass. If players can no longer identify the construction grammar after this swap, we have created color themes rather than materially different directions. Do not turn every A opening cobalt or every B edge acid yellow: interactive accents are sparse and state-owned.

## Pixel scale, UVs and shape

**P density experiment:** compare 32 and 64 source texels per world unit for floor/wall/cover after world scale is agreed; neither is a locked base density. Use 640×360 as the common research comparison with lighting, 1280×720 as the current-native diagnostic, and optionally lighting’s 320×180 stress case. The earlier 480×270 suggestion is an additional candidate only if presentation review asks for it; avoid multiplying every resolution across every material/light treatment. Display by an integer scale where available. These are experimental bands, not a commitment to emulate original Doom resolution. A 128×128 tile then spans 2×2 units; a 256×128 trim spans 4×2. Keep world texel density equal on U/V and across adjoining faces unless a named exception is justified. Current body collider height 2.35 and camera anchor 1.42 are distinct; neither automatically means metres. Use agreed actor height H and door clearance to establish a scale anchor before art production.

**A pattern scale:** one 2-unit floor tile has at most one principal paving panel; avoid the current nine small panels per full image. Wall assembly joints can occur at half or whole H, with an intentionally simpler base field. **B pattern scale:** one large surface sheet; cuts occur at real plane edges, never tiled fake cuts across open floor. Coarse brush marks are subordinate to planes. For either, test a tell-sized bright mark behind a foe: if wall detail resembles its windup at the actual displayed size, remove it or move it out of the threat backdrop.

UV origin belongs to map area/boundary, not each draw call. Floor adjoining patches share world U/V and orientation; wall continuation retains trim height; doors have per-leaf UV anchors so opening moves artwork with the leaf. Step risers use wall/riser material while treads use floor, with a deliberate aligned nosing. Avoid stretching one tile to fill an arbitrarily long wall. Reserve a trim sheet for caps/frames, tileable fields for planes, unique panels for functional controls, and unique/backdrop assets for landmarks. No secret clue in a randomly rotated tile.

Do not randomize floor/door symbols or wood/brush grain by free 90° rotation. Only catalogue-approved symmetrical field tiles rotate. Repetition is reduced through authored construction bays, one repair variant and geometry/trim breaks; random staining everywhere destroys wear meaning. Aiming lanes get quieter surfaces. Landmarks use macro silhouette and placement; unique expensive artwork is unnecessary for every wall.

For props, big silhouette comes first: one bench with an open lower gap, one squat storage mass, one tall narrow marker. The storage mass may be real full cover; the bench is optional nonblocking dressing only if shape/placement makes that believable. Avoid pseudo-cover made from dense transparent bars until traces and materials support it. Decorative props stay against boundaries outside intended dodge paths. Enemy corpse/debris remains its own entity/collision policy, not an environment artist's decision.

### Scale must earn its density through projection

**PF:** native `engine3d.cpp:15,510` renders 1280×720 and constructs a 60° **vertical** perspective; horizontal FOV therefore varies with aspect ratio. Enemy definitions have canvas heights 2.05–2.55 world units; the rendered canvas width is `1.5 × world_height`, not the definition’s `world_width` or collision width. Pixels outside the opaque silhouette do not count as readable body/tell detail. Movement currently uses 2.85 units/s with a 2× Shift multiplier. Those facts provide an initial experiment geometry, not a future movement/asset scale contract.

**P projection worksheet:** for an upright, camera-facing canvas at camera-space depth Z, level camera and no clipping, `projected_height ≈ internal_height × canvas_height / (2 × Z × tan(vertical_FOV/2))`. At pitch or off-axis positions, project the actual vertices through the view/projection matrix and measure exported opaque bounds; distance along the floor is not always camera-space Z. For a 2.35-high example canvas at 60° vertical FOV:

| Z in world units | 1280×720 canvas height | 640×360 canvas height | 320×180 canvas height |
|---|---|---|---|
| 4 | ~366 px | ~183 px | ~92 px |
| 8 | ~183 px | ~92 px | ~46 px |
| 16 | ~92 px | ~46 px | ~23 px |

This is computed prediction, **not measured current footage**. A sprite whose opaque mass occupies 65% of its canvas would have much less useful height. Measure each actual pose/tell alpha bounding box and visible unoccluded silhouette, then choose positions to yield lighting’s near 64–128, tactical 32–63 and preview 16–31 **opaque scene-pixel** bands. Do not select a nominal 16-unit range and assume all actors occupy the same band. Do not rescale actors between material/light conditions to rescue readability. Tell timing and projectile speed also determine whether a preview can fairly become an attacking range.

At 640×360, 60° vertical FOV, an approximate 1-world-unit horizontal span at Z=8 is 39 scene pixels. A 64-texel/unit wall therefore minifies ~1.64 source texels into one scene pixel; at Z=16 it is ~3.28. Floor footprints are anisotropic at grazing angles, so this wall arithmetic cannot predict floor aliasing. Measure a marked floor patch’s projected U/V spans or screen-space UV derivatives. A material’s source density, internal render pixels and display upscale are three separate quantities. Lock density only after the same chosen sprite, route width, FOV, floor angles and movement speed produce usable output.

**P floor shimmer inspection:** author a quiet floor field plus a diagnostic patch with known world dimensions and declared minimum feature width. Run a fixed forward path, lateral strafe and yaw sweep with camera height/FOV fixed, at walking and Shift speeds, identical sampling/frame cadence and no flashes or moving actors. Capture uncompressed/lossless internal-resolution frames before upscale; record path positions and simulation time. Inspect a fixed world patch as it traverses screen rows, including near/mid/far and grazing-angle parts. Annotate its projected width/depth and the projected spacing of seams/grain in scene pixels. Features below about two pixels are an alias-risk diagnostic, not an automatic failure threshold. Look for high-frequency features reversing contrast, crawling seams, periodic moiré and bright flicker that resembles a projectile. Review a crop at 1× plus the ordinary display clip; enlarging a still cannot establish motion quality.

Compare the same 32/64 field with nearest/no-mip, nearest/authored-mip and restrained filtered-mip policies. Keep UV scale, path, light C and all asset details fixed in each sampler comparison. A screen-fixed pixel changes legitimately as the camera moves; counting that difference alone is not shimmer. If a temporal metric is later used, reproject a static world patch into consistent coordinates and distinguish disocclusion/lighting from residual sampling variation. No automated metric or capture is implemented here. Choose the lowest detail/sampling combination retaining the intended seam/material character without recurrent distracting crawl, supported by side-by-side motion review.

**P actor/background inspection:** capture body-only, tell-active and composite frames at measured opaque pixel bands in lighting’s V1–V4 views and along both strafe paths. For each visible external silhouette edge, sample the actor-side color and immediately adjoining background outside alpha coverage; exclude geometric occlusion, another actor and transparent canvas margins, and report how many edges were excluded. Convert with the **declared output transfer curve** before discussing linear luminance; absent that contract, label byte-value difference as an approximate diagnostic. Record edge separation distribution and locations of weak contiguous outline segments, tell occupied width/height/area and any floor/door/sky high-contrast mark of comparable projected size. Texture variation behind an actor matters more than whole-frame average brightness.

Use lighting’s provisional .10 linear-luminance difference on half the visible border and 3×3 tell footprint only as review flags. A robust animation/posture cue may work outside them, and passing them does not prove recognition. During maximum firing and actor movement, record lost-outline intervals, missed/late tell identification and visible backdrop changes. Compare C/A/B lighting at fixed sprite art and material; compare material A/B at fixed light C. Do not add adaptive outlines or brighten actors per pixel to improve the score.

Palette selection therefore uses **rendered swatch ladders, actual surface/actor edge samples and player recognition**, including intended light, darkest supported state, grayscale and relevant display conditions. Hex values are source intent only. Record color pipeline/profile/display brightness and preserve them across comparisons; separate a user’s warm display mode diagnostic. Retain shape/pose for lock and hazard states. Select a palette only after it preserves role distinctions and tells in moving scene output, rather than selecting whichever isolated color chart is attractive.

## Light and effects interface

Material color must be reviewed in a **neutral diagnostic light**, **unlit preview**, **intended room light** and **darkest permitted combat state**. No texture bakes an orange point-light hotspot unless the chosen stylized pipeline deliberately uses painted light and the lighting lead owns that exception. A favors diffuse neutral fill and broad contact wear; B can use painted broad plane shading but must not double-shade the same face into black. No realism/PBR requirement for either.

Emission is a separate optional mask and semantic permission. Static decorative windows/vents have a lower prominence budget than attack and interaction cues. A powered switch emits only its status tab; locked/off changes shape and value even when light has no dynamic component. Bloom is optional and cannot be the sole affordance. Fog needs a tested maximum extinction distance relative to engagement range; sky/landmark visibility and sprite outline must survive. Flicker, steam and glare cannot obscure a mandatory tread edge or hostile tell.

Damage/VFX lead consumes impact material class (mineral, coated metal, ceramic, fabric, graphic composite), location and surface normal. Audio lead consumes the same class plus authored acoustic region. A ceramic hit and ceramic footstep can differ by event; surface identity should agree across sight/sound. Visual metal is not proof a bullet penetrates it. Penetration/ricochet remain explicit weapon/gameplay rules. Persistent decals protect usable symbols and edge trims; moving door decals attach in local coordinates or are deliberately omitted. Reset restores material-state and decal policies consistently.

## Original production workflow

1. Director approves a room grammar and chooses the presentation bands; level/lighting/enemy leads sign off surface roles, light states and target distances. Create a concise manifest before generating a library.
2. Draw flat swatches and macro-joint/cut diagrams in editable layered masters. Choose brush/cluster rules and a palette once. Neutralize baked light. A small original hand-painted tile/trim set is the simplest control; authored procedural aggregate or coarse brush masks can make deterministic variants.
3. Optional generated bitmap concept material supplies inspiration or a draft field. It must be rebuilt/edited to role, seamlessness, UV/pixel scale and rights/provenance requirements. A pretty 1254-pixel image is not automatically a tile. Independent generated variants can drift in rivet size, light direction or edge language; use a shared approved master and revision history. No asset generation occurs in this research phase.
4. Optional original 3D prop renders are useful for consistent silhouettes/multi-view billboards. Real cover should use matching simple geometry or an explicit validated volume; a rotating billboard cannot change perceived blocker width unpredictably. Select one method per prop family, not whatever produces the nicest isolated sheet.
5. Tile fields and trims are exported to explicit role resolution, with edge continuity/corner checks, documented color space and sampler policy. Signs/locks keep vector or layered masters and export crisp authored pixels; no baked text on freely rotated field tiles.
6. Compare exported files on the unchanged material room and approved actor sprites under all test lights. Art lead checks cluster/detail consistency, level lead checks traversal implication, audio/VFX leads confirm material events, and director records user playtest feedback.
7. Expand construction variants/district kits only after room passes. Keep a base tile, one repair/wear variant, relevant trim/frame, one functional control and one landmark per required room role. Add a new asset only when it carries a different useful role or construction history. Asset counts are not a quality target.

**Import/compression P:** retain lossless sRGB color PNG masters and linear data masks; explicit alpha rather than black-key transparency for new cutouts. Current runtime BMP export remains a compatibility step if that engine wins, with deterministic conversion from one master and correct pixel row handling. Default prototype runtime can use uncompressed RGBA8; 128² costs 64 KiB base level, versus ~6.0 MiB for 1254² RGBA, before overhead. Full mip chains add roughly a third. Those are storage arithmetic, not measured GPU cost. PNG disk compression does not reduce an RGBA upload's memory. Engine lead chooses supported formats; defer BC/ETC compression until target hardware/quality is evaluated because block artifacts can damage sparse symbols/alpha edges. Do not JPEG source textures.

Compare nearest sampling without mips, nearest with authored palette-aware mip levels, and a restrained filtered mip policy on the slanting floor. Crisp magnification and reduced distant shimmer are different requirements. A global nearest switch can make a noisy floor worse. Mip generation must keep opacity/coverage and functional symbols; distant signs should be geometry/unique-panel cues, not a one-texel glyph expected to survive. Atlas use requires appropriate gutters/mip padding and per-region wrap; repeating fields should not bleed into unrelated controls. No fixed performance budget is justified without the user's GPU and engine choice.

## Pipeline interface (proposal)

A map face references `material_id`, `surface_role`, UV origin/axes/repeat scale and optional `state_binding`. The geometry owner supplies normal, collision channels, real step edge and mover ID. Material data never silently sets collider geometry.

```text
MaterialRecord
  id / version / construction_family / allowed_surface_roles
  color_asset / optional_emission_mask / optional_normal_or_other_data
  color_space_per_input / alpha_mode / sampler_and_mip_policy
  world_tile_dimensions / trim_region / rotation_permissions
  value_detail_class / protected_cue_regions / effect_priority
  impact_class / footstep_class / acoustic_hint
  source_master / author_or_method / licence_or_rights_record / export_recipe
  optional_state_variants: inactive, active, locked, damaged
```

This is an interface sketch, not a proposed compiled schema. `acoustic_hint` is a default only; authored area acoustics and geometry own occlusion/reverb. Interaction controller owns state and exposes state to a visual binding; no inference from RGB. Render/collision/audio/navigation share one geometry source per engine proposal. Authoring errors should identify map face/entity and invalid material reference. Missing texture gets a conspicuous diagnostic fallback in developer preview and fails release validation, rather than silently becoming white/untextured. Unsupported role/state or unlicensed/untracked imported master blocks production import, not playtesting of flat graybox.

## One test room and fair comparison

Use one **Material Court** derived from level control C's teach module: safe entry, one offset solid cover island, equal-width left/right paths, far stationary threat anchor against a wall, ordinary usable door toward a recovery vestibule, adjacent locked specimen outside the required route, one optional-secret panel, and a view toward an original skyline through a clearly impassable window. One broad stair/landing specimen occupies a side spur only in an elevation-capable engine. Until then label it non-playable preview geometry and exclude elevation results; do not make false claims from a rendered stair.

Same geometry, collider, FOV, render resolution, actor sprites, weapon/event timings, item positions, UI assistance and light recipe for C/A/B. Exactly one variable per sub-pass: texture grammar under neutral light; intended light with the same materials; later palette swap; finally decal/impact clutter. Final direction review can evaluate each art system's preferred light separately, clearly labelled a whole-scene comparison. Avoid changing light and material in the same diagnostic A/B and attributing all results to texture.

| Authored specimen | Question |
|---|---|
| Entry floor leads around cover to both exits | Does surface rhythm preserve both legal routes, or falsely funnel players? |
| Cover front, cap and rear viewed while strafing | Can players predict the blocker footprint and line-of-fire protection? |
| Door open/closed/locked and decorative wall panel nearby | Can players find actual use, understand denial and distinguish decoration without hue/text alone? |
| Real landing edge and nonreachable window sill | Does art correctly distinguish walkable height from scenery? |
| Far actor plus repeated wall/sky behind it | Are silhouette, role and windup readable at gameplay distances? |
| Several fired impacts plus decal accumulation | Do traces/material feedback agree, and do route/lock cues persist? |
| Short recovery vestibule with repaired wall/quiet prop | Can environmental history be read without stopping for exposition or inspecting every wall? |

### Explicit material × lighting comparison

Use **M-A** for assembly/wear and **M-B** for layer/cut; use **L-C/L-A/L-B** for lighting’s control/broad/graphic treatments so the repeated letters are unambiguous. The six cells use one geometry, actor, sampler, UV scale, resolution, camera presets and world-state sequence. Material control M-C is a baseline outside this 2×3, and remains available if both artistic grammars underperform.

| Material grammar | L-C: uniform neutral area fill | L-A: broad architectural fields | L-B: graphic structural plateaus |
|---|---|---|---|
| **M-A assembly/wear** | Isolate assembly joints, wear and threshold function. Quiet plane/joint structure must stand on its own. | Check whether graded opening fields reveal construction/support or wash out pale joints and opaque actor edges. | Check whether crisp plateaus clarify depth while preserving assembly continuity; do not recolor M-A into Eclipse. |
| **M-B layer/cut** | Isolate real thickness/cut/recess cues; prove it works without staging that hides ambiguity. | Check whether broad fields preserve cut caps and recess depth or soften the graphic grammar into indistinct sheets. | Check whether authored plateaus strengthen layering across all views or only flatter one chosen camera. |

**Fixed recipe for the isolated texture pass:** use lighting’s **L-C uniform neutral area fill** for M-C/M-A/M-B: temporary consistent unlit multipliers floor .75, wall .80, ceiling .65, actor .85; no distance darkening, camera-relative orange lamp, colored fields, dynamic flash, bloom, fog or decorative emission; one middle-gray distant background. Cover top/side orientation assignments are written once and reused. These are RGB multiplier hypotheses, not claimed final luminance. Establish the recipe on neutral material once and lock it for all three texture treatments; do **not** rematch mean luminance per material, because a material’s own value hierarchy is part of the tested grammar. If first calibration makes C unusable, revise once and rerun all conditions. Initial tell recognition uses an identical pale nonemissive tell; a separate later tell/emission pass uses identical bounded emission across cells.

**Light isolation precedes the six cells:** first run L-C/L-A/L-B with neutral M-C as specified by lighting: approximately match mean neutral-surface luminance in V2, lock fields for V1/V3/V4 and keep actor fill identical. Lock those exact field recipes for the six M-A/M-B cells without per-palette or per-view brightness rescue. L-A retains its world-fixed broad graded field and multiple transition samples; L-B its world-fixed maximum three large plateaus; L-C no same-face patch. Keep actor fill .85 initially, so lighting’s later continuous versus shade-ramp actor response is a separate follow-up. Report any exposure/material-dependent clipping; it is a compatibility result, not something to silently normalize away.

Use lighting’s calibration shell and V1–V4 as the shared core measurement scene. Material Court’s door/lock/elevation specimens are a later extension on identical appended geometry for every cell, after the engine implements those functions. This avoids two different rooms claiming one controlled comparison. V1–V4 source positions/look-at points are copied from the lighting report; any occluded view is corrected once for all cells. Add both-direction cover strafe only after checking the four static views.

Run texture-only M-C/M-A/M-B under L-C, then neutral light isolation, then six crossed conditions at the one common 640×360 experiment resolution; selected worst-view conditions subsequently receive the resolution/sampler stress checks. Counterbalance six-cell order across short sessions and log fatigue/familiarity; do not show 36 nearly identical clips and interpret fatigue as material preference. Repeatability and diagnostics come before a larger player trial. Different preferred lights/palettes can be reviewed later as complete scene directions, with that changed-variable scope explicitly labelled.

Select from navigation/tell failures, floor shimmer, place recognition, player preference and actual authoring effort separately. If M-B works only under L-B from V2, reject or revise its all-view readability. If M-A/L-A is preferred but loses tactical silhouettes, revise construction backdrop/light fields before a beauty recommendation. If neither grammar improves on M-C in a useful way, keep quiet materials and invest in geometry/actor/audio identity. These are future comparison plans; no six-cell images or playtest results exist yet.

### Proposed acceptance checks, not executed

- **Geometry agreement:** visible full cover stops specified player/enemy shots and actor passage; edge/collider footprint overlays agree; open door is actually open. Any disagreement fails before judging art.
- **First-use comprehension:** in a small formative trial of 3–5 unfamiliar players, record initial guesses for floor, cover, ordinary door, locked door and scenery; investigate every repeated wrong guess. Small samples diagnose; they do not establish statistical quality. Record time-to-correct-use and requests for help rather than inventing a pass percentage.
- **Threat read:** at intended near/mid/far engagement distances and in movement, participants identify role and windup. Compare errors and useful-hit timing with C. If material direction materially worsens these, simplify backdrop before adding outline glow. Match gameplay and report variance, not a synthetic aggregate score.
- **Noncolor state:** grayscale and color-vision diagnostic captures preserve door/key matching through notch/shape/pose, hazard boundaries and step edges. Simulations complement real user feedback and are not guarantees of accessibility.
- **Tiling/scale:** 3×3 repeat, adjacent faces, every tile corner, trim junction, opening leaf and patch intersection have no accidental seam, stretched motif, density jump or floating wear. Test moving camera at grazing floor angle and through FOV bands for shimmer.
- **Light:** unlit and intended state maintain support/threshold semantics; darkest supported combat still exposes flank routes and actor mass. No important state depends on a lamp being on. Actor and environment appearance need not be physically identical but must be intentionally related.
- **Clutter:** after a representative fight's maximum approved decals/debris/effects, lock/exit indicators and landing rims remain readable. Frame capture includes peak muzzle/effect overlap; still screenshots alone are insufficient.
- **Production:** one changed wall length updates UVs/trim/collision from authored source, material preview matches runtime export, stable IDs resolve, repeated import is deterministic and metadata complete. Report actual time to revise one room rather than promising “20× content.”

## Edge cases and priorities

A dramatic sky must not be target-bright everywhere; reserve a calm combat backdrop even under a lit skyline. A silhouette balcony with enemies needs actual supporting geometry, collision and aiming; scenery cannot borrow gameplay elevation language. Bright floor stripes should not resemble projectiles or require following a path during combat. Floor reflections/wetness are deferred until they do not imply a slippery movement rule or mirror duplicate enemies. Tiny nicks and grime should not be taught as secret cues. Color/state binding on a multi-effect switch follows committed world state per interaction report, not button press alone.

A door partly open reveals true leaf depth/collider; decals and local UVs follow it. Glass is either visibly solid with appropriate hit response or genuinely shoot-through with explicit rules; start with opaque materials. Mipmapped lock symbols need a fallback frame/shape at distance; alpha-tested fences can change visual coverage with distance and should not be essential cover in the first test. Mirrored UVs cannot reverse writing, lock shape or directional wear. Cover caps visible from elevation must not expose an untextured underside. Fog cannot erase a required return landmark. Restart restores powered/damaged/locked visual variants alongside controller state; world atmosphere does not retain accidental one-shot changes.

## Self-critique and decision gates

A risks clean generic civic architecture, too much orderly alignment and sterile surfaces. Wear must show different physical use, and macro geometry must carry local identity. B risks becoming flat poster scenery, false recesses and repetition of the rejected near-black look. It needs visible thickness, reachable edge clarity and medium-valued threat backdrops; painted light cannot excuse unreadable geometry. Both are systems, not complete worlds. Story can select place function, but should not force a special material puzzle into every room.

The research has strong evidence for the current asset/filter/UV mismatch and for separating surface categories. It has limited direct evidence for modern games' exact environment pipelines; no texture dimensions or proprietary rendering recipes are guessed. We have not heard material impacts in this task, inspected every scene/light state, or observed a player navigating these proposals. The strongest next decision is a small comparative room, not a declaration that A or B will be better.

Director/lighting cross-review must resolve accent conflicts, dark-state value hierarchy and the sampler/pixel budget. Level/engine review must establish true elevation and single-source geometry. Enemy art review must reserve backdrop quietness for actual sprite shapes. Audio/VFX review must agree material class events. After those dependencies, the user should see moving C/A/B samples and play the same room before any campaign-sized material expansion.
