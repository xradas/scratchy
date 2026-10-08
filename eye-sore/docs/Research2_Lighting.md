# Eyesore round 2: lighting, visibility and rendering

**Role 08 · GPT-6.1 Sol / medium · 3 October 2026.** Research and proposed experiments only. No renderer, asset, map, build or gameplay changes. No new playtest was run. The native FPS is the working target; engine and art direction remain undecided.

## Decision summary

The current game has two different illumination pipelines, so a readable calibration frame does not demonstrate that the ordinary game is readable. Ordinary architecture receives orange fixed-function lighting, ordinary enemy sprites bypass it, and calibration architecture uses grayscale surface modulation instead. Unify the meaning of material, area brightness, actor response and transient effects before adding more lights.

Compare **C, neutral area fill**, against **A, broad architectural light**, and **B, graphic plane staging** in the same room with identical actors and gameplay. A expresses depth and navigation through large lit surfaces and gentle changes around openings. B expresses depth through deliberately separated value planes and hard light boundaries. Neither needs a dark observatory, global orange ambient, heavy fog, or a flashlight to make basic combat usable. Test the lower-cost area-based versions first. Dynamic shadows and automatic exposure do not earn inclusion merely because a modern reference has them.

The first decision is whether either challenger improves place recognition and mood while preserving the control's threat recognition. The following values and thresholds are **test hypotheses**, not measurements of the references or proven accessibility standards.

## Evidence conventions and boundaries

**PF:** project fact read from source or an existing report; report-only observations are identified. **RF:** reference fact supported by primary source code or a developer statement. **I:** inference. **P:** proposed Eyesore behavior. Numbers marked P are adjustable experiment settings. Source dates are reference publication dates, not claims that their technical implementation is current.

Inspected: `engine3d.cpp`, `calibration_scene.cpp/.h`, calibration contracts, engine, movement, art, enemy and level round 2 reports. This report does not diagnose the desktop's WhatsApp/Firefox color issue: the renderer evidence is internal to Eyesore. Display processing is a separate viewing condition to record, never a substitute for correcting image hierarchy.

## Direct renderer audit

| PF: location | Confirmed behavior | Consequence / I |
|---|---|---|
| `engine3d.cpp:15,409–417,510` | OpenGL 2.1 immediate-mode scene, 1280×720 constants; smooth vertex shading; 60° vertical perspective; no explicit lower-resolution scene target. | The existing game is not rendering to a Doom-sized pixel buffer. Asset resolution and actual projected pixels must be measured separately. |
| `engine3d.cpp:510` | The point light position `(0,3.3,0,1)` is submitted with identity modelview **before** pitch/yaw/camera translation. | It is fixed in eye coordinates, hence follows the camera in the world. It is not an authored ceiling lamp at world origin. Rotating/moving changes which surfaces receive it. |
| `engine3d.cpp:511` | Diffuse `(1,.28,.08)` normally; shooting changes green/blue to `.75/.35`; global ambient `(.09,.025,.02)`. | Color values are altered by strong red/orange illumination. A broad gun effect changes illumination hue; it does not represent an occluded local muzzle light. |
| `engine3d.cpp:258–261,318–328` | Ordinary floor/ceiling/walls receive both face tint via color material and the enabled fixed-function light, with surface normals. | The scalar called `light` is also a material modulation factor, not the final pixel brightness. A floor tint of 1 cannot guarantee a bright floor. |
| `engine3d.cpp:330–353` | Calibration disables `GL_LIGHTING`/`GL_LIGHT0` while drawing surfaces. Floors read .42/.68/.88/.75 scene rectangles; walls use fixed face tints .68–.86 and ceiling .55. | These are unlit RGB multipliers. Wall brightness does not derive from the floor's region. The room is a useful contrast experiment but not a complete consistent area-light implementation. |
| `engine3d.cpp:223–225` | Ordinary enemy sprite multiplier is 1; calibration samples X/Z rectangles and clamps multiplier to at least .55; entire sprite is modulated uniformly; `GL_LIGHTING` disabled. | Ordinary enemies are effectively unlit/fullbright as texture samples, though dark painted bodies remain dark. Calibration sprites stay brighter than the .42 west floor. Neither pipeline separates emissive pixels from body material. |
| `engine3d.cpp:223` | Inclusive rectangle bounds and successive assignment; no blend at borders; outside all rectangles defaults to 1. | A boundary can choose the later region; outside coverage brightens unexpectedly. Need explicit ownership/coverage/transition rules before campaign maps. |
| `engine3d.cpp:137–148` | Some sprite imports remove pixels with RGB all below 12; nearest sprite minification/magnification; opaque surface minification linear, magnification nearest; no mip levels generated here. | A dark opaque silhouette can become transparent during import. Light cannot restore missing pixels. Texture shimmer/blur is also a sampling/pixel-budget issue. |
| `engine3d.cpp:174–178,231–255` | Projectile effect sprites use additive blending and bypass light; viewmodel drawn unlit; some first-person launches/flashes disable depth testing. | Bright effects are not local world lights. Oversized additive effects may hide threats; an overlay may ignore occlusion intentionally. Document which rendering layer each effect belongs to. |
| Whole `engine3d.cpp` audit | No shader program, shadow map, fog configuration, tone mapper, automatic exposure, gamma/color-space conversion, or configured distance attenuation found. | Do not budget for capabilities absent here. No distance attenuation is configured, distinct from the directional change of a point light across vertex normals. The color pipeline needs an explicit future decision. |

