extends SceneTree
## Actual main UI selection/music/lifecycle. Route gameplay is checked separately.
var app: Control
var failures: Array[String] = []
var records: Array[Dictionary] = []
var evidence_dir := "res://verification/expansion-v1/main"
const MENU_PATH := "res://assets/audio/music/menu_abelian.ogg"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label); push_error(label)

func freeze_actors() -> void:
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)

func cue_identity() -> Dictionary:
	var result: Dictionary = {}; var streams: Dictionary = {}
	check(app.combat_audio.cue_map.size() == 35,"expanded profile exposes35 resolved cues")
	for kind in ["unsealed","vessel","ironbound","censer","reaver","surveyor"]:
		var names: Array[String] = []
		for action in ["attack_warning","hurt","death"]:
			var id := StringName(kind + "_" + action)
			check(app.combat_audio.cue_map.has(id),"mapped demonic cue " + String(id))
			if not app.combat_audio.cue_map.has(id): continue
			var cue: CombatCue = app.combat_audio.cue_map[id]
			check(cue.bus == &"Creatures" and cue.spatial,"creature positional voice bus " + String(id))
			var path: String = cue.variations[0].resource_path
			check(not path.is_empty() and not streams.has(path),"unique species voice resource " + String(id))
			streams[path] = true; names.append(path)
		result[kind] = names
	return result

func fresh_world(entry: Dictionary, expected_arenas: Dictionary) -> void:
	var stage: Node3D = app.world
	check(stage.get_meta("stage_id","") == entry.id,"selector instantiates authored stage " + String(entry.id))
	check(stage.get_meta("stage_title","") == entry.title,"authored stage title " + String(entry.id))
	check(stage.flags.is_empty() and stage.collected.is_empty() and stage.dead_ids.is_empty(),"retry clears keys/pickups/death accounting")
	check(stage.secrets.is_empty() and stage.shortcuts.is_empty() and stage.arena_active.is_empty(),"retry clears secrets/shortcuts/arena activation")
	check(not stage.finished and not stage.secret_found and not stage.shortcut_open,"retry clears completion/extras flags")
	check(stage.arena_remaining == expected_arenas,"retry restores authored arena counts")
	check(stage.enemy_groups.size() == app.combat.total_enemies,"retry restores stage target mapping")
	for item in stage.pickups: check(item.visible,"retry restores physical pickup")
	for mechanism in stage.mechanisms:
		if mechanism.has_method("reset_door"): check(not mechanism.opened and mechanism.position == mechanism.origin,"retry resets visible/colliding gate")
		if mechanism.has_method("reset_lift"): check(not mechanism.upper and not mechanism.moving and mechanism.position == mechanism.origin,"retry resets real lift")
	check(app.combat.kills == 0 and not app.combat.dead,"retry clears combat kills/death")
	check(app.combat.health == 100 and app.combat.armor == 50 and app.combat.ammo_pistol == 36 and app.combat.ammo_shotgun == 12,"retry restores starting combat resources")
	check(app.combat.gore.death_count == 0 and app.combat.gore.death_records.is_empty() and app.combat.gore.stains.is_empty() and app.combat.gore.remains.is_empty() and app.combat.gore.particles.is_empty(),"retry clears all gore collections")
	check(app.combat_audio.voices.is_empty() and app.combat_audio.seen_events.is_empty(),"retry clears voice/event ownership")
	check(not app.level_complete and app.level_message.is_empty() and app.damage_flash == 0 and app.muzzle_time == 0 and not app.muzzle_pending,"retry clears main completion/message/hit/flash flags")
	check(not app.automap.visible,"retry hides map overlay")

