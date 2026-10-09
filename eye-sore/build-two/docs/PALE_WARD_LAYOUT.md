# Pale Ward authored route

Containment Hall starts at ground level and frames the broad central staircase and raised locked rear door. The east opening leads into the Bio Wing and Operating Room, where the containment key is found. A west connector returns through the Operating Room shortcut to the hall. The key opens the raised containment door into the Rear Lab. A physical lift rises three metres to the discharge gallery and exit. The hall's west service alcove is optional and marked as a secret when opened.

The route uses continuous shared rendered/physical floors, twelve low stair treads, door meshes and lift platform. There is no jump, dash or reload. Doors open once and remain open during play; this avoids closing/crushing an actor. Reset restores closed doors only when the encounter is restarted. The lift moves at 1.25 metres per second with `AnimatableBody3D` physics synchronisation; the player's existing `CharacterBody3D` platform carry transports grounded passengers.

## Scene contract

- `ward_room: String` on room centre markers; `room_bounds: Vector3` contains local **half extents**. IDs are `ContainmentHall`, `BioWing`, `OperatingRoom`, `RearLab`, `ExitGallery`, `Secret`.
- `ward_pickup: String` on visible pickup nodes: `health`, `armor`, `pistol`, `shells`, `key`; optional integer `amount`. Collection is automatic within 1.05 metres. Health and armor cap at 100, and full supplies remain available rather than being consumed.
- `ward_door: String` on an `AnimatableBody3D` with `ward_door.gd`, physical shape and visual mesh; IDs `rear`, `shortcut`, `secret`. Metadata `required_key`, `open_offset`, optional `use_anchor` local position. The anchor stays at the original doorway after opening.
- `ward_lift: bool` on an `AnimatableBody3D` with `ward_lift.gd`, physical platform and mesh; `lift_offset`, optional `use_anchor`. Lift travel cannot be reversed in mid-flight.
- `ward_exit: bool` on the discharge interaction marker. E completes once, with the containment key.
- `ward_nav: Array[String]` on doorway markers connects exactly two room IDs; optional `ward_nav_door: NodePath` excludes shut gates. BFS supplies the first open portal to awakened enemies whose direct view is blocked. Lift travel is a player route, not an enemy navigation edge.

## Runtime API

`setup(combat, player)` discovers authored markers. `interact()` handles E with a 2.6 metre maximum distance and a physical world visibility ray. `get_level_state()` provides objective, prompt, current room, visited IDs, pickup count, key/shortcut/secret/completion flags. `map_rooms` includes only visited rooms, each with `id`, `label`, `rect: Rect2` in world XZ, `position`, `bounds`, and `visited: true`. `get_chase_target(enemy_position, player_position)` provides a portal waypoint. Signals are `completed` and `message_changed(text)`. `reset()` restores pickup visibility, gate/lift state and discovery flags.

## Validation

Run `tools/check_pale_ward_route.gd` with the pinned Godot 4.7.2 editor. The fixture uses actual player physics with injected W input, disables enemies to isolate traversal, and records route segments, key gate, supply effects, grounded lift transport, exit and reset under `verification/combat/pale-ward-route.json`.

This is a connected playable authored art pass. Its duration, enemy pacing and complete-level polish require actual play review; no five-to-eight-minute completion-time claim is made.

The pinned 4.7.2 headless route fixture passed on the authored twelve-step scene. Each tread's visible box dimensions and ray-contact top match its physical shape. The real player traversed the main route and secret without jumping, could not cross the locked rear door, operated both gates with E, rode the lift up and down, completed the exit and restored pickup/mechanism state on reset. Stair ascent/descent logs retain brief physics floor-flag transitions rather than claiming uninterrupted floor flags.

The mandatory starting/placed supplies provide 56 pistol rounds and 28 shells against 1,200 total authored enemy HP. Their maximum damage capacity is 4,256 assuming every ray/pellet hits; this arithmetic excludes melee and secret supplies and does not establish combat survival or pacing. The traversal fixture disables enemies. Real encounter play review remains separate.
