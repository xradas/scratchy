extends SceneTree
## Controlled imported-stream/Combat/Main lifecycle audit, not route or listening proof.
const BASE := "6d3dc8b5b984ec3acb9809bbf32e8c65afbbedb5"
const KINDS := ["unsealed", "vessel", "ironbound", "censer", "reaver", "surveyor"]
const GUNS := ["melee", "pistol", "shotgun", "twin_shotgun", "rivet_cannon", "siege_launcher"]
var checks := 0
var failures: Array[String] = []
var report := {"preservation": {}, "actual_contacts": [], "actor_voices": [], "campaign_lifecycle": [], "supply_events": []}
var events: Array[Dictionary] = []
var fixture: Node3D
var combat: Node3D
var director: Node3D
var player: CharacterBody3D
var camera: Camera3D
var app: Control
var profile: CombatAudioProfile
var art: Dictionary

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("BALANCE_AUDIO_V4_FAILED: " + message)
func receive(event: Dictionary) -> void: events.append(event.duplicate(true))
func count(type: String, target: String = "") -> int:
	var total := 0
	for event in events:
		if String(event.type) == type and (target.is_empty() or String(event.get("target_id", "")) == target): total += 1
	return total
func cues(key: String) -> int: return int(director.cue_counts.get(StringName(key), 0))
func git(args: PackedStringArray) -> Dictionary:
	var out: Array = []
	var repo := ProjectSettings.globalize_path("res://../..").simplify_path()
	var cmd := PackedStringArray(["-C", repo]); cmd.append_array(args)
	var code := OS.execute("git", cmd, out, true)
	return {"code":code, "text":"".join(out)}
func preserved() -> void:
	var paths := PackedStringArray(["eye-sore/build-two/assets/audio", "eye-sore/build-two/resources/combat_audio.tres", "eye-sore/build-two/resources/default_bus_layout.tres", "eye-sore/build-two/scripts/combat_audio.gd", "eye-sore/build-two/scripts/combat_audio_profile.gd", "eye-sore/build-two/scripts/combat_cue.gd"])
	var tree := git(["ls-tree", "-r", "--name-only", BASE, "--", "eye-sore/build-two/concepts"])
	check(tree.code == 0, "Git baseline source tree readable")
	var dirs: Dictionary = {}
	for path in String(tree.text).split("\n", false):
		if path.begins_with("eye-sore/build-two/concepts/audio"):
			var bits := path.split("/"); dirs["/".join(bits.slice(0,4))] = true
	for path in dirs: paths.append(path)
	var args := PackedStringArray(["diff", "--name-only", BASE, "--"]); args.append_array(paths)
	var delta := git(args)
	check(delta.code == 0 and String(delta.text).strip_edges().is_empty(), "all tracked licensed audio sources, runtime cues, music, profile, buses and director unchanged from release")
	args = PackedStringArray(["ls-tree", "-r", "--name-only", BASE, "--"]); args.append_array(paths)
	var inventory := git(args)
	var hashes: Array = []
	for cue in profile.cues:
		check(not cue.variations.is_empty() and AudioServer.get_bus_index(cue.bus) >= 0, "real cue stream/bus " + String(cue.identifier))
		for stream in cue.variations:
			hashes.append({"cue":String(cue.identifier),"file":stream.resource_path,"sha256":FileAccess.get_sha256(stream.resource_path),"bus":String(cue.bus),"spatial":cue.spatial,"gain_db":cue.gain_db,"duration_seconds":stream.get_length()})
	check(profile.cues.size() == 48, "actual release profile has 48 cues")
	report.preservation = {"baseline_commit":BASE,"git_diff_paths":paths,"changed_paths":String(delta.text).split("\n",false),"tracked_files_compared":String(inventory.text).split("\n",false).size(),"cue_count":profile.cues.size(),"runtime_stream_hashes":hashes,"audio_generation_or_sourcing":false}
