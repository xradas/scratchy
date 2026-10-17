extends SceneTree
## Cosmetic integration fixture using actual Combat events, profile and chunk helper.
const DT := 1.0/60.0
const Chunk := preload("res://scripts/gore_chunk_v12.gd")
var world: Node3D
var player: CharacterBody3D
var combat: Node3D
var gore: Node3D
var results: Array[Dictionary] = []
var failures := 0
var shot_id := 0
var species_results: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String, detail: Dictionary = {}) -> void:
	results.append({"check":label,"passed":ok,"detail":detail})
	if not ok: failures+=1; push_error(label+": "+JSON.stringify(detail))
func solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new();world.add_child(body);body.position=at
	var node := CollisionShape3D.new();var shape := BoxShape3D.new();shape.size=size;node.shape=shape;body.add_child(node)
	return body
func clean() -> void:
	gore.reset()
	for enemy in combat.enemies:
		if is_instance_valid(enemy): enemy.collision_layer=0;enemy.queue_free()
	combat.enemies.clear();combat.kills=0;combat.dead=false;combat.health=100;combat.armor=50
	await physics_frame;await physics_frame
func advance(count: int) -> void:
	for n in count: gore._physics_process(DT);await physics_frame
func fixture_event(weapon: String, material: String = "flesh") -> Dictionary:
	shot_id+=1
	return {"type":"enemy_hurt","target_id":"fixture_"+str(shot_id),"shot_id":shot_id,"weapon_id":weapon,"material":material,"position":Vector3(0,1.2,0),"direction":Vector3(0,.08,-1).normalized()}
