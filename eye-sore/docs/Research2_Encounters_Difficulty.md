# Eyesore research round 2: encounters, resources and difficulty

**Role 05. Status:** research for coordinator review, 3 October 2026. No direction, numerical tuning, engine migration or production content is approved here. This pass changed this document only; no game code, assets, builds or tests were produced. Model allocation: GPT-6.1 Sol / medium.

## Decision summary

The current native FPS has a fixed three-group combat ladder. It increases enemy count and per-instance health, then gives a new weapon after every required clear. It has no finite ammunition, armor or healing economy. This structure cannot yet answer whether exploration, weapon choice, recovery and route knowledge make Eyesore satisfying. Making a much larger version of this ladder would preserve its underlying limitations.

Stage the comparison from ordinary precision / close spread weapons and projectile / pursuer roles; introduce an area weapon and anchor role only in later matched package trials. **Mechanics control M0** is one matched encounter with abundant ammunition, so scarcity is not a decision. **Shared map C, folded sequence**, is the level report’s five-space forward spine, with an optional alcove and a proposed 3–5 minute session. **Resource policy R1, persistent route economy**, makes saved resources matter across fights. **Resource policy R2, local pressure pulses**, makes placement and timing inside a combat court matter while dependable supplies between courts limit resource spirals. R1/R2 are resource/encounter policies; they are not the level report’s topology alternatives A/B. These are encounter policies, independent of names, factions, story and visual setting. They do not require the prior observatory, infernal, Glass Choir, Red Mile or Witness themes.

No resource policy is preferred before a matched test. M0 first establishes readable combat, then shared map C establishes the spatial baseline. Compare one resource rule at a time on C before broader R1/R2 packages. Only after those tests should the team judge whether persistent route planning or dependable local recovery improves the experience.

## Evidence labels and boundaries

**Project fact** means source was inspected directly. **Source fact** means the linked developer, publisher or original source establishes the statement. **Inference** means an interpretation that may fail in Eyesore. **Proposal** means an original design or tuning hypothesis. No commercial level budgets, enemy timings or damage totals are claimed without a primary source. I did not play commercial games during this task or inspect their shipped maps. Store descriptions establish broad features, not exact pacing rules. Live player enjoyment and fairness remain unmeasured.

Reports read: round tracker, reference direction, engine architecture, movement/aiming, weapon mechanics and enemy behavior. Related reports contain unapproved alternatives and are treated as dependencies to challenge, not canon. Native FPS is the current working product assumption; legacy browser/C implementations are distinct prototypes.

## 1. Current project audit

| Project fact | Direct evidence | Encounter consequence / inference |
|---|---|---|
| Fourteen hard-coded positions, health values and type indexes | `linux-game/src/engine3d.cpp:16`, `:42–44` | Content requires code editing; encounter composition and resource access cannot be reviewed as data today. |
| Group 1 has indices 0–2; group 2 has 3–6; group 3 has 7–13 | `setup_first_level`, progression block at `:432–436`, `:501–505` | Three, four and seven enemies form the whole combat ladder. Later groups materialize together when a pickup is touched. |
| First group clears before shotgun cache appears at `(0,0,12)`; second clears before arc cache at `(0,0,-12)` | progression block | Every combat group is mandatory for progression. A remaining unreachable enemy would prevent the next cache. Pickup both unlocks/switches weapon and starts the next group; reward and commitment are coupled. |
| Health array is `4,4,4,7,8,8,10,9,10,12,10,12,12,14`; the same type occurs at different health values | arrays at `:43–44` | Unsignaled health variation can undermine learned shots-to-kill. The proposal keeps a role's health constant until a clearly distinct variant justifies a change. |
| Native starts at health 100; damage subtracts directly; reset restores 100 | `:430`, `reset_combat`, melee/projectile damage blocks | No healing pickups or armor absorption in this path. Attrition is unavoidable unless the player takes no hits or restarts. |
| Native weapon firing has cooldown and health checks but no ammo counter/cost | `fire_player_weapon`, `:466–475` | Resource budgets do not exist in the main native FPS. Infinite ammo can support a valid game, but this prototype has not made that an intentional policy. |
| Standard pistol/spread fire are visual projectiles with damage 1/2.5; calibration uses hitscan with damage 3 per precision shot / seven 1.25 pellets; arc deals 4 | fire lambdas | A native economy cannot be balanced using the calibration's shots-to-kill. Weapon path unification is a prerequisite to a resource experiment. |
| Notice is distance based; ranged shots additionally require sight; every actor in an active group runs its update | `enemy_notices_player`, main AI loop | Activation is not governed by authored room logic; no encounter threat release schedule or spawn fairness policy is present. |
| Death reports fallen and R restarts the entire combat setup; last clear sets wave 5 and title to descent clear | reset and title blocks | No checkpoint snapshots, local retry, save/load or physical exit transition in this native path. Clear status is title text. |
| Variable `dt` clamped at .05; in-loop AI and progression | main loop | Pacing measurements would be invalid if render rate alters simulation time. Engine report's fixed simulation contract must be resolved. |

