extends SceneTree
## Controlled actual Main shots in authored Intake; no gameplay resource edits.
var app: Control
var expected: Dictionary
var output := ""
var capture_dir := ""
var failures: Array[String] = []
var checks := 0
var events: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var captures: Array[String] = []
var capture_records: Array[Dictionary] = []
var measuring := false
var frame_metrics: Array[Dictionary] = []
var last_frame_usec := 0
var tested_bursts := {}
var particle_peak := 0
var perf_phase := "setup"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected="): expected=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--expected=")))
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
		if arg.begins_with("--capture-dir=" ): capture_dir=arg.trim_prefix("--capture-dir=")
	process_frame.connect(record_frame)
	call_deferred("run")
func record_frame() -> void:
	var now := Time.get_ticks_usec()
	if measuring and last_frame_usec>0 and frame_metrics.size()<3000:
		frame_metrics.append({"phase":perf_phase,"tick":Engine.get_physics_frames(),"time_usec":now,"wall_frame_ms":float(now-last_frame_usec)/1000.0,"process_cpu_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"physics_cpu_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"particles":app.combat.gore.particles.size(),"remains":app.combat.gore.remains.size(),"stains":app.combat.gore.stains.size()})
		if is_instance_valid(app) and is_instance_valid(app.combat): particle_peak=maxi(particle_peak,app.combat.gore.particles.size())
	last_frame_usec=now
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error("GORE_V12: "+label)
func frames(n: int) -> void:
	for i in n: await physics_frame
func observe(event: Dictionary) -> void:
	var copy := event.duplicate(true); copy.qa_observed_usec=Time.get_ticks_usec(); copy.qa_phase=perf_phase
	events.append(copy)
func count(type: String,target := "") -> int:
	var result := 0
	for event in events:
		if String(event.get("type",""))==type and (target.is_empty() or String(event.get("target_id",""))==target): result+=1
	return result
func freeze_actors() -> void:
	app.player.set_physics_process(false); app.world.set_physics_process(false)
	for enemy in app.combat.enemies:
		enemy.set_physics_process(false); enemy.collision_layer=0
		for body in enemy.hurt_shapes: body.collision_layer=0
func install() -> void:
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	check(app.campaign_mode and String(app.campaign.current_level().id)=="pale_ward_01","actual Main command-line Intake world loaded once")
	app.enter_combat(); freeze_actors()
	app.combat.combat_event.connect(observe)
	app.combat.grant_weapon(&"twin_shotgun",0); app.combat.grant_weapon(&"siege_launcher",0)
	app.combat.ammo_pistol=100; app.combat.ammo_shotgun=20; app.combat.ammo_rockets=8; app.combat.normalize_ammo()
	await frames(15)
func target_at(index: int,point: Vector3) -> Node3D:
	var enemy: Node3D=app.combat.enemies[index]
	enemy.global_position=point; enemy.state=&"chase"; enemy.state_time=0; enemy.update_sprite()
	var surfaces := 0
	for body in enemy.hurt_shapes:
		var surface: CollisionShape3D=body.get_node_or_null("HitSurface")
		if surface==null:
			check(body.name=="SpriteQueryOwner" and body.collision_layer==0,"intentional query-owner sentinel has no physical contact surface")
			continue
		if surface.shape!=null: body.collision_layer=4; surfaces+=1
	check(surfaces>0,"selected actual actor has nonempty anatomical contact surfaces")
	return enemy
func prepare_weapon(weapon: StringName) -> void:
	for i in 180:
		if app.combat.cooldown<=0: break
		await physics_frame
	if app.combat.currentweapon!=weapon:
		check(app.combat.select_weapon(weapon),"actual weapon selection "+String(weapon))
		for i in 60:
			if app.combat.cooldown<=0 and app.combat.weapon_phase!=&"switch": break
			await physics_frame
