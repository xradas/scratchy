# Eyesore story integration: research draft

**Status:** narrative synthesis for peer critique, not approved canon. Creative proposals below are original and do not authorize art, audio, code, or map production. The current design briefs and playable prototype do not yet establish a story.

## 1. What is established, rejected, and open

### Established project facts

- Target: an original fast, readable boomer shooter informed by Doom, Wolfenstein 3D, DUSK, Prodeus, Boltgun, and Dead Space. References provide design lessons, not asset sources. [Reference direction](REFERENCE_DIRECTION.md)
- Current native prototype: rectangular arena, staged fights, ember pistol, rivet shotgun, arc cannon, four enemy types, projectile combat, sprinting, and mostly fixed-height movement. Its earlier key-loop level and newer storm-coast observatory are unvalidated proposals, not game canon. [World research](World_Design_Redesign_Research.md) [Native README](../linux-game/README.md)
- The world lacks an authored material catalogue and real level graph. Combat lacks persistent narrative interactions. Creature silhouettes/states are too similar, attack poses lose facing, and computed sprite tint is overwritten. Current audio is rejected and needs human listening review. These are constraints, not story facts. [Creature research](Creature_Redesign_Research.md) [Audio research](Audio_Redesign_Research.md)

### Rejected or not canon

- The user rejected the existing flat/bad audio and the later A/B/C shotgun audition. They also rejected the calibration-room concept as a quality target. Do not reinterpret those as approved style.
- The “First Descent” brief's kill gates and repeated HP increases are flagged for revision; its plot, secret, key, and exit are not canon.
- The “Witness Works / Low Tide Observatory” and “Glass Choir” are independent specialist proposals. They share a coast/optical/body-horror vocabulary, but neither has been chosen. Details such as the offshore lens city, the organism replacing people, and named districts/enemies must not be presented as settled facts.

### Open decisions

Player identity and motive; what “Eyesore” means; whether the threat is alien, engineered, ecological, or human-made; the facility's relationship to the coast; intended gore/body-horror level; whether combat enemies can be bypassed; how much story is communicated through short radio/physical clues versus direct dialogue; and whether the existing weapon names survive. Also unresolved: browser/isometric project language in the root README versus the native FPS prototype and current team plan. Resolve that product-identity conflict before content production.

## 2. Two original story/world directions

Both proposals keep plot subordinate to movement and combat.

### A — The Witness Works: “the coast remembers”

A storm-survey station over a deep-water fault was expanded into a predictive archive, a machine that records physical events and reconstructs them from local materials. During a blackout it begins replaying an earlier disaster. A rescue/maintenance operator arrives to restore a relay and evacuate survivors. The apparatus now reproduces traces of former staff, but not their full identities; players infer that these “recordings” are being used to make new bodies.

The hook is **memory as a material process**, not an observatory tour. A broken lens, dry tide marks, duplicated tools, and a warning light repeating an earlier state imply the incident on the move. Begin in waterworks; reveal the optical archive after the first combat loop. Keep motive ambiguous: rescue, concealment, or deliberate preservation?

The Glass Choir can fit as one possible enemy ecology: recordings that assemble tissue, work uniforms, optical fixtures, and pressure hardware into distinct bodies. It is not the world's name or a required religion/faction. The four current types do not map to these roles yet.

### B — The Red Mile: “the city follows the wrong map”

A landlocked, high-altitude freight city is built around a vast rail interchange and automated civil-defense network. After a disaster, an obsolete evacuation system misreads its own maps and seals inhabited districts to protect the central power route. The player is a former route courier who stole the current switch ledger; they must reach a broadcast tower and expose which neighborhoods were knowingly cut off. Threats are human: security crews following bad orders, rival freight guards exploiting the shutdown, and maintenance machines whose dangerous actions are clearly signaled by their work lights and tools. No deep-water organism or body-replacement premise is required.

Dead Space's environmental storytelling can inform how players piece together the cover-up: the same evacuation arrow appears in three places, but each points to a route that has since been sealed; a dispatch board and abandoned luggage show who was left behind. Short authored quiet pockets let the player read a clue or hear a clipped transmission, then the route opens into a clear fight. Keep one forward objective and no moral-choice system in the first level. This stays closer to Doom/Boltgun pace than a branching crisis simulation.

### Comparison and recommendation status

| Measure | A — Witness Works | B — Red Mile |
|---|---|---|
| Distinctiveness | Low-to-medium at this point: it connects directly to the existing observatory and Glass Choir cluster, so it risks repeating that concept. | Higher: inland rail city, human conflict, false evacuation, and route-map clues break from the coast/optical/body-horror direction. |
| Gameplay fit | Strong: visible machinery, route loops, a clear relay objective, and material/creature combat roles. | Strong: sightline-rich rail halls, crossing lanes, doors, elevated freight platforms, and distinct human combat jobs support fast fights. Clues can sit in safe transition spaces. |
| Scope | Moderate, but it leans on a location and art pipeline already unsupported by the fixed-height engine. | Moderate: one interchange district can carry a full slice. Keep broadcast objective linear; avoid simulating a whole city, train physics, branching factions, or complex civilian AI. |
| Main risk | Repeats the proposals the team is already trying to move beyond; abstract “memory machine” may not read quickly. | Human factions may feel generic or invite too much dialogue; false-map premise needs clear visual proof and a strong enemy silhouette/art direction. |

**Recommendation remains open; slight lean to B.** A efficiently synthesizes existing drafts, but risks repeating their outcome. B better stress-tests a distinct world while retaining readable fast combat. Choose A only for optical/body horror; choose B for human conflict and a visually legible evacuation deception. A one-room test for both is preferable to committing from prose.

