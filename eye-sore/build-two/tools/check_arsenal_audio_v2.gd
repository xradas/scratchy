extends SceneTree
## Actual Combat events route imported candidate recordings. Release-safe checks.
## Headless execution verifies stream ownership/routing, not listening acceptance.
var world: Node3D
var combat: Node3D
var audio: Node3D
var player: CharacterBody3D
var events: Array[Dictionary] = []
var records: Array[Dictionary] = []
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("ARSENAL_AUDIO_FAILED: " + message); quit(1); return false
	checks += 1; return true

func ready_weapon(id: StringName) -> void:
	combat.currentweapon = id; combat.cooldown = 0; combat.weapon_phase = &"idle"

func cue_count(id: StringName) -> int: return int(audio.cue_counts.get(id, 0))

func count_event(type: StringName) -> int:
	var count := 0
	for event in events:
		if event.type == type: count += 1
	return count

func resolve_projectile() -> bool:
	for child in combat.get_children():
		if child.get_script() != preload("res://scripts/player_ordnance.gd") or child.resolved: continue
		child.set_physics_process(false)
		for frame in 140:
			child._physics_process(1.0 / 60.0)
			if child.resolved: return true
			await physics_frame
		return false
	return false

func run() -> void:
	var profile: CombatAudioProfile = load("res://resources/combat_audio.tres")
	var before: CombatAudioProfile = load("res://concepts/audio-v6/preservation/combat_audio-before.tres")
	if not check(profile.cues.size() == 48 and before.cues.size() == 35, "48 runtime cues with 35 preserved baseline cues"): return
	if not check(profile.music.resource_path == before.music.resource_path and profile.music_gain_db == before.music_gain_db, "old music path and gain unchanged"): return
	for i in before.cues.size():
		var prior: CombatCue = before.cues[i]; var current: CombatCue = profile.cues[i]
		if not check(prior.identifier == current.identifier and prior.bus == current.bus and prior.gain_db == current.gain_db and prior.spatial == current.spatial and prior.variations.size() == current.variations.size(), "old cue exported values preserved: " + String(prior.identifier)): return
		for j in prior.variations.size():
			if not check(prior.variations[j].resource_path == current.variations[j].resource_path, "old sample resource preserved"): return
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/runtime-cues.json"))
	var old_ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://concepts/audio-v6/preservation/runtime-before.json"))
	for key in old_ledger.cues:
		if not check(ledger.cues[key] == old_ledger.cues[key], "old runtime ledger entry unchanged: " + key): return
	world = Node3D.new(); root.add_child(world)
	var spawns := Node3D.new(); spawns.name = "EnemySpawns"; world.add_child(spawns)
	player = CharacterBody3D.new(); player.collision_layer = 2; world.add_child(player)
	player.position = Vector3(0, .87, 0)
	var camera := Camera3D.new(); camera.name = "Camera3D"; camera.position.y = .4; player.add_child(camera)
	combat = preload("res://scripts/combat.gd").new(); world.add_child(combat)
	combat.setup(world, player); combat.set_physics_process(false)
	audio = preload("res://scripts/combat_audio.gd").new(); world.add_child(audio); audio.setup(profile, false)
	combat.combat_event.connect(audio.handle_event)
	combat.combat_event.connect(func(event: Dictionary): events.append(event.duplicate()))
	for weapon in [&"twin_shotgun", &"rivet_cannon", &"siege_launcher"]:
		for material in [&"flesh", &"armor", &"hard"]:
			audio.stop_all(); combat.reset(); combat.set_physics_process(false)
			if not check(combat.grant_weapon(weapon, 10), "actual pickup enables audio test weapon"): return
			var obstacle: Node3D
			if material == &"hard":
				var body := StaticBody3D.new(); body.collision_layer = 1; body.set_meta("hit_material", material)
				world.add_child(body); body.position = Vector3(0, 1.27, -2)
				var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(4, 4, .05); shape.shape = box; body.add_child(shape); obstacle = body
			else:
				var enemy: CharacterBody3D = combat.spawn_enemy(&"vessel" if material == &"armor" else &"unsealed", Vector3(0, 1.27, -2))
				enemy.health = 1000; enemy.set_physics_process(false); obstacle = enemy
			await physics_frame; await physics_frame
			ready_weapon(weapon); events.clear()
			var fire_id := StringName(String(weapon) + "_fire"); var impact_id := StringName(String(weapon) + "_" + String(material))
			var fire_before := cue_count(fire_id); var impact_before := cue_count(impact_id); var explosion_before := cue_count(&"siege_explosion")
			if not check(combat.try_fire(), "actual accepted shot: " + String(weapon)): return
			if weapon == &"siege_launcher":
				if not check(await resolve_projectile(), "actual swept siege collision for " + String(material)): return
			if not check(count_event(&"shot") == 1 and count_event(&"impact") == 1 and cue_count(fire_id) == fire_before + 1 and cue_count(impact_id) == impact_before + 1, "one actual fire and material sound for " + String(weapon) + "/" + String(material)): return
			if not check(cue_count(&"siege_explosion") == explosion_before + (1 if weapon == &"siege_launcher" else 0), "sole authoritative siege explosion cue"): return
			var counts: Dictionary = audio.cue_counts.duplicate()
			for event in events:
				if int(event.get("shot_id", 0)) > 0: audio.handle_event(event)
			if not check(audio.cue_counts == counts, "duplicate delivered resolved events create no second voice"): return
			if not check(not combat.try_fire() and audio.cue_counts == counts, "cooldown rejection produces no accepted audio"): return
			records.append({"weapon": weapon, "material": material, "shot_id": combat.shot_counter, "actual_shots": count_event(&"shot"), "actual_impacts": count_event(&"impact"), "actual_explosions": count_event(&"ordnance_explosion"), "fire_cue": fire_id, "contact_cue": impact_id, "duplicate_suppressed": true})
			obstacle.queue_free(); combat.enemies.clear(); await physics_frame; await physics_frame
	# Actual repeated rapid fire: each fresh accepted shot has its own short sample.
	audio.stop_all(); combat.reset(); combat.set_physics_process(false); combat.grant_weapon(&"rivet_cannon", 10)
	ready_weapon(&"rivet_cannon"); events.clear(); var repeated_before := cue_count(&"rivet_cannon_fire")
	for shot in 4:
		if shot > 0: combat._physics_process(.16)
		if not check(combat.try_fire(), "actual repeated rivet cadence accepted"): return
	if not check(count_event(&"shot") == 4 and cue_count(&"rivet_cannon_fire") == repeated_before + 4 and combat.ammo_rivets == 6, "four accepted shots, four voices, four ammo"): return
	if not check(audio.cue_map[&"rivet_cannon_fire"].variations[0].get_length() <= .17, "rapid sample does not obscure following .16 second discharge"): return
	# Use the longer real twin discharge to observe pausable playback ownership.
	audio.stop_all(); combat.reset(); combat.set_physics_process(false); combat.grant_weapon(&"twin_shotgun", 10)
	ready_weapon(&"twin_shotgun")
	if not check(combat.try_fire(), "launch actual sound before pause"): return
	var voice: Node = audio.voices.back()
	await create_timer(.04, true).timeout
	paused = true; var position_before: float = voice.get_playback_position()
	await create_timer(.12, true).timeout
	var drift: float = absf(voice.get_playback_position() - position_before)
	if not check(voice.can_process() == false and drift < .04, "tree pause freezes actual imported voice"): return
	paused = false; await create_timer(.06, true).timeout
	if not check(voice.can_process() and voice.get_playback_position() >= position_before, "resume retains existing voice owner"): return
	# Retry cleanup clears old identities, so reset shot 1 can sound once again.
	var retired_voice: Node = voice
	audio.stop_all(); combat.reset(); combat.set_physics_process(false)
	if not check(not retired_voice.playing and retired_voice.stream == null and audio.voices.is_empty() and audio.seen_events.is_empty(), "retry cancels streams and duplicate identities"): return
	combat.grant_weapon(&"twin_shotgun", 4); ready_weapon(&"twin_shotgun"); var retry_before := cue_count(&"twin_shotgun_fire")
	if not check(combat.try_fire() and combat.shot_counter == 1 and cue_count(&"twin_shotgun_fire") == retry_before + 1, "retry shot id 1 gets a fresh sound"): return
	var result := {"checks": checks, "scope": "Headless actual Combat/imported audio stream routing and ownership. No subjective listening approval or audible output capture claimed.", "old_cues_preserved": 35, "new_cues": 13, "pause_playback_drift_seconds": drift, "actual_contacts": records, "repeated_rivet_shots": 4, "retry_fresh_identity": true}
	var path := "res://verification/arsenal-architecture-v2/audio-runtime.json"
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if not check(error == OK, "audio evidence directory writable"): return
	var output := FileAccess.open(path, FileAccess.WRITE)
	if not check(output != null, "audio evidence file writable"): return
	result.checks = checks
	output.store_string(JSON.stringify(result, "  ") + "\n"); output.close()
	audio.stop_all(); world.queue_free(); await process_frame; await process_frame
	print("ARSENAL_AUDIO_OK: %d release-safe checks; 35 old cue/profile values unchanged; nine actual new gun/material contacts; single explosion/duplicates; four actual rapid shots; pause/resume/retry. Listening acceptance pending." % checks)
	quit(0)
