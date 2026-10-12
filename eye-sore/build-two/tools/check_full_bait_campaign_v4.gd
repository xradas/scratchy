extends SceneTree
## Main campaign interaction fixture, deliberately NOT a combat/traversal proof.
## Setup places actors near probes, freezes enemy AI, restores an overfilled owned
## entry snapshot and injects lethal damage after trap checks. Pickup approach uses
## actual W input, and manual controls use Main's actual E event path.
const CAPS := {"pistol":96,"shells":40,"rivets":160,"rockets":12}
const FIELDS := {"pistol":"ammo_pistol","shells":"ammo_shotgun","rivets":"ammo_rivets","rockets":"ammo_rockets"}
const ARENAS := ["arena_one","arena_two","final_arena"]
const OUTPUT := "res://verification/combat-balance-v4/full-bait-progression.json"
var app: Control
var failures: Array[String] = []
var records: Array[Dictionary] = []
var events: Array[Dictionary] = []
var messages: Array[String] = []
var injection_id := -1
var active_label := ""

func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(active_label+": "+message)
		push_error("FULL_BAIT_V4: "+active_label+": "+message)
func xyz(point: Vector3) -> Array: return [point.x,point.y,point.z]
func ammo() -> Dictionary:
	var result: Dictionary = {}
	for kind in CAPS: result[kind]=int(app.combat.get(FIELDS[kind]))
	return result
func key(code: int, pressed: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
func ticks(count: int) -> void:
	for frame in count: await physics_frame
func freeze() -> void:
	app.player.set_physics_process(false);app.player.velocity=Vector3.ZERO
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
func place(point: Vector3) -> void:
	key(KEY_W,false);app.player.set_physics_process(false)
	app.player.global_position=point;app.player.velocity=Vector3.ZERO
	app.player.get_node("Camera3D").rotation=Vector3.ZERO
func count_event(type: String, start: int) -> int:
	var count:=0
	for index in range(start,events.size()):
		if String(events[index].get("type",""))==type: count+=1
	return count
func physical_contact(item: Node3D, should_collect: bool, repeat := false) -> Dictionary:
	# Only the short approach is a movement proof. Remote setup is declared.
	var directions: Array[Vector3]=[Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]
	var selected:=directions[0];var best:=-INF
	var start: Vector3=item.global_position+selected*1.8+Vector3(0,.22,0)
	var tread_axis:=-1
	var support: Dictionary=app.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(item.global_position+Vector3(0,.1,0),item.global_position-Vector3(0,1,0),1))
	if not support.is_empty() and support.collider.has_meta("stage_step"):
		var tread: CollisionShape3D=support.collider.get_node("Collision")
		tread_axis=2 if tread.shape.size.x>tread.shape.size.z else 0
	for direction in directions:
		# A case supported by a stair tread is approached along its authored run.
		# The preserved lateral attempt can clip the adjacent, higher riser's side.
		if tread_axis>=0 and absf(direction[tread_axis])<.5: continue
		var candidate: Vector3=item.global_position+direction*1.8+Vector3(0,.22,0)
		var floor_hit: Dictionary=app.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(candidate+Vector3(0,1,0),candidate-Vector3(0,2,0),1))
		if floor_hit.is_empty() or floor_hit.normal.y<.7: continue
		candidate.y=floor_hit.position.y+.87
		if absf(candidate.y-item.global_position.y)>1.2: continue
		var occupancy:=PhysicsShapeQueryParameters3D.new()
		occupancy.shape=app.player.get_node("CollisionShape3D").shape
		occupancy.transform=Transform3D(Basis.IDENTITY,candidate);occupancy.collision_mask=1
		if not app.world.get_world_3d().direct_space_state.intersect_shape(occupancy,1).is_empty(): continue
		# Check candidate body clearance at the unchanged native step height.
		# This only chooses initial setup; actual W movement proves contact.
		occupancy.transform.origin.y+=app.player.STEP_HEIGHT
		occupancy.motion=-direction*1.3
		if app.world.get_world_3d().direct_space_state.cast_motion(occupancy)[0]<1.0: continue
		var separation:=1000.0
		for other in app.world.pickups:
			if other!=item and not app.world.collected.has(other.get_instance_id()): separation=minf(separation,candidate.distance_to(other.global_position))
		if separation>best: best=separation;selected=direction;start=candidate
	check(best>-INF,"no supported unobstructed pickup approach: "+item.name)
	place(start);await ticks(2)
	if not repeat: check(not app.world.collected.has(item.get_instance_id()),"pickup consumed before W approach: "+item.name)
	app.player.rotation.y=atan2(selected.x,selected.z)
	app.player.set_physics_process(true);key(KEY_W,true)
	var elapsed:=0
	while elapsed<75:
		await physics_frame;elapsed+=1
		if (not repeat and app.world.collected.has(item.get_instance_id())) or app.player.global_position.distance_to(item.global_position)<.7: break
	key(KEY_W,false);app.player.set_physics_process(false);app.player.velocity=Vector3.ZERO
	await ticks(2)
	var contact_distance: float=app.player.global_position.distance_to(item.global_position)
	check(contact_distance<1.2,"actual player did not reach pickup contact: "+item.name)
	check(bool(app.world.collected.has(item.get_instance_id()))==should_collect,"unexpected contact acceptance: "+item.name)
	return {"setup_position":xyz(start),"contact_position":xyz(app.player.global_position),"contact_distance":contact_distance,"ordinary_w_ticks":elapsed,"collected":app.world.collected.has(item.get_instance_id())}
