# Eyesore research round 2 — role 21: story and world integration

3 October 2026 · GPT-6.1 Sol / high · **Research proposals only. No package, engine, narrative, art direction or production work is approved.** This pass changes only this report. It creates no game code, images, sprites, recordings, music, maps or tests; no game, new reference playthrough or listening session was performed.

**Decision for review:** consider three separate games within Eyesore's fast first-person shooter ambition: **The Taking**, a fight against armed urban repossession; **White Hunger**, a range warden's assault through a predator nesting ground; and **The Tribute War**, a gunner's attack on a usurper's animated funeral army. Each has a player job, a concrete immediate objective, a threat with a reason to obstruct it, and a distinct material and sound vocabulary. None is selected. Their narrative belongs in a later authored experience, after basic movement, shots, attack tells and delivery work. The neutral M0 room cannot answer which story is compelling.

## Evidence, history and reference limits

**PF** = project fact directly observed in files in this pass. **PR** = project finding reported by another specialist, attributed below rather than independently reproduced. **RF** = an external observation supported by a linked primary/developer source. **I** = inference. **P** = an original proposal awaiting review. The three package sections and all their names, events, characters, appearances and sample wording are P. No exact tuning value below is attributed to a reference game.

**PF:** `Research2_Storytelling.md` was absent when this assignment began. [Story_Integration_Research.md](Story_Integration_Research.md) is the available historical story report. It offered Witness Works, an apparatus reconstructing a coastal disaster, and Red Mile, a rail city's false evacuation and route-ledger cover-up. Its slight Red Mile lean was expressly provisional. Preserve those as comparison history, not two additional contenders or prior approval. Witness Works returns to the observatory/Glass Choir/recording/body-replacement cluster; Red Mile changes geography but still risks generic guards, failed infrastructure and a broadcast-evidence mission. This pass withdraws any inherited preference and does not elaborate either package.

**PF:** the root [README](../README.md) still describes a browser/isometric game; the [native README](../linux-game/README.md) and [C++ entry and firing code](../linux-game/src/engine3d.cpp) describe/implement a native first-person prototype. **PR:** roles 01/02 establish native FPS as the working direction from the user's conversation, treating old browser copy as stale documentation. **I:** narrative research should follow that direction; asking again whether this should be isometric would reopen a resolved working assumption. This does not select the future native engine.

**PF:** native firing still differs by mode: standard precision/spread labels launch one projectile each; calibration uses immediate rays, with a pellet fan for spread. The current firing path consumes no ammunition. Setup uses hard-coded actors, caches and wave conditions. **PR:** roles 01/03/04/07/20 identify missing shared map/event/interaction/actor support contracts. Those reports' collision concerns remain unperformed fixture risks, not proven play failures. **I:** current guns, demon-like actors, weapon names and all-enemy wave gates are prototype evidence, not a canon roster to explain retrospectively.

**PR:** roles 00/08/10 describe near-black historical imagery, repeated enemy silhouettes, inconsistent illumination and alpha/tint problems. Role 20 qualifies the inspected frame as historical and lacking current bundle identity. Roles 13–16 retain the user's sound rejection; their reference listening worksheets and new-source auditions remain pending. Role 18/19 report that the existing package targets the C toy and misses native nested dependencies; **PF:** the current [Makefile](../linux-game/Makefile) confirms that package target/copy recipe. **I:** neither a story paragraph nor a parseable manifest cures these delivery and quality gaps. This pass makes no visual, hearing or runtime approval claim.

### Reference observations and proposed transfers

These are bounded source observations, freshly checked on 3 October 2026. They establish craft principles; they do not reconstruct proprietary pipelines, prescribe a soundtrack, prove market demand or certify originality. No reference game assets, dialogue, maps, animations or score themes are proposed as inputs.

