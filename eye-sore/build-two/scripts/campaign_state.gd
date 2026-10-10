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

func seek(level_id: String) -> bool:
	for index in levels.size():
		if String(levels[index].id) == level_id:
			current_index = index
			entry_snapshot.clear()
			return true
	return false

func current_level() -> Dictionary:
	return levels[current_index] if current_index >= 0 and current_index < levels.size() else {}

func next_level() -> Dictionary:
	return levels[current_index + 1] if current_index + 1 < levels.size() else {}

func advance() -> bool:
	if next_level().is_empty(): return false
	current_index += 1
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
	combat.dead = false
	combat.weapon_phase = &"idle"
	combat.phase_time = 0.0
	combat.cooldown = 0.0
	combat.recoil_remaining = 0.0
