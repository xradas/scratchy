extends SceneTree
# Bounded real-physics fixture: production enemy, combat, armed hitscan release
# and optional registered native atlas. No production resources are mutated.
const DT := 1.0 / 60.0
var world: Node3D
var player: CharacterBody3D
var combat: Node3D
var audio: Node3D
var enemy: CharacterBody3D
var events: Array[Dictionary] = []
var results: Array[Dictionary] = []
var tick := 0
var failed := 0
var manifest: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String, details: Dictionary = {}) -> void:
	results.append({"check":label,"passed":condition,"details":details})
	if not condition:
		failed += 1
		push_error(label + ": " + JSON.stringify(details))

func matching(kind: StringName) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for event in events:
		if event.type == kind: selected.append(event)
	return selected

func solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); world.add_child(body); body.position = at
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new()
	shape.size = size; collision.shape = shape; body.add_child(collision)
	body.set_meta("hit_material", &"hard")
	return body

func fixture(kind: StringName, distance: float) -> void:
	if is_instance_valid(world):
		if is_instance_valid(audio): audio.stop_all()
		world.queue_free()
		await physics_frame; await physics_frame
	world = Node3D.new(); root.add_child(world)
	var spawns := Node3D.new(); spawns.name = "EnemySpawns"; world.add_child(spawns)
	solid(Vector3(0,-.5,0), Vector3(30,1,30))
	player = CharacterBody3D.new(); player.collision_layer=2; world.add_child(player)
	player.position = Vector3(0,.85,0)
	var node := CollisionShape3D.new(); var capsule := CapsuleShape3D.new()
	capsule.height=1.7; capsule.radius=.3; node.shape=capsule; player.add_child(node)
	var camera := Camera3D.new(); camera.name="Camera3D"; camera.position.y=.4; player.add_child(camera)
	camera.current = true
	combat=load("res://scripts/combat.gd").new(); world.add_child(combat)
	combat.combat_event.connect(func(event: Dictionary):
		var entry := event.duplicate(); entry["fixture_tick"] = tick
		if event.type == &"enemy_weapon_release":
			entry["displayed_frame"] = enemy.sprite_frame
			entry["displayed_muzzle"] = enemy.attack_origin()
		events.append(entry))
	combat.setup(world,player); combat.set_physics_process(false)
	audio = load("res://scripts/combat_audio.gd").new(); world.add_child(audio)
	audio.setup(load("res://resources/combat_audio.tres"), false)
	combat.combat_event.connect(audio.handle_event)
	enemy=combat.spawn_enemy(kind,Vector3(0,.85,-distance)); enemy.set_physics_process(false)
	var art: Dictionary = manifest.get("enemies",{}).get(String(kind),{})
	if not art.is_empty():
		var clips := {}
		for state in art.clips:
			var bounds: Array = art.clips[state]; clips[StringName(state)] = Vector2i(bounds[0],bounds[1])
		var pivot: Array = art.get("foot_pivot",[0,0])
		enemy.configure_sprite_sheet(art.file,art.columns,art.directions,clips,art.get("pixel_size",.015),Vector2(pivot[0],pivot[1]),art.get("sprite_options",{}))
	events.clear(); tick=0
	await physics_frame; await physics_frame

func advance(count: int, actor: bool = true) -> void:
	for n in range(count):
		tick += 1
		if actor: enemy._physics_process(DT)
		for child in combat.get_children():
			if child.has_method("is_combat_projectile"):
				child.set_physics_process(false)
				if not paused: child._physics_process(DT)
		await physics_frame

func first_release() -> void:
	for n in range(70):
		if matching(&"enemy_weapon_release").size() > 0: return
		await advance(1)
	check(false,"first security pistol release reached before timeout")

func hurt(lethal: bool = false) -> void:
	enemy.apply_damage(enemy.health if lethal else 1.0, 900+tick, &"pistol", enemy.global_position)