func manual_e(button: Node3D, enabled: bool) -> void:
	place(button.global_position+Vector3(0,-.18,1.2));await ticks(2)
	check(app.world.nearest_mechanism()==button,"physical control probe did not select expected button")
	key(KEY_E,true);await ticks(2);key(KEY_E,false)
	var flag:=String(button.get_meta("stage_button"))
	check(bool(app.world.flags.get(flag,false))==enabled,"manual E control permission wrong for "+flag)
func door_ray(door: Node3D, center: Vector3, normal: Vector3, blocked: bool, phase: String) -> Dictionary:
	var hit: Dictionary=app.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center-normal*.7,center+normal*.7,1))
	check((not hit.is_empty() and hit.collider==door) if blocked else hit.is_empty(),phase+" ray did not match real slab")
	return {"phase":phase,"blocked":not hit.is_empty(),"collider":String(hit.collider.name) if not hit.is_empty() else "","from":xyz(center-normal*.7),"to":xyz(center+normal*.7)}
func swept_projectile(door: Node3D, center: Vector3, normal: Vector3, blocked: bool, phase: String) -> Dictionary:
	# Uses the same native enemy-projectile API as tools/check_combat.gd.
	# This geometry probe is not an enemy attack or an accepted player shot.
	var source: CharacterBody3D=app.combat.enemies[0]
	var projectile: Node3D=app.combat.launch_projectile(source,center-normal*.65,normal)
	projectile.set_physics_process(false)
	var before:=events.size()
	projectile._physics_process(1.3/maxf(source.definition.projectile_speed,.01))
	var resolved: bool=projectile.resolved
	check(resolved==blocked,phase+" swept projectile disagrees with real door obstruction")
	var traveled: float=(projectile.global_position-(center-normal*.65)).length()
	check(count_event("player_hurt",before)==0,phase+" projectile probe unexpectedly touched player")
	projectile.queue_free()
	return {"phase":phase,"door":String(door.name),"resolved_at_obstacle":resolved,"traveled":traveled,"expected_obstruction":blocked,"scope":"Injected native enemy projectile, manually advanced one sweep; no player fire/ammo or live AI."}
func blocker_at(point: Vector3) -> CharacterBody3D:
	var actor:=CharacterBody3D.new();actor.name="FixtureEntryOccupancy";actor.collision_layer=2;actor.collision_mask=1
	app.world.add_child(actor);actor.global_position=point
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.7;shape.shape=capsule;actor.add_child(shape)
	return actor
