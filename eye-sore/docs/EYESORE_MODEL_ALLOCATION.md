# Eyesore model allocation proposal

Status: proposed for review, 2 October 2026. This document changes no agent settings and launches no implementation workers.

Use **GPT-6 Astra / high** for every specialist's planning brief, shared contracts and milestone design review. Use focused implementation workers after the brief is accepted. A worker gets the approved brief and relevant files, rather than the full planning conversation. Avoid asking every planner to independently redesign the whole game.

Default implementation model: **GPT-6 Luna**. Use **low** reasoning for explicit transformations, data entry, exports and straightforward UI; **medium** for bounded behavioral code and creative tool orchestration. Use **GPT-6.1 Sol / medium** for the more coupled systems below. The model choices are engineering recommendations, not task-specific benchmark results.

| Specialist | Planning model | Implementation model / effort | Reason for implementation choice |
|---|---|---|---|
| Art direction | Astra / high | Luna / medium | Apply the agreed palette/style to bounded concept briefs and comparisons; human/visual review still required |
| Engine architecture and simulation | Astra / high | Sol / medium | Geometry, renderer and simulation contracts affect every discipline |
| Player movement and aiming | Astra / high | Sol / medium | Collision, timing, momentum and camera behavior need careful interaction handling |
| Weapon mechanics | Astra / high | Luna / medium | Small state machines and parameter tables once timing and damage contracts are explicit |
| Enemy behavior | Astra / high | Sol / medium | Awareness, collision, attack transitions and retaliation interact |
| Encounters, resources and difficulty | Astra / high | Luna / low | Author data from approved encounter budgets; escalate unexplained balance failures |
| Level layout and navigation | Astra / high | Luna / medium | Build approved geometry/layout data; engine capability changes return to the architecture owner |
| World interactions | Astra / high | Sol / medium | Door/lift state must agree with collision, AI, projectiles and restart |
| Lighting and visibility | Astra / high | Luna / medium | Author room light values and effects from the plan; new renderer mechanisms require Sol review |
| Environment materials and props | Astra / high | Luna / low | Execute approved source selection, imports, tiling and placement work with visual review |
| Creature sprites and animation | Astra / high | Luna / low | Asset orchestration, frame preparation and consistency checks; actual image production uses separate tools |
| First-person weapons and animation | Astra / high | Luna / medium | Implement the approved frame/event timeline and stable view placement |
| Combat effects and feedback | Astra / high | Luna / medium | Bounded visual effects tied to explicit combat events |
| Weapon and impact sound design | Astra / high | Luna / medium | Edit/render documented source layers under an approved brief; user audition decides quality |
| Creature and environmental sound | Astra / high | Luna / medium | Prepare distinct cue families and variations; inspect/listen in scene |
| Music composition | Astra / high | Sol / medium | First original musical sketch, motif/arrangement and editable musical source; Luna handles later exports and simple revisions |
| Audio programming and mixing | Astra / high | Sol / medium | Callback safety, format conversion, headroom, spatial updates and loop/device behavior |
| HUD, automap and interface | Astra / high | Luna / low | Implement agreed layouts and straightforward options; complex map geometry returns to Sol |
| Content tools and asset pipeline | Astra / high | Luna / low | File transforms, manifests, scripts and import checks with clear expected outputs |
| Session and release systems | Astra / high | Sol / medium | Save/load and restart consistency; Luna handles bounded packaging and configuration tasks |
| Independent quality review | Astra / high | Sol / medium | Independent integration/defect analysis; Luna runs scripted checks and assembles reports |

Cost controls:

- Start routine implementation with Luna and a small task. Do not send it broad, under-specified requests such as 'make the audio good'.
- After two unsuccessful focused repair attempts, hand the failure evidence and patch to Sol. Architecture uncertainty or a cross-system design conflict goes back to Astra before more implementation.
- Use Astra for planning and significant milestone review; do not repeat that expense for every asset rename or small edit.
- Use low reasoning for deterministic chores, medium for behavioral changes, and reserve higher reasoning for a demonstrated difficult problem.
- Run up to three independent workers alongside the coordinator. Give each its own files/worktree and return a compact handoff: changes, checks, limitations and decisions needed.
- Check the first few completed tasks before expanding Luna's scope. Total accepted-work cost includes retries and review, not only token price.

The session exposes `gpt-6-astra`, `gpt-6.1-sol` and `gpt-6-luna` as explicit subagent model choices. New workers can be spawned with those choices after review; changing a task label on an existing worker does not establish a new model assignment. The coordinator's own model is controlled by the host/user selection.

The published **standard short-context API** rates are $0.10 input / $0.50 output per million tokens for Luna, $2 / $10 for 6.1 Sol, and $10 / $50 for Astra. These are comparison rates, not a quotation for this account or the session's billing/service tier. Image generation and other tools have separate costs; API rate ratios do not guarantee equivalent end-to-end savings.

Official sources fetched for this proposal:

- [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna)
- [GPT-6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol)
- [GPT-6 Astra](https://developers.openai.com/api/docs/models/gpt-6-astra)

These general-purpose models do not directly output finished audio or raster sprite assets. They can plan, write code/MIDI and operate editing or generation tools. Music, SFX and sprite production still need an appropriate workflow and listening/visual review. Stronger reasoning can help direct that process but cannot certify its artistic result.