func make_fixture() -> void:
	fixture = Node3D.new(); root.add_child(fixture); fixture.set_meta("campaign_level_id", "audio_fixture")
	var markers := Node3D.new(); markers.name = "EnemySpawns"; fixture.add_child(markers)
	var floor_body := StaticBody3D.new(); floor_body.collision_layer = 1; floor_body.position.y = -.1; fixture.add_child(floor_body)
	var shape_node := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(100,.2,100); shape_node.shape = box; floor_body.add_child(shape_node)
	player = CharacterBody3D.new(); player.position.y = .87; player.collision_layer = 2; player.collision_mask = 3; fixture.add_child(player)
	var collision := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.height = 1.7; capsule.radius = .3; collision.shape = capsule; player.add_child(collision)
	camera = Camera3D.new(); camera.name = "Camera3D"; camera.position.y = .4; player.add_child(camera)
	combat = preload("res://scripts/combat.gd").new(); fixture.add_child(combat); combat.setup(fixture,player); combat.set_physics_process(false)
	director = preload("res://scripts/combat_audio.gd").new(); fixture.add_child(director); director.setup(profile,false)
	combat.combat_event.connect(director.handle_event); combat.combat_event.connect(receive)
func spawn(kind: String) -> CharacterBody3D:
	var enemy: CharacterBody3D = combat.spawn_enemy(StringName(kind),Vector3(0,.87,-1.4)); enemy.set_physics_process(false); enemy.rotation.y = PI
	var data: Dictionary = art.enemies[kind]; var clips := {}
	for key in data.clips: clips[key] = Vector2i(data.clips[key][0],data.clips[key][1])
	var foot: Array = data.foot_pivot
	enemy.configure_sprite_sheet(data.file,data.columns,data.directions,clips,data.pixel_size,Vector2(foot[0],foot[1]),data.sprite_options)
	return enemy
func aim(enemy: CharacterBody3D) -> Dictionary:
	var anchor := enemy.global_position + Vector3(0,.22,0); var best := INF; var result := {}
	for key in enemy.sprite_bodies:
		var body: StaticBody3D = enemy.sprite_bodies[key]; var shape: ConcavePolygonShape3D = body.get_node("HitSurface").shape
		if shape == null or body.collision_layer != 4: continue
		var faces := shape.get_faces()
		for i in range(0,faces.size(),3):
			var point := body.to_global((faces[i]+faces[i+1]+faces[i+2])/3.0); var distance := point.distance_squared_to(anchor)
			if distance < best: best = distance; result = {"point":point,"material":String(key)}
	if not result.is_empty(): camera.look_at(result.point)
	return result
func actual_matrix() -> void:
	make_fixture()
	for kind in KINDS:
		for gun in GUNS:
			director.stop_all(); combat.reset(); combat.set_physics_process(false)
			combat.grant_weapon(&"twin_shotgun",40); combat.grant_weapon(&"rivet_cannon",160); combat.grant_weapon(&"siege_launcher",12)
			var enemy := spawn(kind); enemy.health = 1000
			await physics_frame; await physics_frame
			var selected := aim(enemy); check(not selected.is_empty(), "live opaque aim for " + kind + "/" + gun)
			await physics_frame; await physics_frame
			combat.currentweapon = StringName(gun); events.clear()
			var fire_key: String = "melee_swing" if gun == "melee" else gun+"_fire"; var fire_before := cues(fire_key)
			check(combat.try_fire(), "accepted actual " + kind + "/" + gun)
			if gun == "siege_launcher":
				for frame in 100:
					if count("ordnance_explosion") > 0: break
					for child in combat.get_children():
						if child.has_method("is_combat_projectile"):
							child.set_physics_process(false)
							if not child.resolved: child._physics_process(1.0/60.0)
					await physics_frame
			check(count("shot") == 1 and cues(fire_key) == fire_before+1, "one actual shot/fire owner " + kind + "/" + gun)
			check(count("impact", enemy.target_id) == 1 and count("enemy_hurt", enemy.target_id) == 1 and count("enemy_death", enemy.target_id) == 0, "aggregated contact and separate hurt " + kind + "/" + gun)
			for event in events:
				if String(event.type)=="impact":
					var cue_id := StringName(gun+"_"+String(event.material))
					check(director.cue_map.has(cue_id) and director.cue_map[cue_id].bus==&"World" and director.cue_map[cue_id].spatial, "actual material event selects recorded positional cue " + String(cue_id))
			var delivered: Array = []; var ownership: Dictionary = director.cue_counts.duplicate(true)
			for event in events:
				if String(event.type) in ["shot","impact","enemy_hurt","ordnance_explosion"]:
					delivered.append({"type":String(event.type),"material":String(event.get("material","")),"pellets":event.get("pellets",0),"target":String(event.get("target_id",""))}); director.handle_event(event)
			check(director.cue_counts == ownership, "duplicate actual event presentation suppressed " + kind + "/" + gun)
			check(not combat.try_fire() and director.cue_counts == ownership, "cooldown rejected shot is silent")
			report.actual_contacts.append({"species":kind,"weapon":gun,"events":delivered,"cue_counts":ownership,"health_removed":1000-enemy.health,"actual_native_sprite_triangles":true})
	# Real enemy windup and damage methods drive warnings/pain/death cancellation.
	for kind in KINDS:
		director.stop_all(); combat.reset(); combat.set_physics_process(false); var enemy := spawn(kind)
		await physics_frame; await physics_frame; events.clear(); enemy.awake = true
		enemy._physics_process(1.0/60.0)
		check(count("enemy_attack_warning") == 1, "actual enemy windup cue " + kind)
		var warning: Node = director.voices.back()
		enemy.apply_damage(1,900,&"pistol",enemy.global_position)
		var hurt: Node = director.voices.back()
		check(not warning.playing and warning.stream == null and hurt.get_meta("role") == "enemy_hurt", "hurt cancels same actor warning " + kind)
		enemy.apply_damage(enemy.health,901,&"pistol",enemy.global_position)
		check(not hurt.playing and hurt.stream == null and director.last_cue == StringName(kind+"_death") and count("enemy_death") == 1, "death replaces hurt exactly once " + kind)
		report.actor_voices.append({"species":kind,"actual_windup":true,"actual_damage_methods":true,"hurt_interrupts_warning":true,"death_replaces_hurt":true})
	director.stop_all(); fixture.free(); await physics_frame; await physics_frame