| Reference / RF | Supported observation | Eyesore inference and concrete proposal / I, P |
|---|---|---|
| Doom | The released actor source separates chase, attack actions, sight/range checks and role-associated sound calls; different actions launch missiles or resolve line/melee attacks. [id Software actor source](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_enemy.c) | Build readable attack verbs and distinct firing consequences before elaborate lore. Every candidate initially dresses only Hold/Cross after their neutral behavior works; it does not inherit Doom monsters, combat values or a complete bestiary. |
| Wolfenstein 3D | The released actor state tables place shooting and death sounds/actions in explicit states. [id Software actor/state source](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_ACT2.C) | Short state cues can carry meaning during movement. A hostile preparing, releasing and dying needs different authored gestures and sounds; a generic alert beep cannot cover all three. No Nazi uniforms, castle plan or recognizable bark is transferred. |
| DUSK | Its developer/publisher-authored description distinguishes three handcrafted campaign episodes from Endless Survival, and lists a varied arsenal. [Official DUSK description](https://store.steampowered.com/app/519860/DUSK/) | Give a campaign places with different purposes and spatial pressures, rather than extend one arena with more waves. This source supports that campaign distinction, not precise claims about a particular room's navigation or sound mix. |
| Prodeus | Its official description combines modern rendering with retro presentation, a handcrafted campaign/editor, and a score that changes with action. [Official Prodeus description](https://store.steampowered.com/app/964800/Prodeus/) | A complete commercial-feeling image can be authored with modern tools. Select one pixel/material/effect grammar and an original performed score; do not assume strict old hardware emulation or particle quantity provides identity. Adaptive score remains a later capability. |
| Boltgun | Lead designer Grant Stewart describes enemy state machines, authored arena zones and models rendered into eight-direction flipbooks, with damage/sound/projectile markers editable in animation data. [Auroch developer account](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/) | Use a reproducible facing/pose source and one simulation event authority. The lesson is coordination of art and action, not licensed armor, heraldry, chainswords, Doom-derived silhouettes or Boltgun's full encounter system. |
| Dead Space | Motive describes coordinated audio/light/environment/spawn ingredients and deliberate tension peaks and valleys. It also describes uncertainty and surprise as its horror aim. [Motive Intensity Director account](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director) | Borrow authored contrast and place evidence in protected transitions. Eyesore's active attacks still require fair tells; random rear spawns, lethal light outages and an intensity director do not follow from this reference. Quiet should help the next fast fight feel substantial. |

**RF:** Microsoft's guidance calls for additional sensory channels and configurable subtitles/captions for meaningful audio. [XAG 103](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103), [XAG 104](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/104). **P:** use that principle with role 17's semantic eligibility rules. Captions complement visible attack posture, preserve mute/mono access and never expose hidden enemies. Following a guideline is not evidence that this game is accessible to everyone; actual users must review it.

## The shared boundary: M0 first, C later, story after that

The coordinator's latest [role 20 clarification](Research2_Quality_Playtest.md#coordinator-clarification-critical-path-and-four-unperformed-fixtures) governs this report where older specialist examples differ. **This is unapproved paper scope, not a frozen, implemented or user-accepted fixture.**

| Stage / P | Current paper contract | Narrative consequence |
|---|---|---|
| D_light | Separate image diagnostic using the inspected calibration shell, V1–V4 and controlled targets/treatments. | No story claim. A static preferred image cannot establish fair gameplay, route learning, spatial audio or enjoyment. |
| M0 | Hold anchored with a committed target point and clear-shot release; Cross directly approaches, commits to a short bounded movement/attack, then recovers. Two neutral weapons: immediate precision and close spread. Abundant finite ammo proposed, no scarcity, heavy/area tool, new faction mechanics, required pickup, key or compulsory clear gate. Teach Hold, Cross, then both. Dry cues as declared; score and ambience disabled. | No protagonist, villain, narrative pickup, themed sky, lore, bespoke weapon trick or environmental reveal is required. Do not rename the neutral actors into a candidate's cast and claim its fiction has been tested. |
| C | Proposed flat S–T–P–M–X spine; ordinary optional O attached to M. Both weapons owned from S for initial spatial/resource comparisons. No initial mandatory key, secret, clear condition, moving geometry or weapon-unlock beat. Exit with survivors permitted. Dimensions, placements and resource quantities remain open. | First C navigation is neutral. A later approved world wrapper can keep this graph while assessing a complete experience; it is a separate trial, not isolated proof of narrative superiority. |
| Later authored slice | Selected world, art and sound plus reliable C, followed only by justified door/credential/secret/elevation/new-role fixtures. | A brief motive, visible place function, two clues and an exit consequence can earn expansion. No campaign implementation follows from this paper report. |

**P exact shell recommendation copied from role 20:** 24×20 outer footprint; floor Y0, ceiling Y5; .4-thick perimeter; divider Z5–6, west wing X−12–3 and east wing X6–12, leaving gap X3–6; center solid X−2–0 / Z0–2.5 / Y0–5. This is **full-height center cover**, superseding the older waist-height M0 illustration only as an unapproved paper recommendation. It supplies a genuine sight break without crouch/elevation. Its occlusion/dogleg may hinder gameplay exposure; if so, change the gameplay room openly and retain D_light as the original diagnostic. Do not decorate this reused shell into a production set or call the rejected calibration concept accepted.

**Still to freeze:** exact feet/camera/facing/safe start; collider radius/height and camera offset; speed, acceleration/stopping/sprint, aim/pitch/FOV; actor placements/body/awareness/tell/commit/release/recovery/HP/damage/interruption; gun damage/range/spread/cadence/ready/switch; ammo quantities/caps/reset; exit/survivor rule; tick/seed/RNG/event/cancel order; neutral material/light/actor/UI/FX; dry banks/useful onset/gain/caption eligibility; supported output/capture and build/content identity. A suggested 600 ms spread recovery in roles 11–13 is a timing specimen, not a chosen balance value. Narrative supplies none of these defaults.

## Package A — The Taking

**Pitch:** an armed property buyer is dismantling a living city district by district. You are the municipal breaker who was ordered to prepare your own neighborhood for demolition. You turn the demolition route into an assault route and fight toward the buyer's removal crews before the next block is taken.

### Player, motive and antagonist pressure

The player is a practiced demolition worker with a service firearm and access to a confiscated clearance gun. Their job explains confidence with recoil, route knowledge and damaged masonry; it does not add a repair minigame, tool inventory or physics grab. An optional short opening line gives the motive: **“They bought the street. We still live here.”** A plain objective says **Reach the block's removal yard**. The player remains active, with no compulsory voiced performance or cinematic. Their former employer publicly labels obstructing residents and this worker an **eyesore**; that is a possible title connection, never a HUD resource.

The antagonist is a specific human purchaser who knowingly buys occupied districts and uses a private armed force to strip useful buildings while leaving residents stranded. This is deliberate coercion, not a misreading evacuation AI, false map or broadcast-ledger mystery. First pressure is local: disciplined seizure crews already hold the route. Later pressure is territorial: progressively richer districts are being turned into depots for the next seizure. Authored aftermaths and changing orders show this escalation; there is no real-time destruction simulation or hidden deadline punishing exploration.

The first visible evidence is ordinary life crossing the seizure boundary: a communal table set on one side of a cut building joint; numbered demolition marks carried through inhabited doorways; the same detached balcony panel stacked for sale in the yard. The marks indicate history/ownership, not interactive targets or damage weak points. A clue can be understood as “someone is removing this home” without reading a legal document. The eventual campaign choice is to stop the purchaser's capacity to seize, not collect paperwork until a voice explains the injustice.

### Enemy families, arsenal and escalation

| Candidate family / P | Physical identity and first mapping | Later decision, only after its own mechanics review |
|---|---|---|
| Claim gunner | Tall narrow human, projecting stake-launcher held away from torso, broad empty arm/tool gap. Braces at an anchor, visibly sets the axis, launches one readable weighted capsule. **Hold skin later; no hitscan rifle is silently substituted.** | Two known lane threats at offset positions can ask which lane to break first. True repositioning waits for navigation. |
| Breach hand | Low human fighting posture, broad split forearm pads and exposed legs. Sets feet, separates front masses, makes a bounded direct attack and plants to recover. **Cross skin later.** Pads are clothing/protection imagery, not bulletproof shield rules. | Different approach angles around real cover create pressure without higher HP. A faster lunge requires a swept actor/collision fixture. |
| Later removal anchor | Wide horizontal harness and a visibly planted firing assembly; silhouette differs from the upright gunner. | A sustained lane followed by a long recoverable move is a possible third verb. No armor, support command or area weapon enters until it has a distinct counter. |

Weapons are recognizable guns with original mechanisms, rather than harmless tools relabeled as guns. **Precision:** narrow offset barrel spine, dark enamel housing and a short visible axial slider; exact trace/cadence comes from mechanics. **Spread:** low broad outlet, guarded underbar return bar, one substantial down/back recoil and a hand return below the reticle. No dual-barrel Doom silhouette or Boltgun-sized receiver is proposed. Fire/ready sounds match actual events; a drawing of a cartridge slot does not require reload gameplay.

Initial themed C keeps both weapons from S. In a later campaign, the precision gun serves distance and the spread gun makes entering close space worth the recovery; introducing it after a safe demonstration is an independent unlock-timing experiment. A visible bounded area projectile could later clear a defended lane, only if role 03's ordinary two-gun baseline has earned expansion. No marking, ricochet, explosive wall destruction or target-material signature is required. Progress from residential court to stripping depot to purchaser's public auction complex changes cover/sightlines and authority, rather than repeat “same guard, more health.” A final yard siege/boss is a later authored encounter, not a task to kill every generic worker.

### Space, material and tactical light

| Plane / P | Authored grammar and consequence |
|---|---|
| Floor | Large warm aggregate slabs; wide repaired seams and swept travel wear. Quiet center lets low Cross silhouettes and spread recoil read. Seizure cuts stop at actual solid boundaries rather than resemble pits. |
| Wall | Pale plaster over thick blue-gray structural ribs. Missing facing exposes broad construction layers; one stepped joint around doorways identifies this city. Dense notices live only in recovery pockets. |
| Ceiling | Thick transverse ribs and matte undersides; darker than walls with enough value to read height. No pipe carpet or decorative crawl vents. |
| Sky/backdrop | Clear dusty blue with one unmistakable stepped civic silhouette. Daylight violence is the emotional hook. Distant demolition silhouettes are background until a playable geometry capability exists. |
| Elevation | Later broad stairs to a gallery, loading ledge or roof court offer genuine upper/lower shot choices. In first C all support stays flat; painted risers, fake climbable scaffolds and mandatory jumps are excluded. |
| Light | Role 08 broad architectural fields are a plausible match: readable fill plus large canopy shadows, protected combat values and warm practicals at local controls. A required hostile tell cannot vanish when the purchaser's lights go out. If broad-field differentiation fails, use the simpler neutral system with this material grammar. |

Cover is thick structural wall remnants with visible footprint, never paper notices or noncolliding furniture. Prop life clusters outside dodge lanes; the player should feel they are fighting through occupied civic space rather than a construction asset showroom. The palette proposal is chalk, muted blue-gray and dark cloth, with hostile tell and usable-state accents assigned only after roles 00/08/09/10 resolve conflicts. No automatic cobalt-route/vermilion-hostile convention is selected here.

### Original sound, score and interface

**Weapon masters:** acquire fresh dry blast/impulse takes with distribution rights, author the precision attack as one compact release with an enamel body and the spread attack as a broader physical body plus a separate real return-bar performance. Layer selection must preserve the source transient; it is not the rejected firearm+sine/metal processing pack. Original recorded clamp/wood/padded-plate impulses can challenge the dry control under role 13's Struck Mass method. Human listening decides whether these actually feel like dangerous guns. Do not add demolition ambience to make a weak blast sound substantial.

**Enemies:** separate performed awareness effort, two-part Hold brace, Cross load/exhale, release, interruption and death; use distinct voices/performance, not one growl pitched into a roster. Brief human calls can reveal deliberate seizure, but essential attacks read through posture and nonverbal action even with speech off. No inherited Wolfenstein bark, military chant or universal whistle signature.

**World:** recorded textile flaps, shoe weight on aggregate, distant cart wheel/load settling and occasional ceramic household contact. Localized work activity recedes in P, leaving a recognizable empty street and one domestic detail. No furnace loop, constant metal drone, randomized threatening crash or audible clue that promises a hidden spawn. A disabled sound is not fictional silence; delivery status remains separate.

**Music:** propose clipped picked-bass/drum propulsion with one dry low reed answer and controlled electric sustain; a short original question/answer motif suggests purposeful retaliation. First compare role 15's common motif arrangements; this package does not select Cut-paper propulsion by its label. A later full composition can become more forceful through register and phrasing at M, then leave real space in P/X. Avoid jaunty civic whimsy and a Doom-style traced metal riff. Combat score follows legitimate engagement and warns neither of unseen reinforcements nor false victory.

**HUD/map/access:** Field Margins is a plausible visual match, with the stable essentials information retained: **Health**, **Precision / Spread**, actual ammo and ordinary objective text. The explored map may resemble a building survey but cannot become a confiscation ledger revealing the whole city or O. Threat captions use **Gunner preparing — left** / **Runner preparing — right** after recognition; generic ranged/approach labels remain available. Essential captions preempt purchaser speech. High-contrast opaque UI, larger text, muted/mono, reduced motion/flash/gore and rebinding must preserve the same state truth.

### A later world wrapper for C

| C node / P | Meaning without changing baseline topology or combat |
|---|---|
| S | Resident service court; see the distinct removal-yard exit structure through a solid opening. Brief objective; both weapons owned. |
| T | Building-stripping court; learn the gunner, then breach hand, with two routes around cover. |
| P | Protected public wash passage; inhabited place evidence contrasts with numbered removal marks. Optional one sentence, no interaction needed to proceed. |
| M | Loading court; known pair around asymmetric structural cover. Onward route visibly open; no simulated moving crane or compulsory demolition. |
| O | Open side storage with optional supplies and a removed home fixture. It is an ordinary detour, not a hidden secret. |
| X | Removal-yard vestibule; entering the threshold ends this slice and frames the next assault. Actual sabotage/world transformation waits for interaction support. |

**Desired feel:** brisk indignation and physical competence; substantial shots in bright open courts, then a brief sting when the familiar household evidence returns. The player reads danger, cuts through it and keeps moving.

**Derivative risk and revision:** “worker versus evil corporation” is familiar; a rail depot, security helmets and expose-the-ledger ending would merely rename Red Mile. Revision: retain intentional physical seizure, inhabited buildings as saleable pieces, daylight public rooms, visible construction anatomy and an assault objective. Remove rail/tower/broadcast plot, omniscient dispatch AI, black armor and generic soldiers with colored rank badges. **Remaining weakness:** human opponents and civic slabs could still feel like any dystopian FPS. Reject or rework the package if the unlabeled scene/clue is described only as “warehouse guards,” or if the strongest enjoyment comes solely from a speech about the buyer. It must offer a compelling image and fight with that speech muted.

**Feasibility/dependencies:** static flat courts and two readable human poses fit the smallest later art effort, but manually drawing lowered human anatomy consistently across facings is not free. Destruction is authored evidence initially, not simulated architecture. Multi-room navigation, weapon state/event truth, RGBA import, world-fixed lighting, sky, package/capture and semantic captions need the chosen engine/pipeline. Campaign crowds, civilians, demolition physics, auction scripting, squad commands and rooftop routes are deferred. If the premise requires any of those to become understandable, its proposed small slice is too ambitious.

## Package B — White Hunger

**Pitch:** the springs of a high dry plateau have become nesting sites for pale mineral-shelled predators. You are a range warden who knows the migration roads. You fight upstream through terraces and covered spring houses to reopen the only watering route before the next seasonal journey.

### Player, motive and antagonist pressure

The warden carries a range firearm and a broad brush gun; they are a dangerous professional, not a helpless researcher discovering an alien lab. The objective is tangible: **Reach the upper spring**. A hand-placed departure marker, drained troughs and abandoned harnesses establish who needs the route. An optional opening line is **“No spring, no way across.”** No caravan escort, thirst meter, survival crafting or timed drought simulation enters the slice.

The antagonist is the **White Matron**, a dominant territorial predator directing pressure through its physical nesting territory, not a sentient queen remotely controlling a hive. Smaller animals persist if it dies. The campaign follows increasingly defended spring territory, then a confrontation that creates a safe passage; it does not reveal a central research apparatus or organism wearing missing humans. The player can observe a concrete progression: scrape tracks at a trough, thick nest deposits over irrigation walls, then deliberately guarded approaches. These are still wild animals with habitat behavior; attack-capable animals get consistent tells rather than arbitrary ambush realism.

“Eyesore” could be the local name for the new chalk-white nest lesions across maintained terraces. Keep that as spoken/optional world language, not glowing eyes or a mandatory optical metaphor. The proposed body horror is material and joint tension: shell, leathery support and awkward weight, with optional restrained fluid response. Avoid human faces, elongated human limb arrays, exposed spines and Necromorph-like dismemberment. Whether that degree of creature horror appeals remains a user decision.

### Enemy families, arsenal and escalation

| Candidate family / P | Physical identity and first mapping | Later decision, only after its own mechanics review |
|---|---|---|
| Spoutback | Narrow upright body on clearly separated support legs; one lateral neck/throat structure projects away from the central mass. Braces over a feeding/nest station and expels one visible coarse mineral pellet along its committed axis. **Hold skin later.** No spores, homing or perfect lead. | Offset nests make crossing a lane matter. Anchor relocation or ledge attacks require support/navigation capabilities. |
| Knuckle grazer | Broad low wedge, two front contact masses and a leathery underside; walking is distinct from lowering and opening the front before a bounded rush. **Cross skin later.** “Grazer” is ecology, not harmless disposition. | Approach combinations force lateral decisions. A long fast charge is not promised by the art or fictional strength. |
| Later nesting blocker | Horizontally wide animal with a broad folded shelter mass, unmistakable from the low wedge and upright spoutback. | A short, telegraphed lane obstruction/attack then exposed recovery could change route choice. It cannot create physical walls or armored weak points until those rules are approved. |

The palette can make the body pale, but whole creatures are not emissive; undersides, support gaps and directional posture separate them from pale stone. A damaged shell does not imply an armor-break mechanic. Ordinary hits are cosmetic contact plus truthful pose/action outcome. Death folds support and closes the projecting organ, leaving a clear nonattacking corpse. Corpses remain nonblocking in the early baseline.

**Precision gun:** long slim spine, off-axis short counterweight and dark grips; a clear compact recoil shows range competence. **Spread gun:** low crescent guard around a straight broad working edge, braced by the support hand, with one opposed return action below the target lane. These are candidate Counterweight Arms appearances on ordinary mechanics, not resonance guns, pressure tools, bouncing projectiles or charged aim puzzles. Heavy bodies and convincing impulses must survive muted visual review and dry listening independently. Both guns start owned in C; later separate ammo/unlock review may make a scarce launch capsule useful against dense nest approaches. An area projectile remains an optional later orthodox role, not an M0 requirement.

Level progression changes habitat and space: maintained trough court → terrace retaining passages → shaded spring houses → exposed high nesting ground. Known roles recur with useful sight breaks and different approaches; scarce resources, vertical fights and the Matron are later discrete additions. No automatic difficulty increase through larger HP shell variants. The final predator can combine learned verbs with readable intervals only after boss body/trace/animation/encounter support exists.

### Space, material and tactical light

| Plane / P | Authored grammar and consequence |
|---|---|
| Floor | Broad compacted ochre paths and smooth worn limestone paving. Nest deposits sit along nonwalkable edges and have opaque thickness; a white crust does not become damage terrain from its texture. |
| Wall | Large pale retaining blocks alternating with dull umber spring plaster; quiet dark recess backdrops support pale bodies. Mineral nest seams follow a different rounded support rhythm from human joints. Avoid universal orange cracks. |
| Ceiling | Low masonry spring-house vaults or heavy woven shade bands, each with a readable underside. No dripping fleshy ceilings or endless cables. |
| Sky/backdrop | Large faded blue above a hard pale plateau edge and a distinct stepped mesa notch. No observatory dome, coastal storm, desert worm skyline or neon planet. Dust is occasional background, never opaque combat fog. |
| Elevation | Real terraces eventually give broad stairs, raised troughs and one safe descending route. First C is a level route through terrace architecture; distant terraces are backdrop. No fake climbable cliff or jumping requirement. |
| Light | Broad daylight under broken shade; warm ground and cool reflected fill can make shelter feel different while preserving tell support. Dark body planes remain visible under a canopy. Moving shade cloth does not flicker across a lethal cue. Neutral fill remains a valid lower-cost alternative. |

Springs are evidence and destination initially: a narrow nonwalkable water strip can be visual/audio decoration with a declared boundary. Swimming, draining, wet physics, reflective water and traversable hazards are separate capabilities. If a combat route crosses water later, its support/hazard/audio semantics must be explicit. Fixed salt/stone cover cannot disappear when a shell is hit.

### Original sound, score and interface

**Weapon masters:** new dry impulses with a short wooden stock/cavity body, coarse broad spread attack and restrained spring/counterweight mechanism recordings. Mineral target contacts use separate ceramic/stone friction/impact foley and damp underside contacts only where the resolver declares that material. A brittle garnish may challenge the dry source under role 13's Fractured Light vocabulary, but the gun must still have a convincing broad physical body; glassy treble and volume cannot supply force. No boiler pressure hiss on every shot, generic animal roar over gunfire, or borrowed game sample.

**Creatures:** separately perform Spoutback's scraping set then held hollow exhale, Knuckle grazer's broad effort plus grounded joint set, release, unloading, pain/interrupt and terminal support collapse. Record membrane, dry gourd/cavity and coarse ceramic-contact experiments with documented performers/sources. The brief demands a threatening animal rhythm; no synthetic descending warning tone or one pitch-shifted human voice across all species. Pre-release warnings share actual state/cancel timing; mouth noises do not imply imminent attacks during idle behavior.

**World:** sparse wind through specific shade openings, strap/harness movement, stone contact and an audible trickle at the known spring approach. Short quiet pockets expose the missing water and nearby grounded movement. A dry basin has a different bed from the upper spring; no generalized windy hiss across every room. Water sound can reinforce a destination but cannot be its only navigation cue or reveal unobserved route geometry.

**Music:** propose an original low electric line with plucked pulses, broad drum accents and rounded mallet answers. It should feel stubborn and physically propulsive, with rests around the throat/brace tells; avoid default cinematic desert drones or imitated regional music as location shorthand. A later score can grow through register and harmonic pressure rather than endless distortion. Role 15's fixed-motif arrangement test can compare a sustained palette with clipped and quiet alternatives before a full White Hunger composition. No actual melody or audition exists yet.

**HUD/map/access:** Stable Essentials or Field Margins with plain functional text is plausible; a warden identity need not shrink health into a compass gadget. The explored map labels **Spring house** after observation, keeps the upper spring objective simple and never marks unseen nests or a Matron position. Caption labels can be **Spoutback preparing — left** after recognition, with **Ranged creature preparing** as the plain-language option. Shell flecks/low gore retain hit/interrupt/death clarity. Reduce piercing crackle independently of warning intelligibility; mono, muted captions, high contrast, larger reticle/text and reduced cloth/camera movement require human review.

### A later world wrapper for C

| C node / P | Meaning without changing baseline topology or combat |
|---|---|
| S | Range shelter overlooking the distinctive upper spring-house entrance through a solid gap. Both guns and simple objective ready. |
| T | Maintained trough court; one anchored Spoutback then visible Knuckle grazer. |
| P | Shaded bend with drained trough and discarded travel harness; protected next-room preview. No mandatory note or thirst event. |
| M | Covered spring approach; known pair, real retaining cover, two usable flat local lanes and open onward route. |
| O | Open side service alcove with optional supply and a nest trace. No required seed collection, secret or puzzle. |
| X | Upper spring vestibule; water/source landmark reframes the dry approach. Threshold ends the slice; restoring flow and Matron confrontation are later capabilities. |

**Desired feel:** exposure, speed and resolve; chunky guns against pale weight-bearing animals in spacious daylight, short uneasy shelter intervals and a concrete sense of moving upstream. Horror comes from recognizing nesting behavior in a place people rely on, with combat maintaining agency.

**Derivative risk and revision:** desert creatures, hidden nest and a queen can collapse into generic alien infestation or familiar sand-war fantasy. Revision: keep settled irrigation and migration livelihood, independent animals, a territorial Matron rather than hive control, mineral/leather construction, no human assimilation, worms, insect swarm silhouettes, research lab or prophecy. **Remaining weakness:** pale rocky beasts may look like reskinned fantasy golems, and ecology may fail to provide a memorable antagonist. Reject/rewrite if the player recalls only “stone monsters in a desert,” cannot see why the spring matters, or if strong tension requires compulsory darkness. A clearer human sponsor could later enrich motivation, but turning that sponsor into another purchaser would collapse A/B's distinction.

**Feasibility/dependencies:** the first habitat can be static and flat, with two body/action sets. Creature anatomy demands a stronger turnaround/facing source than improvising disconnected sheets; rig-to-sprite is a candidate workflow, not selected technology. Moving cloth, living nest growth, water physics, particle weather, roaming fauna, climbing and a giant Matron are deferred. Exact body height, projected tell pixels, shell material mapping, source/performance quality and pale-actor lighting are high-risk review dependencies. Do not make dismemberment necessary to read damage.

## Package C — The Tribute War

**Pitch:** a ruler's funeral has become the successor's military takeover. Gifts that the city was forced to build for the procession are marching as armed effigies. You are the dismissed household gunner, fighting through tribute courts toward the command standard before the new ruler can send the procession into the rest of the country.

### Player, motive and antagonist pressure

The player once defended the household, then refused the successor's order to fire on mourners. Their arms and route familiarity make them capable from the first shot. The immediate objective is **Reach the procession standard**. An optional line is **“The gifts are coming back armed.”** The protagonist can remain unnamed and mostly silent; a personal dismissal token or damaged cuff communicates history without requiring a character creator or long dialogue.

The antagonist is the living **Successor**, who commissioned purpose-built tribute bodies and is using the public funeral's assembly as a conquest force. Their power is a fictional binding embodied in a physical command standard. This is a secular dynastic technology/magic convention, not a hidden cult, resurrection of the dead ruler, recording of past events or organism replacing mourners. The player fights new constructed bodies, not possessed human victims. People made these gifts under coercion; craft labor explains seams, different materials and the shocking reuse of familiar objects.

First evidence: a recognizably noncombat tribute animal still on its plinth, an identical fabrication with added weapon cradle in T, and empty attachment sockets on the recovered pedestal in P. The inference is “they turned our gifts into soldiers,” not “a mystery machine has copied someone.” Distant static procession silhouettes communicate force; crowd simulation, a moving parade and an invisibly advancing clock are unnecessary. “Eyesore” could be the successor's name for the player's deliberately unadorned service uniform in a regime obsessed with display; reject that title connection if it feels forced.

Breaking the standard is a later objective interaction/boss result. The first C slice only gets the player to its vestibule. No wrapper claims the standard has already been destroyed, no mandatory shot-at-a-glyph puzzle is inserted, and killing one figure does not silently kill all constructs unless an explicitly reviewed later rule says so.

### Enemy families, arsenal and escalation

| Candidate family / P | Physical identity and first mapping | Later decision, only after its own mechanics review |
|---|---|---|
| Bearing figure | Tall narrow effigy: layered textile body, visible rigid support, side-mounted tribute tube separated from torso by a large gap. Braces, unfolds the tube axis and throws one visible shot. **Hold skin later.** | Offset anchored figures form a recognizable defended court. No animated banner becomes a homing attack, shield or teammate order. |
| Folding beast | Low broad constructed animal; two forward masses, coarse hinge/support line and solid feet. Compresses/opens front masses before direct bounded attack, then visibly settles. **Cross skin later.** | Familiar closing pressure in a richer court. A leap, disassembly or reassembly mechanic remains deferred. |
| Later load bearer | Wide empty-centered frame carrying a single large mass; permanent negative space distinguishes it from the first two. | A prepared throw or advancing attack with a clear recovery can be a third role. No unkillable parade wall or puppet swarm enters the initial slice. |

No effigy is a cultist in a hood. Faces are optional coarse plate forms; role identity rests on torso/support/weapon axis, not glowing eyes. Use thick opaque construction and heavy stops so the enemy feels dangerous rather than a weightless paper toy. Ordinary impact can show textile compression, ceramic contact and restrained temporary accents; the surface cannot peel into a weak state merely because a hit looks dramatic. Death collapses the support arrangement and drops the active tool; reanimation is not a baseline gimmick.

**Precision gun:** an unornamented household carbine with a narrow exposed action, dark satin body and one pale structural plane. **Spread gun:** a low broad service salvo gun, common firing/support hands, guarded moving plate and one heavy return action. It is a lethal firearm rather than a party cannon. The contrast with ornate effigies gives the player identity; no sacred weapon, runes, skull furniture, oversized power armor or spinning mechanical flourish is needed. Both guns inherit the reviewed ordinary trace/fan mechanics and start owned in C. Later launch ordnance may give deliberate area pressure in wider courts; its unlock, ammo and recovery are separate proposals.

Campaign progression can move from public gift yards to covered mourning walks to an inheritance hall and finally the standard court. The same construction families gain different silhouettes/jobs before new mechanics are added. Escalation is the conversion from gifts into organized force, expressed through placement and apparatus; it is not every opponent becoming a larger version with higher HP. A later standard guardian could combine learned attacks, but boss binding/destruction and world changes wait for stable interaction/event support.

### Space, material and tactical light

| Plane / P | Authored grammar and consequence |
|---|---|
| Floor | Broad dark plum stone and chalk inset strips aligned with genuine routes; no patterned carpet across every dodge lane. Route markers use shape and position, not a magic glowing ribbon. |
| Wall | Thick overlapping painted plaster/mineral slabs with coarse double-cut edges; pale cross-sections make solid depth visible. Decorative textiles hang in protected bays, leaving calm actor backdrops. |
| Ceiling | Large folded shade/canopy planes with clearly solid overhead supports. No Gothic vault forest, chains, occult symbols or unreachable climb affordances. |
| Sky/backdrop | Muted lavender evening above a coarse angular civic roofline; dark cavities stay outside the active target plane. The funeral palette is vivid and matte rather than black/red religious horror. |
| Elevation | Later generous ceremonial steps and overlook galleries create real two-level shots. Initial C remains flat; relief art is not a stair or passable balcony. No compulsory platforming. |
| Light | Role 08 structural plateaus are a plausible match: calm foreground, legible middle combat field and distinct back plane. All reachable rear/side views must work; a single staged beauty camera is insufficient. No lantern outage or strobing cloth shadow removes active tells. |

This is a possible Painted Eclipse/layer-and-cut pairing, not selection of those reports' palette or lighting algorithm. Its material thickness and heavy body animation must survive a diagnostic palette swap; otherwise it is merely colored paper. Shadows, fixed illumination and actor light response are authored world data, not giant silhouettes painted onto surfaces pretending to be solid enemies. Props do not silently become weapon-proof cover.

### Original sound, score and interface

**Weapon masters:** newly selected dry broad impulses and separately performed short action/return sounds; dense wooden/mineral cavity body can contrast with the softer effigies. The restrained carbine attack must remain a gun, the salvo gun must remain one unified release, and neither gets festive brass, an entire cannon tail or a borrowed sacred choir. Role 13 dry control/Struck Mass/Fractured Light remain independent audition choices; visual paper does not require tinkling paper-like gun audio. Human review must reject thin craft foley masquerading as weapon force.

**Constructs:** record heavy fabric tension, rigid joint stops, rubbing broad wood/composite masses and short resonant cavity air. Distinct Hold two-part set/hold and Cross single grounded compression establish attack rhythms; release, interrupt and collapse use different performances. A restrained nonhuman exertion can be authored from original performed sources, without human death screams implying there are bodies trapped inside. Avoid nursery-toy clicks, one metallic note for every hit, whisper choir or reverb making every warning distant.

**World:** localized canopy cloth/load rope creak, heel/foot weight, one empty pedestal's coarse contact and occasional remote procession hardware. Quiet P leaves an unsettling lack of public celebration; it does not need a false enemy groan or random scare. Long returns belong to an actual hall preset after engine/acoustic support; score creative return remains separate. No constant industrial drone or church bell convention.

**Music:** original low bowed/plucked electric voices, dry drums and clipped chamber answers, with forceful irregular accents inside a stable pulse. The writing should sound imposing and resentful, never whimsical, a familiar royal march or chanting ritual. Start with role 15's same-motif arrangement pass, then assess a full composition's density/phrase on C. The standard reveal may transform the motif later; no music state is the only explanation of what the effigies are. One mixer-owned threat envelope protects tells, rather than baked ducking plus a second score duck.

**HUD/map/access:** Instrument Rail is a plausible appearance on the same health/ammo/state information, with plain labels and digits; ceremonial border shapes cannot replace reading. The explored atlas uses actual area boundaries, not a decorative procession plan showing unseen courts. Plain captions **Construct preparing — left** can remain until the player recognizes Bearing/Folding roles; subtitle speaker labels identify any successor speech without crowding threat rows. UI scale/opacity, low-vision contrast, muted/mono warning access, reduced particle/cloth movement/flash and low gore must preserve state and route meaning. Decoration cannot turn essential prompts into heraldic riddles.

### A later world wrapper for C

| C node / P | Meaning without changing baseline topology or combat |
|---|---|
| S | Public gift court, standard-court vestibule visible through a solid aperture; guns ready and plain objective. |
| T | Assembly court; Bearing figure then Folding beast, beside a noncombat gift that establishes their origin. |
| P | Protected mourning walk; empty pedestal/socket and discarded procession instructions give the armed-gift clue. Reading is optional. |
| M | Tribute yard; known pair around thick layered cover, two flat lanes and open onward route. No moving float or reassembly system. |
| O | Ordinary open packing alcove; optional supplies and a clear construction detail. No secret mask collection or ceremonial key. |
| X | Standard-court vestibule; frame the physical objective and end the slice at its declared threshold. Destruction/release consequences belong to later interaction work. |

**Desired feel:** forceful trespass through a grand public ceremony made hostile; heavy mundane guns breaking thick crafted bodies, sharp silhouettes changing as the player circles, short mournful valleys and an aggressive push toward a visible authority.

**Derivative risk and revision:** funeral, effigies and a command standard could become DUSK-like cult horror, a haunted palace or a 40K-looking sacred army. Revision: a living political antagonist, newly manufactured nonhuman tribute bodies, public civic spaces, vivid matte construction, secular coercive labor, no resurrection, hooded fanatics, skulls/crosses, chanting, cathedral geometry or recording/replay premise. **Remaining weakness:** cursed objects in a stylized court can still feel familiar, and lore explaining a binding may be too abstract. Reject or simplify if players infer only “haunted puppets,” if the gunner's task requires a magic exposition speech, or if material craft reads as comic toy destruction. The actionable villain/standard must remain clear even if the binding's origin is never explained.

**Feasibility/dependencies:** rigid multi-part effigies suit a consistent model/pose-to-sprite source, but heavy cloth follow-through across views and edge thickness at tactical pixels are substantial art tasks. Whole creature/weapon/lighting packages cannot be bundled into an alleged same-body material comparison. Animated cloth, crowd/parade simulation, reassembly, teleportation, many coordinated effigies and large moving carriers are deferred. Static backgrounds, two heavy bodies, one supported light grammar and a plain objective must already carry the premise.

## Cross-discipline decisions, disagreements and dependencies

This integration inspected the 00–20 reports and their coordinator revisions as domain evidence. Older examples remain history where later clarification narrows M0/C. This table records what the story proposals consume, and where they disagree with an attractive but premature expansion.

| Role / report | Shared agreement consumed | Story disagreement or remaining dependency |
|---|---|---|
| [00 Art direction](Research2_Art_Direction.md) | One image grammar, value/scale hierarchy; Civic Daylight and Painted Eclipse are alternatives. | A's daylight and C's layered staging are plausible pairings, not automatic choices. B is not simply Civic Daylight recolored sand; its anatomy/retaining construction must differentiate it. Do not multiply every world by every art option as a mandatory tournament. |
| [01 Engine](Research2_Engine_Architecture.md) | Native FPS working target; bounded C++/Godot feasibility comparison, one authoritative geometry/event truth. | No story selects Godot, a sector port, middleware or a Doom-derived runtime. Versions and license/product decisions are owned by the engine/release review, not copied here as current guarantees. |
| [02 Movement](Research2_Movement_Aiming.md) | Direct arena response is a first hypothesis; exact body/aim/speed and comfort unresolved. | None of these protagonists requires sprint stamina, dash, jump, climbing or impaired survival movement. Hero competence does not choose acceleration or camera shake. |
| [03 Weapons](Research2_Weapon_Mechanics.md) | Two ordinary neutral roles first; novelty may come from original world/art/sound. | Older three-role/exotic/witness-mark examples do not enter M0. Candidate gun silhouettes cannot create charge, reload, bounce, mark or material weaknesses through their appearance. |
| [04 Enemies](Research2_Enemy_Behavior.md) | Hold/Cross commitment and recovery; no homing/omniscient tactical flank. | Candidate families are later skins with unchanged initial semantics. Route Crew/Returned Routine do not constrain new worlds. Human slow projectile fiction needs a visible launcher, not an undodgeable rifle. |
| [05 Encounters](Research2_Encounters_Difficulty.md) | Abundant M0; C both weapons from S, survivor exit; economy variables isolated. | A demolition deadline/B dry season/C procession are narrative pressure, not real timers or scarcity rules. Later economy cannot be attributed to world preference. |
| [06 Levels](Research2_Level_Design.md) | C folded spine, protected preview, optional O, genuine sight connection versus traversable edge. | World wrapper is not a substitute for neutral first navigation. Its showpiece terrace/gallery/moving yard waits; a map that only works because narration gives directions fails its layout question. |
| [07 Interactions](Research2_World_Interactions.md) | Simple trigger/condition/effect/feedback/reset, one authority; extend only when needed. | Reaching X is enough for the first wrapper. Stopping removal/restoring water/breaking binding is an eventual story consequence, not a hidden M0 switch/door/key implementation. |
| [08 Lighting](Research2_Lighting.md) | Neutral, broad fields and plateaus are proposed controlled treatments; protected threats; all legal views. | Bright A/B and evening C are emotional proposals, not altered baseline values. Story outages never remove legal reaction cues. Merge treatments if their claimed image differences fail. |
| [09 Environment](Research2_Environment_Art.md) | Separate material/surface/state, real support/cover/sky/elevation; projection decides density. | Residential marks, nest lesions and standard decoration have no inherent collision/damage/interaction. Wear must show use at broad scale, not disguise missing geometry with textures. |
| [10 Creatures](Research2_Creatures.md) | Distinct low wedge/narrow trunk, facing/foot support, alpha/light contract; original Print/Clay alternatives. | A is human; B/C are independently authored nonhuman constructions. Their complete anatomy comparisons are not identical-silhouette experiments. Shell contact is not Dead Space-style dismemberment. |
| [11 Weapon art](Research2_Weapon_Art.md) | Release/kick/return/ready timeline, fixed projection/envelopes and tell masks; Service/Counterweight alternatives. | A service and B counterweight suggestions are not selected. C's plain firearm contrast may warrant a third art brief only if existing options fail. No larger gun or flash is awarded to a preferred story. |
| [12 Feedback](Research2_Combat_Feedback.md) | Resolver-owned contact/material/outcome, short contact constructions, truthful real state, muted review. | Effigy fragments/mineral chips cannot imply armor break, stun or weak point when only damage occurred. Physical heft can exist without gore or camera displacement. |
| [13 Weapon audio](Research2_Weapon_Audio.md) | New-source dry/Struck Mass/Fractured Light auditions; useful onset, release/contact separation, repeated cadence. | All candidate sound recipes are acquisition/composition briefs awaiting ears. Prose adjectives cannot approve force; a new name cannot rehabilitate rejected takes. |
| [14 World audio](Research2_World_Audio.md) | Distinct notice/tell/release/cancel/death; authored quiet, perceptible event cues; pause lifecycle. | Environment is not an omnipresent furnace bed or generic warning drone. No fake danger cue is needed to dramatize a protected clue. |
| [15 Music](Research2_Music.md) | Original common-motif arrangement pass then whole-score experience; authored states, meaningful silence. | Package palettes are possible full compositions, not evidence that one score arrangement is best. No per-shot musical stingers, tempo-driven fight delays or hidden-enemy disclosure. |
| [16 Audio engineering](Research2_Audio_Engineering.md) | One event packet; one threat duck; separate score/world returns; pause freeze versus mute; measured capture. | Do not complete a full custom portal DSP/adaptive system to serve story before engine choice. Dry source listening may progress independently; in-scene claims await truthful playback/capture. |
| [17 Interface](Research2_Interface.md) | Stable essentials, map knowledge distinct from physical world, semantic captions before volume, external preferences. | Flavor terminology never replaces Health/Ammo/Preparing. Map/clue captions cannot reveal hidden enemy/secret/remote state. Story speech gets lower priority than imminent threat information. |
| [18 Pipeline](Research2_Content_Pipeline.md) | Stable semantic IDs, one authoring truth; distinct structure/import/delivery/source/mix/user stages; actual package closure. | Character names/styles can change without IDs drifting. No bulk generation, complete bestiary, soundtrack library or new editor is earned by choosing a premise. |
| [19 Session](Research2_Session_Release.md) | Full retry/generation barrier, pause/focus/input truth, survivor exit; harness ready-paused distinct from player start. | No mandatory operator setup card, lore replay or dialogue recap on ordinary retry. Optional short opening can be skipped/replayed; preferences survive retries. Disk campaign saves remain deferred. |
| [20 Quality](Research2_Quality_Playtest.md) | Exact unapproved reused shell recommendation, profile freeze, staged fixtures, invalid/null/rejected results preserved. | M0 is narrow and may feel generic; that is not a reason to insert a world mechanic. Conversely, success in M0 does not select a story. Human whole-scene judgment must eventually supplement isolated diagnostics. |

### Single production dependency chain

**P:** paper profile freeze → matched engine feasibility/choice → canonical geometry/event/retry/input foundation → role 20 contact/clearance fixtures and package/capture identity → movement/Hold/Cross review → isolated image/feedback/sound integration → neutral C navigation → separately named resource/progression questions → selected complete world slice review. Dry original source/performance selection, story choice and concise sample briefs can proceed alongside the engine comparison; the new sources cannot assert fair in-game playback before those foundations exist.

After engine selection, decide actual import/color/alpha/filtering/renderer resolution and world-fixed actor light, supported sky/elevation/water/doors, audio backend and capture route, UI scaling/input, and authoritative content format. Until then the concepts are portable briefs with known optional extensions, not files to import. Exact pixel envelopes, light values, output gains, voice limits, supported machine budgets and combat parameters remain owner decisions validated in the agreed profile. Reference numbers and specialist bands are not final settings.

Use source masters, eight-facing/body guides, explicit pivots/alpha, authored event markers, original recording/performer rights and editable composition source. A rig/render/paint process can improve consistency; hand-authored sprites can also work if reviewed in motion. Neither workflow is selected by this report. The full release packet must contain the correct executable and every referenced resource/rights record and launch without source-tree fallback. Structural validity, successful import, runtime delivery, source hearing, in-game mix and user acceptance remain six different statuses.

## Concrete review packet and decision questions

**P review order:** present these three short pitches and the material/pressure comparisons first. Let the user choose one, request a revision, retain a pair for comparison or reject all. No weighted score or asset count ranks them. They differ in promise, not measured quality:

| Decision dimension | The Taking | White Hunger | The Tribute War |
|---|---|---|---|
| Player fantasy | Skilled local retaliation against deliberate human force | Armed route warden confronting territorial predators | Household gunner breaking a usurper's constructed force |
| Primary pressure | Inhabited places being stripped | Watering route becoming a nesting ground | Familiar public gifts becoming an army |
| Distinctive image | Bright thick civic construction and human work/fight postures | Pale shell/leather weight against shaded dry terrace masonry | Heavy layered tribute bodies against vivid matte public ceremony |
| Violence/unease | Human consequence; optional restrained gore | Nonhuman physical horror; no people transformed | Destruction of constructed bodies; mournful political threat |
| Main production risk | Generic guards; consistent lowered human facings | Original anatomy/tells on pale scenery; credible fauna/Matron | Toy/cult associations; thickness/weight and plot clarity |
| Later feature temptation to resist | Destruction/civilians/squad simulation | Water/weather/climbing/ecology simulation | Crowd/parade/cloth/reassembly simulation |

After a direction or bounded comparison is authorized, a **small future packet**, not yet produced, can include one silhouette/material scene composition and one representative gun/actor motion specimen at tactical pixels, a genuinely new dry gun/creature/world source audition, one original common-motif arrangement sketch, and a C-shaped playable wrapper only after the neutral foundations pass. Do not require three whole games, every pairing of style choices or a soundtrack before making a decision. Art/audio first samples may still reject the selected premise; preserve that possibility.

**Human art review:** assess a near/tactical/preview composition and legal front/side/rear motion, floor/wall/ceiling/sky separation, cover truth, all active tells and viewmodel/FX/UI masks. Ask what the place is used for and what changed before naming the candidate. No screenshot is approved merely because its palette matches this report. Complete world comparisons may change several linked art features; report them as complete experiences, not isolated material evidence.

**Human listening review:** fresh dry source at comfortable matched perceived level first; actual repeated cadence and warning-under-fire next; one new world layer, then score. Log playback/source/settings/capture truth and unprompted force/character/fatigue reasons. No source recording was heard here. Successful onset repair, measured peaks or captions cannot reverse the user's earlier creative rejection. If all new variants fail, return to source/performance craft rather than insist a more dramatic story will fix them.

**Human play/story review:** first navigation instruction is simply **Reach the exit**; then a separate complete-world run can use **Reach the removal yard / upper spring / standard court**. Do not coach the symbolic clue or demand a plot quiz while fighting. Afterward ask what the player was trying to do, what stood in the way, what the place was for, which attack they could predict, and which moment they remember. Record survivors/skipped clues and whether the player enjoyed moving/shooting independently of comprehension. A fast bypass is valid exit, not proof that the intended narrative/combat beats were experienced. First-visit knowledge is not restored by retry.

**P failure decisions:**

- If attacks/routes fail technical truth, repair their shared owner before judging the world. Missing capture/audio/import invalidates the affected review.
- If the place/motive is unclear despite readable combat, strengthen one visible cause/consequence or shorten the objective; do not add a lore terminal chain.
- If the world feels generic, change its material/body/pressure relationship or discard it; names, more props and extra enemies do not provide distinction.
- If story interferes with speed, remove the compulsory speech/use step and preserve the physical clue. If that erases its identity, reconsider the premise.
- If two packages converge in actual experience, identify the overlap and merge/reject the redundant one openly. Different pitch nouns do not require three final games.
- If both/all complete experiences are disliked despite technical correctness, retain the rejection. Human taste is a result, not a scoring error.

**Questions that make owner review concrete, without blocking this research:**

1. Which repeated fantasy should Eyesore sell: retaliation against people taking a city apart, a professional's assault through a predator habitat, or a gunner's attack on an armed tribute ceremony? Rejecting all three is valid.
2. Should the threat be principally human, bodily nonhuman or constructed nonhuman—and should gore be restrained, optional or central to the intended impact? The low-gore mode must preserve gameplay truth regardless.
3. Should the player remain mostly silent with a one-line motive, or have brief authored voice? Current proposal is mostly silent and no dialogue gate; a named character can be added later without changing M0.
4. Which evidence should settle the disputed promise first: A's occupied-building clue and human threat silhouette, B's moving shell/leather anatomy and spring motive, or C's heavy effigy motion and armed-gift clue? Choose the risky representative sample, not bulk asset production.

**Self-critique:** all three still use familiar spatial shooter roles and an assault destination. That familiarity is intentional for the basic shooter, but originality is unproven until the material/action/pressure relationship appears in a compelling assembled scene and the user hears/plays it. A and C both concern coercive human authority; their difference must survive the human-versus-constructed enemy experience and the public-space evidence, not merely the purchaser/successor names. B supplies the clearest nonhuman departure but has the weakest interpersonal villain; do not fix that by importing A's plot. The report avoids mandatory new mechanics, yet the final game's commercial identity needs more than a neutral room. A later complete, authored experience is necessary, and remains unapproved.