**PF from art report:** its sampled old playtest frame is near-black with dark enemy masses merging into repeated infernal walls, and bright emblems/fire drawing most of the attention. This report did not remeasure that video or replay the build. **I:** the combination of very dark material paint, red-biased lighting, competing bright motifs, and uneven world/actor treatment explains plausible value collapse. A screenshot alone cannot apportion each cause. Diagnose with neutral materials, unlit asset views, and light-only views rather than turn every gain upward.

**PF:** native world is currently one flat enclosure subdivided by boxes; area/portal authoring, vertical traversal, moving-sector geometry and occluded light propagation remain engine proposals. The level role's cross-court design is the lower-risk challenger; rim-and-basin relies on new vertical capabilities. Lighting experiments must not silently implement those missing systems.

## Reference research and limits

**Doom RF:** sectors supply light levels; rendering builds scale/distance light tables; sprite projection selects diminished lighting or fullbright state, with fixed-colormap overrides. Walls include direction-dependent light-level adjustments. Gun brightness is represented by `extralight`; sector specials implement explicit light changes. This is authored palette-map lighting rather than real shadow-casting lamps. **I:** model room brightness and state deliberately; use fullbright for a communication purpose; depth cues do not require dynamic shadows. Eyesore need not inherit exact distance tables or palette. [r_main.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_main.c), [r_things.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_things.c), [r_segs.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/r_segs.c), [p_lights.c](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_lights.c).

**Wolfenstein 3D RF:** `WL_DRAW.C` uses separate horizontal and vertical wall picture tables and dedicated wall/door rendering branches. It offers evidence for intentional face distinctions, not evidence for Doom's sector-light model. **I:** a compact vocabulary of orientation, doorway and actor cues can carry navigation with very little lighting machinery. Do not attribute modern colored light or automatic exposure to the original engine. [id source: WL_DRAW.C](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_DRAW.C).

**DUSK RF:** Szymanski's developer interview discusses tailoring environments and the care involved in creating a seemingly retro game; New Blood describes three distinct episodes and fast combat. Neither inspected source provides photometric light values, a shader specification or a target-recognition benchmark. **I:** varied location composition and controlled contrast deserve more attention than a universal darkness filter. Study a bright approach, an indoor fight and a horror interval separately before inventing an engine explanation. [Szymanski interview](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games), [New Blood DUSK](https://newblood.games/dusk).

