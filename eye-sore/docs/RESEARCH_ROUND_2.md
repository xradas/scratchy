# Eyesore research round 2

**Status:** active research only; no creative direction or production content approved. **Model policy:** remaining substantial specialist research and design work uses GPT-6.1 Sol / high; Sol / medium is for bounded fact checks/revisions and Luna for routine implementation after approval. No Astra. Earlier waves were already launched on Luna / high or Sol / medium before the user raised the model preference; their actual assignments remain recorded below.

## Aim

Use project evidence and careful reference study to define an original game with clear decisions across every discipline. New work must challenge earlier briefs, especially the observatory/Glass Choir/industrial-horror cluster, instead of making that cluster more detailed by default. Doom, Wolfenstein 3D, DUSK, Prodeus, Boltgun, and Dead Space are references for analysis, not asset or story templates. Cite primary/developer sources for claims; separate observation, inference, and proposal.

Each specialist must inspect the current project, identify confirmed implementation facts and failed/unapproved experiments relevant to their field, research reference games relevant to that role, develop alternatives (not just adjectives or asset counts), compare against gameplay, and define a reviewable acceptance test. The coordinator will critique every report with the specialist and cross-review dependencies before any direction or production is proposed.

## Roster and progress

| ID | Specialist | Round 2 report | Status |
|---:|---|---|---|
| 00 | Art direction and visual development | `Research2_Art_Direction.md` | Reviewed and revised with story/style compatibility matrix — Luna / high |
| 01 | Engine architecture and simulation | `Research2_Engine_Architecture.md` | Reviewed; assumptions and score arithmetic corrected — Luna / high |
| 02 | Player movement and aiming | `Research2_Movement_Aiming.md` | Reviewed and revised with native FPS assumption and staged gates — Luna / high |
| 03 | Weapon mechanics | `Research2_Weapon_Mechanics.md` | Revised: neutral graybox control loadout is GO; bespoke A/B/C first test is NO-GO — Luna / high original and followups |
| 04 | Enemy behavior | `Research2_Enemy_Behavior.md` | Revised with story-neutral Hold/Cross control, matched comparison and engine deferrals — Luna / high original and followup |
| 05 | Encounters, resources and difficulty | `Research2_Encounters_Difficulty.md` | Revised to separate M0 mechanics, shared C spatial control, and isolated R1/R2 resource comparisons; prior preference withdrawn — GPT-6.1 Sol / medium |
| 06 | Level layout and navigation | `Research2_Level_Design.md` | Revised with matched placements, counterbalance, separate exposure/orientation reporting, and ungated spatial test — GPT-6.1 Sol / medium |
| 07 | World interactions | `Research2_World_Interactions.md` | Revised report complete with minimal core and deferred extensions — Luna / high |
| 08 | Lighting and visibility | `Research2_Lighting.md` | Revised with matched-view distinctions, renderer capability matrix and merge/falsification rules — GPT-6.1 Sol / medium |
| 09 | Environment materials and props | `Research2_Environment_Art.md` | Revised with six-cell material/light comparison, projection-based density and sampling checks — GPT-6.1 Sol / medium |
| 10 | Creature sprites and animation | `Research2_Creatures.md` | Revised with shared lighting contract, Hold/Cross role mapping and separate same-silhouette material test — GPT-6.1 Sol / medium |
| 11 | First-person weapon art and animation | `Research2_Weapon_Art.md` | Revised with flat-floor low-threat/side-flanker mask tests, matched timelines, and elevation deferred — GPT-6.1 Sol / medium |
| 12 | Combat effects and feedback | `Research2_Combat_Feedback.md` | Revised with distinct transient contact grammars, resolver-owned material and shared role 13 event/mix contract — GPT-6.1 Sol / medium |
| 13 | Weapon and impact sound design | `Research2_Weapon_Audio.md` | Revised with source/mixer/capture stop-go gates and shared role 11/12 timing, contact and warning contracts — GPT-6.1 Sol / medium |
| 14 | Creature and environmental sound | `Research2_World_Audio.md` | Revised with frozen pause/resume event lifecycle and shared score/ambience return/duck ownership — GPT-6.1 Sol / medium |
| 15 | Music composition | `Research2_Music.md` | Revised with same-motif A/B/C arrangement pass, whole-score experience pass, and shared pause/duck/return contract — GPT-6.1 Sol / medium |
| 16 | Audio programming and mix | `Research2_Audio_Engineering.md` | Sol / medium report revised after Sol / high review; zero-delta transaction, event/clock watermarks, pause, capture and D1–D6 dry-M0 fixtures clarified; all fixtures unrun |
| 17 | HUD, automap and interface | `Research2_Interface.md` | Revised with shared event/caption/UI/map ownership and correction that legacy browser map shows full grid — GPT-6.1 Sol / medium |
| 18 | Content tools and asset pipeline | `Research2_Content_Pipeline.md` | Revised with an illustrative M0 ID/caption JSON slice, native package-closure failure, staged validators and separate structure/import/listening/user approvals — GPT-6.1 Sol / medium |
| 19 | Session systems and release | `Research2_Session_Release.md` | Revised: harness starts paused, player startup remains a minimal flow hypothesis; role18 bundle/package and disabled score/ambience reconciled — GPT-6.1 Sol / medium |
| 20 | Independent quality and playtest analysis | `Research2_Quality_Playtest.md` | Revised: exact unapproved shared D_light/M0 shell recommendation, tradeoffs, transfer limits and remaining profile-freeze fields documented — GPT-6.1 Sol / medium |
| 21 | Narrative integration/storytelling | `Research2_Storytelling.md` | Sol / high synthesis received and coordinator-reviewed; three distinct unselected packages integrated with roles 00–20, historical draft retained as comparison |

## Work waves

Run up to three independent specialists at once. Begin with 00–02 because visual, engine, and movement decisions constrain the rest. Continue 03–07; 08–12; 13–17; then 18–20. Revisit 21 once the reports are available. Give each agent its bounded domain and the related reports, not a request to redesign every discipline. Each agent gets a substantial report plus a concise decision summary; overlapping interfaces are assigned explicitly. Remaining substantial research uses GPT-6.1 Sol / high; use Sol / medium for bounded follow-ups and fact checks. No Astra. Pro provides more included usage but not an unlimited continuous quota; keep bounded waves and track remaining usage in the account dashboard.

## Review gates

1. Specialist self-check: distinguish source fact, observed project behavior, inference, and proposal; surface uncertainty and counterarguments.
2. Coordinator critique: point out unsupported assumptions, dependencies, duplication, and where a proposed result is too similar to prior rejected work. Require one targeted revision where needed.
3. Cross-specialist review: resolve collisions (e.g. weapon sound vs animation timing, light vs sprite visibility, level graph vs engine capability) using one shared encounter/level slice.
4. User review: show original alternatives with their tradeoffs and no production implementation hidden behind them. Proceed only after the user selects a direction.

The existing short reports remain useful evidence, not accepted designs. Rejected calibration/audio auditions stay rejected. Research quality is demonstrated by source traceability, specific design consequences, and a testable difference in player experience—not by word count, reference count, asset count, or more elaborate lore.