func run() -> void:
	root.size=Vector2i(960,540)
	world=Node3D.new();root.add_child(world)
	var markers:=Node3D.new();markers.name="EnemySpawns";world.add_child(markers)
	solid(Vector3(0,-.5,0),Vector3(70,1,70))
	player=CharacterBody3D.new();world.add_child(player);player.position=Vector3(0,.87,5)
	var cam:=Camera3D.new();cam.name="Camera3D";cam.position.y=.4;player.add_child(cam);cam.current=true
	combat=load("res://scripts/combat.gd").new();world.add_child(combat);combat.setup(world,player);combat.set_physics_process(false)
	gore=combat.gore;gore.set_physics_process(false)
	await physics_frame;await physics_frame
	var expected_hurt:={"pistol":16,"shotgun":36,"twin_shotgun":52,"rivet_cannon":24,"siege_launcher":64,"melee":12}
	var expected_death:={"pistol":26,"shotgun":56,"twin_shotgun":72,"rivet_cannon":38,"siege_launcher":80,"melee":22}
	for weapon in expected_hurt:
		await clean()
		var event:=fixture_event(weapon)
		gore.handle_event(event)
		var along:=0.0
		for p in gore.particles: along+=(p.velocity as Vector3).normalized().dot(event.direction)
		along/=maxi(1,gore.particles.size())
		check(gore.particles.size()==expected_hurt[weapon],weapon+" explicit flesh count")
		check(along>.65,weapon+" stronger spray follows authoritative contact direction",{"mean_direction_dot":along})
		var count:int=gore.particles.size();gore.handle_event(event)
		check(gore.particles.size()==count,weapon+" duplicate event produces no extra gore")
		var splats:=0
		for p in gore.particles:
			if p.splat:splats+=1
		check(splats<=6,weapon+" drop stain work bounded per burst")
		await clean();gore.handle_event(fixture_event(weapon,"armor"))
		var blood:=false
		for p in gore.particles: blood= blood or p.blood
		check(gore.particles.size()==gore.profile.spark_counts[weapon] and not blood,weapon+" armor contact sparks without blood")
		await clean()
		var enemy:CharacterBody3D=combat.spawn_enemy(&"unsealed",Vector3(0,.87,0));enemy.set_physics_process(false)
		shot_id+=1;enemy.apply_damage(enemy.health,shot_id,StringName(weapon),enemy.position)
		var record:Dictionary=gore.death_records[enemy.target_id]
		check(enemy.dead and not enemy.gibbed and record.part_count==0 and gore.remains.is_empty(),weapon+" ordinary death leaves corpse without bodypieces")
		check(gore.particles.size()==expected_death[weapon] and combat.kills==1,weapon+" ordinary death explicit count and one kill")
		var saved:float=combat.health;var kills:int=combat.kills
		await advance(2)
		check(combat.health==saved and combat.kills==kills,weapon+" cosmetic update changes no gameplay")

	# Use actual Combat splash aggregation: one explosion event precedes both
	# resolved enemy hurt events. The camera faces-Z while victims sit on±X.
	await clean()
	var left:CharacterBody3D=combat.spawn_enemy(&"unsealed",Vector3(-1.2,.87,0));left.set_physics_process(false);left.health=1000
	var right:CharacterBody3D=combat.spawn_enemy(&"unsealed",Vector3(1.2,.87,0));right.set_physics_process(false);right.health=1000
	await physics_frame;await physics_frame
	shot_id+=1;var origin:=Vector3(0,.87,0)
	combat.resolve_ordnance_explosion(combat.weapons[&"siege_launcher"],origin,null,&"hard",shot_id)
	var left_count:=0;var right_count:=0;var left_bias:=0.0;var right_bias:=0.0
	for p in gore.particles:
		if p.node.position.x<0:left_count+=1;left_bias+=(p.velocity as Vector3).normalized().dot(Vector3.LEFT)
		else:right_count+=1;right_bias+=(p.velocity as Vector3).normalized().dot(Vector3.RIGHT)
	check(left.health<1000 and right.health<1000 and left_count==64 and right_count==64,"actual single Siege splash resolves two outward flesh bursts")
	check(left_bias/maxi(1,left_count)>.7 and right_bias/maxi(1,right_count)>.7,"side-by-side splash fans point away from actual same explosion origin",{"left_mean_outward":left_bias/maxi(1,left_count),"right_mean_outward":right_bias/maxi(1,right_count)})
	for index in 40:gore.handle_event({"type":"ordnance_explosion","shot_id":10000+index,"position":Vector3(index,1,0)})
	check(gore.explosion_origins.size()==32,"cosmetic explosion origin cache bounded32")
	await clean();check(gore.explosion_origins.is_empty(),"reset clears cosmetic explosion origins")

	for kind in gore.profile.species_atlases:
		await clean()
		var enemy:CharacterBody3D=combat.spawn_enemy(StringName(kind),Vector3(0,.87,0));enemy.set_physics_process(false)
		shot_id+=1;enemy.apply_damage(enemy.health+100,shot_id,&"shotgun",enemy.position)
		var expected:int=gore.profile.gib_counts[kind]
		var parts:=0;var full_volume:=true;var no_colliders:=true
		var positions:Array[Vector3]=[];var nodes:Array[MeshInstance3D]=[]
		for p in gore.particles:
			if not p.gib:continue
			parts+=1;var node:MeshInstance3D=p.node;nodes.append(node);positions.append(node.position)
			var size:=node.mesh.get_aabb().size
			full_volume=full_volume and node.get_meta("mesh_closed",false) and size.x>.01 and size.y>.01 and size.z>.01
			no_colliders=no_colliders and node.find_children("*","CollisionObject3D",true,false).is_empty()
		check(enemy.gibbed and parts==expected and full_volume,kind+" rupture owns explicit closed-volume bodypieces",{"parts":parts,"expected":expected})
		check(no_colliders,kind+" cosmetic chunks have no actor colliders")
		paused=true;await advance(4)
		var unchanged:=true
		for i in nodes.size():unchanged=unchanged and nodes[i].position==positions[i]
		check(unchanged,kind+" pause freezes exact chunk transforms")
		paused=false
		await advance(240)
		check(gore.particles.is_empty() and gore.remains.size()==expected,kind+" all rupture chunks settle on actual flat support before4seconds",{"settled":gore.remains.size(),"expected":expected,"flying":gore.particles.size()})
		var identical:=true
		for node in gore.remains: identical=identical and node in nodes and node.get_meta("settled",false) and node.mesh.get_aabb().size.z>.01
		check(identical,kind+" settled volume retains same flying MeshInstance")
		species_results.append({"kind":kind,"parts":parts,"settled":gore.remains.size()})

	await clean()
	var enemy:CharacterBody3D=combat.spawn_enemy(&"infected_scientist",Vector3(0,.87,0));enemy.set_physics_process(false)
	shot_id+=1;enemy.apply_damage(enemy.health,shot_id,&"pistol",enemy.position)
	var original_kills:int=combat.kills;var integrity:float=enemy.corpse_integrity
	shot_id+=1;enemy.apply_corpse_damage(integrity,shot_id,&"shotgun",enemy.position)
	var record:Dictionary=gore.death_records[enemy.target_id]
	check(enemy.gibbed and combat.kills==original_kills and gore.death_count==1 and record.corpse_bursts==1,"postmortem rupture keeps integrity/kill/death ownership")
	var before:int=gore.particles.size();enemy.apply_corpse_damage(100,shot_id,&"shotgun",enemy.position)
	check(gore.particles.size()==before,"postmortem duplicate cannot duplicate burst")
	gore.reset()
	check(gore.particles.is_empty() and gore.stains.is_empty() and gore.remains.is_empty() and gore.seen.is_empty() and gore.death_records.is_empty() and gore.death_count==0,"reset clears every cosmetic owner and dedupe")
	for i in 24:gore.handle_event(fixture_event("siege_launcher"))
	check(gore.particles.size()<=256 and gore.stains.size()<=384 and gore.remains.size()<=128,"crowded volleys obey exact node caps")
	var node_count:=gore.get_child_count()
	await process_frame;await process_frame
	check(gore.get_child_count()<=gore.profile.max_particles+gore.profile.max_stains+gore.profile.max_remains,"deferred eviction leaves bounded resident nodes",{"before_flush":node_count,"after_flush":gore.get_child_count()})
	# Saturated cosmetic workload on the native renderer, with sustained resolved
	# flesh bursts and existing support pieces. Timings isolate physics CPU cost;
	# coordinator actualMain captures assess complete encounter render cadence.
	var samples: Array[float] = []
	var max_live: int = gore.particles.size()
	var started := Time.get_ticks_usec();var start_frames := Engine.get_frames_drawn()
	for frame in 60:
		if frame%6==0:gore.handle_event(fixture_event("siege_launcher"))
		max_live=maxi(max_live,gore.particles.size())
		var tick_start := Time.get_ticks_usec()
		gore._physics_process(DT)
		samples.append((Time.get_ticks_usec()-tick_start)/1000.0)
		await physics_frame
	var elapsed := (Time.get_ticks_usec()-started)/1000000.0
	samples.sort()
	var perf := {"scope":"60 production gore ticks; initial256drops then sustained64drop Siege flesh burst every6ticks; native window960x540 when available. Cosmetic physics timing excludes event creation and completeMain scene.","physics_ticks":60,"peak_live_particles":max_live,"physics_cpu_ms_p50":samples[30],"physics_cpu_ms_p95":samples[57],"physics_cpu_ms_max":samples[59],"elapsed_seconds":elapsed,"rendered_frames":Engine.get_frames_drawn()-start_frames,"mesh_cache":Chunk.cache_state()}
	check(max_live<=256 and perf.mesh_cache.spheres<=96,"saturated burst sweep shapes and nodes remain bounded",perf)
	gore.reset();await process_frame
	var suffix:="headless" if DisplayServer.get_name()=="headless" else "native"
	var folder:="res://verification/production-v12/bursts";DirAccess.make_dir_recursive_absolute(folder)
	var report:={"schema_version":12,"fixture":"Production Combat.apply_damage/corpse_damage -> actual gore profile/helper; real shared flat support; controlled60Hz. Root independent actualMain/native stairs validation separate.","checks":results,"failed":failures,"species":species_results,"renderer":RenderingServer.get_current_rendering_method(),"performance":perf}
	var file:=FileAccess.open(folder+"/runtime-"+suffix+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("BURSTS_V12 checks=%d failures=%d"%[results.size(),failures])
	quit(1 if failures>0 else 0)
