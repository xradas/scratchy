# Daylight and gate visual refinement

Native review identified broad orange Citadel clerestories and cyan Line daylight panels that read as flat glowing blocks. The stage author now samples the unchanged panel cell from each native architecture atlas through an `AtlasTexture`, with subdued warm grey Citadel or cool grey Line tint and emission energy 0.5. Thin dark mullions divide the panels at intervals no greater than 1.2 metres. Their meshes have no colliders. Existing lamps, coals, OmniLights and SpotLights retain their settings.

Progression gate leaves now use the dedicated `door_skin` atlas material. Two small horizontal lock indicators and the existing label move with each leaf. Gate dimensions, collision, impact metadata, requirements, animation offsets and interaction anchors remain identical.

Before regeneration, every body transform, collision shape, collision and impact metadata, polygon vertex/height, and Omni/Spot light setting was captured. The regenerated scenes match all 4,913 records exactly. The comparison receipt is `verification/arsenal-architecture-v2/visual-refinement-physics.json`. Structural and ambush checks cover all three stages; full route receipts retain their prior geometry validity.

The initial, unaccepted native images are preserved byte-identically in `verification/arsenal-architecture-v2/captures-initial/` (148 PNGs; 157 original files total). `verification/arsenal-architecture-v2/evidence-relocation.json` maps their historical paths. The initial source audit is retained as `source-pack-audit-initial.json` and `.log`. Fresh native captures use `verification/arsenal-architecture-v2/captures/` after the root agent schedules GPU access. This source change and its automated checks do not claim human visual acceptance.
