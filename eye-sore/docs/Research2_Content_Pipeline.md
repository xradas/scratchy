# Research round 2 — role 18: content authoring and iteration

3 October 2026 · GPT-6.1 Sol / medium · Research proposal only. No importer, map, asset, build or test was made or run. Source inspection and primary documentation research support this report. Roles 00–16 were read for their decisions and handoffs; role 17 was still drafting at initial writing. Every proposed schema and gate below remains unimplemented.

## Recommendation and evidence boundaries

Make one room reproducibly editable before producing a campaign. The first pipeline should let us change a cover box, an actor tell, or a dry gun take, inspect the exact change, restart the same encounter, and deliver that exact version for the user to play. The current separation of hard-coded geometry, render definitions, generated sheets and audio calls prevents that reliable loop.

**PF** means directly inspected project fact; **RF** means linked primary/developer evidence; **I** means inference; **P** means Eyesore proposal. Research prose cannot approve the sound, art, level or engine. A technical validator can establish structural correctness; the user must still hear and play the result.

**P:** use a small engine-neutral content contract for M0, with a native adapter or Godot resources after the engine comparison. Use text authoring first because the assistant writes content and the user plays it. A visual editor becomes worthwhile when geometry review or repeated placement demonstrably costs more than maintaining an adapter. The hybrid external-authoring route is a later option, not a prerequisite for the room.

## Current pipeline audit

| PF: inspected file | Behavior | I: consequence |
|---|---|---|
| [Makefile](../linux-game/Makefile) | Separate C toy and C++ FPS targets; named generation/verification scripts; native source dependencies listed explicitly. `package` depends on `build/eye-sore`, copies that C executable and top-level `assets/*.bmp` only. | Existing package recipe does not deliver the native FPS or its nested enemy/weapon/projectile assets, sounds/music. A local launch can work while the delivered package is incomplete. No package was built in this pass. |
| [combat_world.h](../linux-game/src/combat_world.h), [combat_world.cpp](../linux-game/src/combat_world.cpp), [engine3d.cpp](../linux-game/src/engine3d.cpp) | Shared room/solid boxes feed collision and finite traces. Standard drawing independently reconstructs architecture; calibration renders `active_world.solids` but still owns floor patches separately. Surface enum is `none/room/wall/pillar`. | Useful query seam already exists, but no stable face/material/boundary IDs or canonical connected map. Current geometry categories cannot supply material contact or acoustic semantics. |
| [calibration_scene.h](../linux-game/src/calibration_scene.h), [calibration_scene.cpp](../linux-game/src/calibration_scene.cpp) | C++ constants define room, player camera anchor, pickup, caster, boxes and brightness rectangles. One player-start vector uses Y=1.42 as camera height. | Preserve observed geometry as an experiment reference; do not call this a body-height or new M0 production contract. Editing data still recompiles code. Area names lack a cross-role registry. |
| `engine3d.cpp` enemy/weapon arrays and main loop | Numeric type/frame arrays, named-file construction, fixed spawn/wave/cache rules; standard/calibration weapon paths differ. Runtime calls mixer directly; no universal event IDs or level manifest. | Same presentation cannot yet guarantee same mechanics. Content should name actor archetypes, instances and experiment profiles separately. Audio/fire/contact aliases need one event authority. |
| `texture_from_bmp` | Loads BMP, fallback relative to executable; optional near-black RGB key removes pixels whose channels are all below 12. Returns 0 on failed texture. | Opaque dark body pixels can disappear. A frame-count check does not prove in-game alpha fidelity. Required actor assets should fail level load explicitly. |
| [build_enemy_directional_frames.sh](../linux-game/tools/build_enemy_directional_frames.sh), [build_enemy_combat_frames.sh](../linux-game/tools/build_enemy_combat_frames.sh) | Grid crop, selected checkerboard guessing/morphology, trimming/extent, special cell repairs; PNG derivative exported to black-background BMP with alpha removed. Directional builder applies different crop/scale branches. | Existing generated-sheet cleanup is specific repair work, not a dependable production recipe. Retain source scale/pivot/grid metadata, true alpha and explicit exceptions rather than silently carving out neutral body pixels. |
| [verify_weapon_assets.sh](../linux-game/tools/verify_weapon_assets.sh), enemy/projectile verification scripts | Useful dimensions/counts, some alpha checks, reconstruction/equality checks and selected support-baseline checks. Enemy combat PNG alpha is checked; runtime key reconstruction is not compared to approved alpha. | Keep useful checks but manifest declarations must replace fixed global counts. Alpha-channel presence alone does not prove correct coverage, pivot or silhouette. |
| [build_weapon_sounds.sh](../linux-game/tools/build_weapon_sounds.sh), [build_shotgun_auditions.py](../linux-game/tools/build_shotgun_auditions.py) | Shell synthesis/filter/trim recipe; separate Python audition includes hashes, source windows, measurement and randomized processing support. Shell noise generators have no explicit seed in inspected arguments. Python audition ROOT is `parents[1]`, which resolves to `linux-game` from its present path, while its described sources/output use `public`. | The audition approach contains useful provenance ideas, but path assumptions and generation reproducibility need a future correction before reuse. Do not assume rerunning tools reproduces committed derivatives. This pass did not execute either builder. |
| [verify_audio_assets.sh](../linux-game/tools/verify_audio_assets.sh), native `self_test` | Codec/rate/channel/file/duration checks; explicit legacy mono 44.1 kHz policy. Native self-test contains selected asset and gameplay assertions. | Format success does not approve source identity, onset, clipping, warning coverage, stereo fold, loops or subjective quality. Exact legacy duration can conflict with current generator output. |
| `engine3d.cpp` CLI/record/reset | Flags depend on `argv[1]`; calibration and record therefore cannot combine by ordinary flag composition. FFmpeg receives video only. Reset manually clears state. | Future CLI must compose map/profile/seed/capture options and declare unavailable capture; current video is not evidence of audible quality. Generation/reset semantics need one shared owner. |
| [package.json](../package.json), `components/arena.tsx`, [main.c](../linux-game/src/main.c) and README files | Browser React project, C raycast toy and native C++ FPS coexist with different mechanics/builds. | Designate native FPS as present research target. Preserve legacy variants explicitly; do not let `npm build` or the toy package count as FPS delivery. |