Historical contrast: `linux-game/src/main.c` has finite ammo `[120,36,14]`, one +35 medkit, one ammo pickup and key-granted ammo, four enemies and a kill/key exit. `components/arena.tsx` has four equal-health targets, no finite ammo economy and a kill/position win check. Neither proves the native FPS economy works. Copying their values into the new design would be arbitrary.

**What is absent in inspected native code:** difficulty profiles, per-encounter stable IDs/data, optional combat accounting, health/ammo pickups, player armor, checkpoint persistence and declared encounter exits. Existing score counts kills; it does not describe fairness, resource access or player decision quality.

**Failed/unapproved context:** the user rejected flat audio and the repeated concept. Current calibrated art/audio experiments are not accepted baselines. This role cannot turn those experiments into approved content through naming or by increasing quantity. The novel differences proposed below are route economics and local pacing policies, which can be demonstrated with debug shapes.

## 2. Reference study and consequences

### Doom: difficulty is authored placement plus resource rules

**Source facts.** `P_SpawnMapThing` filters map things using skill bits. `P_GiveAmmo` uses ammo type capacities and pickup quantities, doubles ammo for trainer and Nightmare, and preserves full pickups by returning false. `P_DamageMobj` halves player damage in trainer mode; armor absorbs a fraction until its points run out. These are independent mechanisms, not one universal enemy-health multiplier. [id: map thing spawning](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_mobj.c), [id: interactions](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_inter.c).

**Inference.** Difficulty can preserve a learned enemy while changing who occupies a lane and how forgiving the surrounding economy is. Supplies are geography because capped pickups can remain available for later. **Eyesore proposal:** use authored placement variants and accessible reserves; hold baseline enemy HP and attack tells constant. **Question:** does a return to an earlier supply alcove feel like a useful remembered option or tedious walking?

Do not read these functions as proof of a particular Doom map's pacing, secret requirements or fairness. We have not audited the shipped maps here.

### Wolfenstein 3D: alternate populated routes

**Source fact.** `ScanInfoPlane` has difficulty-gated map tile codes for enemy placements, including stand and patrol variants. Higher difficulty can add placements that lower settings skip. [id: `WL_GAME.C`](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/WL_GAME.C).

**Inference.** A route can retain its architecture and become a different exposure problem through composition. **Eyesore proposal:** put an extra ranged lane watcher on the challenge profile, rather than doubling every opponent's HP. **Question:** can returning players identify the new tactical difference without re-learning every shot count?

### DUSK: campaign and survival are different commitments

