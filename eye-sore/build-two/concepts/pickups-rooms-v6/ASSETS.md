# Pickup and furnishing artwork

Created with the built-in imagegen tool, using the approved theme boards as style references. Generated PNGs are copied byte-for-byte; native authored UV regions select panels without resizing or repainting them. Physical pickup and furniture geometry is authored in the project.

| Saved production asset | Exact prompt / generation record |
|---|---|
| [Pickup surface atlas](../../assets/pickups/pickup-v6-atlas.png) | [Tool prompt](pickup-tool-prompt.txt), [generation record](pickup-generation.json), [runtime presentation](../../resources/pickups/presentation-v6.json) |
| [Pale Ward furniture atlas](../../assets/materials/room-props-v6/pale_ward-atlas.png) | [Prompt](pale_ward-props-prompt.txt), [native regions and hashes](props-generation.json) |
| [Ash Citadel furniture atlas](../../assets/materials/room-props-v6/ash_citadel-atlas.png) | [Prompt](ash_citadel-props-prompt.txt), [native regions and hashes](props-generation.json) |
| [Occupied Line furniture atlas](../../assets/materials/room-props-v6/occupied_line-atlas.png) | [Prompt](occupied_line-props-prompt.txt), [native regions and hashes](props-generation.json) |

The [level object lists](../../docs/room-program-v6/OBJECT_LISTS.md) and [machine-readable programme](../../docs/room-program-v6/levels.json) define room purpose, explicit working-room footprints, furnishings and key/switch/gate order before scene creation. Runtime generation is deterministic authoring, with shared physical geometry and deliberate equipment bays. Full visual acceptance against the original complete concept scenes remains pending.

The [pickup audio ledger](audio/manifest.json) identifies the nine short CC0-derived item receipts, retained original files, exact source/license evidence and edits. [Dry/designed auditions](audio/index.html) are separate from the actual game mix and human listening approval.
