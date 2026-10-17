extends RefCounted

const COMBAT_FIELDS := ["health", "armor", "ammo_pistol", "ammo_shotgun", "ammo_rivets", "ammo_rockets", "owned_weapons", "currentweapon"]

var levels: Array[Dictionary] = []
var current_index := 0
var entry_snapshot: Dictionary = {}

func load_catalog(path: String) -> bool:
	levels.clear()
	if not FileAccess.file_exists(path): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.has("chapters"): return false
	for chapter_value in parsed.chapters:
		if not chapter_value is Dictionary: return false
		var chapter: Dictionary = chapter_value
		if not chapter.has("id") or not chapter.has("title") or not chapter.has("levels"): return false
		var chapter_levels: Array = chapter.levels
		for local_index in chapter_levels.size():
			var level_value: Variant = chapter_levels[local_index]
			if not level_value is Dictionary: return false
			var level: Dictionary = level_value.duplicate(true)
			for key in ["id", "title", "scene", "theme"]:
				if String(level.get(key, "")).is_empty(): return false
			level["chapter_id"] = chapter.id
			level["chapter_title"] = chapter.title
			level["chapter_index"] = local_index
			level["chapter_length"] = chapter_levels.size()
			levels.append(level)
	return not levels.is_empty()

func reset() -> void:
	current_index = 0
	entry_snapshot.clear()
	clear_checkpoint()

func seek(level_id: String) -> bool:
	for index in levels.size():
		if String(levels[index].id) == level_id:
			current_index = index
			entry_snapshot.clear()
			clear_checkpoint()
			return true
	return false

func current_level() -> Dictionary:
	return levels[current_index] if current_index >= 0 and current_index < levels.size() else {}

func next_level() -> Dictionary:
	return levels[current_index + 1] if current_index + 1 < levels.size() else {}

func advance() -> bool:
	if next_level().is_empty(): return false
	current_index += 1
	clear_checkpoint()
	return true

func is_chapter_end() -> bool:
	var current := current_level()
	var next := next_level()
	return not current.is_empty() and (next.is_empty() or current.chapter_id != next.chapter_id)

func capture(combat: Node) -> Dictionary:
	var result: Dictionary = {}
	for field in COMBAT_FIELDS:
		var value: Variant = combat.get(field)
		result[field] = value.duplicate(true) if value is Dictionary else value
	return result

func restore(combat: Node, snapshot: Dictionary) -> void:
	for field in COMBAT_FIELDS:
		if snapshot.has(field):
			var value: Variant = snapshot[field]
			combat.set(field, value.duplicate(true) if value is Dictionary else value)
	# The new campaign world is already bound to combat here. Clamp carried
	# ammunition before Main records this level's retry snapshot.
	if combat.has_method("normalize_ammo"): combat.normalize_ammo()
	combat.dead = false
	combat.weapon_phase = &"idle"
	combat.phase_time = 0.0
	combat.cooldown = 0.0
	combat.recoil_remaining = 0.0

# One latest in-memory checkpoint. Never serialized to user:// or a save file.
var checkpoint_snapshot: Dictionary = {}

func clear_checkpoint() -> void:
	checkpoint_snapshot.clear()

func has_checkpoint(level_id: String = "") -> bool:
	return not checkpoint_snapshot.is_empty() and (level_id.is_empty() or String(checkpoint_snapshot.get("level_id",""))==level_id)

func capture_checkpoint(world: Node, combat: Node, player: CharacterBody3D, checkpoint_id: String) -> bool:
	if world.get("objective_profile")==null or not world.checkpoint_is_safe():return false
	var world_state:Dictionary=world.capture_checkpoint_state()
	if world_state.is_empty():return false
	checkpoint_snapshot={"level_id":world.objective_profile.level_id,"checkpoint_id":checkpoint_id,"inventory":capture(combat),"combat":{"kills":combat.kills,"shot_counter":combat.shot_counter},"world":world_state,"player":{"transform":player.global_transform,"camera_pitch":player.get_node("Camera3D").rotation.x,"crouching":bool(player.get("is_crouching"))}}
	return true

func restore_checkpoint(world: Node, combat: Node, player: CharacterBody3D, data: Dictionary) -> bool:
	if world.get("objective_profile")==null or String(data.get("level_id",""))!=world.objective_profile.level_id:return false
	if not world.restore_checkpoint_state(data.get("world",{})):return false
	restore(combat,data.get("inventory",{}))
	for field in ["kills","shot_counter"]:combat.set(field,data.get("combat",{}).get(field,0))
	combat.empty_cooldown=0.0
	player.set_movement_active(false)
	if bool(data.get("player",{}).get("crouching",false)) and player.has_method("_set_crouching"):player._set_crouching(true)
	player.global_transform=data.player.transform;player.velocity=Vector3.ZERO
	player.get_node("Camera3D").rotation.x=float(data.player.get("camera_pitch",0.0))
	# Directional hurt/corpse registration must use the restored camera now,
	# including before the next physics tick or an immediate accepted shot.
	for enemy in combat.enemies:enemy.update_presentation()
	return true
