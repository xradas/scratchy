extends StaticBody3D
## A metal mechanism is never an enemy: no definition, health reward or gore.
@export var health: float = 60.0
@export var completion_flag: String = ""
var target_id: String
var disabled := false
var stage: Node
var seen_shots: Dictionary = {}
var initial_health: float
func _ready() -> void:
	health=float(get_meta("health",health));initial_health=health
	collision_layer|=4
	target_id=String(get_meta("stable_id",name))
	completion_flag=String(get_meta("completion_flag",completion_flag))
	set_meta("hit_material",&"armor")
func is_shootable_mechanism() -> bool: return true
func setup(owner_stage: Node) -> void:
	stage=owner_stage
func reset_mechanism() -> void:
	health=initial_health;disabled=false;seen_shots.clear();refresh_presentation()
func refresh_presentation() -> void:
	set_meta("disabled",disabled)
	var live:=get_node_or_null("LiveIndicator")
	var broken:=get_node_or_null("BrokenIndicator")
	if live is Node3D: live.visible=not disabled
	if broken is Node3D: broken.visible=disabled
func apply_mechanism_damage(amount: float, shot_id: int, weapon: StringName, point: Vector3) -> Dictionary:
	if disabled or amount<=0 or seen_shots.has(shot_id) or get_tree().paused or not is_instance_valid(stage) or stage.combat.dead:return {}
	seen_shots[shot_id]=true
	if not stage.missing_requirements(self).is_empty(): return {}
	health=maxf(0.0,health-amount)
	var event:={"type":&"mechanism_damaged","target_id":target_id,"shot_id":shot_id,"weapon_id":weapon,"position":point,"material":&"armor","damage":amount,"health":health}
	stage.combat.emit_event(event)
	if health<=0:
		disabled=true;refresh_presentation()
		if not completion_flag.is_empty():stage.set_progress_flag(completion_flag)
		stage.combat.emit_event({"type":&"mechanism_disabled","target_id":target_id,"shot_id":shot_id,"weapon_id":weapon,"position":point,"material":&"armor","completion_flag":completion_flag})
	return event
func capture_mechanism_state() -> Dictionary:
	return {"health":health,"disabled":disabled,"seen_shots":seen_shots.duplicate(true)}
func restore_mechanism_state(data: Dictionary) -> void:
	health=float(data.get("health",initial_health));disabled=bool(data.get("disabled",false));seen_shots=data.get("seen_shots",{}).duplicate(true);refresh_presentation()
