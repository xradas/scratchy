# Connected campaign and weapon presentation

The user confirmed nine playable levels: three each in The Pale Ward, The Ash Citadel, and The Occupied Line, in that order. This supersedes the earlier deferred chapter ordering. Preserve the three older standalone stages and their accepted source/export evidence.

The Pale Ward's containment failure is being fed by something buried beneath the facility. The specimen breach opens a passage to an old reliquary. Its furnace powers a transit conduit into the occupied civic network. Destroying the occupation engine ends the campaign. Keep the story in short level introductions and physical exit landmarks; combat and exploration remain the focus.

| Chapter | Level | Route identity | Connection |
| --- | --- | --- | --- |
| Pale Ward | Intake | Arrival, sunken triage court and conspicuous Twin Shotgun cache | Surgical access |
| Pale Ward | Containment | Reservoir returns and upper surgical galleries; Rivet Cannon | Specimen access |
| Pale Ward | Breach | Silo and rupture court; Siege Launcher | Buried occult passage |
| Ash Citadel | Ash Approach | Ramparts and cloister court | Furnace gate |
| Ash Citadel | Furnace Choir | Furnace/altar rings and elevated crossings | Reliquary ascent |
| Ash Citadel | Black Reliquary | Upper vaults and ritual machinery | Civic transit conduit |
| Occupied Line | Dead Platform | Trackbeds, platforms and overhead crossings | Administrative access |
| Occupied Line | Civic Lockdown | Administration hub, mezzanines and return loops | Engine access |
| Occupied Line | Occupation Engine | Turbine courts and final riser | Campaign finale |

Each level needs its own route geometry and encounter arrangement, clear critical supplies, optional secrets and side rooms, usable height changes, and a recognizable exit. Chapter creatures and material palettes stay exclusive to their setting. Existing music remains unchanged, including Abelian on the menu and the provisional shared Ward/Line score.

Campaign transitions carry health, armor, weapon ownership, ammunition, and selected weapon. Retry reconstructs the current level and restores its entry loadout. New Game begins with the existing pistol, shotgun, melee, normal health/armor/ammunition, and no acquired heavy guns. Persistent campaign saves remain outside this change.

The crosshair represents the authoritative centered camera ray. View sprites must illustrate that ray with a coherent breech-to-muzzle axis; moving the crosshair to cover a crooked weapon is not a correction. Muzzle effects belong at the registered barrel tip. Switching can lower the weapon without pretending it is a firing pose. Test screen transforms under letterboxing, source-alpha boundaries, receiver scale and repeated firing, as well as ray/contact ownership.

The replacement Rivet atlas is produced by builtin ImageGen, using the old gun as a rejected design reference and the original Pale Ward board as the style reference. Preserve the generated PNG unchanged, register native source rectangles, and retain previous assets. Exact input hashes, output hash and prompt are in `concepts/campaign-v3/provenance.json` and `rivet-prompt.txt`.

Primary API references checked by the coordinator: [Camera3D projection and unprojection](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) and [SceneTree lifecycle](https://docs.godotengine.org/en/stable/classes/class_scenetree.html). The project rebuilds the existing SubViewport world rather than replacing the main settings/UI scene. These references support API use, not visual or human play acceptance.

Verification distinguishes controlled native gun views, ordinary automated CharacterBody/AI routes, genuine exported runs, and human acceptance. No generated concept screenshot is presented as live gameplay. The full original concept target, physical mouse feel, listening and human encounter pacing remain user review items.
