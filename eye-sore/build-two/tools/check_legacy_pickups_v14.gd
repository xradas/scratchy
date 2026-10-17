extends SceneTree
## Actual legacy Main with physical walk-to-cache; actor thinking frozen only.
var app:Control
var checks:Array[Dictionary]=[]
var events:Array[Dictionary]=[]
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks.append({"check":label,"passed":ok})
	if not ok:failed+=1;push_error(label)
func frames(count:int)->void:
	for i in count:await physics_frame
func key(down:bool)->void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_W;event.keycode=KEY_W;event.pressed=down;Input.parse_input_event(event)
func run()->void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.enter_combat();await frames(4)
	for saturated in [false,true]:
		if saturated:app.restart_level();await frames(4)
		for actor in app.combat.enemies:actor.set_physics_process(false)
		var world:Node3D=app.world;var combat:Node3D=app.combat;var player:CharacterBody3D=app.player
		var bait:Node3D=world.get_node("Bait_arena_one")
		check(world.objective_profile==null,"Actual legacy scene has no objective profile saturated="+str(saturated))
		check(typeof(world.pickup_identity(bait))==TYPE_INT,"Actual legacy cache retains integer identity saturated="+str(saturated))
		combat.owned_weapons[&"twin_shotgun"]=true;combat.ammo_shotgun=40 if saturated else 20
		var initial_shells:int=combat.ammo_shotgun
		events.clear();combat.combat_event.connect(func(event:Dictionary):events.append(event.duplicate(true)))
		player.set_physics_process(false);player.global_position=bait.global_position+Vector3(0,.22,3);player.velocity=Vector3.ZERO
		player.set_movement_active(true);player.set_physics_process(true);await frames(8)
		check(bait.visible and not world.traps.arena_one.triggered,"Cache still untouched before real approach saturated="+str(saturated))
		for i in 180:
			if not bait.visible:break
			var motion:Vector3=bait.global_position-player.global_position;motion.y=0
			player.rotation.y=atan2(-motion.x,-motion.z);key(true);await physics_frame
		key(false);await frames(3)
		check(not bait.visible and world.collected.has(world.pickup_identity(bait)),"Physical W approach consumes actual legacy cache saturated="+str(saturated))
		check(world.traps.arena_one.triggered,"Actual legacy bait triggers physical trap saturated="+str(saturated))
		check(combat.ammo_shotgun==(40 if saturated else initial_shells+4),"Legacy accepted/saturated ammunition semantics saturated="+str(saturated))
		var receipts:=0
		for event in events:
			if String(event.type)=="item_collected":receipts+=1
		check(receipts==(0 if saturated else 1),"Legacy receipt exists only for accepted mutation saturated="+str(saturated))
		world.update_player(player,combat)
		var repeated:=0
		for event in events:
			if String(event.type)=="item_collected":repeated+=1
		check(repeated==receipts,"Repeated proximity cannot republish legacy reward saturated="+str(saturated))
		await frames(100)
		check(world.is_arena_active("arena_one"),"Ordinary physical closet travel wakes authored legacy arena saturated="+str(saturated))
	app.combat_audio.stop_all();app.menu_music.stop();app.menu_music.stream=null
	var stop_at:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-stop_at<300:await process_frame
	app.queue_free();paused=false;await frames(6)
	var folder:="res://verification/ward-spatial-v14/runtime";DirAccess.make_dir_recursive_absolute(folder)
	var suffix:="headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open(folder+"/legacy-pickups-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"scope":"Actual Main Ash Citadel01 legacy scene, controlled supported starting pose3m from actual cache, physical W approach. Enemy thinking frozen; geometry, integer identities, inventory mutations, pickup receipts, physical trap/closet and activation unchanged. Not a full legacy combat route."},"  "))
	print("LEGACY_PICKUPS_V14 checks=%d failed=%d"%[checks.size(),failed]);quit(1 if failed else 0)
