# Weapon animation and effects

Owner: assigned specialist; coordinator owns shared contracts and final integration.

Model: GPT-6.1 Sol/high for substantial design or difficult integration; Sol/medium for bounded implementation. Do not use Astra. At most three workers alongside coordinator.

Scope: Hand-author pistol, shotgun and melee hand/weapon idle, firing, recoil/recovery and switching sequences plus impacts, muzzle flash and pickup effects.

Deliverables: Editable frame sources, event/frame mapping and in-game repeated firing evidence.

Acceptance constraints: One firing event owns release/audio/damage; animation does not independently trigger a duplicate shot. Selection comes before complete sequences.

Gate: follow `../PRODUCTION_PLAN.md`; identity selection precedes full asset production, combat exchange review precedes level expansion. Keep changes in your assigned project paths, report evidence and limitations, and hand off reviewable files. Do not overwrite earlier source assets or checkpoint another specialist’s work.
