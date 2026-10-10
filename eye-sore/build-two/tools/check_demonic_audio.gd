extends SceneTree
## Focused real-resource regression for redesigned creature voices.
## tools/godot.sh --headless --script tools/check_demonic_audio.gd -- \
##   --evidence-dir=res://verification/demonic-aim-v1/audio

const CREATURES := ["unsealed", "vessel"]
const ACTIONS := ["attack_warning", "hurt", "death"]
const BASELINE := "res://verification/demonic-aim-v1/audio/prechange-preserved-audio.json"
var evidence_dir := "res://verification/demonic-aim-v1/audio"
var checks := 0
var failures: Array[String] = []
var report: Dictionary = {"creature_cues": {}, "preserved_audio": {}, "lifecycle": {}}
var app: Control

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	call_deferred("run_check")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("DEMONIC_AUDIO_FAILED: " + message)

func read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func cue_by_name(profile: CombatAudioProfile, name: String) -> CombatCue:
	for cue in profile.cues:
		if String(cue.identifier) == name: return cue
	return null

func raw_path(path: String) -> String:
	return path if path.begins_with("res://") else "res://" + path

func save_report() -> void:
	report.checks = checks
	report.failures = failures
	report.passed = failures.is_empty()
	report.scope = "Real-resource creature cue routing, authored audio identity and ownership only; subjective demonic tone and stereo mix require listening review."
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir))
	var file := FileAccess.open(evidence_dir.path_join("audio-contract.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	else: push_error("Could not write audio contract report")
	print("DEMONIC_AUDIO_%s: %d checks, %d failures" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func run_check() -> void:
	var manifest := read_json("res://assets/audio/runtime-cues.json")
	var baseline := read_json(BASELINE)
	var design := read_json("res://concepts/audio-v4/manifest.json")
	check(not manifest.is_empty() and not baseline.is_empty() and not design.is_empty(), "audio manifest, design ledger and preservation baseline load")
	if manifest.is_empty() or baseline.is_empty() or design.is_empty(): save_report(); return
	var profile: CombatAudioProfile = load("res://resources/combat_audio.tres")
	check(profile != null, "real combat audio profile loads")
	if profile == null: save_report(); return
	for name in baseline.preserved:
		var original: Dictionary = baseline.preserved[name]
		var path: String = original.get("path", original.get("registration", {}).get("file", ""))
		var actual_sha := FileAccess.get_sha256(raw_path(path))
		check(actual_sha == String(original.sha256), name + " source audio bytes preserved")
		if original.has("registration"):
			var entry: Dictionary = manifest.get("cues", {}).get(name, {})
			check(entry == original.registration, name + " cue registration preserved")
			var cue := cue_by_name(profile, name)
			check(cue != null and cue.bus == StringName(entry.get("bus", "World")) and cue.variations.size() == 1 and cue.variations[0].resource_path == String(entry.get("file", "")), name + " real profile still selects preserved file and bus")
		report.preserved_audio[name] = {"path": path, "sha256": actual_sha, "matches_baseline": actual_sha == String(original.sha256)}
	var seen_paths: Dictionary = {}
	for kind in CREATURES:
		for action in ACTIONS:
			var name: String = kind + "_" + action
			var entry: Dictionary = manifest.get("cues", {}).get(name, {})
			var cue := cue_by_name(profile, name)
			check(cue != null and not entry.is_empty(), name + " manifest and profile entry exist")
			if cue == null or entry.is_empty(): continue
			var path: String = entry.get("file", "")
			var designed: Dictionary = design.get("cues", {}).get(name, {})
			check(not designed.is_empty() and path == raw_path(String(designed.get("runtime", ""))), name + " selects designed runtime cue")
			check(FileAccess.get_sha256(path) == String(designed.get("runtime_sha256", "")), name + " byte hash matches design ledger")
			check(path.begins_with("res://") and not seen_paths.has(path), name + " selects a distinct source file")
			seen_paths[path] = true
			check(cue.bus == &"Creatures" and cue.spatial and entry.get("bus", "") == "Creatures", name + " routes spatially to Creatures bus")
			check(cue.variations.size() == 1 and cue.variations[0].resource_path == path, name + " real profile selects manifest stream")
			var stream: AudioStream = cue.variations[0] if not cue.variations.is_empty() else null
			var duration := stream.get_length() if stream != null else 0.0
			check(duration >= 0.08 and duration <= 5.0, name + " stream has bounded audible duration")
			report.creature_cues[name] = {"path": path, "sha256": FileAccess.get_sha256(path), "duration_seconds": duration, "bus": String(cue.bus), "spatial": cue.spatial}
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	check(is_instance_valid(app.menu_music) and app.menu_music.playing, "menu music owns title")
	app.enter_combat()
	app.combat.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	var director: Node3D = app.combat_audio
	check(is_instance_valid(director) and not app.menu_music.playing and director.music_player.playing, "combat music owns encounter")
	for kind in CREATURES:
		var target: String = kind + "_audit"
		var other_target: String = "other_" + kind
		var position := Vector3(2, 0, -3)
		director.handle_event({"type": "enemy_attack_warning", "enemy_kind": kind, "attack_id": 100, "target_id": target, "position": position})
		var warning: Node = director.voices.back()
		check(warning is AudioStreamPlayer3D and warning.bus == &"Creatures" and warning.global_position.is_equal_approx(position), kind + " warning voice is positional")
		director.handle_event({"type": "enemy_attack_warning", "enemy_kind": kind, "attack_id": 100, "target_id": target, "position": position})
		check(int(director.cue_counts.get(StringName(kind + "_attack_warning"), 0)) == 1, kind + " repeated attack event suppressed")
		director.handle_event({"type": "enemy_attack_warning", "enemy_kind": kind, "attack_id": 101, "target_id": other_target, "position": Vector3(-2, 0, -3)})
		var other: Node = director.voices.back()
		director.handle_event({"type": "enemy_hurt", "enemy_kind": kind, "shot_id": 200, "target_id": target, "position": position})
		var hurt: Node = director.voices.back()
		check(warning.is_queued_for_deletion() and not warning.playing and not other.is_queued_for_deletion() and hurt.get_meta("role") == "enemy_hurt", kind + " hurt interrupts only same actor warning")
		director.handle_event({"type": "enemy_death", "enemy_kind": kind, "shot_id": 201, "target_id": target, "position": position})
		var death: Node = director.voices.back()
		check(hurt.is_queued_for_deletion() and not hurt.playing and death.get_meta("role") == "enemy_death" and not other.is_queued_for_deletion(), kind + " death replaces same actor pain only")
		report.lifecycle[kind] = {"warning_count": director.cue_counts.get(StringName(kind + "_attack_warning"), 0), "hurt_count": director.cue_counts.get(StringName(kind + "_hurt"), 0), "death_count": director.cue_counts.get(StringName(kind + "_death"), 0), "actor_interruption": true}
	director.handle_event({"type": "player_hurt", "target_id": "player", "position": Vector3.ZERO})
	check(director.last_cue == &"player_hurt" and director.voices.back().get_meta("target_id") == "player", "player hurt path stays separate")
	app.set_paused(true)
	check(not director.can_process() and not app.menu_music.playing, "pause suspends combat audio owner")
	app.set_paused(false)
	check(director.can_process(), "resume restores combat audio owner")
	var old_owner := director
	app.restart_combat()
	check(not is_instance_valid(old_owner) and app.combat_audio.voices.is_empty() and app.combat_audio.music_player.playing, "retry replaces voice owner and starts level music")
	app.return_to_title()
	check(app.menu_music.playing and not app.combat_audio.music_player.playing and app.combat_audio.voices.is_empty(), "title restores menu music and clears voices")
	app.menu_music.stop()
	app.menu_music.stream = null
	app.combat_audio.stop_all()
	app.free()
	app = null
	await create_timer(0.6, true).timeout
	save_report()
