# Eyesore second-round research: art direction and visual development

**Role:** 00 — Art Direction and Visual Development  
**Status:** research proposal for critique, not an approved visual bible. No assets or game code were produced by this pass.  
**Research date:** 3 October 2026  
**Scope:** inspect current project evidence, study Doom (1993), Wolfenstein 3D, DUSK, Prodeus, Boltgun, and Dead Space, then propose two deliberately different original visual systems.

## Executive read

Eyesore does not yet have a coherent, tested visual identity. It has a native first-person prototype, several strong-looking but visually disconnected generated assets, a large amount of design prose, and multiple competing world proposals. The files called “infernal” are the most established palette/material family in the repository, but they are not proof the user wants an infernal game. Likewise, the coast/observatory, Glass Choir, Red Mile and Witness Works are proposals, not settled art direction.

The clearest visible issue is not “needs more detail.” It is that the assets do not yet form the same readable image. A captured gameplay frame is almost entirely black with a repeating red-cracked wall, two near-identical cruciform armored figures, one bright flame figure, and a large bronze/blue weapon. The wall pattern, ambient values, enemy silhouettes, and weapon focal color compete without a consistent hierarchy. The current enemy concept sheet has eight views and four poses, but the four rows read as near-identical idle/crouched variants at contact-sheet scale; its horn, pale mask, dark body and orange chest focal point repeat motifs already common in the current enemy family. The “infernal wall” is a highly detailed black rock-and-lava repeat; it cannot by itself tell a player whether they are looking at a wall, floor, landmark, hazard, or route.

Two candidates below are intentionally far apart: **A, Civic Daylight** makes architecture and route reading work through broad pale/cool values and saturated wayfinding; **B, Painted Eclipse** makes spaces and actors read as layered stage silhouettes with hard-edged, selective color. Both can support a fast shooter. Neither currently earns a recommendation: the repo still has a product-identity conflict (browser/isometric copy versus native FPS), and no art-direction benchmark has been tested at gameplay distance.

## 1. What exists, what is only proposed

### Project evidence inspected

- The root and game READMEs describe both a browser/isometric product and a native SDL/OpenGL FPS. The current art files and game capture belong to the native FPS, but the product target needs explicit owner confirmation before a production visual bible is treated as binding.
- Native assets include a tiled orange-cracked rock wall/floor/ceiling set, a three-weapon viewmodel sheet with metallic black/bronze/cyan accents, four enemy families with dark bodies and hot red/orange emphasis, and a high-detail “Kiln Wretch” concept/contact sheet. Most are labeled prototype or infernal; no current document proves they are approved direction.
- The current game capture (`linux-game/build/eye-sore-playtest.mp4`, sampled at 10 seconds) shows a near-black room. A large central armored enemy has a bright red cross-like chest/head mark; a second far enemy repeats the armor silhouette and mark. A much brighter flaming figure at far left is more legible than either armored figure. The weapon is large, dark bronze and cyan, which draws the eye down and forward. This is useful audit evidence, not a quality endorsement.
- `SPRITE_PRODUCTION_BRIEF.md` precisely describes today’s image pipeline: 8 views × 4 walking poses at 384×256, separate 4-frame attack/pain/death/gib states, alpha/color-key hazards, and hard-coded four-type limits. Those constraints matter, but they should not determine the design itself.
- `Creature_Redesign_Research.md` and `World_Design_Redesign_Research.md` contain promising diagnosis alongside unapproved proposals. Their proposed “Glass Choir” and coastal observatory vocabulary is not a project decision. The level brief’s “First Descent” is also a proposal. `Story_Integration_Research.md` itself says that neither Witness Works nor Red Mile is canon.
- The references file recommends Doom readability, DUSK identity, Prodeus presentation, Boltgun weight, Wolfenstein cue clarity, and selective Dead Space tension. These are useful lessons, not a composite look. A pile-up of references would create a generic “retro industrial horror” result.

### What the repo demonstrates versus what it cannot prove