**Prodeus RF:** the developer/publisher description explicitly combines modern rendering technology with retro aesthetics and gameplay and a handcrafted campaign/editor. This establishes a hybrid presentation goal; it does not disclose the exact light budget, shader or exposure curve. **I:** choose an authored pixel/effect grammar, and measure how light and particles affect target tracking. Modern rendering is an available means, not a requirement that Eyesore reproduce its entire effects stack. [Official Prodeus listing](https://store.steampowered.com/app/964800/Prodeus/).

**Boltgun RF:** lead designer Grant Stewart describes 3D enemies rendered from eight directions into flipbook sprites, animation data marking damage/sound/fireball moments, and encounter zones/spawn points in a modern runtime. He does not specify sprite normal maps or dynamic-light response in that article. **I:** sprites need consistent baked art lighting and explicit combat markers, independently of world illumination; author encounter positions so tells remain visible. Do not claim Boltgun proves a particular light shader. [Auroch lead designer on Boltgun](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/).

**Dead Space RF:** Motive's Intensity Director article describes authored atmospheric variations and intensity peaks/breathers using environmental and encounter components; the GDC lighting talk is framed around light and darkness for its horror setting. The public talk landing page is an abstract, not an inspected complete technical lecture. **I:** take bounded event coordination and quiet intervals; preserve fast-combat visibility when using those techniques. Near-black spaces and surprise are tools with a tracking cost, not default quality. [EA Intensity Director](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director), [Goudreault GDC talk](https://gdcvault.com/play/1029020/-Dead-Space-Harnessing-the).

## Shared rendering contract before style

### Material and illumination are different data

**P:** a material declares category (floor/wall/ceiling/sky/door/prop/actor/effect), base color, alpha/cutout, sampling, texture density, and optional emissive mask. A room/area declares illumination, face modulation, transition rules and protected combat envelope. An effect declares its layer and temporary contribution. The existing function argument called `light` must not be the sole owner of all three meanings.

For a future color-managed shader path, conceptual composition is `body = base_linear × area_light × face_factor × distance_factor`, followed by bounded transient contributions; emissive is added from a separate mask. Convert/display once using an explicit transfer curve. This is an architectural proposal, not an equation valid for today's fixed-function sRGB-like byte multiplication. A temporary native experiment may use documented unlit scalar tints consistently, but must label them as such and not pretend they are physically meaningful intensities.

Author sprite base shading with one neutral, broad lighting setup per family. Preserve all eight views' value hierarchy and the foot baseline. Avoid a painted orange rim that implies a lamp which does not exist. Declare whether a bright weapon/tell pixel is self-luminous or merely pale paint. Do not use black RGB as the transparency contract in future exports; explicit alpha permits opaque near-black forms.

Environment coordination: the current orange cracked texture visually implies heat, yet the audited wall draw has no crack-specific emissive mask or hazard metadata. Classify it explicitly as decorative pigmentation, actual emissive material, or traversable hazard with separate gameplay semantics; never assume an orange pixel deals damage or casts light. Every new material is reviewed unlit and under neutral diagnostic illumination before style lighting. Emissive coverage/intensity is bounded per material family so repeated seams cannot overpower a hostile tell. Route, cover, door frame and open/closed shape cues must retain stable value and form at the **darkest supported combat state**, including a story outage; a nominal bright-state image is insufficient.

Sky is an unlit distant background with its own middle-value band, not a dynamic ambient estimator. Floor/wall brightness must remain independently adjustable so pits, steps and doorway planes do not disappear when the palette changes. A bright floor is not sufficient if a dark actor lies against a same-value wall.

### Threat pixels, contrast and fullbright

**P:** define three projected bands: near 64–128 px tall, tactical 32–63 px, preview 16–31 px **at internal scene resolution**. These are initial review bands. Use actual projected opaque actor height, not a 384×256 source canvas or 720p upscale height. Smaller previews may communicate presence/direction; they must not demand precise identification of a two-pixel tell. Encounter range and tell geometry need to agree with the minimum tactical band.

At each band judge outline, facing, role and tell with route/cover behind the actor. A high average brightness does not prove edge separation. In screenshots, examine local border values and the tell's occupied area; in motion, judge recognition and tracking. A candidate diagnostic is an absolute linear luminance difference of .10 on at least half the visible external border at tactical range, plus a tell spanning at least 3×3 scene pixels. This is a flag for review, **not a universal pass rule**: dark-on-light, light-on-dark, animated posture and negative space can all succeed differently. Never repair the metric by adding a through-wall outline.

Neutral baseline actors receive stable area fill; pale parts and broad dark masses do the work. Fullbright is limited to authored attack apertures, projectiles, active interaction marks and required feedback. Whole actor fullbright is an optional accessibility/diagnostic treatment to compare, not a production default. Emissive masks do not grant visibility through geometry. Behind cover, tell audio may communicate warning but visual information stays occluded according to combat rules.

Flicker, steam, decorative shadows and local light failure never remove the protected minimum on an active lethal tell. No automatically brightening camera to compensate for bad lighting in the first trial. Start with fixed exposure/brightness; offer calibration and a stable minimum-visibility option. Dark adaptation is primarily the player's real perceptual/display condition. A proposed narrative dimming uses a gradual transition with a persistent route landmark and combat fill; it does not require the player to wait to regain sight.

## Three systems to compare

### C — neutral area fill control

**P:** uniform neutral illumination per area, no distance darkening, transient world light off, sky/background middle gray. Floor/wall/ceiling and face modulation provide quiet spatial differentiation. Actors share a stable documented response with emissive tells. Start with surface multipliers .75/.80/.65 and actor .85 in the temporary unlit native path, then adjust from rendered pixels. These are RGB multiplier hypotheses, not final luminance.

**Purpose:** expose silhouette/material failures and establish readable ordinary gameplay. C should be usable enough to ship as a low-effects preset if challengers provide little benefit. It is not a beauty frame. No style succeeds merely by outperforming a deliberately broken dark control.

### A — broad architectural light

**P:** world-positioned large light fields model openings, overhangs and transitions; broad neutral fill remains everywhere combat occurs. Build the first version from authored polygons/surface partitions and actor area samples, not moving point lights. Sun/opening patches establish near/far planes and a route landmark; small warm/cool practical pools mark local function without recoloring every texture. Gentle transition widths prevent a sprite popping when crossing a region edge.

Actor response uses foot/torso area samples or a declared scalar blend, independent of billboard normal and viewing yaw. Decorative shadow shapes are fixed surface paint/geometry values until a real shadow system exists. No fake moving occluder shadow: a door changes the authored light-state variant, or no shadow is represented. Protected actor fill persists under overhangs; reflected light is a designed value, not a claim of simulated GI.

**Range proposal:** initially no light falloff inside the valid encounter range. Compare a bounded distant atmospheric approach only later: distance factor 1 through tactical range, gently declining to .8 in previews, never making an attacking actor less visible than its background. Apply depth treatment consistently to surface/actor body; keep emissive readable without becoming an opaque glowing dot. A single scalar per giant quad cannot produce useful distance gradients: split/bake geometry or defer to shader path.

**Identity:** spaces read through architecture and large illumination shapes; a player recognizes an opening and remembers its relationship to a court. Excellent fit for Civic Daylight. With Painted Eclipse use wider mid-value pools and restrained hue, retaining graphic materials; it becomes softer and may weaken its sharp theatrical identity.

**Risk:** generic sunny concrete, flattened mood, vertex gradients or light seams, excessive surface subdivision, actors floating in stable fill. Counter with a designed sky/aperture, three depth bands, foot contact cue, and comparison of matched grayscale frames. A requires an authorable light-field layer, not high-end dynamic render tech.

### B — graphic plane staging

**P:** author front/middle/back plane values and crisp illumination boundaries. A middle-value backdrop frames pale/dark actor masses; dark cavities sit outside the active aim/route plane. Use offset doorway frames, upper wall bands and flat patterned pools to construct distinct views. This is intentional graphic staging, not a conventional dark room rescued by neon edges.

Actors use two or three controlled body value bands plus one tell color; area light selects a small authored shade ramp rather than a continuously changing RGB tint. Smooth only the crossing of area assignments enough to avoid a one-frame brightness jump; the surfaces retain crisp boundaries. Emissive shapes are angular and limited in footprint. No bloom in first trial; muzzle/impact sprites have a small hot core plus a restrained solid edge rather than a fog cloud.

**Range proposal:** depth uses backdrop values and texture detail bands, not near-black distance falloff. Distant walls may lighten toward sky; a threatened plane is restaged by geometry/background if necessary. Do not adjust an enemy's brightness based on the pixel behind it in real time: that can shimmer, disclose camouflage, and be hard to debug. Use authored backdrops and verify other approaches.

**Identity:** room views resemble stacked painted planes with fast changes of silhouette as the player circles. Natural fit for Painted Eclipse; with Civic Daylight, retain its light palette and use crisp overhang/corner shadows as graphic shapes. Do not secretly substitute Eclipse's near-black palette just to make B obvious.

**Risk:** looks clear from the art director's chosen camera but collapses from side/back paths; outline-like bright masks flatten actors; surfaces look like unrelated cutouts. Validate every reachable combat view and elevation. The cross-court's multiple approaches are specifically valuable here. B may cost more authoring time than A even with cheaper rendering.

| Comparison axis | C | A | B |
|---|---|---|---|
| Visual grammar | Calm neutral surfaces | Broad pools, openings, soft area transitions | Crisp boundaries, deliberately staged planes |
| Depth owner | Geometry/face difference | Architectural fields plus geometry | Backdrop/plane value design plus geometry |
| Transients | Minimal overlay only | Small bounded local accents later | Sharp limited graphic accents |
| First runtime requirement | Consistent unlit area sampling | Surface partitions + area blend | Surface partitions + shade variants |
| Worst failure | Flat/no place identity | Washout and floaty actors | Camera-specific readability |
| Primary selection evidence | Usable basic fight | Better place recognition without tracking cost | Better silhouette/room identity from all paths |

### Falsifiable distinction in the same views

**P, revision after coordinator critique:** C/A/B are initially **three authored image treatments using one renderer contract**, not three existing light engines. A new name is justified only by a visible difference in the matched images and a useful gameplay or place-recognition consequence. Sharing unlit drawing does not invalidate the comparison, but changing only a global multiplier does.

Use the calibration shell/cover with one identical neutral gray material, fixed neutral actor at `(0,0,-2)`, stable exposure/FOV, no emissive, no flashes, and exactly the same geometry. Define camera presets by position plus a look-at point, avoiding an ambiguous yaw convention: **V1** `(-6,1.42,8)` looking through the east opening `(4.5,1.42,5)`; **V2** `(6,1.42,3)` toward `(0,1.42,-2)`; **V3** `(-5,1.42,-5)` toward `(0,1.42,-2)`; **V4** `(5,1.42,-7)` toward `(0,1.42,-2)`. Check authored collision/visibility before capturing: any blocked view is adjusted once and identically for all conditions. No condition moves the camera, actor, opening, or cover to rescue its composition.

Match mean visible neutral-surface luminance approximately across C/A/B in V2, then lock all values for V1/V3/V4. Record the residual difference; do not rematch per camera or perform local image exposure. Actor fill stays identical in this **first** surface-only comparison. This prevents brighter actors or a brighter global image explaining the result. The following spatial marks belong to light treatment, not different base textures.

| Treatment | Concrete authoring distinction | What V1/V2 must show | What V3/V4 must show | Evidence that falsifies the distinction |
|---|---|---|---|---|
| **C** | Each face has one scalar by orientation; no interior patch or same-face brightness variation. Identical-oriented shell faces share values. | Clear geometry, but an uninterrupted floor/wall has no brightness landmark pointing toward the east opening. | Same face values remain unchanged; depth comes from geometry and face orientation alone. | A same-face band/patch appears, or camera movement changes its value. That means C is contaminated by a style/light treatment or camera-relative light. |
| **A** | A world-fixed broad strip leads inward from the east gap: wide middle bright region plus **at least four monotonic transition strips on each side**, spanning several actor widths overall. A matching broad wall field occupies the northern part of the east wall; darkening under the divider is broad and gradual. Adjacent transition values differ modestly; no narrow neon border. | The same broad field connects opening, floor and side wall. A long same-surface sampling line contains a graded progression, not one value or a two-value step. | The same field is seen from behind/side in the same world position, including its graded edges. It is not recentered on the player/actor. | It is indistinguishable from C after mean matching; strips alias into a single hard edge at the chosen resolution; field moves with camera; or its only difference is global brightness. |
| **B** | At most three intentional value plateaus per visible structural composition: darker entry/divider plane, middle floor/cover plane, brighter far wall/doorway backdrop. Boundaries coincide with selected structural edges or one **hard** authored surface boundary; no graded strips or opening-shaped pool. Same orientation may differ by structural plane role. | Distinct foreground/middle/background plateaus frame the actor/route, with abrupt edges. The plateau design is visible in a grayscale thumbnail without glow. | The plane assignments remain world-fixed and the alternative approaches retain at least two separated large planes; actor cannot disappear when the far-wall backdrop no longer lies behind it. | It reduces to orientation tints like C; its hard fields look like A's broad pool at final pixels; it requires moving the actor/camera or changing base art; or alternative views lose threat/route separation. |

The four-or-more strips are a provisional **image diagnostic**, not a production subdivision requirement. Their purpose is to prove that A's soft broad edge survives the selected pixel grid. They can be replaced by interpolated vertex colors, baked values or a shader later, provided the same image distinction survives. Sample a fixed world-space line across the floor field and a second across the east wall: C should be constant apart from geometric/texture boundaries, A should have multiple intermediate values over a broad interval, B should have a few plateaus with abrupt transitions. Annotate the samples on an image for review; do not require an automated screenshot test or claim these images already exist.

Follow with the same room using candidate art and emissive tells. A separate actor-crossing clip may compare continuous A response and bounded B shade assignments only **after** surface distinctions pass. Keeping initial actor light identical deliberately avoids testing five variables simultaneously. Place recognition and threat recognition remain separate outcomes: discernible images can still be equally useful or equally bad.

**Merge rule:** if A and B fail their graded-field versus structural-plateau distinction in V1–V4 at actual internal resolution, merge **A+B** into one “authored area and surface lighting” candidate and choose the simpler coverage/transition implementation. Keep C as the uniform control. If A differs from C only by mean brightness, collapse **A into C**; if B differs from C only by orientation tint or different material art, collapse **B into C**. If both collapse, run one shared visibility system and discuss art treatments as art, rather than maintain a fictitious lighting choice. If image distinctions pass but neither improves recognition, mood preference or authoring efficiency over C, retain C and defer the extra treatment.

### Renderer-path matrix: existing code versus proposed simulation

**PF:** only the first two rows describe implemented behavior. All C/A/B experiments and later paths below require future authorized work; this report did not create them.

| Path | Actually implemented today? | Where image brightness comes from | What is simulated/authored rather than solved | Capability absent or still needed |
|---|---|---|---|---|
| Ordinary native mode | **Yes** | Camera-relative fixed-function orange light × normals/material face tint; actor/viewmodel unlit | Painted texture brightness and manually tinted faces; muzzle diffuse hue change is broad stylization | No shared area light, emissive masks, world-fixed authored pools, shadows or configured distance attenuation |
| Calibration native mode | **Yes** | Unlit surface scalar tints; floor rectangles; actor rectangle sample with .55 floor | Flat “brightness regions” drawn as floor values, with independently tinted walls | No soft edge interpolation, per-material masks, shared surface/actor area ownership, or validation of coverage |
| C on current GL 2.1 | **Proposed**; calibration supplies partial primitives | One documented unlit scalar per face/area; constant actor fill | Ambient/fill represented by value, without a lamp solve | Must unify paths and region coverage; no shader or shadows needed |
| A on current GL 2.1 | **Proposed** | Unlit surface partitions with multiple graded strips; optional future per-vertex colors; actor continuous area blend in second trial | Broad opening light and soft shadow represented by authored values. No ray-based occlusion, bounce, penumbra or physical sun | Existing `quad` takes one scalar, so graded strips need new partition data/draw calls; vertex interpolation would need changing the draw inputs. Authoring/UV/seam validation needed |
| B on current GL 2.1 | **Proposed** | Unlit faces/partitions assigned a few plateaus; optional authored actor shade variants in second trial | Stage-like light boundaries represented by values, not a physical lamp/shadow solve | Explicit plane/partition assignment and validation; existing quad can draw a uniform plateau, but map data/material ownership is missing |
| A/B in selected shader engine | **Proposed; engine undecided** | Shared material/light contract mapped to controlled shader, baked field/lightmap or authored area lookup | Authored areas may still deliberately replace physical light even when engine supports it | Transfer curve, debug view, masks/import and occlusion rules must be implemented and measured; choosing Godot does not make the contract automatic |
| Dynamic lamp/shadow tier | **Deferred** | Geometric local lighting/occlusion with bounded scene effects | Any retained authored fill remains an artistic approximation | New light/shadow integration, billboard response and GPU budget. Cannot claim current GL light or calibration rectangles implement this |

Different art looks can be produced by the same unlit path. Renderer novelty is not the goal. The test asks whether a specific graded architectural field or structural-plane arrangement changes the visible spatial information enough to justify its authoring/runtime cost.

## Muzzle flashes, colored light and comfort

**P:** firing event has one simulation timestamp/ID; weapon art and sound use it. Flash onset coincides with the accepted release marker, duration is authored per weapon. Start at 40–70 ms as a hypothesis, cap summed contribution during automatic fire, and preserve reticle/target tell contrast. A screen-covering flash is not required for weight. World contribution is optional and separate from the first-person sprite. A flash cannot make a hidden attacker visible through a wall or cast a truthful shadow without an occluded-light implementation.

Tier 1 can use a bounded area accent only in the firing area, declaring it a stylistic approximation; it does not simulate a lamp passing through doorways. If that approximation produces obvious leaks or texture hue shifts, remove it and keep the overlay/impact cue. Tier 2 can use a small per-pixel light with geometry occlusion in the chosen engine. Both need a reduced flash setting retaining fire/reload state feedback. No routine global ambient pulse or exposure pumping.

Hue is secondary: hostile tell differs by expanding/aiming shape and sound; interaction mark by stable icon/state; hazard by geometry/material edge. Red/green, yellow/white or blue/purple cannot be sole state distinctions. Compare grayscale and protan/deutan/tritan simulations, then ask actual players about ambiguity; simulations are diagnostic, not certification. Keep the reference art proposals' role colors under review rather than declare them accepted. Colored light must not transform hostile tell into the usable-state color. Reduce environmental chroma under combat if necessary, not by silently recoloring authored icons.

Fog, steam and damage overlays share an obscuration budget with weapon kick and muzzle art. Record target occlusion duration/area and missed tells. Offer reduced motion/flash/fog options that preserve event information. Do not introduce rapid strobing merely to imitate old light specials.

## Shared test room and comparison protocol

**P:** begin with the existing calibration geometry as a reproducible *diagnostic room*, preserving its 24×20 footprint, entry gap and central block. Convert neither its encounter nor its HUD into approved content. Use consistent source material and illumination behavior across calibration/ordinary modes for this trial; preserve existing rejected build separately. A drawn upper ledge can be studied in images, but a playable ledge is deferred until height rules work.

Prepare four interchangeable backdrops: neutral quiet wall, candidate Civic broad plane, candidate Painted plane, and current infernal wall as a stress diagnostic. Use the same two neutral Hold/Cross role silhouettes/tells and the same neutral control loadout for each lighting condition, as described in weapon/enemy reports. Do not compare a new bright creature against an old dark one and attribute the outcome to light. First compare all systems with neutral materials, then a 2×3 art/system matrix with fixed actor state/position.

Views: entry through gap; clockwise and counterclockwise around central block; far back wall facing entry; side-by-side and overlapping actor silhouettes; actor crossing a region border; approach from a dark decorative corner; active tell against floor, ceiling and doorway. Cover occludes, not dims, the actor. A three-room route should follow only after these views pass so level identity can be judged. In the later matched route test, use control/alternative level layouts with the same chosen illumination system; do not change layout and lighting simultaneously.

Capture a static unlit/material-only image, area-only image, emissive-only image and final composite; capture short movement/tell clips at matched simulation times. Record actual internal resolution, output size, FOV, renderer path, transfer curve, brightness slider, OS/profile/night-color state and display type. Native current constants are 1280×720; hypothesized future targets 640×360 and 320×180 are experiments, not chosen production resolution. Compare 1× source crops and integer upscales, with UI rendered separately as its own legibility problem.

Viewing conditions: user's normal screen and room; a brighter ambient room if practical; dim comfortable room; 100% and reduced comfortable monitor brightness with exact setting noted. These are relative conditions, not calibrated luminance. Do not change the system color profile as a game fix. Include normal seated distance, windowed and full-screen, and a lower-end display if available. A black-level pattern checks clipping; it does not guarantee actor contrast. Test warm display mode separately if user uses it.

First run an assistant/operator diagnostic followed by 2–3 players' short blinded-order sessions, then expand when failures/alternatives are meaningful. Present random or counterbalanced C/A/B ordering; same gameplay seed/route/actor placement/resources/weapon timing; rest between repetitions. Identify prior shooter familiarity and fatigue. No claim of statistical population validity from this initial sample.

### Acceptance and failure hypotheses

| Measure | Proposed gate | Why / limitation |
|---|---|---|
| Basic spatial read | Every view retains floor/wall edge, cover outline and usable opening at normal display settings; no indispensable route encoded only by color. | Geometry is still the authority; a brighter frame alone is insufficient. |
| Threat recognition | At tactical pixel band, at least 90% correct role/tell identifications in brief randomized diagnostic clips; no recurring lethal tell disappearance during motion in any supported view. | 90% is a starting gate, not a universal standard. Clip exposure duration must match actual tell opportunity and be logged. |
| Tracking cost | Candidate causes no recurring extra lost-target incidents versus C; investigate median tell-recognition delay increase above 100 ms or roughly 15%, rather than average away bad views. | Small sample/timing uncertainty makes these flags, not statistical proof. |
| Regional transitions | No one-frame body light pop, uncovered area default brightening, emissive flicker or silhouette alpha loss on crossing. | Explicit ownership/transition coverage can be inspected independently of taste. |
| Flash/overlay | Tell and reticle remain parseable during maximum accepted firing cadence; reduced-flash mode retains shot timing and hit state. | No pass from an isolated beauty flash. |
| Color robustness | Required state identified by value/form in grayscale and color-vision diagnostics; player descriptions reference form/location in addition to hue. | Simulations do not replace players with relevant visual needs. |
| Identity benefit | Players distinguish the room's opening/landmark and describe the chosen light grammar after the route; A/B preference has a concrete reason beyond “brighter”. | Taste and recognition are recorded separately from combat fairness. |
| Technical budget | On named target hardware, stable selected frame target with comparable 95th/99th percentile frame time during matched stressed view; no sustained regressions above agreed budget. | Hardware and frame target must be selected first; no invented 1993-derived draw/light cap. |

Any candidate that works only from the entry screenshot fails. Any atmosphere that demands fullbright debug outlines to restore ordinary combat should be redesigned. If A/B fails a view C passes, first adjust background plane/material/tell scale; only add a more complex renderer when its benefit is specifically demonstrated. Acceptance criteria above are future work, not tests run by this research pass.

## Implementation tiers and costs

**Tier 0, research gate:** approve shared pixel/material/light meanings and matched room; choose which art candidates to render for review. Inspect alpha/mask export and screenshot values. No runtime commitment.

**Tier 1, cheap native experiment:** consistently unlit geometry/sprites with authored area/face values; explicit region coverage/priority; simple actor transition blend; separate body/emissive drawing if necessary; small tagged overlay effects. This fits OpenGL 2.1 without global illumination/shadow maps. Surface polygons require subdivision at area boundaries and validated UV continuity; that authoring cost must be counted. Limited shade variants/dual passes create asset and overdraw cost; do not assume free. This is an experiment after approval, not a production implementation performed here.

**Tier 2, selected engine slice:** engine-neutral area/material contract mapped to a shader/static baked light or lightmap; proper linear/display conversion; emissive masks; optional small local flash; occlusion-aware propagation and performance instrumentation. Godot's default physically based look is not the artistic answer; a custom unlit/controlled shader is a valid option. Custom C++ needs shader/debug/import ownership; decide from the architecture slice. Both can preserve A/B grammar without expensive moving lights.

**Tier 3, only demonstrated need:** selected dynamic lights/shadows on major moving geometry; local fog/volumetric effects; sprite normals or directional response. Compare against cheaper authored substitutes. Pixel-art shadow alignment, billboard normals, shadow acne, light leaks, overdraw and GPU fill cost are all risks. Dynamic GI, ray tracing, exposure director and campaign-wide procedural darkness systems are deferred. We cannot estimate a safe light count until the target GPU, resolution and renderer are measured.

## Cross-role contracts

| Owner | Required input/output | Rule shared with lighting |
|---|---|---|
| Engine/map tools | Area ID/volume, surface partitions, light state, transition, priority, portal/occluder IDs; debug light-only/coverage view | Rendering uses authoritative world geometry; missing/overlapping coverage is an actionable authoring error, not silent brightness 1. |
| Level/encounters | Reachable viewpoints, tactical distances, role slots, protected tell envelope, opening/landmark | Design for every approach; optional darkness outside envelope never moves an active lethal tell into unreadability. |
| Creature art/AI | Alpha-safe silhouette, body/emissive masks, state/tell marker and occupied pixel shape | Light does not invent an attack cue after AI commits; actor light does not depend on camera-facing billboard normal. |
| Weapon art/VFX/audio | Release event ID/time, aperture position, visual flash footprint/duration, mix cue | One causal event; bound additive sum and screen obscuration; impact light follows actual collision, not sprite animation guess. |
| Interactions/story | Authoritative state transition ID, affected area IDs, before/after light variant, priority/duration/reset behavior | Switch/door light changes follow committed state. A cosmetic outage cannot silently change AI sight, collision or attack permission. |
| HUD/accessibility | Brightness calibration, minimum visibility, flash/fog controls, state shapes | UI drawn independently of world exposure; low-effect modes preserve event meaning; no desktop profile mutation. |
| Audio engineering | Same event ID and occlusion/area facts | Darkness never promises a sound warning the mixer cannot reliably deliver; hearing alone does not excuse an invisible attack. |
| QA | Build/config/viewpoint/pixel bands/state trace and failure cause | Record missed tell vs geometric occlusion vs alpha loss vs hue confusion; do not bundle them as “needs more brightness”. |

**P minimal light event:** `{event_id, simulation_time, source_entity, area_id, position, kind, visual_priority, duration, amplitude_cap, occlusion_policy, reset_policy}`. Persistent light states are saved/restarted with world interaction state; temporary flashes expire and do not enter save data. Decorative beats have lower priority than combat tell protection. No global “intensity” number should secretly decide enemy visibility or spawn rules.

Door light changes need only authored open/closed states at Tier 1. If animated intermediate changes are shown, visual timing must match geometry and be tested; no expensive continuous illumination required. Story can interrupt the backdrop or practical lamps after a stable tell has finished, while preserving combat floor and route landmark. This achieves coordinated drama without approving the prior observatory/glass narrative.

## Self-critique and coordinator decisions

1. A and B may converge if both become scalar area tints. Their difference must be visible in large shape placement, transition treatment, depth organization and authoring cost, even in grayscale. If matched neutral frames cannot distinguish them, merge instead of naming duplicate systems.
2. Proposed pixel bands and recognition thresholds are practical hypotheses. They need user hardware, actual tell timing and varied player feedback before production gates. A far preview is not automatically a fair firing target.
3. Stable actor fill can look pasted on; multi-sample area response and contact cues help, but should not recreate dark body loss. Compare cohesion and fairness independently. Emissive masks add pipeline complexity and may be unnecessary if a pale tell already works.
4. Broad fill risks blandness; graphic staging risks camera bias. Neither earns a recommendation from prose. C may win and leave atmosphere to materials, spatial rhythm and audio.
5. Reference material provides concrete evidence for Doom and Wolf source behavior and Boltgun authoring, but public DUSK/Prodeus sources do not justify exact renderer internals. No invented light count, luminance, normal-map or exposure claim is included.
6. This pass used source reading and existing image findings, not a fresh playable measurement. The ordinary/calibration mismatch is confirmed code evidence; assigning percentages of fault to light, art and display would be premature.

**Recommended next decision:** coordinator validates the shared contract and low-cost matched-room protocol; user reviews C/A/B paired frames after research integration. Defer final brightness ramps, target resolution, dynamic-light scope and creative direction until then. The aim is a repeatable room/actor visibility standard that survives future assets and levels, rather than another dark concept with brighter glow.
