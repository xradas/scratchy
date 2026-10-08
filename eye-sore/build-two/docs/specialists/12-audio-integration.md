# Audio integration and mixing

Owner: assigned specialist; coordinator owns shared contracts and final integration.

Model: GPT-6.1 Sol/high for substantial design or difficult integration; Sol/medium for bounded implementation. Do not use Astra. At most three workers alongside coordinator.

Scope: Integrate Master/Weapons/Creatures/World/Music/UI buses, positional world emitters, persistent stereo music, pause/mute/restart voice semantics.

Deliverables: Routing ledger, audio lifecycle verification, dry/designed/game listening comparisons and stereo capture.

Acceptance constraints: Pause freezes gameplay audio; mute only changes audibility; restart clears voices. Loudness analysis supports listening judgment.

Gate: follow `../PRODUCTION_PLAN.md`; identity selection precedes full asset production, combat exchange review precedes level expansion. Keep changes in your assigned project paths, report evidence and limitations, and hand off reviewable files. Do not overwrite earlier source assets or checkpoint another specialist’s work.

User requirements, 9 October 2026: Dispatch by weapon × actual hit material, plus separate species hurt/death/attack voices. Deduplicate presentation per resolved shot/target, never valid gameplay damage. Abelian plays in the menu; pause/settings do not layer menu music over suspended level music. Restart clears all previous combat voices.