func bait_probe(arena: String) -> Dictionary:
	var world: Node3D=app.world
	var bait: Node3D=world.get_node("Bait_"+arena)
	var weapon:=StringName(bait.get_meta("stage_pickup"))
	var entry: Node3D=world.trap_entries[arena]
	var threshold: Vector3=entry.get_meta("entry_threshold")
	var normal: Vector3=entry.get_meta("entry_normal")
	var button: Node3D=world.get_node("Button_"+{"arena_one":"breaker","arena_two":"release","final_arena":"exit_control"}[arena])
	var inhabitants: Array[CharacterBody3D]=[]
	for enemy in app.combat.enemies:
		if String(enemy.get_meta("arena_id",""))==arena: inhabitants.append(enemy)
	var expected:=inhabitants.size()
	check(expected>0 and int(world.arena_remaining.get(arena,-1))==expected,"authored living arena count differs")
	check(app.combat.has_weapon(weapon) and ammo()==CAPS,"owned saturated entry fixture not established")
	await manual_e(button,false)
	place(threshold+normal*2.5+Vector3(0,.87,0));await ticks(2)
	check(not world.traps[arena].triggered and not world.is_arena_active(arena),"entry alone woke trap")
	check(entry.is_open(),"lure entry is initially blocked")
	for enemy in inhabitants: check(not enemy.awake and not enemy.dead,"concealed actor awake/dead before bait")
	var rays: Array[Dictionary]=[];var sweeps: Array[Dictionary]=[]
	var entry_center: Vector3=entry.get_parent().to_global(entry.origin)+Vector3(0,-1.1,0)
	rays.append(door_ray(entry,entry_center,normal,false,"entry initially open"))
	for shutter in world.trap_shutters[arena]:
		var center: Vector3=shutter.get_parent().to_global(shutter.origin)+Vector3(0,-1.1,0)
		rays.append(door_ray(shutter,center,Vector3.RIGHT,true,"closet initially closed"))
	# Block occupied closure before physical bait contact; no scene/runtime edits.
	var obstruction:=blocker_at(threshold+Vector3(0,.87,0));await ticks(2)
	check(not entry.sweep_is_clear(),"occupied entry sweep was reported clear")
	var event_start:=events.size();var before: Dictionary=ammo();var contact: Dictionary=await physical_contact(bait,true)
	check(world.traps[arena].triggered and not bait.visible,"saturated owned bait failed to spring once")
	check(ammo()==before and count_event("ammo_added",event_start)==0 and count_event("weapon_granted",event_start)==0,"saturated bait produced false ammunition/grant event")
	check(entry.opened and not entry.sealing,"occupied sweep allowed entry closure")
	await ticks(8)
	var first_shutter: Node3D=world.trap_shutters[arena][0]
	var moving_shutter_center: Vector3=first_shutter.global_position+Vector3(0,-1.1,0)
	rays.append(door_ray(first_shutter,moving_shutter_center,Vector3.RIGHT,true,"closet moving"))
	sweeps.append(swept_projectile(first_shutter,moving_shutter_center,Vector3.RIGHT,true,"closet moving"))
	await ticks(100)
	check(world.traps[arena].shutters_open and world.is_arena_active(arena),"physical open shutters failed activation")
	for enemy in inhabitants: check(enemy.awake and not enemy.dead,"concealed roster failed actual wake")
	for shutter in world.trap_shutters[arena]:
		check(shutter.is_open(),"shutter never physically opened")
		var center: Vector3=shutter.get_parent().to_global(shutter.origin)+Vector3(0,-1.1,0)
		rays.append(door_ray(shutter,center,Vector3.RIGHT,false,"closet fully open"))
	# Actual player below the three-metre threshold holds retreat open too.
	place(threshold+normal*2.5+Vector3(0,.87,0));obstruction.queue_free();await ticks(4)
	check(entry.opened and not entry.sealing,"closure ignored safe three-metre threshold")
	place(threshold+normal*4.5+Vector3(0,.87,0));await ticks(45)
	check(entry.sealing and not entry.is_closed(),"safe entry did not start physical closure")
	var moving_center: Vector3=entry.global_position+Vector3(0,-1.6,0)
	rays.append(door_ray(entry,moving_center,normal,true,"entry moving closed"))
	sweeps.append(swept_projectile(entry,moving_center,normal,true,"entry moving closed"))
	# Occupying the sweep while the high leaf descends must pause its motion.
	place(threshold+Vector3(0,.87,0));await ticks(3)
	var held_position: Vector3=entry.position;var player_position: Vector3=app.player.global_position
	var health: float=app.combat.health;await ticks(20)
	var pause_verified: bool=not entry.sweep_is_clear() and entry.position==held_position and app.player.global_position==player_position and app.combat.health==health
	check(not entry.sweep_is_clear() and entry.position==held_position,"descending leaf moved through occupied player sweep")
	check(app.player.global_position==player_position and app.combat.health==health,"closure displaced/crushed fixture player")
	place(threshold+normal*4.5+Vector3(0,.87,0));await ticks(110)
	check(entry.is_closed() and world.traps[arena].latched,"safe entry did not fully latch")
	rays.append(door_ray(entry,entry_center,normal,true,"entry fully latched"))
	sweeps.append(swept_projectile(entry,entry_center,normal,true,"entry fully latched"))
	await manual_e(button,false)
	check(int(world.arena_remaining[arena])==expected,"arena count changed without injected deaths")
	var injected: Array[Dictionary]=[]
	for enemy in inhabitants:
		var remaining_before: int=world.arena_remaining[arena]
		var damage: float=enemy.health+1.0
		var event: Dictionary=enemy.apply_damage(damage,injection_id,&"pistol",enemy.global_position)
		injected.append({"target_id":String(enemy.target_id),"synthetic_shot_id":injection_id,"damage":damage,"event":String(event.get("type",""))});injection_id-=1
		check(enemy.dead and int(world.arena_remaining[arena])==remaining_before-1,"injected death failed decrement")
		world.notify_enemy_death(String(enemy.target_id),arena)
		check(int(world.arena_remaining[arena])==remaining_before-1,"duplicate death changed remaining count")
		if remaining_before>1: check(not world.flags.get("clear_"+arena,false),"arena enabled manual control before last death")
	check(int(world.arena_remaining[arena])==0 and world.traps[arena].cleared and not world.traps[arena].latched,"last death failed retreat release")
	check(not world.flags.get(String(button.get_meta("stage_button")),false),"arena clear bypassed manual button")
	await ticks(110)
	check(entry.is_open(),"cleared retreat remains blocked")
	rays.append(door_ray(entry,entry_center,normal,false,"cleared retreat open"))
	sweeps.append(swept_projectile(entry,entry_center,normal,false,"cleared retreat open"))
	await manual_e(button,true)
	var repeat_event_start:=events.size();await physical_contact(bait,true,true)
	check(ammo()==CAPS and events.size()==repeat_event_start,"consumed bait repeated grant or event")
	return {"arena":arena,"weapon":String(weapon),"authored_bait_ammo":int(bait.get_meta("amount")),"contact":contact,"saturation_events":{"ammo_added":count_event("ammo_added",event_start),"weapon_granted":count_event("weapon_granted",event_start)},"ammo_before":before,"ammo_after":ammo(),"entry_threshold":xyz(threshold),"closure_safe_distance":4.5,"occupied_sweep_paused":pause_verified,"shutters":world.trap_shutters[arena].size(),"authored_enemies":expected,"injected_deaths":injected,"manual_control":String(button.get_meta("stage_button")),"rays":rays,"swept_projectiles":sweeps,"final_trap":world.traps[arena].duplicate(true)}
