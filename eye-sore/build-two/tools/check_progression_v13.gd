extends SceneTree
## Real production Stage/Combat/Player on shared fixture solids; no scene edits.
const DT:=1.0/60.0
const Profile:=preload("res://scripts/stage_objective_profile.gd")
const Campaign:=preload("res://scripts/campaign_state.gd")
var world:Node3D
var player:CharacterBody3D
var combat:Node3D
var button:Node3D
var key_item:Node3D
var anchor:StaticBody3D
var door:AnimatableBody3D
var checkpoint_ids:Array[String]=[]
var events:Array[Dictionary]=[]
var checks:Array[Dictionary]=[]
var failed:=0
var main_levels_tested:Array[String]=[]
var shot:=1000
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String,detail:Dictionary={}) -> void:
	checks.append({"check":label,"passed":ok,"detail":detail})
	if not ok:failed+=1;push_error(label+": "+JSON.stringify(detail))
func box(parent:Node,at:Vector3,size:Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();body.position=at;parent.add_child(body)
	var node:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;node.shape=shape;body.add_child(node)
	return body
func marked(name:String,at:Vector3,metadata:Dictionary) -> Node3D:
	var node:=Node3D.new();node.name=name;node.position=at
	for field in metadata:node.set_meta(field,metadata[field])
	world.add_child(node);return node
func fixture(profile:StageObjectiveProfile) -> void:
	if is_instance_valid(world):world.queue_free();await physics_frame;await physics_frame
	world=load("res://scripts/stage_level.gd").new();world.objective_profile=profile;root.add_child(world);world.set_physics_process(false)
	box(world,Vector3(0,-.5,0),Vector3(90,1,90))
	marked("SafeRoom",Vector3.ZERO,{"stage_room":"safe","room_bounds":Vector3(6,4,6)})
	marked("DeconRoom",Vector3(20,0,0),{"stage_room":"decon","room_bounds":Vector3(3,4,3),"arena_id":"decon"})
	var spawns:=Node3D.new();spawns.name="EnemySpawns";world.add_child(spawns)
	for index in 3:
		var marker:=Marker3D.new();marker.position=Vector3(20+index*6,.87,0);marker.set_meta("kind","unsealed");marker.set_meta("stable_id","unit.enemy."+str(index));marker.set_meta("arena_id","decon" if index==0 else "");spawns.add_child(marker)
	player=load("res://scripts/player.gd").new();player.name="Player";player.position=Vector3(0,.87,0);player.collision_layer=2;player.collision_mask=3
	var node:=CollisionShape3D.new();node.name="CollisionShape3D";var capsule:=CapsuleShape3D.new();capsule.height=1.7;capsule.radius=.3;node.shape=capsule;player.add_child(node)
	var camera:=Camera3D.new();camera.name="Camera3D";camera.position.y=.68;player.add_child(camera);world.add_child(player);player.set_physics_process(false)
	button=marked("PowerControl",Vector3(0,.87,-1),{"stage_button":"local_power","stable_id":"unit.control.power"})
	key_item=marked("Credential",Vector3(3,.87,0),{"stage_pickup":"brass","stable_id":"unit.key.credential"})
	marked("Exit",Vector3(0,.87,-6),{"stage_exit":true,"stable_id":"unit.exit"})
	marked("FirstCheckpoint",Vector3(0,.87,0),{"checkpoint_id":"power_return","requires":["local_power"],"radius":1.5})
	marked("SecondCheckpoint",Vector3(10,.87,0),{"checkpoint_id":"credential_return","requires":["surgical_credential"],"radius":1.5})
	door=load("res://scripts/stage_door.gd").new();door.name="Gate";door.position=Vector3(8,1,0);door.set_meta("stage_door","unit.gate");door.set_meta("stable_id","unit.gate");world.add_child(door);door.set_physics_process(false)
	var collision:=CollisionShape3D.new();collision.name="Collision";var shape:=BoxShape3D.new();shape.size=Vector3(1,2,.3);collision.shape=shape;door.add_child(collision)
	anchor=load("res://scripts/shootable_mechanism_v13.gd").new();anchor.name="Anchor";anchor.position=Vector3(0,1,-3);anchor.set_meta("stable_id","unit.anchor");anchor.set_meta("completion_flag","anchor_a");world.add_child(anchor)
	collision=CollisionShape3D.new();shape=BoxShape3D.new();shape.size=Vector3(.7,1,.7);collision.shape=shape;anchor.add_child(collision)
	combat=load("res://scripts/combat.gd").new();world.add_child(combat);combat.combat_event.connect(func(event:Dictionary):events.append(event.duplicate(true)));combat.setup(world,player);combat.set_physics_process(false)
	for enemy in combat.enemies:enemy.set_physics_process(false)
	world.setup(combat,player);world.checkpoint_reached.connect(func(id:String):checkpoint_ids.append(id))
	events.clear();checkpoint_ids.clear()
	await physics_frame;await physics_frame
	player.set_movement_active(true)
	for i in 8:player._physics_process(DT);await physics_frame
	player.set_movement_active(false)
func count(kind:String) -> int:
	var amount:=0
	for event in events:
		if String(event.type)==kind:amount+=1
	return amount
func fire(weapon:StringName) -> bool:
	combat.currentweapon=weapon;combat.weapon_phase=&"idle";combat.cooldown=0
	player.get_node("Camera3D").look_at(anchor.global_position)
	await physics_frame;await physics_frame
	return combat.try_fire()
func kill(enemy:CharacterBody3D,gib:bool=false) -> void:
	shot+=1;enemy.apply_damage(enemy.health+(100 if gib else 0),shot,&"shotgun" if gib else &"pistol",enemy.position)
func main_checkpoint_check() -> void:
	if is_instance_valid(world):world.queue_free();await physics_frame;await physics_frame
	var app:Control=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	app.automated_input=true;app.campaign_mode=true;app.campaign.seek("pale_ward_01");app.stage_id="pale_ward";app.replace_world({})
	app.campaign.entry_snapshot=app.campaign.capture(app.combat)
	check(app.world.objective_profile!=null,"actual redesigned Intake Main binds objective resource")
	main_levels_tested.append("pale_ward_01")
	if app.world.objective_profile==null:app.queue_free();return
	for enemy in app.combat.enemies:enemy.set_physics_process(false)
	var dead_actor:CharacterBody3D=app.combat.enemies[0]
	dead_actor.apply_damage(dead_actor.health,90001,&"pistol",dead_actor.position)
	var dead_id:=String(dead_actor.target_id)
	var gib_actor:CharacterBody3D=app.combat.enemies[1]
	gib_actor.apply_damage(gib_actor.health+100,90002,&"shotgun",gib_actor.position)
	var gib_id:=String(gib_actor.target_id)
	app.combat.health=73;app.combat.armor=28;app.combat.ammo_pistol=17
	app.world.set_progress_flag("local_power")
	var marker:Node3D=app.world.get_node("Checkpoint_power_return")
	app.player.global_position=marker.global_position+Vector3.UP*.95
	app.enter_combat()
	for n in 100:
		await physics_frame
		if app.has_checkpoint():break
	check(app.has_checkpoint(),"actual Main automatically secures grounded safe authored checkpoint")
	if not app.has_checkpoint():
		check(false,"Main fixture checkpoint safety",{"position":str(app.player.position),"on_floor":app.player.is_on_floor(),"velocity":str(app.player.velocity),"safe":app.world.checkpoint_is_safe()})
		app.combat_audio.stop_all();app.menu_music.stop();app.queue_free();paused=false;await process_frame;return
	var snapshot:Dictionary=app.campaign.checkpoint_snapshot.duplicate(true)
	var old_gore:Node=app.combat.gore
	var held:=InputEventKey.new();held.physical_keycode=KEY_W;held.keycode=KEY_W;held.pressed=true;Input.parse_input_event(held)
	app.combat.receive_player_damage(1000,"unit_death",app.player.position)
	await process_frame;await process_frame
	check(app.combat.dead and paused and app.resume_button.text=="Continue from Checkpoint","death menu defaults to latest checkpoint")
	app.enter_combat()
	check(not app.combat.dead and app.combat.health==73 and app.combat.armor==28 and app.combat.ammo_pistol==17,"Main death Continue restores exact saved inventory")
	check(not is_instance_valid(old_gore) and app.combat.gore.particles.is_empty() and app.combat.gore.stains.is_empty() and app.combat.gore.remains.is_empty(),"checkpoint replaces and clears transient gore owner")
	check(app.combat.kills==2 and app.world.dead_ids.has(dead_id) and app.world.dead_ids.has(gib_id),"Main restores dead and gibbed actor progression without duplicate kills")
	var actors:Dictionary={}
	for enemy in app.combat.enemies:actors[String(enemy.target_id)]=enemy
	check(actors.has(dead_id) and actors[dead_id].dead and not actors[dead_id].gibbed and actors[gib_id].gibbed,"fresh Main reconstructs persistent corpse and gibbed logical actors")
	var restored:Vector3=app.player.global_position
	for n in 5:await physics_frame
	check(app.player.global_position.distance_to(restored)<.03,"held forward key is suppressed after death Continue")
	held.pressed=false;Input.parse_input_event(held)
	for n in 3:await physics_frame
	check(app.world.flags.get("local_power",false) and app.world.checkpoint_used.has("power_return"),"Continue retains objective and checkpoint marker state")
	app.restart_level()
	check(not app.has_checkpoint() and app.combat.kills==0 and app.world.dead_ids.is_empty() and not app.world.flags.has("local_power"),"Restart Level clears checkpoint and all progress")
	check(app.combat.health==100 and app.combat.ammo_pistol==36,"Restart Level uses campaign entrance inventory")
	app.combat.receive_player_damage(1000,"no_checkpoint_fixture",app.player.position)
	await process_frame;await process_frame
	check(app.resume_button.text=="Retry from Entrance","death without checkpoint offers entrance retry")
	app.enter_combat();check(not app.combat.dead and app.combat.health==100 and not app.has_checkpoint(),"death without checkpoint restarts at level entry")
	app.campaign.checkpoint_snapshot=snapshot;app.return_to_title()
	check(not app.has_checkpoint() and not app.started,"Return to title discards session checkpoint")
	app.combat_audio.stop_all();app.menu_music.stream_paused=false;app.menu_music.stop();app.menu_music.stream=null
	await create_timer(.3,true).timeout
	app.set_process(false);app.world.process_mode=Node.PROCESS_MODE_DISABLED;paused=false
	await process_frame;await physics_frame
	preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear();preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()

func ground_at(app:Control, point:Vector3) -> void:
	app.player.global_position=point;app.player.velocity=Vector3.ZERO
	for n in 12:await physics_frame

func aim_at_actor(app:Control, enemy:CharacterBody3D) -> bool:
	enemy.update_presentation();await physics_frame;await physics_frame
	var candidates:Array[Vector3]=[]
	for body in enemy.hurt_shapes:
		var collision:CollisionShape3D=body.get_node_or_null("HitSurface")
		if collision==null or not collision.shape is ConcavePolygonShape3D:continue
		var faces:PackedVector3Array=collision.shape.get_faces()
		for index in range(0,faces.size(),maxi(3,int(faces.size()/70.0)/3*3)):
			if index+2<faces.size():candidates.append(body.to_global((faces[index]+faces[index+1]+faces[index+2])/3))
	var chest:Vector3=enemy.global_position+Vector3.UP*.2
	candidates.sort_custom(func(a:Vector3,b:Vector3)->bool:return a.distance_squared_to(chest)<b.distance_squared_to(chest))
	for point in candidates:
		var origin:Vector3=app.player.camera.global_position
		var hit:Dictionary=app.combat.ray(origin,point+(point-origin).normalized()*.1,app.combat.anatomical_exclusions(),true)
		if not hit.is_empty() and hit.collider.has_meta("combat_target") and hit.collider.get_meta("combat_target")==enemy:
			app.player.camera.look_at(point);return true
	return false

func clear_actual_checkpoint_threats(app:Control, marker:Node3D) -> bool:
	# AI is frozen, but health/colliders/safety remain authoritative. Clear real
	# authored nearby actors through finite accepted shots, never a safe override.
	var near:Array[CharacterBody3D]=[]
	for enemy in app.combat.enemies:
		if not enemy.dead and enemy.global_position.distance_to(marker.global_position)<19:near.append(enemy)
	for enemy in near:
		var placed:=false
		for offset in [Vector3(0,0,1.7),Vector3(1.7,0,0),Vector3(0,0,-1.7),Vector3(-1.7,0,0)]:
			var candidate:Vector3=enemy.global_position+offset
			var floor_hit:Dictionary=app.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*1.5,candidate-Vector3.UP*2.5,1))
			if floor_hit.is_empty() or floor_hit.normal.y<.65:continue
			candidate.y=floor_hit.position.y+.87
			await ground_at(app,candidate)
			if await aim_at_actor(app,enemy):placed=true;break
		check(placed,"actual native target has unobstructed checkpoint defense contact "+String(enemy.target_id))
		if not placed:return false
		for shot_index in 12:
			if enemy.dead:break
			for n in 150:
				if app.combat.cooldown<=0:break
				await physics_frame
			app.combat.currentweapon=&"shotgun" if app.combat.ammo_shotgun>0 else &"pistol"
			app.combat.weapon_phase=&"idle"
			if not await aim_at_actor(app,enemy):break
			var before:float=enemy.health;var accepted:bool=app.combat.try_fire()
			check(accepted and enemy.health<before,"finite accepted shot clears actual nearby threat "+String(enemy.target_id))
			if not accepted:return false
		check(enemy.dead,"actual checkpoint defense target defeated "+String(enemy.target_id))
		if not enemy.dead:return false
	return true