**Source fact.** The developer/publisher store description identifies three authored campaign episodes and a separate endless survival mode, with a broad arsenal. It does not document internal resource or checkpoint policies. [New Blood: DUSK](https://store.steampowered.com/app/519860/DUSK/).

**Inference.** Repeated wave combat does not have to become the whole campaign grammar. **Eyesore proposal:** include arrival, investigation, combat, aftermath and optional-route beats; reserve an endless mode for a later product choice. **Question:** do players remember a place and route decision after the slice, or only a number of waves? No exact DUSK timing/AI/economy is attributed to this source.

### Prodeus: tools and audio participate in encounter production

**Source fact.** Its publisher/developer description promises an authored campaign, an integrated level editor/community maps and music that changes with action. It does not establish its detailed checkpoint semantics. [Bounding Box/Humble: Prodeus](https://store.steampowered.com/app/964800/Prodeus/).

**Inference.** An encounter needs a reviewable authoring representation and an audio intensity contract. **Eyesore proposal:** expose encounter areas, entrances, resource reachability and beat state in a debug view before multiplying content. Give music authored state events with a minimum hold to avoid flicker. **Question:** can a designer change one flank route and predict how resource access and the mix will change? We do not adopt a claimed Nexus death policy from community anecdotes.

### Boltgun: authored escalation with bounded spatial choices

**Source fact.** Auroch describes hand-placed enemies plus dynamic wave arenas, a designer nodegraph for escalating encounters, spawn points and zones toward which enemies move. This describes its authoring approach; it does not disclose exact release limits. [Auroch developer article](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/).

**Inference.** Spawn choices can be authored while selecting among valid entrances at runtime. **Eyesore proposal:** R2 chooses only a visible/cued entrance with tested escape geometry; never a position merely because it is behind the camera. **Question:** does variation remain readable on a first run and tactically interesting on repeat?

**Source fact.** Auroch's later official patch notes address enemy spawn-in-wall, awareness/pursuit, inaccessible encounter regions and a final encounter ending without intended enemies killed. They also add a navigation guide and improve obscuring effects. [Auroch: Forges update](https://www.aurochdigital.com/warhammer-40000-boltgun-forges-of-corruption-patch-notes).

**Inference.** Navigation, clear conditions, collision and visibility are part of encounter quality, even in a polished production. **Eyesore proposal:** validate each required enemy's path, every clear condition and all pickup approach widths. These are design acceptance requirements, not a promise that a more complex director prevents bugs.

### Dead Space: coordinated peaks and recovery

**Source fact.** Motive describes a content/spawning/pacing director layering audio, lighting, fog/steam and enemy events, with tension increasing then easing; calm makes subsequent peaks meaningful. [EA/Motive: Intensity Director](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director).

**Inference.** A fast shooter can borrow authored peak/valley structure in transitions. **Eyesore proposal:** clear pressure and let audio settle after a fight; keep locomotion available and let the player choose to leave early. Do not silently add attackers to a previously declared safe recovery pocket. **Question:** does the lull restore attention without slowing the forward-moving game? The director's event count is irrelevant to our first slice and is not a production target.

## 3. Shared combat vocabulary

These are functional slots. Enemy behavior lead owns their final form, state timing and counterplay. Weapon lead owns weapon identity. An encounter should work before faction names and sprite detail are chosen.

| Slot | Spatial demand | First teaching placement | Combination hazard |
|---|---|---|---|
| Projectile caster | Move laterally out of a committed lane; choose when to shoot | Alone across a wide unobstructed floor | Two crossing shots can eliminate dodge space; stagger releases or widen routes. |
| Pursuer | Keep distance, turn/stop it, choose a loop | Visible approach from front/side with escape | It can pin the player against cover while caster attacks; preserve a second outlet. |
| Anchor/heavy | Relocate for exposure/attack window; use strong ammo if useful | Visible before entry; modest supporting pressure | Heavy plus multiple pursuers can make every lane unsafe; teach its tell first. |
| Support, if later approved | Prioritize or break a link | Isolated enough to see effect on one ally | Adds visual/target complexity; defer until three slots produce good fights. |

Orthodox baseline weapons: precision / close spread / committed area attack. Encounters must tolerate any unlocked weapon with reasonable expenditure; no hidden mandatory weapon-type check, material immunity or setup puzzle. Powerful tools should change efficiency and safety, rather than merely unlock damage permission. A finite special pool can encourage conservation, but exhausting it cannot stop the mandatory route.

**Proposal:** define threat using observed demands: active firing lanes, close approach time, available escape width, visible tells, interrupt options and overlapping committed damage windows. A scalar threat score may help the editor sort content later; it cannot certify fairness. Six easy enemies may create worse occlusion than two high-damage enemies.

## 4. Two controls with different purposes

### M0: single matched mechanics encounter

Use the mixed pressure room M from the level report's C map as one isolated encounter. Give the same precision and close spread weapons at entry, ample finite ammunition that exceeds a deliberately miss-heavy run, health 100, no armor, one caster and one visible pursuer, no reinforcement, no pickup trigger, no mandatory clear gate and immediate identical reset. The caster/pursuer pair follows a solo caster exposure before its first comparison session; that teaching is identical for every participant. No anchor or area weapon is needed here.

The M0 question is whether ordinary movement, attack tells, weapon feedback and readable routes work. It does not test resource conservation, exploration or scarcity. Abundant ammo can remain finite for instrumentation, but reaching scarcity makes that run invalid for this comparison. Supply values are hypotheses pending weapon unification. Hold layout, enemies, HP, movement, cue/render/audio quality and initial state fixed. Change one mechanics variable per comparison; no simultaneous weapon unlock, damage, resource or cadence redesign.

### Shared map C: folded sequence

This uses [level design report C](Research2_Level_Design.md), including its space IDs and duration hypothesis. Five spaces form the forward spine; O is an optional sixth space, not a required sixth beat. First version is flat. Intended session is **3–5 minutes**, not a forced timer; clear travel alone is the level report's hypothetical 25–40 seconds. There is no key or kill-all gate in this comparison.

```text
S safe entry/exit preview -> T teach room -> P recovery bend
                                             |
                                             v
                           X exit <- M mixed pressure room <-> O optional alcove
T ............... visual connection only ............... X
```

| Space | Fixed combat/spatial baseline | Baseline supply policy for spatial pass |
|---|---|---|
| S | Safe entry, visual preview of distinct X through solid window | Both tested weapons already owned; abundant ammo for the full route. No pickup starts a fight. |
| T | One caster then one visible approach role; two routes around offset cover | No scarcity or required pickup decision. All comparisons use identical role sequence. |
| P | Protected dogleg with view back and next-room preview | Plain visible kit remains in the same location across spatial comparisons. |
| M | Known caster/approach pair, asymmetric cover, two usable local paths, open onward route | Same weapons and attack timing as M0. No heavy or late reinforcement in the spatial pass. |
| O | Ordinary open optional detour; no secret mechanic yet | Optional pickup exists for navigation cue only; mandatory route does not depend on it. |
| X | Distinct vestibule and authored end threshold; surviving optional enemies permitted | Same exit action and end condition in every comparison. |

The level report mentions a spread weapon before M. For experimental consistency, M0 and the initial spatial/resource comparisons own both weapons from S; a later unlock-timing variant can place the spread weapon before M while holding everything else fixed. This explicit temporary research loadout prevents unlock effects being mistaken for economy effects. No production design is implied.

C measures basic navigation and progression on credible geometry. M0 measures mechanics. They are separate passes, not a single route expected to isolate every cause.

### Resource comparisons on C, before changing topology

Use C as the fixed map and roster. Compare **C0 abundant baseline** against **C1 finite scarcity** first: same pickup positions, weapon ownership, health/kit policy, enemies, timings, profile, music, visual cues, exit and initial state; change ammo quantities/caps only. Then compare **C1 versus C2 redistributed finite supplies** with total usable ammo fixed and only pickup positions changed along valid routes. Then compare **C2 versus C3 dependable boundary supplies**, keeping total ammo and health offered fixed while moving declared baseline supplies to S/P rather than O/exposed routes. Finite supply does not imply regeneration. Any health-policy comparison is a separate pass with ammo held constant.

Only after component results are interpretable compare the larger R1/R2 packages. These package comparisons assess an overall experience; they cannot prove which individual rule caused preference. A pressure-cadence test changes static/reinforcement sequencing with the same finite roster and resource arrangement; resource claims are not inferred from that cadence trial.

| Design dimension | Fixed for component resource tests | Later independent comparison |
|---|---|---|
| Topology/height | Shared C, flat, same geometry/cover | Level A/B with abundant economy first; then chosen economy on selected topology |
| Enemy difficulty | Same roles, HP, tells, count and positions | Profile placements only after standard policy establishes a baseline |
| Weapons | Same ownership from S, damage/range/cost/cadence | Unlock timing or special pool introduced separately |
| Resources | Same unless the named component is under test | Quantity, position, health and boundary floor isolated in successive passes |
| Retry/start | Same complete entry snapshot and health | Wounded/low-ammo stress runs recorded separately from preference runs |
| Presentation | Same light, sprites, audio and feedback | Presentation evaluation belongs to its own domain |

Use matched initial inventories and counterbalance test order. Separate first-play observations from repeat runs: route knowledge and skill practice are expected learning effects, not proof that a supply policy is better. Compare difficulty profiles within each chosen policy later rather than comparing easy R1 against hard R2. Do not match policies only by total enemy HP: arrival angles and threat overlaps also need equivalence or explicit reporting.

## 5. Resource policy R1: persistent route economy

**Player experience hypothesis:** remember and reshape a small connected place, keep health/ammo between fights, choose whether a visible detour improves the next encounter. The route can be fast, and clever players can bypass optional combat. Supplies are finite and fixed; the same seed gives the same layout and placements.

```text
                         [optional reserve]
                         health + special
                            /       \
Start -> Hub -> Gallery ------- Court -> Exit
           \     caster         anchor   ^
            \___ low loop _____/    \___/
                pursuer + ammo     shortcut opens
```

Hub/Gallery/Court/low loop are temporary spatial labels, not lore. Main mandatory route is Start–Hub–Gallery–Court–Exit. The low loop is a visible alternative traversal, not a secret. The optional reserve is an extra combat detour; its incremental reward must exceed its incremental expected expenditure for the intended novice band, or it is a challenge route honestly labeled by exposure rather than advertised as recovery.

| Beat | First run | Repeat run | Resource rule |
|---|---|---|---|
| Hub survey | Hear/see one caster ahead; see two routes and supplies through an opening | Commit quickly to preferred route | Mandatory ammo visible without entering fire; supplies do not trigger enemies. |
| Gallery exchange | Learn lateral lane; pursuer arrives only from an already visible connected route | Pull enemies across lanes or skip optional ones | Fixed small ammo on each route; no kill-conditioned supply drops. |
| Reserve detour | Choose visible health/special reward behind a short readable encounter | Optimize route based on carried inventory | Optional never assumed in mandatory budget. Distinct visual cue, no map-wide secret hunt. |
| Court peak | Known caster/pursuer plus anchor; return route stays usable | Decide speed bypass vs complete clear | One baseline reserve can be reached by ordinary movement from any living arrival state; no jump requirement. |
| Aftermath shortcut | Opens a shorter route to supplies already seen; exit remains recognizable | Route knowledge saves time | Consumed supplies remain consumed; optional living enemies do not silently refill. |

Difficulty grows by changing angles and combinations, then revisiting learned roles in unfamiliar space. Do not increase every enemy's HP. A later distinct heavy variant can have more health/firepower if appearance/tell announces it and the encounter gives a first teaching exposure. Raise one major demand at a time: second firing angle, closer pursuer approach, smaller supply margin, or narrower recovery route. Avoid simultaneous changes until combined behavior is understood.

**Breathers:** protected geometry between fights, a look back over the route, audible activity ahead, optional resource planning. No imposed wait, no stamina gate, no hidden random punishment for standing still. Persistent wounded players can retreat to a remembered unused kit; the map gives a short return path rather than requiring a full empty level walk.

**Novelty:** resource geography makes a connected place part of combat strategy. It differs from the current kill–cache–kill chain and requires no new fictional gimmick. **Risk:** powerful early players can hoard and flatten the last fight while inaccurate players enter a deficit. Cap carrying capacity only after observing this effect, since an aggressive cap can erase deliberate saving. Tune reachable baseline resources first.

## 6. Resource policy R2: local pressure pulses

**Player experience hypothesis:** forward movement through compact courts, with supply location shaping each fight and short safe transitions preventing a long deficit spiral. Inventory remains persistent; dependable authored supply stations offer enough baseline ammo/health to approach the next court. No automatic full heal, no ammo deletion at room boundaries, no supply respawn on camping and no mandatory glory-kill economy.

```text
Safe entry -> Court 1 -> safe transition -> Court 2 -> aftermath/exit
                 N entrance                  [anchor]
             [caster lane]               W entrance  E entrance
            ammo   cover  health           cover  special cache
                 S exit                       exit
```

Each court has a finite authored roster and a small beat list. The first court teaches static enemies. The second shows a clearly cued entrance before using it. A light pulse is a readable encounter event, not a health-dependent ambush. Runtime choice is limited to a prevalidated entrance and a seeded variant; it cannot spawn on the player or multiply a roster because the player is doing well.

| State | Trigger and action | Fairness / resource condition |
|---|---|---|
| Dormant | Player can survey from entry; baseline supplies visible | Entry is safe and retreatable. |
| Introduce | Cross an authored line; one caster activates | Known cue precedes any possible damage. No full-room lock yet. |
| Commit | Player advances into court; pursuer enters marked N opening | Approach is physical; tested escape route remains available. |
| Recompose | First threat resolved or player reaches the far route; known ranged role uses another marked entrance | Cap concurrent damaging commitments; do not use a timer alone to force accumulation. |
| Release | Required authored actors resolved; remaining projectiles finish/expire | Music pressure drops after actual threat passes, not merely last HP reaching zero. |
| Recovery | Exit/next route opens; finite authored rest supply available | No damage spawn in rest space; player chooses when to leave. |

Court 2 reuses learned roles with one anchor; it does not teach a new cast while introducing three entrances. First run uses one fixed entrance sequence. Repeat run can enable a declared alternate sequence under a stable seed; randomized enemies are optional later, not needed for originality. Full-clear lock is used sparingly, such as this one trial court, and is visible before commitment. Most campaign spaces remain traversable.

**Resources:** baseline ammo before entry; tactically placed small ammo on route loops; health in a protected pocket reached by moving, not in the middle of an active killing zone; special ammo on a visible exposed spur. Finite refill stations support the next encounter's minimum band; they do not top everyone to full or penalize people who saved ammunition. High reserves buy experimentation and speed, while low reserves retain viable ordinary weapon choices.

**Novelty:** a room has distinct spatial phases and reliable recovery, rather than three geographically scattered instant groups. **Risk:** it can become a predictable arena conveyor; geometry and objectives must occasionally change, and optional routes survive. A director can create unfair interactions if its authoring rules become probabilistic performance punishment. Keep it small, authored and observable.

## 7. Resource budgets: explicit hypothetical arithmetic

Do not assign raw ammo from a commercial game. First lock weapon paths, per-role HP, range, damage and input behavior. Compute per-weapon **accurate shots required** at intended encounter distances. Spread pellet maximum damage is not typical landed damage. Area collateral is a benefit, not mandatory baseline efficiency.

For mandatory route segment s and weapon pool w:

`expected expenditure = accurate shots required / measured useful-hit fraction + measured wasted shots`

Use actual prototype observations when available. For planning only, toy light enemy health 6 and precision damage 3 implies two accurate shots. Six such targets imply 12 accurate shots. A hypothetical 0.60 useful-hit fraction implies 20 shots, before waste/overkill; +25% margin gives 25. This is not a recommendation for 6 HP, 3 damage, 60% accuracy or 25 rounds. It demonstrates how an economy claim can be reproduced and later replaced with measured values.

Spread and area roles require different measurements: log distance, landed pellet count, targets struck, misses, self-damage and overkill. Do not count a shell as seven guaranteed hits. Budget on a defined conservative playstyle, not perfect splash clustering or infighting.

| Trial band — hypotheses, not promises | Initial planning comparison | Measurement needed |
|---|---|---|
| Minimum mandatory ammo | Supply at least the measured conservative required-kill expenditure plus a proposed 20–35% buffer | Observe inexperienced useful-hit fraction and chosen weapons; confirm zero secrets/optional kills needed. |
| Optional detour | Reward remaining after optional threat expenditure is positive for target band, or clearly a risky challenge route | Compare arrival/exit health and pool-specific ammo; do not combine unlike ammo into an unexplained score. |
| Health recovery | A kit should recover a meaningful mistake sequence; trial roughly 2–3 ordinary-hit equivalents | Verify it does not erase every fight or remain useless after one lethal burst. |
| Armor | Trial a visible finite damage absorption pool with one understandable rule, then compare against health-only C | Weapon/enemy lead must settle damage and HUD must show depletion clearly. No armor added by this report. |
| Breather length | Player-controlled; trial 10–25 seconds of useful traversal/recovery space | Record attention, route confusion and desire to resume. Never force the player to wait this long. |
| Pressure duration | Trial 25–55 seconds for early teaching/combinations and a 50–90 second peak | Actual threat timing, no-damage stretches, ammo use and player fatigue determine changes. |

Check budgets at every irreversible boundary, not just across the level total. Ten shells after a locked arena cannot fund that arena. Supplies on a ledge are unavailable until height/collision/path support works. Ammo dropped by an optional enemy is not baseline income. Ammo for a locked gun is not usable income. Full-cap pickups must stay present or have a declared partial-transfer policy so recovery is not accidentally deleted.

**HP and armor:** track real loss separately from absorbed damage. Armor is a finite forgiveness reserve, not a reason to hide attack damage. A difficulty profile can add a kit or armor before the peak; this is preferable to widening every tell by a different amount until enemy identity changes. If armor's rule cannot be explained in one short HUD/help sentence, postpone it.

**Zero-ammo policy decision:** prefer a modest unlimited fallback or nonlethal bypass opportunity if the final weapons permit it. Never balance on the assumption that every new player can defeat a mixed pack using dangerous melee. A low-strength fallback still needs a verified escape/time-to-kill path. If the game deliberately permits resource failure, give a clear local restart/earlier snapshot rather than trapping the player in a technically alive unwinnable state.

## 8. Difficulty and progression

Proposed profiles are descriptive placeholders; final naming belongs to interface/story review. Keep spawn sets deterministic and documented. Change profile only at a safe boundary and show which rules change.

| Demand | Forgiving | Standard | Challenge |
|---|---|---|---|
| Composition | Single-role teaching first; fewer simultaneous roles | Taught pair then anchor combination | Additional taught lane threat or altered route position |
| HP/tells | Same baseline roles | Same | Same initially; distinct signaled variant later if accepted |
| Releases | One major committed danger at early teaching | Two after combined lesson | Two with greater spatial complexity, before considering more |
| Supplies | More baseline ammo/health along main path | Conservative budget margin | Smaller tested margin, never secret dependency |
| Recovery | More reachable kits and short local retry | Reachable reserve and local retry | Same valid retreat/retry routes; pressure remains deliberate |
| Assistance | Independently selectable damage reduction, invulnerability, aim assistance if supported | Assistance remains user-selectable | Assistance remains user-selectable; challenge stats label rules |

Increase difficulty across a level through a learning curve: observe one role, use the counter, combine with a second, vary geometry, restore attention, then climax with established roles. Do not insist that every minute is harder than the last. The user wanted progressively stronger enemies; meaningful escalation includes more damaging distinct opponents, but relentless HP inflation would conflict with weapon weight and stable feedback. A boss/heavy should alter a decision and visibly announce its danger.

Across a campaign, new locations, route structures, attack roles and weapon applications offer more than repeated larger waves. Track where each role/tell, weapon and mechanic was taught; the first appearance of a new combination should not coincide with mandatory resource starvation or a navigation puzzle.

## 9. Telegraph fairness and recovery contracts

**Proposal:** visible pose + spatial cue + usable avoidance/counter route. Sound aids orientation but cannot carry every mandatory tell alone; visual readability must survive mute, and sound readability must survive combat mix. Projectile flight time is part of a tell only while projectile visibility and player escape geometry are dependable.

The enemy lead's initial cue hypotheses (roughly .65–1.0 seconds before ranged harm) are experiment bands. Derive a required avoidance distance from actual collision radius, lane width, movement response and projectile geometry, then measure it. A cue seen .8 seconds early is still unfair if the route needs 1.2 seconds to clear or a body blocks it. Permit at least one feasible response at the player's position when the commitment begins, under the defined movement/weapon state.

Entrance policy: marked physical openings; enough visible or spatially announced approach before a release; no spawn intersecting player/collider; no body appearing directly in a dodge path after commitment. Rear pressure can work after a readable cue, but a rear hit before a possible turn/response is rejected. Attack release limits cannot substitute for these checks.

Recovery has three separate meanings: a breathing interval, replenishment, and a retry. A quiet space need not fully heal; a kit need not be safe to pick up; a checkpoint need not restore maximum inventory. Declare each. Safe recovery spaces remain safe after they are declared. Retreat can bring already known pursuing enemies only if the space was never declared safe and its use is clearly combat retreat rather than a breather.

## 10. First play, repeat play and failure recovery

**First play:** route/exit visible, supplies preceding commitment, one novel role or combination per teaching beat, no unseen mandatory secret, optional supply detour visible, concise feedback for clear/locked state. Do not teach with a kill prompt covering the center of the view. Players can pause and understand the current objective.

**Repeat play:** deterministic layout/placements permit route mastery; optional bypass and ammunition saving reward knowledge. Challenge variants change authored positions/compositions. Seeds and profile are displayed in replay metadata if R2 later uses alternate entrances. Enemy health and release rules cannot change silently between retries.

**Checkpoint proposal:** an entry snapshot saves player inventory/health/position, pickup consumed IDs, door/switch states, required encounter actors, pending encounter beats, RNG state and objective state. Retry restores that whole snapshot, including enemies and pickups. Resetting player only while retaining damaged/dead enemies creates a different persistence policy and can turn repeated deaths into attrition progress; make that a separately named assistance mode if ever desired, not an accidental default.

Place a checkpoint before mandatory commitment with a viable baseline loadout. Record the exact arrival state and flag a clearly insufficient snapshot for designer review; do not covertly grant resources on every death. A user-visible 'restart from previous safe checkpoint' and whole-level restart remain options when an arrival state is poor. R1 cannot rely only on the last doorway checkpoint if persistent choices can create a deficit; retain an earlier safe snapshot. R2's known supply floor should reduce this risk, but must be validated.

Death feedback: state cause in plain terms if useful, preserve the last playable snapshot, restore quickly, and replay mandatory tells. Test players should describe what they will try differently. Unexplained spawn/collision deaths require design fixes, not a hint blaming the player.

## 11. Cross-role contracts

| Owner | Required agreement before slice authoring |
|---|---|
| Engine | Fixed simulation; stable entity/encounter/pickup IDs; room triggers and events; trace/collision/nav validity; finite actors; snapshot/reset semantics; threat and projectile cleanup; no hidden render-controlled spawn. |
| Movement | Run/walk response, radius/height, step/jump policy, turn/input latency and valid route clearances. All proposed ledges are optional until elevation is supported. |
| Weapons | One damage/trace policy across test/runtime; cadence, unlock, ammo cost/capacity, fallback, switching and interrupt contracts. Confirm special exhaustion cannot block required progression. |
| Enemy behavior | Functional role, learned cue/release/recovery, stagger, targeting, support rules, navigation/body blocking, required vs optional entity flags. Do not use story-dependent gimmicks to make the control work. |
| Level design | Mandatory and optional graph, entry/commitment/retreat, loop clearances, sightlines, supply routes, unique exit landmark and shortcut; revision together on one shared slice. |
| Lighting/materials/sprites | Enemy/tell/pickup contrast at actual gameplay distance and resolution; material categories don't conceal collision/route; no darkness/effects that erase counterplay. |
| Sound/music/mix | Spatial entrance cues and attack identities; combat state/peak/release/recovery events; no mandatory tell masked by weapon/bass/music; no repeated music transition per kill. |
| HUD/automap | Ammo/health/armor meaning, optional objective direction, clear requirement and retry state; avoid permanent crowding. Supplies have readable type/value at speed. |
| Tools | Encounter graph + spatial overlay, profile differences, pickup reachability, required kill validation and immutable snapshot viewer; authoring human-reviewable data. |
| Quality/session | Player cohort/staged protocol, recordings and event logs, profile/seed/build identity, recovery/save checks, accessibility assistance labels. |
| Story | Explain route/objective stakes and aftermath, preserve cues and supply fairness; no scripted speech or blackout forcing helpless damage. |

Minimal authoring record: encounter ID, activation and commitment regions, required/optional actor IDs, permitted entrances/zones, finite beat dependencies, clear/exit actions, profile overrides, safe recovery region, pickup IDs/amounts and snapshot boundary. This is a design contract; content pipeline lead chooses schema. Prefer a small acyclic beat graph before a general director/editor framework.

## 12. Failure cases and acceptance gates

| Failure | Detect / reject |
|---|---|
| Clear never completes because one enemy is stuck | Required actor path/position validates before play; log remaining actor ID and reason; test alternate player routes. Never silently delete it to fake a clear. |
| Spawn releases damage before player can respond | Record cue/visible entry/commit/release/hit and feasible avoidance path; reject the placement even if average deaths are low. |
| Supply exists but is inaccessible during mandatory fight | Per-boundary graph and live route review; check body blocking, height, locked doors and weapon ownership. |
| Low-ammo arrival requires perfect aim or secret | Conservative miss-heavy route and no-secret run demonstrate completion or viable fallback/bypass; revise resource placement or checkpoint. |
| Optional detour costs more health/ammo than it offers | Measure net per-pool balance; label challenge or change reward/roster. |
| Later enemy of same silhouette takes extra shots | Stable role stats or distinct declared variant; reject unexplained per-instance HP. |
| Easy profile teaches misleading tells | Preserve attack semantics/tells; vary composition/economy first. |
| Checkpoint duplicates pickups or keeps dead enemies | Snapshot restore all relevant IDs/events; session owner owns eventual save verification. |
| R2 silently scales pressure because player is succeeding | Designer declares finite roster; logs account for every actor/entrance; no performance-based multiplier. |
| Last kill declares safety while projectile remains threatening | Release waits for harmless resolution/expiry or clears projectiles by declared effect; audio/HUD agree. |

**Staged proposed review, no tests run:**

1. Paper walkthrough of M0/C/R1/R2 by coordinator and level/enemy/weapon leads. Reconcile shared C IDs/geometry; identify mandatory boundaries and viable routes; remove unavailable engine features.
2. When implementation is separately authorized, a 2–3 person first feel test of M0 with abundant ammunition and neutral presentation. Correct weapon equivalence, visible tells, collision and retry before measuring economy.
3. Shared C spatial pass: abundant supplies, fixed roster, both weapons owned from S, no heavy/reinforcement/key/clear lock. Coordinate with level lead's 3–5 minute duration hypothesis. Fix navigation independently.
4. On unchanged C, run the component resource comparisons above. Use a later 5–8 person exploratory session with counterbalanced order, inexperienced and experienced FPS players, separate first/repeat records, and one variable changed per comparison. Small samples expose failures; they do not establish a statistically proven winner.
5. Test broader R1/R2 packages only after component results, then separately test scarcity/recovery under wounded, miss-heavy and no-optional-resource conditions. Package preference is descriptive, not causal evidence for every element.
6. Test level topology A/B under abundant baseline, then apply a promising resource policy. Test difficulty variants after standard is interpretable. A full factorial study is unnecessary initially; staged matched comparisons avoid multiplying prototypes before basic failures are corrected.
7. Select using decision quality, readable causes, recovery and user preference; no prior winner. Content expansion follows selection. Do not select simply by lowest clear time/highest kills.

Log build/config/profile/seed, player positions/facing/speed, visibility and cue times, attack commitments, damage causes, shots/hits/overkill, pool balances at boundaries, pickup IDs/transfers, routes, time in threat/no-threat states, optional choices, deaths/retry snapshot and remaining required actors. Pair telemetry with replay and player explanations.

Acceptance hypotheses: new players explain the counter after one teaching encounter; every mandatory segment is completable by the defined conservative no-secret band; no unexplained HP changes; every damaging event has a readable cause and feasible response; useful optional resource choice can be named; full retry restores a coherent encounter; repeat route mastery changes choices/time without erasing combat. Numerical success-rate thresholds are deferred until a baseline exists. A single reproducible unavoidable spawn or softlock fails the gate even if most players succeed.

## 13. Self-critique and decision risks

R1 may become resource bookkeeping, long retreat walks or easy hoarding. Keep loops short, show supplies through geometry, and let the control reveal whether persistent attrition improves pleasure. Optional rewards must remain genuinely optional. An elegant graph on paper can have terrible FPS sightlines; level lead must co-author the real geometry.

R2 may preserve the current prototype's wave habit under a better state graph. The difference must be demonstrated: readable entrances, local spatial decisions, player-controlled recovery and finite predictable commitments. If players still describe it as kill everyone, take gun, repeat, it has not earned selection. It also needs more authoring/runtime machinery than C/R1.

M0/C can feel too familiar and small. Its purpose is to expose whether basic weapon/enemy feedback already satisfies the user before changing the economy. A strong control is essential because a clever resource policy cannot rescue flat sound, weak hit feedback or unreadable sprites.

The enemy report currently ties some roster proposals to previous story candidates. This encounter report intentionally uses behavior slots and does not endorse those story choices. Cross-review should replace any slot that lacks an ordinary shooter counter before expanding the roster. The weapons report's orthodox baseline is a better first resource control than its more elaborate setup-dependent tools.

Primary evidence is deep for open Doom/Wolf source, narrower for modern games. Exact DUSK/Prodeus encounter budgets, save rules and difficulty multipliers remain unknown. Direct level observation with lawful copies/official footage and timestamped notes would strengthen the next review, particularly layout pacing; it should not be filled in with community hearsay. These proposals remain design hypotheses until the user plays a representative slice.

**Coordinator review requested:** challenge whether R1's persistent economy is enough of a fresh direction, whether R2 truly escapes the existing ladder, and whether the mandatory resource/retry rules are concrete enough to survive inexperienced play. No direction should be approved through this report alone.

## Coordinator revision record

The coordinator identified that this role's initial 5–8 minute, three-fight C conflicted with the level lead's 3–5 minute folded sequence and changed weapons, cadence and supplies together. The revised report uses M0 for a single abundant-ammo mechanics comparison, shared C/S–T–P–M–X (+ optional O) for spatial control, and R1/R2 for resource policies so they cannot be confused with level topology A/B. Resource quantity, position, recovery and cadence comparisons are staged with fixed geometry/roster/difficulty; broader package tests make no isolated causal claims. The earlier preference for persistent economy has been withdrawn pending evidence. All durations/budgets remain hypotheses.