| Evidence | What it demonstrates | What it does not establish |
|---|---|---|
| Rendered playtest video | Actual current screen values, scale, repetition, and combat framing | Desired style, final gameplay, successful readability, or approval |
| Source sheets and exported sprites | Available source material, consistent motifs, frame/layout problems | Reliable in-game alpha, matching scene illumination, or quality at distance |
| Material PNGs | Current repeated infernal material family and its frequency/detail | Correct texel density, collision/material semantics, all level needs |
| Written plans | The team has considered taxonomies and cross-discipline links | Canon, validated scope, engine readiness, or an agreed world |

Do not infer that more sprite frames, a large texture count, extra gore or additional lighting effects will resolve the visual problem. First define the pixel and screen-space budget, value hierarchy, and asset role rules; test one small scene; then expand.

## 2. Reference research: observations and transferable lessons

These references are not equal in genre, technology or player pace. Observations are tagged **Observed** where supported by inspected media or developer/source material; “Eyesore lesson” is a design inference, not a claim made by the source.

### Doom (1993): role contrast and readable material families

**Observed:** the 1993 game builds a shared visual world out of chunky wall/floor/ceiling texture families, vertically oriented masked sprites, a small high-contrast status display, and repeated material motifs that change meaning through lighting and neighboring architecture. Monsters are not all one kind of detail: the visible outline, facing, attack wind-up and projectile shape help distinguish roles. The engine’s sector brightness and texture-column rendering are documented in the released Linux source; read `r_defs.h`, `r_main.c`, `r_draw.c`, `p_enemy.c`, and `info.c` as implementation evidence, not as an art license. The source release is not the game’s complete proprietary art/audio bundle. [id Software DOOM source](https://github.com/id-Software/DOOM)

**Eyesore lesson (inference):** borrow a role system, not the brown/green/stone palette as a recipe. Each large environment family needs a few deliberately designed surfaces whose scale and value survive repetition. A monster’s outline and attack state must remain recognizable before facial texture can be read. UI, actors and world can share graphic language without using the same brightness or material noise.

### Wolfenstein 3D: a small spatial vocabulary can still make identity

**Observed:** the original source and data format foreground a grid-based tile world, repeated wall panels, doors, props and discrete character sprites. Its source README notes the original ray-casting architecture and calls out the absence of taller walls/vertical motion as a deliberate technical limit. This is a much simpler spatial and visual system than Doom, not a target limitation that Eyesore should imitate. [id Software Wolfenstein 3D source](https://github.com/id-Software/wolf3d)

**Eyesore lesson (inference):** consistency and a small repeated icon vocabulary can make a location easy to parse. Give each architecture family one recognizable door frame, corner solution, floor seam and interaction mark. Borrow compact signage and clear state changes. Do not import castle brick, Nazi iconography, grid-bound layouts, or flat wall art.

### DUSK: coherent location changes beat a uniform retro filter

**Observed:** David Szymanski has discussed deliberately studying old-game texture use, low-resolution composition, movement space and the visual identity of each place; the developer interview frames DUSK as a considered design rather than a generic “old graphics” filter. Its game and developer materials show meaningful jumps in environment family and mood across the campaign. [Game Developer interview](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games) · [New Blood: DUSK](https://newblood.games/dusk)

**Eyesore lesson (inference):** decide what each place is made of, who uses it, and what large shapes make it memorable before applying resolution/texture treatment. Palette changes should correspond to places and factions, not arbitrary “level color.” Give the opening enough neutral space to read targets and controls before using the densest imagery.

### Prodeus: deliberately authored retro presentation with modern rendering

**Observed:** its official description explicitly pairs contemporary 3D technology with retro visual presentation and gameplay. The rendered experience combines volumetric/modern effects and detailed geometry with pixel-textured actors and effects; the visual result is an authored mix rather than strict hardware emulation. [Prodeus official page](https://store.steampowered.com/app/964800/Prodeus/)

**Eyesore lesson (inference):** technical layers need a contract. If high-resolution geometry, low-resolution sprite art, noise, blood, and emissive lights all occupy the same high-frequency range, the image becomes busy. Pick a dominant pixel grid and define exceptions for silhouettes, targets, impacts and UI. Modern effects should reinforce a hit or route, not blur their underlying shape.

### Boltgun: faction silhouette and a unified rendering recipe

**Observed:** publisher and developer materials describe Boltgun as a frenetic retro FPS with fluid modern play and fully 3D, sprite-based visuals. It relies on an unusually recognizable licensed universe with established armor, weapons, enemy categories and iconography. [Focus gameplay trailer](https://www.youtube.com/watch?v=DnvF7m1Avzo) · [Auroch development article](https://aurochdigital.com/blog/2025/7/28/words-of-vengeance-interview) · [PlayStation developer details](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/)

**Eyesore lesson (inference):** every art category needs one rendering grammar: nearest sampling / pixel scale, outline/value method, texture frequency, animation cadence, hit treatment and lighting response. Boltgun can lean on instantly recognized Space Marine shape and colors; Eyesore needs original factions with equally disciplined shape families, not borrowed Aquila/crosses, chainswords, skull badges, purity seals, armor proportions or 40K color coding. The playtest image’s repeated red-cross armor is an especially clear motif to reassess.

### Dead Space: readable industrial evidence and selective lighting

**Observed:** Motive describes the remake’s art pillars as horror, immersion and a lived-in world. Developer material also discusses light/shadow and authored event recipes spanning lighting, sound, fog, steam and enemy activity. The remake’s industrial fiction is communicated through functional detail, wear and environmental clues, with light serving dramatic and navigation purposes. [Motive art-direction livestream](https://www.ea.com/ea-studios/motive/amp/news/art-developer-livestream) · [EA: Intensity Director](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director) · [GDC: Harnessing the Power of Light and Darkness](https://gdcvault.com/play/1029020/-Dead-Space-Harnessing-the)

**Eyesore lesson (inference):** use material wear and light to answer “what is this place for?” and “what changed?” Keep the main combat plane legible at all times; put deeper shadows into approaches, corners and aftermath spaces. The emotional and slow-survival pressure of Dead Space is not an art mandate for a fast shooter. Avoid turning every room black, every material into distressed metal, or every enemy into exposed anatomy.

## 3. Cross-reference findings: what is worth combining, what should stay apart

| Reference element | Generalizable principle | Keep it distinct from |
|---|---|---|
| Doom actor/weapon/world separation | Screen-space role and firing feedback | Its exact monsters, weapon models, texture compositions, or map geometry |
| Wolfenstein's repeated panel and signage vocabulary | Compact, learnable door/route symbols | Flat box-maze visuals or iconography |
| DUSK's location identity | Named material and shape changes between districts | Its particular barns, cult symbols, rural/nuclear scenes, or palette |
| Prodeus' mixed-resolution rendering | Deliberate quality and pixel-scale contract | Arbitrary pixelation plus high-detail effects everywhere |
| Boltgun's silhouette unity | Recognizable faction and weapon forms | Licensed 40K forms, marks and color placements |
| Dead Space's lived-in clues and light/sound authorship | Function-first wear, intentional shadow, coordinated beats | Constant darkness, slow survival-horror pace, iconic USG Ishimura and Necromorph design |

The new direction should combine only mechanics of communication: silhouette, material role, scale, state, and contrast. It must select its own subject matter and image-making technique.

## 4. Current visual audit

### Three actual weaknesses visible in the capture / assets

1. **Value collapse:** most of the scene falls close to black. Enemy bodies and the background merge at distance. Bright symbols, fire and weapon blue become the only legible values, so their signals compete. Increasing global brightness alone could flatten the room; the fix is a planned value ladder for room planes, actors, target tells, routes and effects.
2. **Silhouette repetition:** two armored combatants in the captured scene share a broadly similar upright armored form and bright central red symbol. Existing generated enemy art also repeats dark body + horn/ivory mask + orange center-light across types. Distance makes more detail irrelevant; change primary mass, posture, width, height, negative spaces and focal placement first.
3. **Texture / rendering mismatch:** the wall has dense black rock chunks and bright branching orange cracks; the weapon has bronze mechanical detail and cyan glow; enemies have polished contrast and hard bright emblems. These read as three art sources competing within one scene. The repeating wall also has little quiet area behind a target. A canonical value/edge/pixel contract would connect them.

### Additional design risks visible in file organization

- Separate names for floor, ceiling and wall exist, but the “infernal” artwork reads as the same high-frequency molten-stone language. The taxonomy describes many new environment families before one in-game material set has been validated.
- The weapon sheet is rendered at a different apparent pixel/texture scale than the map and actor sprites. Weapon scale can be purposefully large, but its detail should not overpower the target outline or cover too much of the view.
- Concept sheets are judged on black backgrounds and isolated scale. Alpha fringe, actual in-world illumination, turns, attack tells, damage states, and in-game-size outline are the review conditions.
- The four enemy families have documented animation deliverables, but art rows should be judged by motion silhouette rather than whether the contact sheet has the nominal number of frames. Four poses that differ only by minor texture/limb changes do not make a visible gait.

## 5. Two genuinely different original direction candidates

These are visual systems and scene tests, not story decisions. They avoid the current coast/observatory, glass/choir, furnace/lava and infernal vocabulary. The names are working handles only.

### A — Civic Daylight

**Premise of the image:** combat inside a vast inland public works / civic structure whose normal purpose is order, routing and collective use. Make the threat visually alien to the calm, legible, maintained civic shell. This does not require the Red Mile story or a train station.

**Shape language:** broad datum lines, long lintels, recessed door slots, open courts, low waist-height route rails, repeated circular/rectangular service portals. Architecture forms long calm horizontal planes. Threats break those lines with tall asymmetric postures, narrow forward-leaning silhouettes, and one or two deliberate gaps. Avoid gothic arches, brass cathedral details, and repetitive pipe-covered corridors.

**Palette/value structure (proposal):** large surfaces in pale mineral grey, warm chalk, dusty blue-grey and desaturated green; shadows remain navy/charcoal but never black except occlusion pockets. Route and interaction colors use one saturated **safety vermilion** plus one **cobalt** system color, separated by function (e.g. vermilion = hazard/hostile state, cobalt = usable/route/state). Enemies sit in a limited dark blue-violet/oxidized red mass with a warm tell visible before attack; pick a unique color assignment after quick color-vision and screenshot checks. Do not use red and green alone to distinguish state. Lighting is mostly broad reflected daylight through structural openings, with small fixed pools at control surfaces and safe transitions.

**Pixel/detail contract:** let architecture carry 2–3 large value bands and a few clean geometry seams; reserve fine wear for the lower 10–15% of walls, door thresholds and object contact points. Texture grain stays below the enemy outline’s edge frequency. Use a single game-resolution base, nearest-sampled sprites/materials, and permit higher-resolution geometric lighting only when it does not soften sprite contours. Exact internal render resolution must be chosen by engine/art owner; document the visible reference pixel width after screenshots at the gameplay window size.

**Faction and material relationships:** civic surfaces have soft matte roughness and repeated manufactured joints. Functional markings look painted/printed and align to architecture. Enemy surfaces should be visibly unlike both civic concrete and weapon metal: matte, patterned or segmented material with a specific movement reason. Weapons use dark neutral body material; muzzle/capacitor energy gets a very limited accent, distinct from the hostile tell. No shiny chrome across all categories.

**Player / enemy / weapon contrast:** viewmodel stays in the bottom 20–25% of the frame with silhouette against calmer floor or shadow, at least one large negative-space opening around the barrel. At target distance a weak enemy is read by stance and pale/dark mass; its wind-up gets one large, directional shape/color change. A heavy is wider/low rather than “same body with more armor.” HUD uses mineral dark + warm paper/cream text, a simple red health warning, and cobalt keys/objectives; keep it a quiet horizontal instrument panel rather than the Doom status-bar replica.

**District transition:** shift architecture and light geometry more than hue: open sun court → long covered administrative arcade → dense service undercroft → tall civic exchange. Palette can cool and darken gradually underground, but route colors and target color stay stable. Each place gets a new macro-landmark silhouette, one tile seam family, and one interaction frame.

**Potential strength:** more visually distinct from infernal and conventional dark industrial horror; lets enemy and route shapes read without destroying tension. **Potential weakness:** daytime may not match the user's desired horror mood; pale walls can wash out sprites and make gore/impact effects noisy; its civic subject could accidentally turn into generic dystopia. This needs a scene comp before recommendation.

### B — Painted Eclipse

**Premise of the image:** treat each playable room as a layered, hard-edged night tableau with deliberately painted pools of color and large shadow shapes. The place could be a human-made facility or something else; visual direction does not bind story. The visual signature is graphic staging, not realistic battered machinery.

**Shape language:** architecture uses deep portals, cut-out buttresses, slanted support planes, stacked balconies and large stepped silhouettes. Repeated outlines build a clear “frame inside frame” route cue. Actors use contrasting body shapes: thin upright sentry, wide low charging mass, floating radial hazard, tall narrow controller. Effects use simple sharp forms (slit, disc, shard) instead of cloudy glow. Avoid gothic cathedral or Doom E1M8 silhouettes as copied shorthand.

**Palette/value structure (proposal):** near-black indigo/navy fields, medium desaturated plum/blue architecture, bone/ivory actor highlights, and very selective **acid yellow** for actionable route/weapon information plus **coral-magenta** for hostile charge tells. Avoid cyan-blue emissive overload. Keep sky or distant backs as one clear middle value so silhouette edges show. Full black is reserved for deep cavities behind silhouettes, not all unlit surfaces. Lighting is sharp, authored areas with crisp boundaries and stable fill on actors; flicker is decorative and never changes essential visibility.

**Pixel/detail contract:** work at a coarser visible texel scale than A and define texture clusters like brush marks, not photo grime. Use crisp 2D sprite silhouettes with very restrained dithering; background geometry gets larger low-frequency color planes. Muzzle flashes, impact cuts and silhouettes share one stepped edge logic. Keep screen effects short and mostly opaque; no bloom halo that consumes enemy negative space. Establish whether all assets use one low internal render resolution or two calibrated tiers; the two-tier route may look like mixed-media collage, but it must be checked at the user’s actual display size.

**Faction and material relationships:** architecture is a sequence of broad planar surfaces, not a library of realistic metals. A “faction” can be identified by repeated graphic motif and edge shape (e.g., paired slashes, split circles, stair-step cut), each with one restrained accent. Enemies use a strong primary outline and a single light-emitting wound/weapon shape. Weapons have bold silhouette, low surface detail and one firing aperture; the glow color must not duplicate both route and enemy cues. UI can use a rectangular painted frame with angular separators and very sparse symbol fills; do not imitate pixelated 90s type or Doom's face/status bar.

**Player / enemy / weapon contrast:** the gun silhouette occupies little area and uses a distinct warm-neutral metal against the cool lower field. Enemy center masses avoid the aim point's background value; silhouettes need a clearly visible separation rim or mid-value ground. Charge tell is a unique geometric construction (for example, a disk unfolding into three blades) rather than brighter red. Shooting effects must not cover the enemy’s full outline for multiple frames. A small consistent reticle and hit mark carry accuracy feedback; avoid gore spray as the main contrast tool.

**District transition:** build a progression by changing shape scale and staging (tight framing → broad silhouette court → stacked vertical cutaways → open horizon). Each district can rotate one accent hue, but retain invariant UI/state colors. Use light placement and negative space to make the transition, rather than every level having a new unrelated palette.

**Potential strength:** strong identity even with a compact asset budget; low-detail surfaces leave space for sprites/effects. **Potential weakness:** easy to become generic neon/noir, too stylized for Boltgun's physical weight, or too close to a dark horror game. It may sacrifice the “lived-in world” if we ignore function, wear and material causality. The main test is target silhouette and perceived depth under simultaneous fire.

### Direction comparison

| Criterion | Civic Daylight | Painted Eclipse |
|---|---|---|
| Core contrast | Pale large architectural fields vs dark/colored actors | Deep cool planes vs light/coral/acid silhouettes |
| Mood | Uneasy public space; threat intrudes into order | Mythic, graphic, theatrical hostility |
| Texture role | Sparse wear at joints, floor edges and hand-contact points | Almost no realistic grain; broad planes and chosen brush/pixel clusters |
| Lighting | Broad ambient fill, function lights, comfortable target visibility | Hard pools and stable fill, stronger negative-space composition |
| Newness relative to repository | High; leaves infernal dark rock and coast/glass themes | High in technique, but risks “generic neon horror” |
| Main risk | Drifts to mundane bureaucratic dystopia | Drifts to ungrounded neon abstraction |
| Level-one stress case | Bright service court with fast projectile attackers | Dark layered court with flying and close pressure enemies |
| Current confidence | Unvalidated | Unvalidated |

**Recommendation:** none yet. The best next review is a matched single-screen scene comp for A and B using identical player position, enemy roles, weapon, and objective. A wins only if it stays evocative while improving first-glance target/route distinction; B wins only if actor layers survive muzzle flash, movement, and low display brightness. If neither passes, discard both. Do not average their colors or textures into a third compromise.

### Compatibility with the two unapproved story/world candidates

These are visual-fit readings, not a story recommendation. Keep the story choice and the rendering-system choice separable: each story should be testable in each visual direction, and the signature named below should remain intact if the story changes.

| Pairing | Fit and strain | Original signature that remains | One test-frame cue |
|---|---|---|---|
| **Civic Daylight × Witness Works** | **Strained, but workable.** The proposal's coast survey/archive setting can justify maintained public infrastructure, but its storm-coast optics and replaying past may pull the look toward the already-proposed observatory/glass vocabulary. Do not solve this by darkening every room or filling it with lenses. | Broad pale architectural planes, calm wayfinding colors, and an uneasy contrast between civic order and an impossible event. The archive is expressed through a state contradiction, not a glass/choir motif. | From a bright pump/archive threshold, a clean route and one hostile silhouette read clearly; beyond them, a single wall-mounted work indicator repeats an earlier state while its neighboring physical door is visibly sealed. No lens tower or creature close-up is needed to read the discrepancy. |
| **Painted Eclipse × Witness Works** | **Strong mood fit, with repetition risk.** Graphic staging can make the archive's repeated-event premise immediate, but it can slide straight back into the proposed optical horror look. Keep the effect as a flat, hard-edged offset of the room's shapes, not translucent glass, prismatic beams or tissue. | Deep indigo stage planes, sharp negative-space framing and restrained coral hostile tells. The archive's visual cue is a precise mismatch between two hard-edged scene states. | Frame a familiar maintenance doorway in two aligned silhouettes: the real door is open, while a hard-edged, offset block-in shows its recorded closed position for a brief beat. Keep player, enemy, exit and attack tell on stable values. |
| **Civic Daylight × Red Mile** | **Strong functional fit, but close to the direction's premise.** Public-service routes and evacuation evidence sit naturally in ordered, readable architecture; risk is making “civic daylight” mean only railway concourses and signage, so the look becomes inseparable from this one story. | Pale/cool surfaces, route rails and a vermilion hazard/cobalt interaction vocabulary. The image still reads as a broader civic architecture system if the setting changes. | A sunlit concourse frames a stopped train and two evacuation arrows. The forward arrow terminates at a sealed gate whose matching route indicator is already dark; the safe detour stays visible in the same shot. Readable without text close-up or a character explaining it. |
| **Painted Eclipse × Red Mile** | **Workable, with strong genre-cliché risk.** Hard-edged lighting and bold sign shapes support fast route reading, but rail silhouettes plus neon colors could become generic cyberpunk. Keep the palette selective and the environment grounded in actual civic function rather than adding holographic clutter. | Layered dark planes, precise route framing, an acid-yellow usable-state cue, and a hostile tell reserved for coral-magenta. The signs use original geometric symbols, not familiar rail/evacuation icon sets copied wholesale. | A dark platform view places the active exit lane in acid yellow; the false evacuation arrow points toward a visibly shuttered platform, while the hostile charge shape occupies a separate coral value. The player can parse route, deception and threat at thumbnail size. |

The matched scene-comp exercise should therefore create four flat blockouts, not only two: keep each world candidate's story clue constant while rendering it in both visual systems. If one pairing only works after importing the other direction's signature, record that as a strain rather than blending the looks.

## 6. Small original scene direction for comparison

**Test scene: The Relay Court** (temporary scene name; neither story nor location is canon). A compact rectilinear court has one central route landmark, one visible side loop, one door/switch, one far ranged threat, one close threat emerging from a visible side, and one horizontal cover block. Player carries the same first weapon and faces the same framing in each direction test. No boss, keys, lore text, secrets or authored set-piece are needed to test the visual question.

### A version

Pale aggregate floor with two broad painted route lanes; deep blue-gray wall recess; one vermilion sealed door; cobalt live switch; warm chalk opening that shows the exit silhouette. The far attacker occupies a muted dark, slightly blue value against a midtone wall; its charge tell adds a broad yellow/cream mass without full-body blinking. A low close attacker reads by wide posture, not face. One shaft of sun gives floor depth and serves the focal landmark, with even fill preserving both enemies.

### B version

Large indigo planes create a bright-backdrop lane behind the far attacker; one stepped platform and two sharp shadow bands frame a central route. Acid yellow marks the live switch and exit route; coral-magenta remains exclusive to the far attacker’s charge geometry. The near threat's low, wide body silhouette stays separated from the floor by an edge-light and negative-space notch. One hard spotlight gives hierarchy, while fixed cool fill keeps flank exits and threat outlines visible.

### Compare at these four scales

1. Thumbnail (10%): can the player locate the exit and count threats?
2. Actual game window, no motion: can a first-time observer separate floor/wall, enemy roles, weapon and interactable?
3. Actual game window during a strafing shot: do silhouettes remain stable and do muzzle/effect frames obscure the attack tell?
4. Reduced brightness and deuteranopia/simulated color-vision condition: do state and enemy role remain distinguishable by value and shape, not color alone?

The scenes should use primitive blockout and flat swatches first. A detailed concept illustration would conceal whether the system works at actual combat scale.

## 7. Proposed original visual rule sheet (to revise after the test)

1. **One dominant image-making method.** State whether Eyesore uses chunky nearest-filtered textures, painted low-res atlases, or graphic flat planes as its base. Exceptions must be few and specified.
2. **Three simultaneous scales.** Large: room/faction silhouette; medium: structural or body mass; small: clues/wear. Small noise never gets equal contrast with large navigation and target shapes.
3. **Value first, hue second.** Route, danger, background, actors and muzzle effects remain distinct in grayscale before a palette is judged.
4. **One meaning per high-saturation accent at a time.** Never use the same flashing color simultaneously for friendly route, enemy tell, pickup and muzzle flash.
5. **Silhouette owns enemy taxonomy.** Role definitions begin with footprint, height, posture, movement and attack line; facial motifs are polish, not identity.
6. **Lighting supports stable combat.** All priority actors and floor boundaries meet visibility thresholds without relying on random flicker, post-processing bloom or muzzle flash.
7. **Material is evidence of use.** Wear appears at contact, traffic and maintenance points. No omnipresent grunge. Every surface has assigned environment use, tiling scale and impact/footstep material.
8. **UI shares grammar, not noise.** It may use architecture’s symbols and edges, but must remain a calm layer over action and use tested text/symbol sizes.
9. **Asset set remains original.** References are about communication and craft. Do not trace, extract or reproduce commercial textures, map layouts, monster shapes, logos, armor marks, HUD, palette arrangements or animation frames.
10. **A contact sheet is not approval.** Inspect the assembled gameplay scene, native size, alpha edges, color-vision variants, and motion before sign-off.

## 8. Explicit open questions for the art-direction review

- Is the product definitely a native first-person shooter, and are browser/isometric descriptions stale? This gates perspective, sprite use, UI, pixel scale and composition.
- Is the dark infernal look a rejected prior experiment, or a direction worth selectively retaining? The files alone cannot answer this.
- Should Eyesore's emotional signature be **order under attack**, **theatrical hostility**, or something neither candidate captured?
- Does the desired amount of horror come from creature design, place/function contradiction, sound/light, or all three in controlled doses?
- Is “close to Doom’s original layout” a reference to top-down map grammar only, or to the 1993 game’s entire visual arrangement? This report treats layout as spatial grammar and visual identity as original.
- Which gameplay window/render resolution, aspect ratios and minimum display brightness should be the baseline for art review?
- Are the latest story agent’s proposals still active alternatives, or should the art team remain world-neutral until story review? Current instruction is to treat both as unapproved.

## 9. Visual playtest acceptance questions

Run at least five people who have not read this brief; capture their first answers verbatim. Test each direction in the same blocked-in scene. Ask:

1. “Point to the safest route forward, the optional route, the interaction, and the most dangerous enemy.” Can they do so in three seconds without explanation?
2. “Which enemy is about to attack, and what told you?” Can they identify the tell from silhouette/motion/color, with sound off as a separate pass?
3. “What material is the floor, wall, and cover made from? Which one is likely to move, hurt or open?” This checks material function without relying on text.
4. “What single shape or color do you associate with this game after this room?” If they name “Doom,” “Boltgun,” “Dead Space,” or “generic retro horror” rather than an original cue, revisit the design.
5. “Could you keep both threats and the exit in view while moving and firing?” Observe, do not only ask. Count missed tells, collisions, and aim corrections caused by visual ambiguity.
6. “Did the muzzle flash or damage effect hide a target for long enough to lose their attack?” Record by weapon/enemy pairing.
7. “Can you tell which way the scene continues after turning around?” This tests landmark and material grammar.
8. “What changed when the switch activated?” A valid art system shows persistent state through a world object or light, not only HUD text.
9. “Does the room feel purpose-built, lived-in and altered by conflict? What object made you think so?” This tests Dead Space-derived functional environmental evidence without cloning its subject matter.
10. “At reduced brightness and grayscale, can you still distinguish route, interactable, floor edge and enemy tell?” Require an explanation based on form/value.

**Pass criteria before production expansion:** at least 4/5 testers identify route, active threat and interactable in ≤3 seconds; at least 4/5 identify the wind-up before release; no more than 1/5 loses both enemies in a shot/effect beat; 5/5 can distinguish floor from wall and route state in grayscale; at least 3/5 recall one original identity cue without naming a reference game. These are proposed internal bars, not industry facts. If either visual direction fails, revise the system rather than increasing texture detail or adding more enemies.

## 10. Self-critique and limits

I have only one short screenshot from the current playtest video and two isolated art samples in this report; I have not run a controlled player study, inspected a broad set of final in-game frames, or audited every atlas individually. This is enough to point out high-level mismatch, not to diagnose every rendering cause. The two options still risk being too tidy: public-civic daylight can drift toward Red Mile’s administrative premise, while dark graphic staging can drift toward generic neon horror. Both need genuinely different scene comps before continuing. “Maximum research” is not the same as collecting more game names; the next useful evidence is an A/B visual test with real player reads, plus art and engine owners confirming render resolution and display targets.

The biggest likely bias is anchoring on the previous proposals and repairing them through palette changes. This report deliberately excludes coast, observatory, lens/prism, choir, glass/tissue, furnace, lava and the current infernal cracked-rock motifs from its new directions. The other bias is treating Doom/Boltgun’s instantly recognizable art as a checklist; their licenses, teams, technology and content histories differ from Eyesore. Use them to inspect communication and cohesion, not to build a near-copy.

## Sources and inspected materials

- [id Software, DOOM source release](https://github.com/id-Software/DOOM) — sector/render/sprite/actor implementation references; code release does not supply a permission to reuse commercial art.
- [id Software, Wolfenstein 3D source release](https://github.com/id-Software/wolf3d) — source/readme and original architecture commentary.
- [David Szymanski interview, Game Developer](https://www.gamedeveloper.com/design/more-than-a-throwback-how-i-dusk-i-nails-the-best-parts-of-90s-fps-games) and [New Blood’s DUSK page](https://newblood.games/dusk) — developer perspective and game reference.
- [Prodeus official Steam page](https://store.steampowered.com/app/964800/Prodeus/) — stated retro presentation/modern rendering blend and official images.
- [Focus Entertainment Boltgun extended gameplay trailer](https://www.youtube.com/watch?v=DnvF7m1Avzo); [PlayStation Blog with Auroch developer detail](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/); [Auroch Digital article](https://aurochdigital.com/blog/2025/7/28/words-of-vengeance-interview).
- [Motive, art-direction livestream](https://www.ea.com/ea-studios/motive/amp/news/art-developer-livestream); [EA, Intensity Director](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director); [GDC, lighting art direction talk](https://gdcvault.com/play/1029020/-Dead-Space-Harnessing-the).
- Local materials inspected: `docs/REFERENCE_DIRECTION.md`, `docs/Story_Integration_Research.md`, `docs/Creature_Redesign_Research.md`, `docs/World_Design_Redesign_Research.md`, `docs/SPRITE_PRODUCTION_BRIEF.md`, `docs/LEVEL1_DESIGN_BRIEF.md`, `docs/EYESORE_TEAM_REVIEW.md`, `linux-game/README.md`, `public/infernal-wall.png`, `public/enemies/prototypes/kiln-wretch-contact-sheet.png`, and one frame extracted from `linux-game/build/eye-sore-playtest.mp4`.