func aim(enemy: Node3D,corpse := false) -> bool:
	enemy.update_sprite(); await frames(2)
	var bodies: Array=enemy.corpse_shapes if corpse else enemy.hurt_shapes
	for body in bodies:
		var surface: CollisionShape3D=body.get_node_or_null("HitSurface")
		if surface==null: continue
		var shape: Shape3D=surface.shape
		if shape==null: continue
		var centre: Vector3=shape.get_debug_mesh().get_aabb().get_center(); var candidates := [centre]
		if shape is ConcavePolygonShape3D:
			var faces: PackedVector3Array=shape.get_faces(); var samples: Array[Vector3]=[]
			for index in range(0,faces.size(),maxi(3,int(faces.size()/90.0)/3*3)):
				if index+2<faces.size(): samples.append((faces[index]+faces[index+1]+faces[index+2])/3)
			samples.sort_custom(func(a:Vector3,b:Vector3)->bool:return a.distance_squared_to(centre)<b.distance_squared_to(centre))
			candidates.append_array(samples)
		for local in candidates:
			var point: Vector3=body.to_global(local); var origin: Vector3=app.player.camera.global_position
			var hit: Dictionary=app.combat.ray(origin,point+(point-origin).normalized()*.1,app.combat.anatomical_exclusions(),true)
			if not hit.is_empty() and hit.collider.get_meta("combat_target",null)==enemy:
				app.player.camera.look_at(point); return true
	observations.append({"aim_failed":enemy.target_id,"corpse":corpse,"player":str(app.player.global_position),"actor":str(enemy.global_position)})
	return false
func accepted_shot(enemy: Node3D,weapon: StringName,corpse := false) -> bool:
	await prepare_weapon(weapon)
	var aimed: bool=await aim(enemy,corpse)
	check(aimed,"actual opaque "+("corpse" if corpse else "living")+" contact aim "+String(weapon))
	if not aimed: return false
	var definition: Resource=app.combat.weapons[weapon]
	var prior_particles := {}
	for p in app.combat.gore.particles: prior_particles[p.node.get_instance_id()]=true
	var before_ammo: int=app.combat.get(String(definition.ammo_key)); var before_shots := count("shot")
	var before_fire := Time.get_ticks_usec()
	var accepted: bool=app.combat.try_fire()
	observations.append({"phase":perf_phase,"weapon":weapon,"shot_id":app.combat.shot_counter,"accepted":accepted,"try_fire_sync_ms":float(Time.get_ticks_usec()-before_fire)/1000.0,"event_scope":"Synchronous real trigger including hitscan resolution; projectile trigger excludes later swept explosion."})
	check(accepted,"accepted real trigger "+String(weapon))
	check(count("shot")==before_shots+1 and app.combat.get(String(definition.ammo_key))==before_ammo-definition.ammo_cost,"one accepted shot owns one event and exact ammo "+String(weapon))
	var now_ammo: int=app.combat.get(String(definition.ammo_key))
	check(not app.combat.try_fire() and count("shot")==before_shots+1 and app.combat.get(String(definition.ammo_key))==now_ammo,"cooldown rejects duplicate without event/ammo "+String(weapon))
	if definition.fire_mode=="projectile":
		for i in 120:
			await physics_frame
			if enemy.dead or enemy.gibbed: break
	if not tested_bursts.has(weapon):
		tested_bursts[weapon]=true
		var blood := 0; var chunks := 0
		for p in app.combat.gore.particles:
			if prior_particles.has(p.node.get_instance_id()): continue
			if p.get("blood",false): blood+=1
			if p.get("gib",false): chunks+=1
		var gore_profile: Resource=app.combat.gore.profile
		var wanted: int=gore_profile.spray_counts[String(weapon)] if not enemy.dead else mini(gore_profile.max_burst_drops,int(gore_profile.death_counts[String(weapon)])+(gore_profile.rupture_extra_drops if enemy.gibbed else 0))
		check(blood==wanted,"actual resolved weapon burst has exact finite blood-drop count "+String(weapon))
		check(chunks==(12 if enemy.gibbed else 0),"actual resolved burst keeps intact/rupture chunk distinction "+String(weapon))
		observations.append({"actual_weapon_burst":weapon,"fresh_blood_drops":blood,"fresh_closed_chunks":chunks,"expected_blood_drops":wanted})
	return accepted
