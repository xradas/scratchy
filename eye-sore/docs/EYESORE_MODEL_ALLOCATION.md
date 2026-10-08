# Eyesore model allocation proposal

Status: model preference updated 3 October 2026. User-directed: raise agent capability beyond Luna, but do not use Astra. For the remaining substantial design/research work, use **GPT-6.1 Sol / high** as the default specialist setting; use Sol / medium for bounded fact checks, mechanical revisions, and repeatable implementation tasks. Sol / high is not a promise of unlimited continuous compute: batch work by decisions that can be reviewed, check the plan's usage dashboard between waves, and keep the agents focused. Astra is excluded. This document does not authorize implementation.

Use **GPT-6.1 Sol / high** for new substantial specialist research, original design work and cross-discipline synthesis. Use **Sol / medium** for bounded reviews and implementation workers when the brief is already approved and specific. If a task is routine and easily checked, use Luna. Do not use Astra. After the user accepts a direction, use focused implementation workers with only their approved brief and relevant files, not the full conversation. Reports already completed on Luna or Sol / medium remain attributed to the model that did the work; do not describe those assignments as upgraded retroactively.

Default implementation model: **GPT-6 Luna**. Use **low** reasoning for explicit transformations, data entry, exports and straightforward UI; **medium** for bounded behavioral code and creative tool orchestration. Use **GPT-6.1 Sol / high** for substantial research/design and coupled systems below; use medium for bounded implementation once decisions are approved. The model choices are engineering recommendations, not task-specific benchmark results.

| Specialist | Planning model | Implementation model / effort | Reason for implementation choice |
|---|---|---|---|
| Art direction | GPT-6.1 Sol / high | Luna / medium | Apply an accepted identity to bounded concept briefs; human/visual review still required |
| Engine architecture and simulation | GPT-6.1 Sol / high | Sol / medium | Geometry, renderer and simulation contracts affect every discipline |
| Player movement and aiming | GPT-6.1 Sol / high | Sol / medium | Collision, timing, momentum and camera behavior need careful interaction handling |
| Weapon mechanics | GPT-6.1 Sol / high | Luna / medium | Small state machines and parameter tables once timing and damage contracts are explicit |
| Enemy behavior | GPT-6.1 Sol / high | Sol / medium | Awareness, collision, attack transitions and retaliation interact |
| Encounters, resources and difficulty | GPT-6.1 Sol / high | Luna / low | Author data from approved encounter budgets; escalate unexplained balance failures |
| Level layout and navigation | GPT-6.1 Sol / high | Luna / medium | Build approved geometry/layout data; engine capability changes return to the architecture owner |
| World interactions | GPT-6.1 Sol / high | Sol / medium | Door/lift state must agree with collision, AI, projectiles and restart |
| Lighting and visibility | GPT-6.1 Sol / high | Luna / medium | Author room light values and effects from the plan; new renderer mechanisms require Sol review |
| Environment materials and props | GPT-6.1 Sol / high | Luna / low | Execute approved source selection, imports, tiling and placement work with visual review |
| Creature sprites and animation | GPT-6.1 Sol / high | Luna / low | Asset orchestration, frame preparation and consistency checks; actual image production uses separate tools |
| First-person weapons and animation | GPT-6.1 Sol / high | Luna / medium | Implement the approved frame/event timeline and stable view placement |
| Combat effects and feedback | GPT-6.1 Sol / high | Luna / medium | Bounded visual effects tied to explicit combat events |
| Weapon and impact sound design | GPT-6.1 Sol / high | Luna / medium | Edit/render documented source layers under an approved brief; user audition decides quality |
| Creature and environmental sound | GPT-6.1 Sol / high | Luna / medium | Prepare distinct cue families and variations; inspect/listen in scene |
| Music composition | GPT-6.1 Sol / high | Sol / medium | First original musical sketch, motif/arrangement and editable musical source; Luna handles later exports and simple revisions |
| Audio programming and mixing | GPT-6.1 Sol / high | Sol / medium | Callback safety, format conversion, headroom, spatial updates and loop/device behavior |
| HUD, automap and interface | GPT-6.1 Sol / high | Luna / low | Implement agreed layouts and straightforward options; complex map geometry returns to Sol |
| Content tools and asset pipeline | GPT-6.1 Sol / high | Luna / low | File transforms, manifests, scripts and import checks with clear expected outputs |
| Session and release systems | GPT-6.1 Sol / high | Sol / medium | Save/load and restart consistency; Luna handles bounded packaging and configuration tasks |
| Independent quality review | GPT-6.1 Sol / high | Sol / medium | Independent integration/defect analysis; Luna runs scripted checks and assembles reports |

Cost controls:

- Start routine implementation with Luna and a small task. Do not send it broad, under-specified requests such as 'make the audio good'.
- After two unsuccessful focused repair attempts, hand the failure evidence and patch to GPT-6.1 Sol / high for a bounded review. Revisit the model choice with the user if a specialist reaches a demonstrated reasoning limit.
- Use GPT-6.1 Sol / high for the remaining substantial Eyesore research/design roles; Sol / medium for bounded follow-up, implementation and factual checks. Re-evaluate after a complete research wave against the actual account usage dashboard.
- Use low reasoning for deterministic chores, medium for behavioral changes, and reserve higher reasoning for a demonstrated difficult problem.
- Run up to three independent workers alongside the coordinator. Give each a bounded domain, relevant project/reference inputs and a compact handoff. Avoid sending the entire repository/history to every specialist.
- Pro raises included usage, but usage is affected by model, context length, reasoning, tools and cloud tasks; weekly limits may still apply. It does not guarantee uninterrupted all-day agent runs. Work in reviewable waves and check the account's usage dashboard before another long wave. [Codex/Work pricing and usage](https://learn.chatgpt.com/docs/pricing)

The session exposes `gpt-6-astra`, `gpt-6.1-sol` and `gpt-6-luna` as explicit subagent model choices. New workers can be spawned with those choices after review; changing a task label on an existing worker does not establish a new model assignment. The coordinator's own model is controlled by the host/user selection.

The published API rates are not a measure of Pro-plan usage; model, context length, reasoning, tool use and cloud tasks all affect included usage. Use the account usage dashboard for actual remaining allowance.

Official sources fetched for this proposal:

- [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna)
- [GPT-6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol)
- [GPT-6 Astra](https://developers.openai.com/api/docs/models/gpt-6-astra)
- [OpenAI model-selection guidance](https://developers.openai.com/api/docs/guides/model-selection)

These general-purpose models do not directly output finished audio or raster sprite assets. They can plan, write code/MIDI and operate editing or generation tools. Music, SFX and sprite production still need an appropriate workflow and listening/visual review. Stronger reasoning can help direct that process but cannot certify its artistic result.
