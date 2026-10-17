# Ash Approach v15 — authored first Citadel level

The first Citadel map follows the chapter's siege geography: look from the outer approach toward the raised inner bridge; descend through the broken trench and breach camp; recover a gatehouse credential in the crypt; climb the stair tower and battlements; operate the bridge winch; cross its physically lowered deck; continue through the cloister and armory to the Furnace Choir gate.

The layout and object programme are defined before generation in `tools/author_ash_approach_v15.py`. The generated `resources/campaign/ash_citadel_01-layout.json` lists all 17 rooms, their functions, height bands, fittings, connections and progression objects. Four floor bands (-2, 0, 2 and 6 m) distinguish trench, approach, inner ward and ramparts. Every listed fitting is represented physically near a room perimeter. Chapter enemies are Ironbound and Censer only; no Ward or Line enemy is placed here.

The gatehouse credential is the only required key. It enables the winch. Using the winch lowers the real bridge collider; a separate solid safety gate waits until the deck reaches its lower stop. The far gate also requires the winch. The exit requires both `gate_winch` and `visited_inner_bridge`, so the player must physically cross. A tower hatch opens a return loop toward the starting overlook. The quartermaster and watch post are optional supply rooms, and the breach camp conceals a tithe vault with extra ammunition. Main-route supplies do not depend on the vault.

Two session checkpoints sit after the crypt credential and beside the winch. The stage reset recreates the raised bridge and closed safety gate. The early overlook's east aperture has a solid 2.5 m sill; a native world ray from the spawn eye reaches the actual raised BridgeDeck through it.

`tools/ash_approach_art_v15.py` adds Citadel-specific noncolliding architectural detail and lighting. `scripts/ash_bridge_v15.gd` owns deck/safety motion. The generator publishes only Ash Approach's scene, layout, route and objective resource. The original v14 playable package remains preserved separately.

Native Godot 4.7.2 source checks have loaded the scene and verified closed/open/reset bridge collision and supported floor at each portal route sample. The nine-level campaign route and human navigation/art review are separate acceptance gates.
