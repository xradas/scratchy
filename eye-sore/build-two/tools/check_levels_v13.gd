extends SceneTree
## Independent actual Main resource/stable-state/physics inspection. All world
## selection and AI freezing below is controlled fixture setup, never routing.
var expected: Dictionary
var report_path := ""
var failures: Array[String] = []
var checks := 0
var observations: Array[Dictionary] = []
var app: Control
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected="):expected=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--expected=")))
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error("LEVELS_V13: "+label)
func frames(n: int) -> void:
	for i in n:await physics_frame
func descendants(node: Node) -> Array[Node]:
	var result: Array[Node]=[]
	for child in node.get_children():result.append(child);result.append_array(descendants(child))
	return result
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	app.automated_input=true
	for level_id in expected.selected_levels:
		app.campaign_mode=true;app.campaign.seek(String(level_id));app.stage_id="pale_ward";app.replace_world({})
		var world: Node3D=app.world
		var design: Dictionary={}
		for entry in expected.levels:
			if entry.id==level_id:design=entry;break
		check(not design.is_empty(),"Selected design exists "+level_id)
		if design.is_empty():continue
		for actor in app.combat.enemies:actor.set_physics_process(false)
		app.player.set_movement_active(false)
		await frames(3)
		check(world.get_meta("design_version",0)==13 and world.objective_profile!=null,"Actual Main binds redesigned scene/profile "+level_id)
		if world.objective_profile==null:continue
		check(world.objective_profile.level_id==level_id,"Exact profile level identity "+level_id)
		check(app.combat.enemies.size()==int(design.enemy_total),"Actual enemy budget "+level_id)
		var ids: Dictionary={}
		for actor in app.combat.enemies:
			var stable: String=String(actor.target_id)
			check(stable.begins_with(level_id+".") and not ids.has(stable),"Unique authored actor identity "+stable);ids[stable]=true
		check(world.rooms.size()==design.rooms.size(),"Actual room count "+level_id)
		check(world.checkpoint_markers.size()==2,"Two actual checkpoint markers "+level_id)
		var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
		var capsule: Shape3D=app.player.get_node("CollisionShape3D").shape
		for marker in world.checkpoint_markers:
			var at: Vector3=marker.global_position
			var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.4,at-Vector3.UP*.4,1)
			var hit: Dictionary=space.intersect_ray(ray)
			check(not hit.is_empty() and hit.normal.y>.95,"Authored checkpoint has actual flat support "+String(marker.name))
			if hit.is_empty():continue
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,hit.position+Vector3.UP*.87);query.margin=.001
			check(space.intersect_shape(query,8).is_empty(),"Actual player capsule fits checkpoint "+String(marker.name))
		var snapshot: Dictionary=world.capture_checkpoint_state()
		check(snapshot.enemies.size()==design.enemy_total,"Snapshot includes every stable actor "+level_id)
		check(world.restore_checkpoint_state(snapshot),"Actual world snapshot roundtrip accepted "+level_id)
		check(world.capture_checkpoint_state()==snapshot,"Snapshot roundtrip preserves complete logical state "+level_id)
		var bad: Dictionary=snapshot.duplicate(true);bad.enemies["unknown.fixture.actor"]={}
		check(not world.restore_checkpoint_state(bad),"Unknown actor snapshot rejected "+level_id)
		check(world.capture_checkpoint_state()==snapshot,"Rejected snapshot leaves actual world atomic "+level_id)
		var anchors:=0
		for node in world.mechanisms:
			if node.has_method("is_shootable_mechanism"):
				anchors+=1;check(node.health==60 and not node.has_method("apply_damage"),"60HP anchor uses mechanism branch "+String(node.name))
		check(anchors==design.anchors.size(),"Actual shootable anchor count "+level_id)
		observations.append({"level":level_id,"scene":world.scene_file_path,"rooms":world.rooms.size(),"actors":ids.size(),"checkpoints":world.checkpoint_markers.size(),"anchors":anchors,"snapshot_fields":snapshot.keys()})
	await finish()
func finish() -> void:
	var report := {"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"observations":observations,"scope":"Controlled actual Main authored resource/count/identity, checkpoint physical capsule/support, complete stable world roundtrip and atomic invalid-state rejection. AI frozen for inspection. Separate physical input route and checkpoint lifecycle fixtures required; no human pacing or live traversal claim."}
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	if is_instance_valid(app):
		app.combat_audio.stop_all();app.menu_music.stop();app.menu_music.stream=null
		await create_timer(.3,true).timeout;app.queue_free();app=null;await frames(3)
	call_deferred("quit",0 if failures.is_empty() else 1)