func secure_actual_marker(app:Control, marker:Node3D, id:String) -> bool:
	await ground_at(app,marker.global_position+Vector3.UP*.87)
	for n in 160:
		if app.has_checkpoint() and app.campaign.checkpoint_snapshot.checkpoint_id==id:return true
		await physics_frame
	check(false,"actual authored checkpoint secured "+id,{"safe":app.world.checkpoint_is_safe(),"on_floor":app.player.is_on_floor(),"velocity":str(app.player.velocity),"position":str(app.player.position),"prompt":app.world.prompt})
	return false

func cleanup_main(app:Control) -> void:
	app.combat_audio.stop_all();app.menu_music.stream_paused=false;app.menu_music.stop();app.menu_music.stream=null
	await create_timer(.3,true).timeout
	app.set_process(false);app.world.process_mode=Node.PROCESS_MODE_DISABLED;paused=false

func other_ward_checkpoints() -> void:
	for level in ["pale_ward_02","pale_ward_03"]:
		var app:Control=load("res://scenes/main.tscn").instantiate();root.add_child(app)
		app.automated_input=true;app.campaign_mode=true;app.campaign.seek(level);app.stage_id="pale_ward";app.replace_world({});app.campaign.entry_snapshot=app.campaign.capture(app.combat)
		check(app.world.objective_profile!=null,"actual "+level+" has redesigned objective resource")
		if app.world.objective_profile==null:await cleanup_main(app);continue
		main_levels_tested.append(level)
		for enemy in app.combat.enemies:enemy.set_physics_process(false)
		app.enter_combat()
		if level=="pale_ward_02":
			for pair in [["isolation_b","waste_safe"],["isolation_a","culture_safe"]]:
				var marker:Node3D=app.world.get_node("Checkpoint_"+pair[1])
				if not await clear_actual_checkpoint_threats(app,marker):break
				var control:Node3D=app.world.get_node("Control_"+pair[0])
				await ground_at(app,control.global_position+Vector3(0,0,1.3))
				check(app.world.nearest_mechanism()==control and app.world.try_use(app.player),"actual E-use isolation control "+pair[0])
				# The control now owns a visible arrival wave. Defeat those real
				# reinforcements before a nearby safe checkpoint may be secured.
				await create_timer(.7).timeout
				for enemy in app.combat.enemies:
					if bool(enemy.get_meta("ambush_reinforcement",false)):enemy.set_physics_process(false)
				if not await clear_actual_checkpoint_threats(app,marker):break
				if not await secure_actual_marker(app,marker,pair[1]):break
			check(app.has_checkpoint() and app.campaign.checkpoint_snapshot.checkpoint_id=="culture_safe" and app.world.flags.get("isolation_a",false) and app.world.flags.get("isolation_b",false),"Containment BA latest checkpoint follows second completed wing")
		else:
			for pair in [["anchor_a","upper_anchor_safe"],["anchor_b","middle_anchor_safe"]]:
				var marker:Node3D=app.world.get_node("Checkpoint_"+pair[1])
				if not await clear_actual_checkpoint_threats(app,marker):break
				var target:Node3D
				for node in app.world.mechanisms:
					if node.has_method("is_shootable_mechanism") and node.completion_flag==pair[0]:target=node;break
				check(target!=null,"authored Breach anchor exists "+pair[0])
				if target==null:break
				await ground_at(app,target.global_position+Vector3(0,0,2))
				app.combat.currentweapon=&"pistol"
				for shot_index in 3:
					for n in 100:
						if app.combat.cooldown<=0:break
						await physics_frame
					app.player.camera.look_at(target.global_position)
					check(app.combat.try_fire(),"actual Breach anchor pistol contact "+pair[0])
				check(target.disabled and app.world.flags.get(pair[0],false),"actual Breach anchor disables via real damage "+pair[0])
				if not await secure_actual_marker(app,marker,pair[1]):break
			check(app.has_checkpoint() and app.campaign.checkpoint_snapshot.checkpoint_id=="middle_anchor_safe","Breach second anchor secures latest authored checkpoint")
		if app.has_checkpoint():
			var snapshot:Dictionary=app.campaign.checkpoint_snapshot.duplicate(true)
			app.combat.receive_player_damage(1000,"checkpoint_fixture",app.player.position);await process_frame;await process_frame;app.enter_combat()
			check(app.combat.health==snapshot.inventory.health and app.combat.ammo_pistol==snapshot.inventory.ammo_pistol and app.combat.ammo_shotgun==snapshot.inventory.ammo_shotgun and app.combat.kills==snapshot.combat.kills,"actual "+level+" death Continue restores exact finite inventory and kills")
			if level=="pale_ward_02":check(app.world.flags.get("isolation_a",false) and app.world.flags.get("isolation_b",false) and app.campaign.checkpoint_snapshot.checkpoint_id=="culture_safe","Containment BA restore retains both branch flags and latest checkpoint")
			else:
				var disabled:=0
				for node in app.world.mechanisms:
					if node.has_method("is_shootable_mechanism") and node.completion_flag in ["anchor_a","anchor_b"] and node.disabled and node.health==0:disabled+=1
				check(disabled==2 and app.world.flags.get("anchor_a",false) and app.world.flags.get("anchor_b",false),"Breach destroyed anchors stay disabled after actual Main restore")
		await cleanup_main(app)
	preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear();preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()

