# Campaign level redesign — v13

Approved direction: independently authored nine-level campaign plans, followed by the three playable Pale Ward replacements. Guided exploration; 20–25 minutes per first successful human playthrough, excluding deaths. This is a target requiring human play, not an automated timing claim.

The preserved v12 source/delivery checkpoint is `5f68f5c5ee51eec0997113e977bd48e4277222bf`; its portable build remains under `/home/rikki/Builds/eyesore-volumetric-gore-v12-2026-10-17`. No old map, asset source or accepted evidence is discarded.

## Why the maps repeated

The old author starts from chapter templates, scales/mirrors them and omits selected rooms. All nine maps retain breaker/release/exit_control, brass/red keys and three arena clears. The stage runtime and campaign bot enforce that same journey. V13 replaces both the authoring input and objective ownership for Ward; the six later playable maps retain their legacy behavior while their replacement designs are prepared.

## Design ownership

The coordinator authored room functions, dimensions, floor elevations, connections, objective dependencies, inventory, encounters, supplies and checkpoint locations before construction. `levels.json` is the authoritative three-Ward construction input. Individual Ward JSON/Markdown/SVG packets are review copies. `contracts.json` records shared interfaces. Later-chapter packets establish distinct objective journeys, district adjacency, height progression and room inventories; their exact collision/portal and supply specifications are resolved at their later construction gate, rather than presenting schematic diagrams as finished playable architecture.

| Level | Distinct journey | Status in this milestone |
|---|---|---|
| Intake | Reception return loop; emergency power, clinical credential, decontamination lockdown | Playable replacement |
| Containment | Culture/waste feeds in either order; first opens cross-feed bridge, second drains lower route | Playable replacement |
| Breach | Staged descent and three shootable containment anchors | Playable replacement |
| Ash Approach | Exterior siege, crypt infiltration, battlements behind gatehouse | Design packet |
| Furnace Choir | Fuel/draft shutdowns, upper ritual feed, cooled crossing | Design packet |
| Black Reliquary | Counterweight, successive seal sightlines, central-vault descent | Design packet |
| Dead Platform | Signals, maintenance overbridge, far track points | Design packet |
| Civic Lockdown | Credential, security power rerouting, changed atrium route | Design packet |
| Occupation Engine | Cooling/induction shutdown, exposed core, untimed escape | Design packet |

## Construction and review gates

1. Freeze shared contracts and all nine design packets.
2. Build and inspect Intake first, including objective ownership, floor/stair/lift support and checkpoint restore.
3. Build Containment and Breach from their independent inputs, retaining distinct objectives.
4. Verify both Containment branch orders, no-secret main routes, checkpoint/restart semantics, existing combat and all nine campaign transitions.
5. Produce a portable Linux export from a clean pushed source checkpoint, then verify the exact exported package outside the development directory. Capture actual gameplay with the stereo game mix. User navigation, visual acceptance and 20–25-minute pacing remain human review.

Three programming workers maximum alongside the coordinator. Runtime owner edits shared progression/checkpoint/combat/menu interfaces; construction owner edits authoring/scenes/resources; independent QA owner edits opt-in test driver and verification. Coordinator handles all research/design decisions, shared contracts, packaging, provenance, integration and Git. Existing specialist roles rotate through bounded tasks; no parallel ownership of shared files.

The Breach upper-to-middle return bridge sits in a sealed silo atrium (floor −4m, roof18m), with observation glazing exposing the vertical route before shortcut release. Containment’s uphill bridge approach uses a15m run with0.46875m treads; physical ascent and descent are verified separately with the unchanged player controller.

Legacy aggregate v3–v9 resource audits remain historical inputs for the unreplaced maps. The current Ward truth is its v13 layout/route/profile and author report, plus new route receipts; old three-arena audit assumptions are not applied to the redesigned maps.

## Checkpoint semantics

Two authored milestone markers per Ward level. One latest snapshot within the current level/session; no disk save. Capture occurs only when grounded/stationary at a safe marker, required flags are set, no live projectile/local threat can hit the landing, and mechanisms have stopped. It is deferred while unsafe, never faked by clearing the encounter.

Continue restores the checkpoint's inventory, player pose, objectives, visited areas, collected supplies, enemies/corpse gameplay state and mechanism state without replaying rewards or combat releases. Transient particles/projectiles/audio voices are cleared. Before the first checkpoint, Continue restores level entry. Restart Level restores the entry loadout and clears the checkpoint. Title, New Game and transition discard the previous checkpoint. Carried campaign inventory still transfers normally.

## Preserved and deferred

Existing art PNGs, weapon definitions, enemy health/AI, v12 gore, accepted gun sounds and every music/audio file remain unchanged. New architecture reuses native material regions and existing fitted prop recipes. No replacement concept images stand in for game captures. Lighting uses visible mounted fixtures and readable progression landmarks.

New enemy families, weapons, original per-level music, persistent campaign saves and reconstruction of the other six playable levels remain later milestones. The selected soundtrack is unchanged; original music for every current/future level remains a recorded later task using those tracks as references.

## Layout reference review

The user-requested [FAQ contents and layout article review](reference-review.md) records accessible sources, blocked wiki destinations, the current structural limitations and the next construction acceptance contract. Passing progression tests does not establish that the layouts meet this spatial combat standard.

The reference-driven structural pass now constructs shared triage/nurse and specimens/crossfire courts, supported raised positions and accessible reservoir firing balconies. Both-feed shutters synchronize with actual drainage. Physical firing slots replace an ineffective solid parapet; offset cover preserves existing enemy navigation. [Fit decisions and evidence boundaries](structural-proposals.md) record these adjustments.