func freeze_app() -> void:
	app.automated_input = true; app.player.set_physics_process(false); app.combat.set_physics_process(false); app.world.set_process(false); app.world.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
func main_lifecycle() -> void:
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app); app.automated_input = true
	check(app.menu_music.playing and not app.combat_audio.music_player.playing, "initial menu exclusively owns Abelian")
	check(is_equal_approx(app.menu_music.stream.get_length(),load("res://assets/audio/music/menu_abelian.ogg").get_length()), "menu owns full approved Abelian")
	app.start_new_campaign(); freeze_app()
	for level in 9:
		var id := String(app.campaign.current_level().id); var owner: Node3D = app.combat_audio; director = owner; combat = app.combat
		check(app.campaign.current_index == level and owner.music_player.playing and not app.menu_music.playing, "sole current chapter music " + id)
		check(owner.profile.music.resource_path == String(app.selected_stage().music), "music matches actual current chapter " + id)
		owner.handle_event({"type":"enemy_attack_warning","enemy_kind":"vessel","attack_id":100+level,"target_id":"lifecycle","position":Vector3.ZERO})
		var voice: Node = owner.voices.back(); await create_timer(.025,true).timeout
		app.set_paused(true); var before: float = voice.get_playback_position(); var music_before: float = owner.music_player.get_playback_position()
		await create_timer(.07,true).timeout
		check(not voice.can_process() and not owner.music_player.can_process() and absf(voice.get_playback_position()-before)<.04 and absf(owner.music_player.get_playback_position()-music_before)<.04 and not app.menu_music.playing, "pause freezes voices and level music without menu overlay " + id)
		var ammo_before: int = combat.ammo_pistol; events.clear(); combat.combat_event.connect(receive)
		combat.ammo_pistol = 95
		check(combat.add_ammo(&"pistol",10) and events.size()==1 and int(events[0].amount)==1, "explicit paused setup grant reports actual partial ammo " + id)
		events.clear(); check(not combat.add_ammo(&"pistol",10) and events.is_empty(), "full ammo produces no false pickup event " + id)
		combat.grant_weapon(&"twin_shotgun",100); events.clear()
		check(not combat.grant_weapon(&"twin_shotgun",100) and events.is_empty(), "duplicate full grant is silent " + id)
		var pickup: Node3D
		for item in app.world.pickups:
			if String(item.get_meta("stage_pickup")) == "pistol": pickup = item; break
		check(is_instance_valid(pickup), "actual stage pistol pickup exists " + id)
		if is_instance_valid(pickup):
			combat.ammo_pistol = 95; events.clear(); app.world.collect(pickup)
			check(pickup.visible and not app.world.collected.has(pickup.get_instance_id()) and events.is_empty(), "paused physical collect is silent and retained " + id)
		var counts: Dictionary = owner.cue_counts.duplicate(); check(not combat.try_fire() and owner.cue_counts==counts and events.is_empty(), "paused authoritative shot produces no voice " + id)
		app.set_paused(false)
		if is_instance_valid(pickup):
			combat.ammo_pistol = 96; events.clear(); app.world.collect(pickup)
			check(pickup.visible and events.is_empty() and owner.cue_counts==counts, "actual full pickup remains available and silent " + id)
			combat.ammo_pistol = 95; app.world.collect(pickup)
			check(not pickup.visible and events.size()==1 and int(events[0].amount)==1 and combat.ammo_pistol==96 and owner.cue_counts==counts, "actual partial collection reports accepted one unit without invented audio event " + id)
		var mute_prior := AudioServer.is_bus_mute(0); AudioServer.set_bus_mute(0,true)
		check(voice.can_process() and owner.music_player.can_process() and owner.music_player.playing and AudioServer.is_bus_mute(0), "mute changes audibility, retains playback owner " + id)
		events.clear(); combat.currentweapon = &"pistol"; combat.cooldown = 0; combat.weapon_phase = &"idle"
		var muted_fire_before: int = int(owner.cue_counts.get(&"pistol_fire",0)); var muted_ammo_before: int = combat.ammo_pistol
		check(combat.try_fire() and count("shot")==1 and combat.ammo_pistol==muted_ammo_before-1 and int(owner.cue_counts.get(&"pistol_fire",0))==muted_fire_before+1, "actual muted shot still owns gameplay and voice dispatch " + id)
		AudioServer.set_bus_mute(0,mute_prior)
		check(owner.can_process(), "resume/mute preserve processing " + id)
		var old_owner: Node = owner; var old_voice: Node = voice; app.restart_combat(); freeze_app()
		check(not is_instance_valid(old_owner) and not is_instance_valid(old_voice) and app.combat_audio.voices.is_empty() and app.combat_audio.seen_events.is_empty() and app.combat_audio.music_player.playing and not app.menu_music.playing, "Retry retires prior voices/music and starts current level only " + id)
		var next_owner: Node = app.combat_audio; var old_music: Node = next_owner.music_player
		app.on_level_completed(); await process_frame
		check(app.level_complete and app.combat_audio.voices.is_empty() and not old_music.playing and old_music.stream==null and not app.menu_music.playing, "simulated completion clears all current sound owners " + id)
		report.campaign_lifecycle.append({"level":id,"theme":String(app.campaign.current_level().theme),"music":String(app.combat_audio.profile.music.resource_path),"pause_freezes":true,"mute_preserves_processing":true,"retry_retires_old_owner":true,"completion_trigger":"controlled Main.on_level_completed; NOT a played route or physical exit"})
		report.supply_events.append({"level":id,"partial_accepted":1,"full_ammo_events":0,"duplicate_full_grant_events":0,"paused_collect_events":0,"pickup_audio_cues_added":0})
		if level<8:
			app.continue_campaign(); freeze_app(); check(not is_instance_valid(next_owner) and not is_instance_valid(old_music), "transition frees prior level music " + id)
	app.return_to_title(); freeze_app()
	check(app.menu_music.playing and not app.combat_audio.music_player.playing and app.combat_audio.voices.is_empty(), "return to title restores sole menu Abelian")
	app.menu_music.stop(); app.menu_music.stream=null; app.combat_audio.stop_all(); app.free(); app=null; paused=false
func run() -> void:
	profile = load("res://resources/combat_audio.tres"); art = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json"))
	preserved(); await actual_matrix(); await main_lifecycle()
	director=null; combat=null; player=null; camera=null; fixture=null; profile=null
	await create_timer(.4,true).timeout
	report.checks=checks; report.failures=failures; report.passed=failures.is_empty()
	report.scope="Headless real imported streams, actual 36 native-sprite weapon contacts and six species windup/damage method dispatch; actual Main nine-level scene replacements/Retry with controlled simulated completion. Not physical campaign route proof, listening approval, audible stereo capture or human input."
	var file := FileAccess.open("res://verification/combat-balance-v4/audio.json",FileAccess.WRITE)
	check(file!=null,"audio ledger writable")
	if file: report.checks=checks; file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
	print("BALANCE_AUDIO_V4_%s: %d checks; 48 real cues; 36 actual contacts; six species; nine controlled Main lifecycles; immutable audio from %s. No listening approval claimed." % ["OK" if failures.is_empty() else "FAILED",checks,BASE])
	quit(0 if failures.is_empty() else 1)