func ammo_box_probes() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for item in app.world.pickups:
		var kind:=String(item.get_meta("stage_pickup"))
		if kind not in CAPS: continue
		for ammo_kind in CAPS: app.combat.set(FIELDS[ammo_kind],int(CAPS[ammo_kind]))
		var start:=events.size();var before: Dictionary=ammo()
		var full_contact: Dictionary=await physical_contact(item,false)
		check(item.visible and ammo()==before and count_event("ammo_added",start)==0,"full ordinary case was consumed or emitted false ammo")
		var offered:=int(item.get_meta("amount"));var room:=mini(5,offered)
		# Declared deficit setup tests acceptance; it is not gameplay ammunition use.
		app.combat.set(FIELDS[kind],int(CAPS[kind])-room)
		start=events.size();messages.clear()
		var partial_contact: Dictionary=await physical_contact(item,true)
		var added:=0;var ammo_events:=0
		for index in range(start,events.size()):
			if String(events[index].type)=="ammo_added": added+=int(events[index].amount);ammo_events+=1
		check(not item.visible and ammo()==CAPS and added==room and ammo_events==1,"partial ordinary case did not accept exact remaining capacity")
		check(messages.has("%s +%d" % [kind.capitalize(),room]),"pickup feedback reported authored rather than actual accepted ammo")
		result.append({"item":String(item.name),"kind":kind,"offered":offered,"full_contact":full_contact,"full_remained_available":not full_contact.collected,"declared_deficit":room,"partial_contact":partial_contact,"accepted_ammo":added,"actual_ammo_events":ammo_events,"feedback":messages.duplicate()})
		for ammo_kind in CAPS: app.combat.set(FIELDS[ammo_kind],int(CAPS[ammo_kind]))
	return result
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	check(app.campaign.levels.size()==9,"campaign catalog is not nine levels")
	var saturated: Dictionary=app.campaign.capture(app.combat)
	for kind in CAPS: saturated[FIELDS[kind]]=int(CAPS[kind])+7
	saturated.owned_weapons={&"melee":true,&"pistol":true,&"shotgun":true,&"twin_shotgun":true,&"rivet_cannon":true,&"siege_launcher":true}
	saturated.health=100.0;saturated.armor=50.0
	for level_value in app.campaign.levels:
		var level: Dictionary=level_value;active_label=String(level.id)
		app.set_paused(true);app.campaign_mode=true;app.level_complete=false;app.campaign.seek(String(level.id));app.stage_id=String(level.theme)
		app.replace_world(saturated);app.campaign.entry_snapshot=app.campaign.capture(app.combat)
		app.combat.combat_event.connect(func(event: Dictionary):events.append(event.duplicate(true)))
		app.world.message_changed.connect(func(message: String):messages.append(message))
		freeze();app.enter_combat();await ticks(2)
		# Isolate trap slabs from overlapping prerequisite progression gates.
		# Their actual native activate API receives declared fixture permission;
		# no world flags/manual arena controls are fabricated by this setup.
		for mechanism in app.world.mechanisms:
			if not mechanism.has_meta("stage_door"): continue
			var permissions: Dictionary={}
			for requirement in mechanism.get_meta("requires",[]): permissions[String(requirement)]=true
			check(mechanism.activate(permissions),"fixture prerequisite gate preparation rejected")
		await ticks(100)
		check(ammo()==CAPS and app.campaign.entry_snapshot.ammo_pistol==96 and app.campaign.entry_snapshot.ammo_shotgun==40 and app.campaign.entry_snapshot.ammo_rivets==160 and app.campaign.entry_snapshot.ammo_rockets==12,"entry was not clamped before retry snapshot")
		var bait_records: Array[Dictionary]=[]
		for arena in ARENAS:
			active_label=String(level.id)+":"+arena
			bait_records.append(await bait_probe(arena))
		active_label=String(level.id)+":ordinary supplies"
		var boxes: Array[Dictionary]=await ammo_box_probes()
		var old_world_id: int=app.world.get_instance_id()
		app.restart_combat();freeze()
		# Freshness is sampled before normal entry-contact physics: Ward 01's
		# nearby armor may legitimately collect on the first ordinary tick.
		for item in app.world.pickups:
			check(item.visible and not app.world.collected.has(item.get_instance_id()),"Retry did not restore fresh pickup: "+item.name)
		await ticks(2)
		check(app.world.get_instance_id()!=old_world_id and app.campaign.current_level().id==level.id,"Retry did not rebuild same level")
		check(ammo()==CAPS,"Retry failed saturated clamped entry restore")
		var retry: Array[Dictionary]=[]
		for arena in ARENAS:
			var bait: Node3D=app.world.get_node("Bait_"+arena)
			check(bait.visible and not app.world.collected.has(bait.get_instance_id()),"Retry did not restore bait")
			check(not app.world.traps[arena].triggered and not app.world.traps[arena].cleared and not app.world.traps[arena].latched and not app.world.traps[arena].shutters_open,"Retry retained trap state")
			check(app.world.trap_entries[arena].is_open(),"Retry retained closed retreat")
			for shutter in app.world.trap_shutters[arena]:check(shutter.is_closed(),"Retry retained opened shutter")
			var fresh:=0
			for enemy in app.combat.enemies:
				if String(enemy.get_meta("arena_id",""))!=arena: continue
				check(not enemy.dead and not enemy.awake and enemy.health==enemy.definition.health and enemy.collision_layer!=0,"Retry retained dead/awake/damaged AI")
				fresh+=1
			check(fresh==int(app.world.arena_remaining[arena]),"Retry remaining does not match restored actors")
			retry.append({"arena":arena,"fresh_dormant_actors":fresh,"bait_visible":bait.visible,"trap":app.world.traps[arena].duplicate(true)})
		records.append({"level":String(level.id),"scene":String(level.scene),"bait_traps":bait_records,"ordinary_ammo_boxes":boxes,"retry":retry,"retry_fresh_pickups":app.world.pickups.size(),"retry_ammo":ammo()})
		print("FULL_BAIT_V4_LEVEL ",level.id," bait=",bait_records.size()," ordinary_ammo=",boxes.size()," failures=",failures.size())
	var actual_shots:=count_event("shot",0)
	var box_count:=0;var ray_count:=0;var projectile_count:=0;var injected_deaths:=0
	for record in records:
		box_count+=record.ordinary_ammo_boxes.size()
		for bait in record.bait_traps:
			ray_count+=bait.rays.size();projectile_count+=bait.swept_projectiles.size();injected_deaths+=bait.injected_deaths.size()
	check(records.size()==9 and actual_shots==0,"fixture completion or injected-death labeling failed")
	var report:={"status":"passed" if failures.is_empty() else "failed","failures":failures,"campaign_levels":records.size(),"physical_bait_contacts":records.size()*3,"ordinary_ammo_boxes":box_count,"door_collision_rays":ray_count,"native_swept_projectile_probes":projectile_count,"explicitly_injected_deaths":injected_deaths,"ammo_caps":CAPS,"actual_player_shots":actual_shots,"records":records,"initial_findings":{"preserved_receipt":"full-bait-progression-initial-failure.json","preserved_log":"full-bait-initial.log","resolution":"Fixture-only corrections: consumed bait repeat is not a fresh pickup, moving slab probes stay below lintels, overlapping prerequisite gate is prepared open, and each contact setup stands above its actual supported floor. Deficits restored between independent ammo probes to prevent cascading false findings; runtime/scenes unchanged."},"scope":"Actual Main full-capacity owned-bait contact, physical shutter/entry collision, safe empty-sweep closure, arena remaining/manual E control, ordinary saturated/partial ammo contact and full retry rebuilding across all nine levels.","limitations":["Declared remote setup placements followed by short actual W approaches; this is not a continuous physical campaign route.","All AI physics frozen to isolate interactions. Arena deaths are injected lethal damage with negative synthetic shot IDs and no accepted player shots; this is not combat balance or survival proof.","Entry snapshots deliberately contain every gun and over-capacity ammunition; actual Main restore clamps them before recording the retry snapshot.","Prerequisite progression gates are opened through their actual activate API with declared fixture permissions to isolate trap slabs; world progression flags/manual controls are not fabricated.","Door projectile probes inject existing native enemy projectiles and advance one swept motion explicitly; they do not claim live enemy attack cadence, player ordnance, render-rate or human acceptance.","Ordinary partial-box probes directly create a declared five-round-or-less deficit to verify actual acceptance and feedback; ammunition is restored to capacity between independent probes."]}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT).get_base_dir())
	if not failures.is_empty() and not FileAccess.file_exists(OUTPUT.trim_suffix(".json")+"-initial-failure.json"):
		var initial:=FileAccess.open(OUTPUT.trim_suffix(".json")+"-initial-failure.json",FileAccess.WRITE);initial.store_string(JSON.stringify(report,"  "));initial.close()
	var output:=FileAccess.open(OUTPUT,FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "));output.close()
	print("FULL_BAIT_V4_", "PASS" if failures.is_empty() else "FAIL", " ",OUTPUT," failures=",failures.size())
	await app.quit_game()
	quit(0 if failures.is_empty() else 1)