func snapshot(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await process_frame; await RenderingServer.frame_post_draw
	var filename := capture_dir.path_join(label+".png")
	check(root.get_texture().get_image().save_png(filename)==OK,"native screenshot "+label); captures.append(filename)
	capture_records.append({"path":filename,"physics_tick":Engine.get_physics_frames(),"particles":app.combat.gore.particles.size(),"stains":app.combat.gore.stains.size(),"remains":app.combat.gore.remains.size()})
func particle_snapshot() -> Array:
	var result := []
	for p in app.combat.gore.particles: result.append({"id":p.node.get_instance_id(),"position":p.node.global_position,"age":p.age})
	return result
func pause_and_mute() -> void:
	await frames(2)
	var before := particle_snapshot(); var health: float=app.combat.health; var kills: int=app.combat.kills
	check(not before.is_empty(),"live real-shot burst present for pause test")
	app.set_paused(true); await create_timer(.12,true).timeout
	check(particle_snapshot()==before,"actual Main pause freezes cosmetic positions and age")
	check(not app.combat.try_fire() and app.combat.health==health and app.combat.kills==kills,"pause rejects trigger and freezes gameplay ownership")
	AudioServer.set_bus_mute(0,true); check(AudioServer.is_bus_mute(0),"Master mute active")
	app.set_paused(false); await frames(5)
	check(particle_snapshot()!=before and app.combat.health==health and app.combat.kills==kills,"muted live gore continues without gameplay changes")
	AudioServer.set_bus_mute(0,false)
func audio_identity() -> void:
	var old: Resource=load(expected.baseline_audio_profile_path); var current: Resource=load("res://resources/combat_audio.tres")
	var mapping := {}
	for cue in old.cues: mapping[String(cue.identifier)]=cue
	check(current.cues.size()==63 and mapping.size()==63,"all original63 native cue objects retained")
	for cue in current.cues:
		var id := String(cue.identifier); check(mapping.has(id),"original audio cue identity "+id)
		if not mapping.has(id): continue
		var prior: Resource=mapping[id]; var paths := []; var before := []
		for stream in cue.variations: paths.append(stream.resource_path)
		for stream in prior.variations: before.append(stream.resource_path)
		check(paths==before and cue.gain_db==prior.gain_db and cue.bus==prior.bus and cue.spatial==prior.spatial,"unchanged cue stream/gain/bus/spatial "+id)
	check(current.music.resource_path==old.music.resource_path and current.music_gain_db==old.music_gain_db,"music native path/gain unchanged")
func cosmetic_collision_count(node: Node) -> int:
	var total := 1 if node is CollisionObject3D or node is CollisionShape3D else 0
	for child in node.get_children(): total+=cosmetic_collision_count(child)
	return total
func check_settled() -> void:
	var gore: Node3D=app.combat.gore
	check(gore.remains.size()>0,"real rupture burst produces settled native chunks")
	check(gore.remains.size()<=128 and gore.stains.size()<=384 and gore.particles.size()<=256,"heavy real-shot effects stay within128/384/256 caps")
	check(cosmetic_collision_count(gore)==0,"all gore cosmetics add zero physics collision")
	var sampled := 0; var worst_clearance := 0.0
	for node in gore.remains:
		check(node is MeshInstance3D and node.mesh!=null,"settled remains retains real mesh node")
		if node.mesh==null: continue
		var size: Vector3=node.mesh.get_aabb().size
		check(minf(size.x,minf(size.y,size.z))>.005,"settled chunk has meaningful noncoplanar thickness")
		check(node.get_meta("mesh_closed",false),"settled chunk uses approved closed surface component")
		if sampled<3:
			var vertices: PackedVector3Array=node.mesh.get_faces(); var edges := {}
			for i in range(0,vertices.size(),3):
				for pair in [[i,i+1],[i+1,i+2],[i+2,i]]:
					var a := str(vertices[pair[0]].snapped(Vector3.ONE*.000001)); var b := str(vertices[pair[1]].snapped(Vector3.ONE*.000001)); var key := a+"/"+b if a<b else b+"/"+a
					edges[key]=int(edges.get(key,0))+1
			var closed := true
			for value in edges.values():
				if value!=2: closed=false; break
			check(closed and not edges.is_empty(),"native triangle topology is closed representative%d"%sampled)
			var bottom := INF
			for vertex in vertices: bottom=minf(bottom,node.to_global(vertex).y)
			var hit: Dictionary=gore.world_ray(node.global_position+Vector3.UP,node.global_position-Vector3.UP*2)
			check(not hit.is_empty(),"native world supports settled representative%d"%sampled)
			if not hit.is_empty(): worst_clearance=maxf(worst_clearance,absf(bottom-hit.position.y))
			sampled+=1
	observations.append({"heavy_settled_chunks":gore.remains.size(),"stains":gore.stains.size(),"live_particles":gore.particles.size(),"representative_support_clearance_m":worst_clearance,"frame_sampled_particle_peak":particle_peak})
func support_geometry() -> void:
	var component: Script=load("res://scripts/gore_chunk_v12.gd")
	var rng := RandomNumberGenerator.new(); rng.seed=120012
	var part: Dictionary=app.combat.gore.part_spec("unsealed",0,true)
	var chunk: MeshInstance3D=component.create(part,rng); app.combat.gore.add_child(chunk)
	check(chunk.get_child_count()==0 and cosmetic_collision_count(chunk)==0,"closed support fixture volume has zero collision descendants")
	var space: PhysicsDirectSpaceState3D=app.world.get_world_3d().direct_space_state
	for name in ["entry_Floor","arena_one_GalleryStairs-10"]:
		var body: Node3D=app.world.get_node(name); var shape: CollisionShape3D=body.get_node("Collision")
		var box: BoxShape3D=shape.shape
		var point: Vector3=shape.global_position+Vector3.UP*(box.size.y*.5+.12)
		var result: Dictionary=component.support_pose(space,chunk,point,0.0)
		check(result.supported,"independent closed volume supported by actual authored "+name)
		if result.supported:
			check(result.contacts.size()>=3 and result.support_polygon.size()>=4,"native support contacts enclose volume centre "+name)
			for contact in result.contacts:
				var ray: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(contact+Vector3.UP*.03,contact-Vector3.UP*.03,1))
				check(not ray.is_empty() and contact.distance_to(ray.position)<.001,"reported support contact lies on actual shared world geometry "+name)
			observations.append({"support_fixture":name,"contacts":result.contacts.size(),"reason":result.reason})
		if name=="entry_Floor":
			var cast: Dictionary=component.sweep(space,chunk,Transform3D(Basis.IDENTITY,point+Vector3.UP),Transform3D(Basis.IDENTITY,point-Vector3.UP),1)
			check(cast.hit and float(cast.fraction)<1,"swept closed volume stops on actual floor")
	var deck: Node3D=app.world.get_node("arena_one_GalleryDeck"); var deck_shape: CollisionShape3D=deck.get_node("Collision"); var box: BoxShape3D=deck_shape.shape
	var edge: Vector3=deck_shape.global_position+Vector3(box.size.x*.5+.3,box.size.y*.5+.12,0)
	var unsupported: Dictionary=component.support_pose(space,chunk,edge,0.0)
	check(not unsupported.supported,"volume beyond native gallery edge cannot fake support across air")
	observations.append({"support_fixture":"actual gallery outside edge","supported":unsupported.supported,"reason":unsupported.reason,"position":str(edge)})
	chunk.queue_free(); await frames(2)