func run() -> void:
	if DisplayServer.get_name() != "headless": root.set_flag(Window.FLAG_NO_FOCUS,true)
	app = preload("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.automated_input = true
	check(app.stage_catalog.size() == 3 and app.stage_selector.item_count == 3,"actual menu exposes three authored catalog stages")
	check(paused and not app.started and app.menu.visible,"initial title remains paused")
	check(is_instance_valid(app.menu_music) and app.menu_music.name == "MenuAbelian" and app.menu_music.playing,"Abelian plays on title")
	check(is_equal_approx(app.menu_music.stream.get_length(),(load(MENU_PATH) as AudioStream).get_length()),"title stream is approved Abelian")
	check(not app.combat_audio.music_player.playing,"title does not play stage music")
	var menu_identity: int = app.menu_music.get_instance_id()
	var identities := cue_identity()
	for index in app.stage_catalog.size():
		var entry: Dictionary = app.stage_catalog[index]
		# Selecting the real OptionButton signal invokes main's title/stage swap.
		app.stage_selector.select(index); app.stage_selector.item_selected.emit(index)
		freeze_actors()
		check(app.stage_id == entry.id and app.selected_stage() == entry,"actual OptionButton signal selects catalog entry")
		check(app.world.scene_file_path == entry.scene,"main loads selected stage scene")
		check(paused and not app.started and app.menu_music.playing,"stage selection returns to paused Abelian title")
		check(not app.combat_audio.music_player.playing,"stage selection title keeps level stream stopped")
		check((app.title_art.texture as AtlasTexture).atlas.resource_path == entry.title_board,"stage selector uses themed title board")
		check(app.menu_title.text.contains(String(entry.title).to_upper()),"menu title reflects selected stage")
		var roster: Dictionary = {}
		for enemy in app.combat.enemies:
			var kind := String(enemy.definition.identifier)
			roster[kind] = int(roster.get(kind,0)) + 1
			check(kind in entry.enemy_kinds,"stage contains only its authored two species")
			check(enemy.has_meta("arena_id") and app.world.enemy_groups.has(enemy.target_id),"main wires every stage enemy group")
		check(roster.size() == 2 and app.combat.total_enemies >= 32 and app.combat.total_enemies <= 44,"expanded stage authored roster32–44 with both species")
		check(app.combat_audio.profile.music.resource_path == entry.music,"selected theme owns level music resource")
		check(app.combat_audio.profile.music.resource_path != MENU_PATH,"Abelian excluded from level music")
		var expected_arenas: Dictionary = app.world.arena_remaining.duplicate()
		var fresh_visited: Dictionary = app.world.visited.duplicate()
		app.enter_combat()
		check(app.started and not paused and not app.menu_music.playing and app.combat_audio.music_player.playing,"Play switches title music to selected level music")
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"automated fixture never captures physical pointer")
		# Material and creature audio enter through the actual main event bridge.
		var kind := String(entry.enemy_kinds[0])
		app.combat.emit_event({"type":&"enemy_attack_warning","enemy_kind":kind,"target_id":"lifecycle_voice","attack_id":71,"position":app.player.global_position})
		check(app.combat_audio.last_cue == StringName(kind+"_attack_warning"),"main routes actual species warning")
		check(not app.combat_audio.voices.is_empty(),"resolved event creates owned voice")
		var old_voice: Node = app.combat_audio.voices.back()
		var rng := RandomNumberGenerator.new(); rng.seed = 21
		app.combat.gore.burst(app.player.global_position+Vector3.UP,Vector3.FORWARD,8,rng)
		app.automap.visible = true
		app.set_paused(true)
		check(paused and not app.automap.visible and app.menu.visible and not app.crosshair.visible,"Pause hides map and stops gameplay processing")
		check(not app.menu_music.playing and not app.combat_audio.can_process(),"pause keeps Abelian stopped and suspends stage audio owner")
		var positions: Array[Vector3] = []
		for particle in app.combat.gore.particles: positions.append(particle.node.global_position)
		var pose: Vector3 = app.player.global_position
		await create_timer(.15,true).timeout
		check(app.player.global_position == pose,"paused player position stable")
		for i in positions.size(): check(app.combat.gore.particles[i].node.global_position == positions[i],"paused gore positions stable")
		app.set_paused(false)
		# Deliberately contaminate persistent state as a late-run retry would encounter.
		var stale_room := String(app.world.rooms.back().get_meta("stage_room"))
		app.world.flags = {"power":true,"brass":true,"red":true,"exit":true}
		app.world.visited[stale_room] = true; app.world.secrets["lifecycle_secret"] = true; app.world.shortcuts["lifecycle_shortcut"] = true
		app.world.collected[1234567] = true; app.world.dead_ids["lifecycle_dead"] = true; app.world.arena_active["arena_one"] = true
		app.world.finished = true; app.world.secret_found = true; app.world.shortcut_open = true
		for arena_id in app.world.arena_remaining: app.world.arena_remaining[arena_id] = 0
		for item in app.world.pickups: item.visible = false
		for mechanism in app.world.mechanisms:
			if mechanism.has_method("reset_door"): mechanism.opened = true; mechanism.position += Vector3.UP * 2
			if mechanism.has_method("reset_lift"): mechanism.upper = true; mechanism.moving = true; mechanism.position += Vector3.UP
		app.automap.visible = true; app.automap.update_map(app.world.get_level_state(),pose,0)
		var corpse: CharacterBody3D = app.combat.enemies[0]
		corpse.apply_damage(corpse.health,900+index,&"pistol",corpse.global_position)
		check(corpse.dead and not corpse.gibbed and not corpse.corpse_shapes.is_empty(),"retry fixture contains real intact corpse queries")
		var old_queries: Array[Node] = []; old_queries.assign(corpse.corpse_shapes)
		app.combat.kills = 29; app.combat.dead = true; app.combat.health = 0
		app.level_complete = true; app.level_message = "lifecycle stale"; app.damage_flash = .24; app.muzzle_time = .5; app.muzzle_pending = true
		var old_world: Node = app.world; var old_combat: Node = app.combat; var old_audio: Node = app.combat_audio; var old_gore: Node = app.combat.gore
		app.restart_combat(); freeze_actors()
		check(not is_instance_valid(old_world) and not is_instance_valid(old_combat) and not is_instance_valid(old_audio) and not is_instance_valid(old_gore),"retry destroys previous owners")
		check(not is_instance_valid(old_voice),"retry destroys old creature voice")
		for query in old_queries: check(not is_instance_valid(query),"retry destroys old corpse query body")
		fresh_world(entry,expected_arenas)
		check(app.world.visited == fresh_visited,"retry restores fresh visited-room state")
		check(app.started and not paused and not app.menu_music.playing and app.combat_audio.music_player.playing,"retry resumes selected level stream")
		# Opening the actual map event updates from the fresh world's visited set.
		var map_event := InputEventKey.new(); map_event.pressed = true; map_event.keycode = KEY_TAB
		app._input(map_event); await process_frame; await process_frame
		check(app.automap.visible,"actual Tab input opens map")
		check(not stale_room in app.automap.state.get("visited_rooms",[]),"retry map contains no previous visited secret/final room")
		app.return_to_title(); freeze_actors()
		check(paused and not app.started and app.menu_music.playing and not app.combat_audio.music_player.playing,"Return to title restores only Abelian")
		check(app.menu_music.get_instance_id() == menu_identity,"stage swaps/retry keep one menu music owner")
		records.append({"stage":entry.id,"scene":entry.scene,"roster":roster,"music":entry.music,"arena_counts":expected_arenas,"selector_signal":true,"title_only_abelian":true,"pause_frozen":true,"retry_flags_map_gore_queries_voices_cleared":true})
	var evidence := {"stages":records,"species_voice_resources":identities,"cue_count":35,"failures":failures,"scope":"Actual main selector/scene/audio/pause/retry ownership; controlled stale-state injection tests reset. Route gameplay and audible appeal are covered separately."}
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var file := FileAccess.open(evidence_dir.path_join("contract.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(evidence,"  ")); file.close()
	print("EXPANSION_MAIN_CHECK_", "OK" if failures.is_empty() else "FAILED", " ",JSON.stringify(evidence))
	app.set_paused(true); app.combat_audio.stop_all(); app.menu_music.stream_paused = false; app.menu_music.stop(); app.menu_music.stream = null
	await create_timer(.3,true).timeout
	app.free(); paused = false
	await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