These are source observations, not fresh runtime failures. Working-tree prototypes and previously rejected auditions remain unapproved.

## Reference authoring research

**Doom RF:** WAD loading reads a directory of named lumps and supports multiple resource files; lookup scans backwards so later resources can override earlier ones. Names are limited to the historical eight-character representation. This is a resource-container mechanism, not a full editor. [id `w_wad.c`](https://raw.githubusercontent.com/id-Software/DOOM/master/linuxdoom-1.10/w_wad.c). **I/P:** Eyesore benefits from explicit resource identity and a complete dependency inventory. Prefer duplicate-ID errors and explicit experiment overrides to hidden filename precedence.

**Doom RF:** map setup reads vertices, lines/sides, sectors, segs/subsectors/nodes, blockmap, reject data and things; the disk structures distinguish authored geometry/placement from runtime lookup structures. [id `p_setup.c`](https://raw.githubusercontent.com/id-Software/DOOM/master/linuxdoom-1.10/p_setup.c), [disk definitions](https://raw.githubusercontent.com/id-Software/DOOM/master/linuxdoom-1.10/doomdata.h). **I/P:** keep a readable authored source and reproducible compiled spatial indices. Do not hand-edit generated collision/visibility data or mandate BSP for a tiny box room.

**Wolfenstein RF:** cache code loads map headers/planes and compressed asset data; actor interpretation and door behavior belong to other runtime modules. [id `ID_CA.C`](https://raw.githubusercontent.com/id-Software/wolf3d/master/WOLFSRC/ID_CA.C). This released runtime is not a verified release of the original production map editor. **I/P:** compact map-plus-placement data is useful; Eyesore requires richer explicit material/height/event semantics than a tile code alone. No original Wolf editor binary/toolchain was verified here.

**DUSK RF:** its developer-pinned SDK FAQ documents packaged source assets/uploader and fully supported Quake 1, Half-Life and BSP2 formats, with partial support for other variants. The post identifies itself as an incomplete SDK at that publication date. [Developer FAQ](https://steamcommunity.com/app/519860/discussions/7/4031348273660875579/). Its historical New Blood wiki was unavailable during this pass. **I/P:** established external authoring can work behind a narrow format adapter; that does not make arbitrary BSP import cheap or authorize distributing those game assets.

**Prodeus RF:** developer listing confirms an integrated level editor and community map browser. [Developer listing](https://store.steampowered.com/app/964800/Prodeus/). Exact serialization, build process and internal validators were not publicly verified. **I/P:** fast preview and delivery form one useful workflow, but we should measure our edit-to-play cycle before financing an integrated editor or community service.

**Boltgun RF:** Auroch lead designer describes rigged models rendered from eight directions, flipbook import, enemy data exposing damage/sound/projectile animation moments, and authored encounter graphs/spawn points/zones. [Grant Stewart's developer account](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/). The article's broad historical statement about Doom maquettes is not adopted here. **I/P:** keep animation source, frame geometry and event markers linked; author bounded encounter dependencies. Exact proprietary node serialization/import internals remain unknown.

**Dead Space RF:** Motive explains the Intensity Director coordinating atmosphere/events and tension peaks/valleys, and emphasizes iteration. [EA/Motive](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director). This does not document its complete event schema or production tooling. **I/P:** preview a bounded authored beat with light/audio/actors together and log its causes; postpone a general director. Eyesore's warning fairness is governed by roles 04/12–16, not the reference's deliberate uncertainty.

**Tool RF:** TrenchBroom supports game configurations and external DEF/ENT/FGD entity definitions; custom engine support still needs a matching game contract/import path. [Official manual](https://trenchbroom.github.io/manual/latest/). Godot provides editable resources/scenes, source import configuration and export filtering. Commit `.import` metadata while regenerating `.godot` caches; semantic gameplay IDs still need our own identity policy. [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html), [import](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html), [export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html), [UID changes](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/).

**Rights RF/P:** Doom's release explicitly requires separately owned game data; source availability does not license its sprites, maps or samples for Eyesore. [id release README](https://github.com/id-Software/DOOM/blob/master/README.TXT). Select the exact engine distribution/license before code reuse; record that decision with role 01. Age alone supplies no pipeline approval. Use original or suitably licensed assets with copied license evidence, attribution/distribution requirements and performer permissions. This report makes no copyright-term determination.

## Three feasible paths

| Path / P | Small first deliverable | Benefit for this team | Main costs and rejection condition |
|---|---|---|---|
| Native C++ data-driven room | Strict JSON room/manifest parsed into current `World`, render surfaces and definitions; small validation command and runtime debug overlays. | Assistant can author reviewed diffs; smallest migration from current native experiment. No editor prerequisite. | Native alpha/events/geometry/capture still need engineering. Reject if each useful geometry edit requires new rendering/collision code or repeated manual tool repairs. |
| Godot-native scenes/resources | One `.tscn` room with reusable actor/cover nodes, typed `.tres` content definitions and external semantic-ID registry; export preset and report. | Existing transform preview, resource inspector/import, audio/channel options and scene composition; user need not edit manually. | Migration and style controls; node path or resource UID is not a save/entity ID. Accidental per-instance shared-resource mutation and editor-generated diff noise need discipline. Reject if one-room parity/control is unreliable or import defaults continually change the intended pixel/audio result. |
| Hybrid external geometry authoring | Narrow TrenchBroom brush/entity subset to canonical room data; original material names; separate semantic entity manifest; compiled indices generated once. Blender may separately produce rig-to-sprite exports. | Spatial editing/inspection scales better than long coordinate lists; artist rigs offer consistent angles. | Adapter, units/axis/UV conversion, unsupported brushes/movers and round-trip ownership. Reject if render meshes and collider boxes require two separately edited sources or exporter silently discards unsupported semantics. |

**P recommendation:** compare native and Godot on the same M0 contract as role 01 requested. Use source-content hashes and explicit residual differences, not a promise of bit-identical renderer/AI output across engines. Add hybrid mapping only after repeated C-map editing demonstrates a real authoring bottleneck. Do not create three full production pipelines. GZDoom is a separate engine/license option owned by role 01; this report does not silently rule it out or impose native tooling on it.

## Minimal content contract and authority

**P:** canonical content is the editable semantic source; render meshes, colliders, trace structures, route graph and acoustic portal indices are derived views. A collider may intentionally differ for gameplay, but its exception must be authored against the same boundary ID and visible in the debug view. Light areas and acoustic areas may share spatial references but are not forced to coincide: a small light patch is not a new chamber.

One world snapshot provides geometry revision plus dynamic mover state to renderer/collision/trace/AI/acoustic queries. Derived caches carry that revision; stale caches cannot answer queries silently. The engine owns query algorithms, not each agent. Closed door, partial aperture, actor clearance and projectile clearance may have different declared thresholds, but all derive from one physical door state.

| Source document / P | Minimum fields and ownership |
|---|---|
| Experiment profile | ID, question, M0/C identity, control/treatment, seed, engine/build requirements, initial loadout, movement/aim/difficulty, presentation/capture settings and permitted overrides. Coordinator owns variable control. |
| Map | Schema/content versions, ID, units/axes, start feet + camera offset + facing, area/boundary/solid/surface IDs, transforms/height/support, surface material IDs, allowed routes, instance placements and exit region. Level/engine own semantics. |
| Material | ID, role class (`floor/wall/ceiling/riser/cover/sky/prop`), source texture, logical texel density/UV scale/origin, alpha/color-space/filter policy, light response, contact/footstep/acoustic class and provenance reference. Art defines appearance; physics flags are explicit. |
| Actor/weapon | Archetype ID, body/target/support dimensions, clips, frame canvas/pivot/trim offsets/direction convention/mirror permissions, event markers, gameplay definition revision and attached emitter origins. Instance IDs are separate. |
| Audio/cue | ID, semantic event bindings, variant files, hashes, original source/rights records, chosen regions/onsets, channels/rate/sample format, gain reference, loop sample bounds, tail policy, concurrency/priority/attachment and semantic cue ID. Caption manifest joins the semantic event independently of bank availability. Mixer owns audio dispatch rules. |
| Interactions | Stable target and trigger IDs, activation/conditions, initial/reset state, allowed transitions, feedback event IDs, persistence scope, obstruction/failure behavior. Start with core ordinary pickup/exit; ordinary door follows in its own fixture. |
| Encounter | ID, activation/commit regions, finite actor roster/entrances/zones, required versus optional actors, bounded beat dependencies/actions, resource placements, recovery/exit rules and reset boundary. Role 05 owns meaning. |
| UI content/config | Caption templates keyed by semantic cue/role/state; locale string/icon/font resources; layout/default comfort policies with equivalent event information. Role 17 owns presentation. |
| User preferences | Versioned values for bindings/scale/contrast/caption/audio/comfort overrides, validated by settings service and persisted outside run/checkpoint state. A level reset does not reset preferences. |
| Build inventory | Engine/toolchain versions, source commit + dirty patch hash, content/source/tool hashes, import policy, target platform, included dependency list/license list, capture/session references and validation status. Pipeline/release own delivery. |

Do not split every table into a separate service. M0 can have one room JSON and one content manifest with small referenced clip/audio records. Use ordinary strict JSON with schema validation for native source, one record per semantic item and canonical formatting. Godot-native resources can remain authoritative under that path; do not maintain a second hand-edited JSON shadow of the same scene. Export a normalized inspection record only for comparisons/validators.

**P ID rules:** semantic IDs are immutable strings such as `m0.cover.center`, `actor.hold`, `cue.weapon.precision.release`; human labels and filenames may change. Do not derive IDs from array position, coordinates, sheet cell, node path or basename. A renamed label retains ID; a different entity gets a new ID. Stable instance identity combines level identity and instance ID; runtime recycling uses an entity generation. Transient events use level generation + tick + sequence + attack/action ID. Texture/audio aliases resolve once and cannot dispatch duplicate gameplay events. Duplicate definitions fail; experiment overlays explicitly name their allowed field overrides and resulting content hash.

## Smallest graybox delivery, then expansion

**P M0 packet:** one neutral flat room with entry divider and one cover island, two usable local lanes, one Hold projectile actor and one Cross pursuer (role 04's agreed semantics), precision and close-spread weapons, abundant reachable ammunition, visible end threshold and full retry. No random reinforcements, economy comparison, key chain, story exposition or compulsory kill gate. Freeze timing/HP/loadout/geometry for each one-variable trial. The calibration room is a source reference, not automatically this fixture.

Packet includes room/definitions/manifest, a plan view with dimensions/body-clearance overlays, neutral material swatch and runtime import diagnostics, original placeholder provenance, complete tell/release/contact/interrupt/death event coverage, selected dry SFX, a documented launch profile and session inventory. A fixture can use a declared silent decorative cue; it cannot silently omit mandatory attack information. Confirm mechanics before art/light/audio packages.

**P M0 sequence:** validate structural contract → inspect imports/runtime alpha and geometry overlays → restart identical initial state → single Hold tell/release/contact → Cross commitment/recovery → interruption/death ordering → both actors together → pause/mute/reset → capture with actual sound when supported. Validators and inspection are implementation tasks proposed for later, not performed in this research.

**P C expansion:** use role 06's shared S–T–P–M–X spine and optional O, first at floor 0. Both weapons start owned for initial comparisons per role 05 revision. Allow departure with surviving enemies unless a separately justified gate is authored. Initial O is an ordinary detour, not a claim of a secret. Test resource rules on fixed C before topology A/B. Add one ordinary door, then a separate credential/switch/secret fixture; elevation is another staged geometry capability. Do not load every specialist's most ambitious alternative into the initial slice.

## Import, provenance and reproducibility

**P:** keep original sources/rigs/recordings/license evidence immutable; edited masters and export recipes separate; runtime derivatives replaceable. Every derivative names source hashes, tool/version, options, seed where relevant, manual repair file and expected output properties. Image generation can be an original concept source but is not a guarantee of coherent directions, anatomical continuity, true alpha or reusable pivots. Record generation/source metadata when available and retain the selected master; do not replace an existing source implicitly on regeneration.

Sprites require integer source rectangles, explicit logical canvas, fixed body scale/support/pivot and trim offsets. Packed output may trim stored pixels while placement restores original coordinates. Direction/state coverage follows the declared role, not an unconditional eight-direction requirement for every effect. True RGBA alpha, blend convention, extruded safe atlas edges, logical resolution and nearest/filter settings are explicit. Neutral opaque black samples must survive runtime import; a gray checkerboard painted into a master is rejected for manual source repair. UV density derives from world units with intentional per-face rotation/origin; sky is distant visual data and not traversable floor.

Audio retains dry recorded masters, source-region and onset markers, processing chain/DAW export settings and license evidence. Current runtime exports may be mono 44.1 kHz S16; future stereo score/bed path is separate and chosen with role 16. Loop bounds are sample indices with end exclusive; loop period and full-file tail are distinct. Measured gain/onset/peak/mono-fold flags accompany listening approval, never replace it. A rejected file remains rejected even if checksum and codec pass. Unseeded generation is labelled nonreproducible unless an approved master output is retained and hashed.

**P atomic import:** read sources into a staging bundle → validate all required dependencies and schema → derive/cache → verify output hashes/properties → create complete inventory → publish one bundle manifest by atomic replacement on the same filesystem. Failed staging never overwrites the active content set. Old bundle remains available for rollback; clean orphan derivatives only after a separate successful inventory. Manifest dependencies forbid path escape, unexpected absolute paths and case-collision names that break platform portability. Limits cover counts, coordinates, dimensions and decoded memory; malformed files are rejected before partial runtime state exists.

Runtime hot reload is initially restricted to a paused/restarted experiment. Loaded voices hold immutable clips until finished; replacing a bank does not free active audio memory. Geometry/gameplay reload restarts the room under a new generation and invalidates queries/events. Cosmetic-only reload later needs an explicit compatibility category. Shader/texture/audio changes do not mutate simulation state as a side effect.

**P versioning:** distinguish schema version, content revision and engine capability version. Unknown major schema fails with a useful migration message; unknown semantic fields fail unless inside a declared extension namespace. Do not reinterpret old enums. Explicit migration preserves IDs and outputs a reviewable diff; backup original. During research, restarting an incompatible checkpoint is acceptable only with an upfront incompatibility message and preserved save, never silent inventory loss. Production saves later include content/build identity and state-version checks; save migration is not part of M0.

**P build:** pin compiler/library/import-tool versions and retain exact commands, seeds and environment-sensitive options. Separate content reproducibility (same normalized semantic data/hashes), asset reproducibility (same bytes where promised), and binary reproducibility (toolchain/platform dependent). Do not claim all three from one checksum. Packages derive from manifest dependency closure, include the native executable/launch path and required resources/licenses, and are inspected/launched from an isolated directory with an unrelated working directory. Avoid shipping rejected audition/raw sources merely because a glob found them. Future release owner decides platform library bundling and signed release policy.

## Validators, invariants and error model

**P:** fatal authoring errors prevent bundle promotion; warnings require disposition; aesthetic notes remain review findings. Informative errors include severity/code, source path + JSON pointer or node path, semantic ID, offending value, related ID, expected rule and repair suggestion. Example: `E_ROUTE_CREDENTIAL: map C /interactions/door_east: requires credential.service; all reachable credential placements lie beyond this door; move an item or author an alternate route.` Plan view highlights both referenced objects. No generic “bad map,” swallowed parse error or invisible actor fallback for required content.

| Invariant / P | Static check | Runtime/review complement |
|---|---|---|
| Schema/identity | Duplicate IDs, unresolved references, invalid enums, finite/ordered bounds, unit/axis declarations, supported versions and explicit capability requirements. | Log loaded bundle/profile and any declared fallback; missing required resource fails entry. |
| Geometry/support | Positive volumes, valid area boundaries, intended adjacency, spawn/target footprints clear of solids, valid support/ceiling clearance, doorway/route width for declared actors. Overlapping solids can be intentional; overlapping conflicting surfaces need explicit priority. | Collider/render/trace/AI/acoustic overlays against same boundary revision; ray/sphere and actor clearance shown distinctly. |
| Route and softlock | State-aware progression graph: credentials/switch prerequisites, required exits, optional secrets excluded from core path; cycles without enabling entry, unreachable mandatory actors and irreversible closed routes flagged. | Walk both branch orders, failed/repeated use, blocked door, skip optional fight/secret, death/retry. Graph proof is limited to the authored abstraction, not proof of physical AI navigation or every player action. |
| Encounter/resources | Finite acyclic beat dependency or explicitly bounded repetition; valid entrances, required/optional actors, permitted skip/clear policy, pickup amounts/loadouts/profiles and no-secret resource baseline. | No spawn on player/invalid support; required actor path and wake state; leave with survivors where permitted; missing optional kill does not block exit. |
| Sprite/material | Integer grid/rectangles, positive durations, canvas/trim/pivot bounds, direction coverage/mirroring, true alpha, atlas padding, logical density/UV class and source hashes. | Runtime decoded alpha compared to approved coverage, pivot/foot markers in motion, dark body opaque, far silhouette and side/rear tell readability, sampling and surface seams. |
| Actor/action events | Declared tell/commit/release/recovery/contact/terminal/cancel events fit action intervals; producer/alias bindings unique; referenced cues/labels exist. | Cross multiple markers in a slow tick once; release before immediate contact; interrupt/death suppress pending release; detached effects do not enlarge damage collider. |
| Audio/mix | Decodable approved format/channels, source/license completeness, onset bounds, loop ranges/aligned stems, hashes, semantic cue coverage, gain/peak limits and explicit silent decorative entries. | Real device/capture logs, warning overlap, onset preservation, no duplication, voices/cancellation/pause phase, mono-fold and repeated-loop listening. Format valid is not “meaty.” |
| Reset/state | Initial/reset/persistence declared per interaction and encounter, no orphan targets, checkpoint schema/version dependencies. | Full retry clears projectiles/cues/pending music requests and increments generation; pickups/actors restore once; pause freezes gameplay transport while mute continues; settings remain user-owned. |
| Delivery | Exact dependency closure, executable target, case/path integrity, licenses, build/content/source hashes and required import metadata. | Launch outside source tree; no source-folder fallback; sound and frame capture explicitly identified as present/absent. |

State-aware graph exploration can become combinatorial. **P:** M0 has no combinatorial puzzle; C has bounded declared states. Set an exploration cap and report `validation incomplete` with unvisited conditions, never a false pass. Exact combat survival cannot be proven by a route graph; conservative resource budgeting and play remain role 05/quality tasks. Dynamic navigation needs runtime fixtures. Pathfinding convenience cannot overwrite canonical geometry.

## Preview and iteration loop

**P initial tools:** a text report, one generated plan view, runtime overlays for boundary IDs/clearance/rays/actor pivots/events and a fixed-camera V1–V4 profile. Audio audition uses selected dry cue, gain/onset metadata, actual device mix capture and anonymous control/treatment label. No giant node editor, universal inspector or web service is required. Shared logs contain build/content/profile/seed, input/tick/action/attack/event IDs, release/contact/material/outcome, state changes, audio queue/drop/cancel, actor/area IDs and generation. Capture settings include internal/display resolution, FOV/light/material variants, output device/backend/buffer and clock mapping. Event log time is distinct from video frame time and audio output sample time.

For each revision: state the player-visible problem/question → change one approved domain variable → validate/import into new bundle → inspect and play/capture same profile → record user decision and evidence → keep/revise/reject with reason. Whole visual/audio package preference is labelled a package comparison; it cannot isolate palette or EQ causality. Give the user a launchable packet, short known-limit note, controls/retry instruction and exact changes. The user should not troubleshoot command-line dependencies or edit code to try our result.

**P metrics:** record edit-to-valid-bundle time, bundle-to-play time, failed-import repair time, unchanged assets rebuilt, manual steps, missing-resource count, first-launch success and restart consistency. Also record minutes of actual audition/play versus tooling work. First collect baseline from three meaningful revisions; then set targets with role 19/20. A provisional aim is no source-code rebuild for ordinary placement/cue swaps and one documented launch per approved profile. Fast iteration is useful only when the resulting change is distinguishable and the user prefers it; agent output volume is not progress.

## Scope limits, handoff and self-critique

M0 excludes campaign save migration, multiplayer, procedural director, online workshop, arbitrary script graph, universal editor, arbitrary BSP support, terrain/room-over-room systems, automatic art cleanup and massive asset generation. C adds only the requirements a shared route actually demonstrates. New systems enter as a named fixture with dependency cost and a rollback plan. No discarded world/theme becomes canon through filenames.

Roles 01/02 own engine/query/movement dimensions; 04 owns Hold/Cross events; 05/06 own M0/C and branch/resource semantics; 07 owns interaction state/obstruction; 08/09 own body/light/material export agreement; 10–12 own animation/feedback truth; 13–16 own source/cue/mix/clock policy; 17 owns UI/config/captions; 19/20 own quality/performance/release checks; 21 owns selected story binding after domain review. Pipeline owns schema/identity/import/inventory, not game taste. A schema dispute is resolved by a tiny source/runtime example before adding another abstraction.

Self-critique: this proposal can itself overgrow into paperwork. The first accepted implementation should have one room file, one manifest, a small validator and a reviewable packet; the larger tables state invariants for staged growth, not a demand to build every validator now. Text coordinates remain awkward for spatial judgment; the plan view and overlays must reveal that cost honestly. Godot offers tools but does not automatically satisfy style/events/identity. External editing saves placement effort but makes importer ownership permanent. Content hashes establish identity, not quality, deterministic physics or provenance truth. Our primary evidence for DUSK/Prodeus/Dead Space establishes features and developer intentions, not their complete internal tool architectures.

Outstanding decision: choose engine from matched M0 practicality, then implement just enough pipeline to make that room repeatedly reviewable. A campaign-sized content backlog before a good room would repeat the present failure of scale outrunning quality.

## Cross-review with role 17: interface ownership

Read the completed [interface report](Research2_Interface.md), including its coordinator ownership revision, and directly discussed the split with its agent. Adopt one versioned simulation event schema from role 16; action/actor/world manifests reference semantic cues, while a caption manifest maps cue + known role/state to localization string ID, direction/eligibility category, priority and presentation lifetime. Locale catalogs and shaping/bidi/font-fallback resources own wording. Gameplay input actions own bindings; dynamic glyphs/text refer to action IDs. UI presentation defaults and user preference overrides are separate documents; user settings persist outside checkpoint/run state.

Authored map geometry and physical door/secret state remain separate from per-player observed area/boundary/lock/secret knowledge. The HUD snapshot references a knowledge version; map style changes cannot reveal new content. Remote unseen unlock does not silently update a remembered lock as current fact. Guide assists have explicit reveal policy and cannot fabricate exploration history. Knowledge is restored/reset with the declared run/checkpoint policy, not a UI-local cache. Caption eligibility derives from gameplay perception/acoustic policy before user volume, so mute does not remove eligible threat text and unheard hidden state does not leak. Caption dwell/fade never delays release/cancel or prolongs false preparation; these consume the same tick/action IDs. Validation must check string/cue/action/area references, font fallback and supported layout bounds while leaving timing truth in simulation.

Role 17 identified two ambiguities in the first table: audio-owned caption label fields and combined UI content/preferences. Both are corrected above. Missing/disabled audio bank cannot suppress an eligible caption; it remains a separately diagnosed audio dependency failure.

## Coordinator revision: minimum M0 bundle example

**P, illustrative one-page inventory; none of these proposed files/assets exists by virtue of this example.** Values marked pending block the corresponding review rather than borrowing rejected prototype content.

```text
m0-bundle/inventory.json
  bundle=m0.neutral.r1; schema=1; engine/build/hash=pending
  profile=m0.mechanics.control; seed=17; map=m0.room
  files=[map.json, content.json, captions.json, en.json, ui.json,
         original-placeholder-frames, approved-dry-WAVs, licences]
  structural_status=pending; source_listening_status=pending

map.json
  id=m0.room; units=world-unit; axes=Y-up/Z-south
  area=m0.court; boundary=m0.divider; solid=m0.cover.center
  start={feet, camera_offset, yaw}; materials=[mat.neutral.wall,
    mat.neutral.floor, mat.neutral.cover]
  actors=[{id:m0.hold.1, archetype:actor.hold},
          {id:m0.cross.1, archetype:actor.cross}]
  encounter=m0.fight; roster=finite; exit=m0.exit; kill_gate=false

content.json
  actions=[weapon.precision, weapon.close_spread]; clips/colliders=pending
  event_schema=role16.shared.v1
  semantic_bindings:
    ShotEmitted + weapon.precision -> bank.weapon.precision.release
    ShotEmitted + weapon.close_spread -> bank.weapon.spread.release
    ContactResolved + mat.neutral.cover -> bank.contact.cover
    enemy.tell_begin + actor.hold -> bank.actor.hold.tell
    enemy.tell_begin + actor.cross -> bank.actor.cross.tell
    InterruptCommitted / DeathCommitted -> terminal/cancel policy
  banks={owner13:weapon/contact, owner14:actor/world}; source hashes=pending
  ambience={source:ambience.m0.room, owner14, enabled:false}
  score={cue:score.m0.control, owner15, enabled:false}
  No furnace loop aliased to score. Disabled background is intentional.

captions.json + en.json + ui.json
  enemy.tell_begin + known actor.hold -> string.threat.hold.preparing
  enemy.tell_begin + known actor.cross -> string.threat.cross.preparing
  eligibility=perception_before_user_gain; cancel=shared attack ID
  locale catalog owns text; UI owns position/scale/defaults
  user overrides remain external to this bundle and run save
```

Use role 16's actual shared packet fields, not a second UI/audio event: `level_generation, simulation_tick, event_id, attack_id, source_entity_generation, target_or_surface_id, contact_index, position, incoming_direction, surface_normal_if_known, material_id, outcome, state_before/after, optional_cancelled_attack_id, seed`, with timestamp/tick-period mapping and optional audio attachment hints. Example: generation 3/tick 120/event 80/attack 7 emits `ShotEmitted`; event 81 resolves immediate `ContactResolved` against `m0.cover.center`/`mat.neutral.cover`. Consumers select weapon/contact banks; flash/flipbook/caption do not emit new releases. Hold tell gets a separate genuine pre-release transition referencing its attack; a later interrupt cancels that attack through the shared packet. No file rename changes event identity. `fire_commit/release` and historical `weapon.fire.accepted` are documentation aliases only; migration normalizes them without dispatching extra events.

Minimum dry M0 may intentionally have no score/ambience. Their IDs/ownership are reserved here to prevent background duplication; enabling either later adds a declared source, transport policy and review gate. Role 13 weapon/contact sources and role 14 actor tells must exist for audio review. Caption template independence allows a muted accessibility run; missing tell WAV remains an explicit failed audio review, not a valid replacement by captions.

This compact JSON slice is syntactically valid and its shown references resolve within the slice; omitted geometry/assets/rights are required in the complete bundle. It demonstrates the proposed identity contract, not a loadable map or a claim that a JSON Schema/parser/validator already exists. The displayed cue is an actor preparation transition; the action's real release is a later shared event, not emitted by its caption or bank.

```json
{
  "schema_version": 1,
  "map": {"id": "m0.room", "area_ids": ["m0.court"], "actor_ids": ["m0.hold.1"]},
  "actors": [{"id": "m0.hold.1", "area_id": "m0.court", "action_ids": ["action.hold.shot"]}],
  "actions": [{"id": "action.hold.shot", "tell_cue_id": "cue.hold.prepare"}],
  "semantic_cues": [{"id": "cue.hold.prepare", "event_kind": "enemy.tell_begin", "action_id": "action.hold.shot"}],
  "audio_bindings": [{"cue_id": "cue.hold.prepare", "bank_id": "bank.hold.prepare"}],
  "audio_banks": [{"id": "bank.hold.prepare", "owner_role": 14, "source_review": "pending"}],
  "caption_templates": [{"cue_id": "cue.hold.prepare", "string_id": "text.hold.prepare", "eligibility": "perception_before_user_gain", "ui_config_id": "ui.m0"}],
  "locale": {"id": "locale.en", "strings": {"text.hold.prepare": "Ranged enemy preparing"}},
  "ui_config": {"id": "ui.m0", "locale_id": "locale.en", "user_preferences_scope": "external"},
  "ambience": {"id": "ambience.m0.room", "owner_role": 14, "enabled": false},
  "score": {"id": "score.m0.control", "owner_role": 15, "enabled": false}
}
```

Future complete-schema acceptance requires bank source/derivative hashes, license evidence, format and useful-onset frame; action tell/commit/release durations and cancellation; actor geometry/clip support; and map clearance/exit/resource data. Pending bank review passes neither source-listening nor audio-quality gates. Cue joins remain independent of that bank: its disabled/missing playback cannot remove eligible preparation text.

## Coordinator revision: staged validation and honest audio delivery

Cross-read role 16's source/capture inventory, queue/device failure and live/offline capture policy. Adopt distinct inventory fields: **structurally valid**, **imported successfully**, **runtime delivery checked**, **source audibly reviewed**, **in-game mix reviewed**, and **user accepted**. Each records reviewer/date/device/profile/asset hashes and evidence, or pending/rejected/invalid. None implies the next. Legacy corrected-but-rejected auditions cannot be promoted because of successful import. An actual missing bank/device or overflow blocks audio-quality review; required cue disappearance cannot silently pass.

**Day-one validator scope:** schema/unique IDs/reference resolution, canonical box geometry/support, declared clip/event/alpha properties, required audio decodability/provenance, and exact package dependency closure. Add the one-room runtime fixtures for release/contact/cancel/retry and actual sound capture next. Graph puzzle exploration, checkpoints, multilevel navigation, adaptive score/stems and broader validators activate only when those features enter C or later. This is a staged gate list, not an instruction to build every table row first.

**Present package must fail the proposed closure gate:** a native profile requires the native FPS executable plus every recursively referenced frame, WAV, material and license file at its declared relative path. Existing `package` ships the C toy and top-level BMPs; it fails both executable identity and missing native nested dependencies. Report `E_PACKAGE_TARGET` and per-resource `E_PACKAGE_DEPENDENCY`, and block native bundle promotion. A structurally valid source manifest does not validate that tarball. Future package acceptance launches the delivered files without repository fallback.

**Capture failures:** missing audio stream, wrong output-monitor route, overflow/dropped capture frames, required dropped cues or unrecorded clock/settings makes an audio/timing review invalid. The current video-only MP4 is explicitly insufficient. Role 16's offline digital mix checks scheduled processing/event placement; live postmaster/output-monitor recording checks the named software route; physical speaker/display latency requires separate measurement with uncertainty. Do not label offline audio a live device capture. Keep validation failures and hearing rejection separately recorded so source, mixer, delivery and creative choices can be revised for the right reason.