func run() -> void:
	root.size = Vector2i(960,540)
	if FileAccess.file_exists("res://assets/combat_art.json"):
		manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json"))
	for old in ["unsealed","vessel","ironbound","censer","reaver","surveyor"]:
		var path := "res://resources/enemies/%s.tres" % old
		if not ResourceLoader.exists(path): continue
		var definition: EnemyDefinition = load(path)
		check(definition.burst_round_count==1 and definition.committed_lunge_speed==0 and definition.melee_contact_range<0,"legacy opt-in defaults: " + old)

	await fixture(&"infected_security",8)
	var first_total: float = combat.health + combat.armor
	await first_release()
	var releases := matching(&"enemy_weapon_release")
	check(matching(&"enemy_attack_warning").size()==1,"one warning before security pistol fire")
	check(releases.size()==1 and releases[0].weapon_id==&"pistol" and releases[0].pellets==1,"one actual pistol release with matching pellet count")
	if is_instance_valid(enemy.sprite): check(enemy.sprite_frame%8==4,"pistol shot uses displayed release pose")
	check(tick>=32,"security visible windup before pistol fire",{"release_tick":tick})
	if releases.size()==1: check(releases[0].displayed_frame%8==4 and releases[0].position.distance_to(releases[0].displayed_muzzle)<.00001,"pistol muzzle agrees with displayed release pose")
	check(matching(&"player_hurt").size()==1 and is_equal_approx(first_total-combat.health-combat.armor,7.0),"one pistol shot owns one 7-damage contact")
	check(int(audio.cue_counts.get(&"pistol_fire",0))==1,"one pistol release owns one matching fire cue")
	enemy.release_attack(); enemy.release_burst_followup()
	check(matching(&"enemy_weapon_release").size()==1 and int(audio.cue_counts.get(&"pistol_fire",0))==1,"duplicate callbacks cannot fire or sound again")
	await advance(5)
	check(enemy.sprite_frame%8==3,"pistol flash returns to rest pose")

	await fixture(&"infected_security",8)
	await advance(14); hurt(); check(enemy.sprite_frame%8==5,"pain immediately removes release flash"); await advance(30)
	check(matching(&"enemy_weapon_release").is_empty() and int(audio.cue_counts.get(&"pistol_fire",0))==0,"pain before fire cancels shot and sound")
	await fixture(&"infected_security",8)
	await first_release(); var first_attack: int=enemy.attack_id
	hurt(); check(enemy.sprite_frame%8==5,"pain immediately removes release flash"); await advance(30)
	check(matching(&"enemy_weapon_release").size()==1,"pain after fire does not repeat committed shot")
	await advance(55)
	var resumed := matching(&"enemy_weapon_release")
	check(resumed.size()>=2 and resumed[1].attack_id!=first_attack,"post-pain attack uses a fresh warning and release ID")

	for before_first in [true,false]:
		await fixture(&"infected_security",8)
		if before_first: await advance(14)
		else: await first_release()
		hurt(true); check(enemy.sprite_frame%8==6,"death immediately removes release flash"); hurt(true); enemy.release_attack(); enemy.release_burst_followup(); await advance(45)
		check(matching(&"enemy_weapon_release").size()==(0 if before_first else 1),"death prevents further pistol fire: " + str(before_first))
		check(int(audio.cue_counts.get(&"pistol_fire",0))==(0 if before_first else 1),"death prevents further pistol audio: " + str(before_first))
		check(matching(&"enemy_death").size()==1 and enemy.dead and enemy.collision_layer==0,"death is once and living collider disabled: " + str(before_first))
		if is_instance_valid(enemy.sprite):
			check(enemy.sprite_frame%8==7 and not enemy.corpse_shapes.is_empty(),"native settled corpse keeps alpha hit registration")

	await fixture(&"infected_security",8)
	await advance(14); var saved_time: float=enemy.state_time
	paused=true; await advance(20)
	check(enemy.state_time==saved_time and matching(&"enemy_weapon_release").is_empty() and int(audio.cue_counts.get(&"pistol_fire",0))==0,"pause freezes pending pistol fire and audio")
	paused=false; await first_release()
	check(matching(&"enemy_weapon_release").size()==1 and int(audio.cue_counts.get(&"pistol_fire",0))==1,"resume releases one pistol shot and sound")

	await fixture(&"infected_security",8)
	await advance(10); solid(Vector3(0,1,-4),Vector3(6,3,.3))
	await physics_frame; await physics_frame; await advance(45)
	check(matching(&"enemy_weapon_release").is_empty() and matching(&"player_hurt").is_empty() and int(audio.cue_counts.get(&"pistol_fire",0))==0,"new shared wall blocks committed pistol shot and sound")

	await fixture(&"infected_scientist",2.3)
	var start := enemy.position
	await advance(44)
	check(matching(&"enemy_melee_release").size()==1,"scientist committed lunge reaches stationary target at2.3m",{"travel":enemy.position.distance_to(start),"distance":enemy.position.distance_to(player.position)})
	check(absf(enemy.position.x-start.x)<.001 and enemy.position.distance_to(start)>.9,"scientist moves physically along committed heading")
	enemy.release_attack(); check(matching(&"enemy_melee_release").size()==1,"scientist contact authoritative once")

	await fixture(&"infected_scientist",2.3)
	await advance(2); player.position.x=2.0; await physics_frame; await advance(42)
	check(absf(enemy.position.x)<.001 and matching(&"enemy_melee_release").is_empty(),"scientist commits warning heading and misses dodging target")
	await fixture(&"infected_scientist",2.3)
	await advance(2); solid(Vector3(0,1,-1.4),Vector3(6,3,.2))
	await physics_frame; await physics_frame; await advance(42)
	check(enemy.position.z < -1.85 and matching(&"enemy_melee_release").is_empty(),"shared wall blocks physical lunge and melee release",{"position":enemy.position})
	await fixture(&"infected_scientist",2.3)
	await advance(33); hurt(); var interrupted := enemy.position; await advance(10)
	check(enemy.position.distance_to(interrupted)<.01 and matching(&"enemy_melee_release").is_empty(),"pain immediately stops lunge and contact")

	var report := {"schema_version":11,"fixture":"production Combat/CharacterBody/armed-security hitscan with shared physics solids","renderer":RenderingServer.get_current_rendering_method(),"native_art_ids":manifest.get("enemies",{}).keys(),"checks":results,"failed":failed}
	var folder := "res://verification/production-v11/enemies-release-pose"
	DirAccess.make_dir_recursive_absolute(folder)
	var suffix := "headless" if DisplayServer.get_name()=="headless" else "native"
	var file := FileAccess.open(folder+"/runtime-"+suffix+".json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("INFECTED_ENEMIES_V11 checks=%d failures=%d renderer=%s" % [results.size(),failed,report.renderer])
	if is_instance_valid(audio): audio.stop_all()
	if is_instance_valid(world): world.queue_free()
	await physics_frame; await physics_frame
	preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear()
	preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	quit(1 if failed>0 else 0)
