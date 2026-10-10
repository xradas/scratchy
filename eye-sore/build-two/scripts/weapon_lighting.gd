extends Node3D
## A single real surface light driven only by Combat's accepted shot events.
## Combat owns ammunition, damage, timing and audio; this node owns only light.
const PISTOL_DURATION: float = 0.055
const SHOTGUN_DURATION: float = 0.08

var combat: Node3D
var flash: OmniLight3D
var remaining: float = 0.0
var active_shot_id: int = 0

func setup(owner_combat: Node3D) -> void:
	if is_instance_valid(combat) and combat.combat_event.is_connected(handle_event):
		combat.combat_event.disconnect(handle_event)
	combat = owner_combat
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not is_instance_valid(flash):
		flash = OmniLight3D.new()
		flash.name = "MuzzleSurfaceLight"
		flash.light_color = Color(1.0, 0.88, 0.72)
		flash.shadow_enabled = false
		add_child(flash)
	reset()
	combat.combat_event.connect(handle_event)

func reset() -> void:
	remaining = 0.0
	active_shot_id = 0
	if is_instance_valid(flash):
		flash.visible = false
		flash.light_energy = 0.0

func handle_event(event: Dictionary) -> void:
	if event.get("type", &"") == &"encounter_started":
		reset()
		return
	if event.get("type", &"") != &"shot": return
	if not is_instance_valid(combat) or not is_instance_valid(combat.camera): return
	var weapon := StringName(event.get("weapon_id", &""))
	if weapon not in [&"pistol", &"shotgun", &"twin_shotgun", &"rivet_cannon", &"siege_launcher"]: return
	var camera: Camera3D = combat.camera
	flash.global_position = camera.global_position - camera.global_basis.z * 0.4
	var values: Vector3 = {
		&"pistol": Vector3(PISTOL_DURATION, 5.0, 2.5),
		&"shotgun": Vector3(SHOTGUN_DURATION, 7.0, 4.0),
		&"twin_shotgun": Vector3(.10, 8.0, 5.5),
		&"rivet_cannon": Vector3(.045, 5.5, 3.0),
		&"siege_launcher": Vector3(.10, 8.5, 5.0)
	}[weapon]
	remaining = values.x
	flash.omni_range = values.y
	flash.light_energy = values.z
	active_shot_id = int(event.get("shot_id", 0))
	flash.visible = true

func _process(delta: float) -> void:
	if remaining <= 0.0: return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0: reset()
