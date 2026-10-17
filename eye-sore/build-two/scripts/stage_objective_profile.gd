class_name StageObjectiveProfile
extends Resource
## Optional authored progression. An absent resource keeps legacy stage rules.
@export var level_id: String = ""
@export var initial_flags: Dictionary = {}
@export var objectives: Array[Dictionary] = []
@export var controls: Dictionary = {}
@export var encounters: Dictionary = {}
@export var keys: Dictionary = {}
@export var exit_requires: Array[String] = []
@export var checkpoint_options: Dictionary = {"stationary_seconds":0.5,"threat_radius":10.0}

static func from_dictionary(data: Dictionary) -> StageObjectiveProfile:
	var result := StageObjectiveProfile.new()
	result.level_id = String(data.get("level_id",""))
	for field in ["initial_flags","controls","keys","encounters","checkpoint_options"]:
		if data.get(field) is Dictionary: result.set(field,data[field].duplicate(true))
	for entry in data.get("objectives",[]):
		if entry is Dictionary: result.objectives.append(entry.duplicate(true))
	for flag in data.get("exit_requires",[]): result.exit_requires.append(String(flag))
	return result

func unmet(requirements: Array, flags: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for flag in requirements:
		if not bool(flags.get(String(flag),false)): result.append(String(flag))
	return result

func objective_text(flags: Dictionary) -> String:
	for entry in objectives:
		if not unmet(entry.get("requires",[]),flags).is_empty(): continue
		var completed := String(entry.get("complete_flag",""))
		if not completed.is_empty() and bool(flags.get(completed,false)): continue
		return String(entry.get("text",""))
	return "Reach the enabled exit." if unmet(exit_requires,flags).is_empty() else "Complete the remaining objectives."
