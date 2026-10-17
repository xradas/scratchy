extends SceneTree
## Actual campaign worlds: deterministic authored arrivals and Continue lifecycle.
var failures: Array[String] = []
var checks := 0
var app: Control

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error("AMBUSH_V20: "+label)
func frames(count: int) -> void:
	for i in count: await process_frame

func run() -> void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	app.automated_input=true
	for level_id in ["pale_ward_01","pale_ward_02"]:
		app.campaign_mode=true;app.campaign.seek(level_id);app.stage_id="pale_ward";app.replace_world({})
		var world:Node3D=app.world
		var combat:Node3D=app.combat
		paused=false
		world.set_physics_process(false)
		for actor in combat.enemies:actor.set_physics_process(false)
		var initial_count:int=combat.enemies.size()
		var wave_id: String="control:local_power" if level_id=="pale_ward_01" else "control:isolation_a"
		world.trigger_ambush_wave(wave_id)
		check(combat.enemies.size()==initial_count+2,level_id+" accepted trigger creates exactly two actors")
		check(combat.total_enemies==initial_count+2,level_id+" HUD kill budget includes arrivals")
		var arrivals:Array[CharacterBody3D]=[]
		for actor in combat.enemies:
			if bool(actor.get_meta("ambush_reinforcement",false)):arrivals.append(actor)
		check(arrivals.size()==2,level_id+" authored arrival identity")
		for actor in arrivals:
			check(not actor.visible and actor.collision_layer==0 and not actor.awake,level_id+" telegraph precedes contact")
			check(is_instance_valid(actor.sprite) or is_instance_valid(actor.visual_rig),level_id+" reinforcement uses production creature art")
			for hurt in actor.hurt_shapes:check(hurt.collision_layer==0,level_id+" telegraph cannot be hit early")
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=actor.get_node("CollisionShape3D").shape
			query.transform=actor.global_transform
			query.collision_mask=1
			check(world.get_world_3d().direct_space_state.intersect_shape(query,4).is_empty(),level_id+" arrival has clear capsule "+String(actor.target_id))
		world.trigger_ambush_wave(wave_id)
		check(combat.enemies.size()==initial_count+2,level_id+" same trigger cannot duplicate wave")
		await create_timer(.78).timeout
		for actor in arrivals:
			check(actor.visible and actor.collision_layer==2 and actor.awake,level_id+" arrival becomes active after telegraph")
			for hurt in actor.hurt_shapes:check(hurt.collision_layer==4,level_id+" arrival opens hurt surfaces")
			actor.set_physics_process(false)
		var snapshot:Dictionary=world.capture_checkpoint_state()
		app.replace_world({})
		check(app.world.restore_checkpoint_state(snapshot),level_id+" Continue rebuilds dynamic roster")
		check(app.combat.enemies.size()==initial_count+2 and app.world.ambush_triggered.has(wave_id),level_id+" Continue retains triggered wave")
		app.replace_world({})
		check(app.combat.enemies.size()==initial_count and app.world.ambush_triggered.is_empty(),level_id+" retry resets wave")
	await frames(2)
	print("AMBUSH_V20 checks=%d failed=%d" % [checks,failures.size()])
	app.combat_audio.stop_all();app.menu_music.stop();app.menu_music.stream=null
	app.queue_free();await frames(3)
	quit(0 if failures.is_empty() else 1)