**Direct critique of the provisional B lean:** a rail hub and false evacuation can collapse into generic dystopian soldiers and signage; dialogue-heavy motive would slow play, and human enemies may not deliver the original creature-design ambition. If that happens, A's more legible material ecology may serve the game better despite its lower novelty. Neither direction has earned approval or playtest evidence.

## 3. How the story supports the game

| Discipline | Direction A proposal | Direction B proposal | Shared gameplay rule |
|---|---|---|---|
| Player role | Response operator restores relay/seeks survivors. | Ex-route courier broadcasts the stolen switch ledger. | One concrete forward objective; no escort or required dialogue. |
| Enemy ecology | Personnel traces, apparatus, archive tissue. | Security trooper, close breacher, misrouting loader. | Teach one tell/dodge, then combine roles; keep stable archetype health. |
| Weapons | Service pistol, pump shotgun; possible electrical tool. | Service pistol, pump shotgun; later breaching/arc tool only if mechanically earned. | Mechanics set cadence/ammo; don't force the current arc cannon into the fiction. |
| Flow/clues | Landing → pump hall → lens court → archive → relay; repeated landmark changes. Flood marks, conflicting signs, duplicate tools. | Concourse → freight crossing → switching hall → broadcast tower. False route signs, sealed luggage, conflicting switch ledger. | Local interactions, optional glance-readable clues, no repeated kill-gates or stopping under fire. |
| Material/light | Chalk, tidal stone, copper, ceramic, dark glass; warm work lamps and cold exterior fill. | Sooted concrete, painted steel, old enamel signage, sodium lamps against cold dawn. | Strong values distinguish threats from backgrounds; light changes signal state, not random danger. |
| Sound/music/pacing | Pressure machinery and relay pulse; quiet return then mixed relay fight. | Two-tone dispatch signal, rail brakes, door motors; calm concourse, crossing fight, quiet tower approach. | Original cues identify threats/routes; adapt Dead Space's authored peaks, quiet intervals, and clues without slowing Doom/Boltgun movement. EA describes the remake's Intensity Director combining audio, lighting, events, and encounters with calmer intervals; adapt the pattern, not its system. [EA](https://www.ea.com/technology/news/inside-dead-space-4-the-intensity-director) |

This links proposals, but has not been playtested. Boltgun developers describe multi-direction rendered animation with synchronized damage/audio/projectile events; the transferable lesson is cross-discipline timing. [Auroch Digital via PlayStation Blog](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/)

## 4. Red Mile opening-level narrative spine (8 beats)

1. **Approach:** enter a freight concourse under emergency lamps; the broadcast tower and a stopped train orient the route. The pistol is ready. No opening cinematic.
2. **Wrong instruction:** a loudspeaker orders evacuation toward a marked platform. The platform is visibly collapsed, but nothing attacks yet; a quieter route sign points toward a service passage.
3. **Teach:** one security trooper notices the player, calls out, and fires a slow, dodgeable burst across a broad crossing. A loop around a freight container teaches movement and the pistol.
4. **First evidence:** after the fight, a departure board and abandoned luggage show this platform was sealed before the evacuation announcement. The player can inspect, but does not need to stop or read text.
5. **Tool and route:** the shotgun is visible in a locked guard booth. A short key loop retrieves it. The direct route crosses a dangerous open platform; a longer side passage offers a small resource cache. Neither requires killing every enemy.
6. **System revealed:** in the switching hall, a maintenance loader moves a barrier according to the obsolete route map, exposing and then blocking lanes. The same two-tone dispatch signal from the concourse now comes from a different speaker zone.
7. **Peak and release:** combine the known trooper with a close-range breacher around freight cover. The exit lane stays visible; no surprise spawn behind the player. On victory, the machinery stops and the player gets a brief quiet transition.
8. **Reframe/exit:** at the tower, the stolen switch ledger shows the central authority marked the populated district “clear” before its gates closed. The player broadcasts the route correction and sees distant station lamps change. The exit remains immediate; the reveal motivates the next level without a forced lore scene.

## 5. Contradictions, missing decisions, and validation slice

**Cross-brief contradictions to resolve:** creature research proposes 14 enemies/six districts, while the team review recommends a small slice first. World research specifies large routes and 40–46 enemies; current engine supports a single room box and fixed-height motion. Audio proposes industrial horror while current labels/textures lean infernal. The root README calls the game browser-based/isometric, while the team plan targets native FPS. Decide the shipped product before production.

**Smallest validating slice:** a 3–5 minute Red Mile route through concourse, freight crossing, and switching hall, ending with a view of the broadcast tower. One optional key loop; one trooper, one breacher, and one loader that changes a lane; pistol and shotgun; one switch/door state; two nonverbal clues plus one optional short transmission; one original dispatch/rail motif. Ask players to name the objective, explain why the evacuation is false, identify both attack tells, and find the tower route. If they cannot infer the deception or describe only generic soldiers, revise the clue/art before adding lore or enemies.

**Questions for the project owner**

1. Which should lead: optical body-horror and a place replaying history (A), or human conflict in an inland rail city (B)?
2. Should the player be a named character with a voice, or an unnamed operator whose identity stays mostly unstated?
3. Is body horror central to Eyesore's promise, or should the threat remain readable and unsettling with restrained gore?

**Peer-critique request:** challenge B's generic-soldier risk and whether the false evacuation is clear from the level evidence without dialogue; identify one enemy, weapon, or flow decision that weakens the fast-shooter fit. Do not treat this draft as user-approved direction.