func run() -> void:
	var inputs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/level-redesign-v13/levels.json"))
	var profile:StageObjectiveProfile=Profile.from_dictionary(inputs.levels[0].objective_profile)
	profile.encounters=inputs.levels[0].encounters.duplicate(true)
	await fixture(profile)
	check(combat.enemies[0].target_id=="unit.enemy.0","authored actor ID survives creation order")
	check(world.objective==profile.objectives[0].text,"resource owns initial HUD objective")
	world.collect(key_item)
	check(not world.flags.has("surgical_credential") and key_item.visible,"key resource prerequisites reject early collection")
	check(world.try_use(player) and world.flags.get("local_power",false),"resource control grants local flag without legacy breaker/power aliases")
	check(not world.flags.has("power") and not world.try_use(player),"legacy flags excluded and repeated control cannot reward")
	world.collect(key_item)
	check(world.flags.get("surgical_credential",false) and world.collected.has("unit.key.credential") and not key_item.visible,"credential sets authored flags and stable pickup identity")
	check(count("item_collected")==1 and events.back().pickup_id=="unit.key.credential","one stable authoritative receipt")
	world.collect(key_item);check(count("item_collected")==1,"collected key cannot replay receipt")
	world.update_player(player,combat);check(world.flags.get("visited_safe",false),"profile room visits expose generic visited flags")
	kill(combat.enemies[1]);check(not world.flags.get("decon_clear",false),"unrelated room kill never clears mandatory encounter")
	kill(combat.enemies[0]);check(world.flags.get("decon_clear",false),"only explicit decon group publishes authored completion flag")
	check(world.get_level_state().exit_ready,"exit readiness follows profile prerequisites")

	# Actual shared collision owns accepted shots and metal-only anchor damage.
	var before_kills:int=combat.kills;var before_gore:int=combat.gore.death_count
	var obstruction:=box(world,Vector3(0,1,-1.5),Vector3(2,3,.2));await physics_frame;await physics_frame
	check(await fire(&"pistol"),"wall-blocked anchor shot still consumes one accepted shot")
	check(anchor.health==60 and not world.flags.has("anchor_a"),"shared wall blocks anchor damage")
	obstruction.queue_free();await physics_frame;await physics_frame;events.clear()
	for i in 3:check(await fire(&"pistol"),"accepted pistol anchor contact "+str(i))
	check(anchor.disabled and anchor.health==0 and count("mechanism_disabled")==1 and count("mechanism_damaged")==3,"60HP anchor disables once after three real pistol contacts")
	check(combat.kills==before_kills and combat.gore.death_count==before_gore and count("enemy_death")==0 and count("enemy_hurt")==0,"metal mechanism emits no enemy damage/kill/gore")
	var all_metal:=true
	for event in events:
		if String(event.type)=="impact":all_metal=all_metal and event.material==&"armor" and event.target_id=="unit.anchor"
	check(all_metal,"mechanism impacts use stable ID and armor sound material")
	anchor.apply_mechanism_damage(100,combat.shot_counter,&"pistol",anchor.position);check(count("mechanism_disabled")==1,"duplicate mechanism release cannot replay completion")
	anchor.reset_mechanism();world.flags.erase("anchor_a");events.clear()
	check(await fire(&"shotgun"),"shotgun anchor shot accepted")
	check(anchor.disabled and count("mechanism_damaged")==1,"pellets aggregate into one mechanism damage owner")
	for weapon in [&"twin_shotgun",&"rivet_cannon",&"melee"]:
		combat.grant_weapon(weapon,4 if weapon==&"rivet_cannon" else 0)
		anchor.reset_mechanism();world.flags.erase("anchor_a");events.clear()
		player.position=Vector3(0,.85,-1.3)
		var definition:WeaponDefinition=combat.weapons[weapon]
		var rounds:=1 if weapon==&"twin_shotgun" else 2
		for index in rounds:
			var shots_before:int=combat.shot_counter
			check(await fire(weapon),String(weapon)+" real accepted mechanism contact "+str(index))
			check(combat.shot_counter==shots_before+1 and count("mechanism_damaged")==index+1,String(weapon)+" each accepted shot owns one aggregated damage event")
		var metal:=true;var raw_damage:=true
		for event in events:
			if String(event.type)=="impact":metal=metal and event.material==&"armor" and event.target_id=="unit.anchor"
			if String(event.type)=="mechanism_damaged":raw_damage=raw_damage and event.damage==definition.damage*definition.pellets
		check(anchor.disabled and count("mechanism_disabled")==1 and metal and raw_damage,String(weapon)+" exact resource damage/metal completion once")
		check(combat.kills==before_kills and combat.gore.death_count==before_gore and count("enemy_hurt")==0 and count("enemy_death")==0,String(weapon)+" mechanism remains outside enemy/gore ownership")
		check(await fire(weapon),String(weapon)+" disabled metal body still accepts physical weapon contact")
		check(count("mechanism_disabled")==1 and count("mechanism_damaged")==rounds,String(weapon)+" disabled target cannot republish flag or damage events")
	anchor.reset_mechanism();world.flags.erase("anchor_a");events.clear();player.position=Vector3(0,.85,8)
	combat.grant_weapon(&"siege_launcher",1);events.clear()
	check(await fire(&"siege_launcher"),"Siege mechanism contact starts one actual accepted projectile")
	for n in 90:
		if anchor.disabled:break
		await physics_frame
	check(anchor.disabled and count("shot")==1 and count("mechanism_damaged")==1 and count("mechanism_disabled")==1 and combat.kills==before_kills,"actual swept projectile explosion dedicated mechanism branch avoids enemy fields")

	# Checkpoint safety is physical and atomic; do not save a chase or moving gate.
	player.position=Vector3(0,.85,0);player.set_movement_active(true)
	for i in 4:player._physics_process(DT);await physics_frame
	player.set_movement_active(false)
	check(world.checkpoint_is_safe(),"grounded stationary secured area is checkpoint-safe")
	world.mechanisms.erase(button);player.velocity=Vector3.RIGHT;world.update_checkpoints(DT)
	check(world.prompt=="Checkpoint · stop here to secure progress","eligible checkpoint explains stationary capture while moving")
	world.mechanisms.append(button);world.prompt="E · nearby control";world.update_checkpoints(DT)
	check(world.prompt=="E · nearby control","checkpoint hint preserves a nearby real interaction prompt")
	player.velocity=Vector3.ZERO
	var living:CharacterBody3D=combat.enemies[2];var remote:=living.position;living.position=Vector3(0,.85,-5)
	check(not world.checkpoint_is_safe(),"near living threat blocks checkpoint")
	world.mechanisms.erase(button);world.update_checkpoints(DT)
	check(world.prompt=="Checkpoint waiting · clear nearby threats","unsafe checkpoint explains nearby threat")
	world.mechanisms.append(button)
	living.position=remote
	var projectile:Node3D=combat.launch_projectile(living,Vector3(0,2,3),Vector3.FORWARD);projectile.set_physics_process(false)
	check(not world.checkpoint_is_safe(),"live enemy projectile blocks checkpoint")
	projectile.resolved=true;projectile.queue_free();door.opened=true
	check(not world.checkpoint_is_safe(),"moving door blocks checkpoint")
	door.sync_to_physics=false;door.position=door.origin+door.open_offset;door.sync_to_physics=true
	await physics_frame;await physics_frame
	check(world.checkpoint_is_safe(),"fully stopped open mechanism permits checkpoint")
	world.update_checkpoints(.25);check(checkpoint_ids.is_empty(),"checkpoint requires stationary dwell")
	world.update_checkpoints(.26);check(checkpoint_ids==["power_return"],"safe marker publishes one accepted checkpoint")
	world.update_checkpoints(1.0);check(checkpoint_ids.size()==1,"same checkpoint marker never resaves continuously")
	var campaign:RefCounted=Campaign.new();combat.health=73;combat.armor=28;combat.ammo_pistol=17
	check(campaign.capture_checkpoint(world,combat,player,"power_return"),"atomic session checkpoint captures current inventory/world")
	var saved:Dictionary=campaign.checkpoint_snapshot.duplicate(true)
	var saved_kills:int=combat.kills;var event_count:=events.size()
	combat.health=1;combat.ammo_pistol=0;world.flags.clear();world.collected.clear();key_item.visible=true;door.reset_door();anchor.reset_mechanism();living.health=1
	check(campaign.restore_checkpoint(world,combat,player,saved),"checkpoint restores same authored world")
	check(combat.health==73 and combat.armor==28 and combat.ammo_pistol==17 and combat.kills==saved_kills,"restore inventory and kill count exactly")
	check(world.flags.get("surgical_credential",false) and not key_item.visible and door.is_open() and anchor.disabled,"restore flags, consumed pickup, gate and disabled anchor")
	check(combat.enemies[0].dead and combat.enemies[1].dead and not living.dead and living.health==80,"restore dead actors and partially/live logical state")
	check(events.size()==event_count,"state restore emits no reward, kill, pickup or mechanism events")
	player.position=Vector3(10,.85,0);world.update_checkpoints(.51)
	check(not checkpoint_ids.is_empty() and checkpoint_ids.back()=="credential_return" and campaign.capture_checkpoint(world,combat,player,"credential_return"),"second safe checkpoint can supersede first")
	check(campaign.checkpoint_snapshot.checkpoint_id=="credential_return","session keeps latest checkpoint only")
	var latest:Dictionary=campaign.checkpoint_snapshot.duplicate(true)
	await fixture(profile)
	var restore_events:=events.size()
	check(campaign.restore_checkpoint(world,combat,player,latest),"stable checkpoint restores into newly instantiated world")
	check(combat.health==73 and not key_item.visible and combat.enemies[0].dead and anchor.disabled and world.flags.get("decon_clear",false),"fresh world restores actors/items/anchors/objectives together")
	check(events.size()==restore_events and combat.gore.particles.is_empty() and combat.gore.stains.is_empty(),"fresh checkpoint rebuild has no replayed effects/events")
	var other:Dictionary=latest.duplicate(true);other.level_id="different"
	check(not campaign.restore_checkpoint(world,combat,player,other),"different level checkpoint is rejected")
	campaign.reset();check(not campaign.has_checkpoint(),"new game/title reset clears checkpoint")

	# Both isolation branch orders are valid; objective selection is flags-only.
	for order in [["isolation_a","isolation_b"],["isolation_b","isolation_a"]]:
		var containment:StageObjectiveProfile=Profile.from_dictionary(inputs.levels[1].objective_profile)
		var flags:Dictionary={}
		for id in order:
			for granted in containment.controls[id].sets:flags[granted]=true
		check(containment.unmet(containment.exit_requires,flags).is_empty() and flags.one_isolated,"Containment supports branch order "+str(order))
	await main_checkpoint_check()
	if FileAccess.file_exists("res://resources/campaign/v13/pale_ward_02-objectives.tres") and FileAccess.file_exists("res://resources/campaign/v13/pale_ward_03-objectives.tres"):
		await other_ward_checkpoints()
	var folder:="res://verification/level-redesign-v13/runtime";DirAccess.make_dir_recursive_absolute(folder)
	var suffix:="headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open(folder+"/progression-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"actual_main_levels":main_levels_tested,"scope":"Production Stage/Combat/Player on shared component solids, plus controlled actual Main checkpoints in all available redesigned Wards. Intake isolates checkpoint restoration with local_power flag and remote corpse/gib setup. Other Wards freeze AI only: authored nearby threats retain health/collision/safety and are defeated with finite accepted shots; real E controls/anchor hits and automatic safe marker capture. Player poses controlled, not a traversal or human acceptance claim. Full physical routes independently verified."},"  "))
	print("PROGRESSION_V13 checks=%d failed=%d"%[checks.size(),failed]);quit(1 if failed>0 else 0)
