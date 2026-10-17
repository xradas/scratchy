extends RefCounted
## Session-only data, stable authored identities, no emitted gameplay events.
const WORLD_DICTIONARIES := ["flags","collected","visited","dead_ids","arena_remaining","arena_active","enemy_groups","traps","secrets","shortcuts","checkpoint_used"]
const WORLD_VALUES := ["current_room","finished","prompt","objective","secret_found","shortcut_open"]
const ENEMY_VALUES := ["health","dead","gibbed","awake","state","state_time","attack_id","released","committed_direction","burst_rounds_remaining","burst_cycle_id","burst_round_index","burst_release_blocked","corpse_integrity","collision_layer","collision_mask"]
const MECHANISM_VALUES := ["opened","sealing","upper","moving","obstructed","departure_pending"]

static func has_property(node: Object, field: String) -> bool:
	for property in node.get_property_list():
		if String(property.name)==field:return true
	return false
static func id_for(stage: Node, node: Node) -> String:
	return String(node.get_meta("stable_id",stage.get_path_to(node)))
static func capture(stage: Node) -> Dictionary:
	var result := {"level_id":stage.objective_profile.level_id,"mechanisms":{},"enemies":{}}
	for field in WORLD_DICTIONARIES: result[field]=stage.get(field).duplicate(true)
	for field in WORLD_VALUES: result[field]=stage.get(field)
	for node in stage.checkpoint_mechanisms():
		var state := {"transform":node.transform}
		for field in MECHANISM_VALUES:
			if has_property(node,field):state[field]=node.get(field)
		if node.has_method("capture_mechanism_state"):state["shootable"]=node.capture_mechanism_state()
		result.mechanisms[id_for(stage,node)]=state
	for enemy in stage.combat.enemies:
		if not is_instance_valid(enemy):continue
		var state := {"transform":enemy.global_transform,"velocity":enemy.velocity,"seen_shots":enemy.seen_shots.duplicate(true),"corpse_seen_shots":enemy.corpse_seen_shots.duplicate(true),"visual_transform":enemy.get_node("Visual").transform,"visual_visible":enemy.get_node("Visual").visible}
		for field in ENEMY_VALUES:state[field]=enemy.get(field)
		result.enemies[String(enemy.target_id)]=state
	return result
static func restore(stage: Node, data: Dictionary) -> bool:
	if stage.objective_profile==null or String(data.get("level_id",""))!=stage.objective_profile.level_id:return false
	# Validate IDs before changing any state; an edited or different map cannot
	# silently restore into unrelated actors/mechanisms.
	var actors := {}
	for enemy in stage.combat.enemies:actors[String(enemy.target_id)]=enemy
	if data.get("enemies",{}).size()!=actors.size():return false
	for id in data.get("enemies",{}):
		if not actors.has(id):return false
	var devices := {}
	for node in stage.checkpoint_mechanisms():devices[id_for(stage,node)]=node
	if data.get("mechanisms",{}).size()!=devices.size():return false
	for id in data.get("mechanisms",{}):
		if not devices.has(id):return false
	for field in WORLD_DICTIONARIES:
		if data.has(field):stage.set(field,data[field].duplicate(true))
	for field in WORLD_VALUES:
		if data.has(field):stage.set(field,data[field])
	for id in data.get("mechanisms",{}):
		var node:Node3D=devices[id];var state:Dictionary=data.mechanisms[id]
		for field in MECHANISM_VALUES:
			if state.has(field):node.set(field,state[field])
		# Paused restore teleports the real mechanism and its collider together.
		var sync:Variant=node.get("sync_to_physics") if node is AnimatableBody3D else null
		if node is AnimatableBody3D:node.sync_to_physics=false
		node.transform=state.transform
		if node is AnimatableBody3D:node.sync_to_physics=sync
		if state.has("shootable"):node.restore_mechanism_state(state.shootable)
	for id in data.get("enemies",{}):
		var enemy:CharacterBody3D=actors[id];var state:Dictionary=data.enemies[id]
		for field in ENEMY_VALUES:
			if state.has(field):enemy.set(field,state[field])
		enemy.global_transform=state.transform;enemy.velocity=state.velocity
		enemy.seen_shots=state.seen_shots.duplicate(true);enemy.corpse_seen_shots=state.corpse_seen_shots.duplicate(true)
		enemy.get_node("Visual").transform=state.visual_transform;enemy.get_node("Visual").visible=state.visual_visible
		enemy.clear_corpse_surfaces();enemy.corpse_frame=-1;enemy.sprite_frame=-1
		enemy.update_presentation()
		if enemy.dead:
			for body in enemy.hurt_shapes:body.collision_layer=0
			if not enemy.gibbed and not is_instance_valid(enemy.sprite):enemy.build_rig_corpse_surfaces()
	for node in stage.checkpoint_mechanisms():
		if node.has_method("refresh_landing_gates"):node.refresh_landing_gates()
	stage.refresh_objective();stage.checkpoint_dwell=0.0
	return true