func run() -> void:
	measuring=true; perf_phase="initial-world-setup"
	await install(); audio_identity(); perf_phase="normal-pistol"
	check(app.combat.gore.profile.max_particles==256 and app.combat.gore.profile.max_remains==128 and app.combat.gore.profile.max_stains==384,"approved bounded gore profile caps")
	app.player.global_position=Vector3(0,.87,7.5)
	var normal: Node3D=target_at(0,Vector3(0,.87,5.5)); await frames(2)
	for i in 8:
		if normal.dead: break
		await accepted_shot(normal,&"pistol")
	check(normal.dead and not normal.gibbed and app.combat.kills==1,"full-health actual pistol contacts leave one intact normal corpse")
	var gore: Node3D=app.combat.gore; var record: Dictionary=gore.death_records.get(normal.target_id,{})
	check(record.get("part_count",-1)==0 and not record.get("gibbed",true),"normal death emits zero detached body chunks")
	check(is_instance_valid(record.get("pool")) and app.combat.gore.death_count==1,"normal corpse owns one death and persistent blood pool")
	normal.set_physics_process(true); await frames(45); normal.set_physics_process(false)
	check(is_instance_valid(normal.sprite) and normal.sprite.visible and not normal.corpse_shapes.is_empty(),"normal corpse stays visible with postmortem query surfaces")
	await snapshot("normal-intact-corpse")
	perf_phase="postmortem-pistol-first-cold-chunks"
	var kills_before: int=app.combat.kills
	for i in 4:
		if normal.gibbed: break
		await accepted_shot(normal,&"pistol",true)
	check(normal.gibbed and app.combat.kills==kills_before and count("enemy_death",normal.target_id)==1 and count("corpse_gib",normal.target_id)==1,"real postmortem contacts rupture once without second kill")
	check(gore.death_count==1 and gore.death_records[normal.target_id].corpse_bursts==1,"one gore death owner and one postmortem burst")
	for event in events:
		if String(event.get("type",""))=="corpse_gib":
			var before: int=gore.particles.size(); gore.handle_event(event); check(gore.particles.size()==before,"replayed resolved corpse event creates no extra cosmetics"); break
	perf_phase="retry-reset-cold-resource-boundary"
	var normal_events := events.duplicate(true)
	var before_reset := Time.get_ticks_usec()
	app.restart_combat(); freeze_actors(); app.combat.combat_event.connect(observe)
	observations.append({"phase":perf_phase,"retry_sync_ms":float(Time.get_ticks_usec()-before_reset)/1000.0,"scope":"World rebuild/old-world teardown; outside accepted combat shots."})
	app.combat.grant_weapon(&"twin_shotgun",0); app.combat.grant_weapon(&"siege_launcher",0); app.combat.ammo_shotgun=20; app.combat.ammo_rockets=8; app.combat.normalize_ammo(); events.clear()
	check(app.combat.gore.remains.is_empty() and app.combat.gore.stains.is_empty() and app.combat.gore.particles.is_empty() and app.combat.kills==0,"actual Retry clears all prior effects and kills")
	await frames(15)
	measuring=true
	var phases := [{"weapon":&"shotgun","indices":[0,1,3,5],"distance":2.0},{"weapon":&"twin_shotgun","indices":[6,7,8,10],"distance":3.0},{"weapon":&"siege_launcher","indices":[13,14,15],"distance":6.0}]
	for phase in phases:
		for index in phase.indices:
			perf_phase=String(phase.weapon)+("-first" if index==phase.indices[0] else "-warm-%d"%int(index))
			app.player.global_position=Vector3(0,.87,5.5+phase.distance)
			var enemy: Node3D=target_at(index,Vector3(0,.87,5.5)); await frames(2)
			var before_kills: int=app.combat.kills
			await accepted_shot(enemy,phase.weapon)
			check(enemy.dead and enemy.gibbed and app.combat.kills==before_kills+1,"full-health actual rupture owns one kill "+String(phase.weapon))
			var current_gore: Node3D=app.combat.gore
			check(current_gore.death_records.get(enemy.target_id,{}).get("part_count",0)==12,"species12 rupture pieces "+String(phase.weapon))
			check(count("enemy_death",enemy.target_id)==1,"one resolved death event "+String(phase.weapon))
			if index==0: await pause_and_mute()
			if index==phase.indices[0]:
				await snapshot(String(phase.weapon)+"-burst-00")
				for tick in [6,12,18]: await frames(6); await snapshot(String(phase.weapon)+"-burst-%02d"%tick)
	# One actual swept Siege explosion against4 full-health authored scientists
	# meaningfully pressures the finite particle budget without synthetic events.
	perf_phase="siege-crowd-four-scientists-cold-staff-chunks"
	app.player.global_position=Vector3(0,.87,11.5)
	var crowd := []
	for pair in [[9,Vector3(0,.87,5.5)],[12,Vector3(1.1,.87,5.5)],[22,Vector3(-1.1,.87,5.5)],[25,Vector3(0,.87,4.4)]]: crowd.append(target_at(pair[0],pair[1]))
	await frames(2); await accepted_shot(crowd[0],&"siege_launcher"); await frames(3)
	for enemy in crowd: check(enemy.dead and enemy.gibbed,"one real Siege blast ruptures authored full-health scientist "+String(enemy.target_id))
	gore=app.combat.gore
	check(gore.particles.size()<=256,"real multi-death Siege burst obeys flying budget")
	observations.append({"accepted_shots":count("shot"),"resolved_deaths":count("enemy_death"),"kills":app.combat.kills,"crowd_particle_count":gore.particles.size(),"scope":"Real accepted shots, corpse query contacts and swept Siege projectiles. Authored actors repositioned into declared intake centre-lane/crowd fixtures; AI/player physics frozen, combat/gore/projectile clocks live."})
	await snapshot("siege-heavy-live"); perf_phase="mass-settlement-after-final48chunks"; await frames(260); check_settled(); measuring=false
	for metric in ["wall_frame_ms","process_cpu_ms","physics_cpu_ms"]:
		var values := []
		for frame in frame_metrics: values.append(frame[metric])
		values.sort()
		if not values.is_empty(): observations.append({"performance_metric":metric,"samples":values.size(),"p50":values[int(values.size()*.5)],"p95":values[mini(values.size()-1,int(values.size()*.95))],"maximum":values.back(),"scope":"Actual Main heavy live-shot/cosmetic interval at60FPS cap; CPU monitors and frame-wall intervals, not GPU timing or comparative baseline."})
	var phase_names := {}
	for frame in frame_metrics: phase_names[frame.phase]=true
	for phase in phase_names:
		var detail := {"performance_phase":phase}
		for metric in ["wall_frame_ms","process_cpu_ms","physics_cpu_ms"]:
			var values := []
			for frame in frame_metrics:
				if frame.phase==phase: values.append(frame[metric])
			values.sort()
			detail[metric]={"samples":values.size(),"p50":values[int(values.size()*.5)],"p95":values[mini(values.size()-1,int(values.size()*.95))],"maximum":values.back()}
		observations.append(detail)
	var spikes := frame_metrics.duplicate(); spikes.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.wall_frame_ms>b.wall_frame_ms)
	observations.append({"largest_wall_frames":spikes.slice(0,mini(spikes.size(),12)),"scope":"Process-frame phase tags bracket real callback work; TIME_* CPU monitors may report prior frame. Exact synchronous try_fire and event timestamps separately identify construction."})
	app.player.global_position=Vector3(3,.87,8); app.player.camera.look_at(Vector3(0,.15,5.5)); await snapshot("heavy-settled-side")
	app.player.global_position=Vector3(1.4,-.1,7.3); app.player.camera.look_at(Vector3(0,.12,5.5)); await snapshot("heavy-settled-low-angle")
	await support_geometry()
	var old: Node=app.combat.gore; app.restart_combat(); freeze_actors(); await frames(3)
	check(not is_instance_valid(old),"Retry destroys old gore owner")
	gore=app.combat.gore
	check(gore.particles.is_empty() and gore.stains.is_empty() and gore.remains.is_empty() and gore.seen.is_empty() and gore.death_records.is_empty() and gore.death_count==0,"Retry resets all gore nodes/dedup/death records")
	check(app.combat.total_enemies==36 and app.combat.kills==0 and app.world.dead_ids.is_empty(),"Retry preserves36 authored actors and clears gameplay deaths")
	var trace := []
	for event in normal_events+events:
		if String(event.get("type","")) in ["shot","enemy_death","ordnance_explosion","corpse_gib"]: trace.append({"type":event.type,"shot_id":event.get("shot_id",0),"target_id":event.get("target_id",""),"observed_usec":event.qa_observed_usec,"phase":event.qa_phase})
	var report := {"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"observations":observations,"resolved_event_trace":trace,"captures":captures,"capture_records":capture_records,"scope":"Controlled actual Main Intake real accepted hitscan/projectile shots. Player and authored actors repositioned, AI/world movement frozen, real combat/gore clocks and unchanged damage resources. Native cosmetic geometry/pause/mute/Retry; no player traversal, subjective art/listening or unchanged-performance claim."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	app.combat_audio.stop_all(); app.menu_music.stop(); app.menu_music.stream=null; await create_timer(.3,true).timeout
	app.queue_free(); app=null; await frames(3)
	preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear(); preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	await frames(3); print("GORE_V12 ",report.status," ",checks," ",failures); call_deferred("quit",0 if failures.is_empty() else 1)
