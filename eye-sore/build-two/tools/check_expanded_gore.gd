extends SceneTree
## Actual accepted weapon shots, query ownership, world occlusion, saturation and lifecycle.
var arena: Node3D
var combat: Node3D
var player: CharacterBody3D
var events: Array[Dictionary] = []
var failures: Array[String] = []
var evidence: Dictionary = {}
var cap := 60
var evidence_dir := "res://verification/expansion-v1/gore"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--gore-fps="): cap = int(argument.trim_prefix("--gore-fps="))
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	Engine.max_fps = cap
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label); push_error(label)

func block(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size; shape.shape = box
	body.add_child(shape); arena.add_child(body); body.position = position
	var visible := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size; visible.mesh = mesh; body.add_child(visible)
	return body

func aim_opaque(enemy: CharacterBody3D) -> Vector3:
	enemy.update_sprite()
	if not is_instance_valid(enemy.sprite): return enemy.global_position
	var sprite: Sprite3D = enemy.sprite
	var image := sprite.texture.get_image()
	if image.is_compressed(): image.decompress()
	var size := Vector2i(image.get_width()/sprite.hframes,image.get_height()/sprite.vframes)
	var origin := Vector2i(sprite.frame % sprite.hframes,sprite.frame/sprite.hframes) * size
	var best := Vector2(size.x*.5,size.y*.55); var distance := INF
	for y in range(0,size.y,3):
		for x in range(0,size.x,3):
			if image.get_pixelv(origin+Vector2i(x,y)).a < .9: continue
			var candidate := Vector2(x+.5,y+.5)
			var metric := candidate.distance_squared_to(Vector2(size.x*.5,size.y*.55))
			if metric < distance: distance = metric; best = candidate
	return enemy.sprite_pivot.to_global(Vector3((best.x-enemy.sprite_foot.x)*sprite.pixel_size,(enemy.sprite_foot.y-best.y)*sprite.pixel_size,0))

func fire(enemy: CharacterBody3D, weapon: StringName) -> void:
	combat.currentweapon = weapon; combat.weapon_phase = &"idle"; combat.cooldown = 0
	player.get_node("Camera3D").look_at(aim_opaque(enemy))
	await physics_frame; await physics_frame
	check(combat.try_fire(),"accepted shot " + String(weapon))

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame; await process_frame
	root.get_texture().get_image().save_png(evidence_dir.path_join("%s-%d.png" % [label,cap]))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	if DisplayServer.get_name() != "headless": root.set_flag(Window.FLAG_NO_FOCUS,true)
	arena = Node3D.new(); root.add_child(arena)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55,-25,0); light.light_energy = .8; arena.add_child(light)
	var markers := Node3D.new(); markers.name = "EnemySpawns"; arena.add_child(markers)
	block(Vector3(0,-.25,0),Vector3(28,.5,28))
	block(Vector3(0,1.7,-4),Vector3(12,3.4,.4))
	for step in 4: block(Vector3(6,.125*step,2-step*.75),Vector3(2,.25*(step+1),.75))
	player = CharacterBody3D.new(); player.collision_layer = 2
	var camera := Camera3D.new(); camera.name = "Camera3D"; player.add_child(camera); arena.add_child(player)
	player.position = Vector3(0,1.5,5); camera.current = true
	combat = preload("res://scripts/combat.gd").new(); arena.add_child(combat); combat.setup(arena,player); combat.set_physics_process(false)
	combat.combat_event.connect(func(event: Dictionary) -> void: events.append(event.duplicate(true)))
	# Optional per-kind resource and rectangular region adapter uses the original texture.
	var source: Texture2D = combat.gore.profile.remains
	combat.gore.profile.species_atlases["atlas_fixture"] = {"texture":source,"regions":{"head":Rect2(0,0,source.get_width()/4.0,source.get_height()/2.0)},"parts":[{"name":"head","material":"flesh","size":Vector2(.4,.5),"tint":Color.WHITE}]}
	var first_spec: Dictionary = combat.gore.part_spec("atlas_fixture",0,true)
	var second_spec: Dictionary = combat.gore.part_spec("atlas_fixture",0,true)
	check(first_spec.texture is AtlasTexture and first_spec.texture == second_spec.texture and first_spec.columns == 1 and first_spec.rows == 1,"per-kind region adapter caches one original cropped resource")
	check(first_spec.name == "head" and first_spec.tint == Color.WHITE,"authored anatomical descriptor preserves tint")
	combat.gore.profile.species_atlases.erase("atlas_fixture")
	evidence.atlas_adapter = {"per_kind_texture":true,"rectangular_regions":true,"bounded_cache":true,"fallback_original_texture":true}
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json"))
	var authored_parts: Dictionary = {}
	for kind in ["unsealed","vessel","ironbound","censer","reaver","surveyor"]:
		check(manifest.enemies.has(kind),"all six actual native sprite atlases registered")
		var atlas: Dictionary = combat.gore.profile.species_atlases.get(kind,{})
		check(atlas.get("parts",[]).size() == combat.gore.profile.gib_counts[kind],"authored species fragment array length " + kind)
		var heads := 0
		for i in atlas.get("parts",[]).size():
			var spec: Dictionary = combat.gore.part_spec(kind,i,true)
			if spec.name == "head": heads += 1
			check(spec.tint == Color.WHITE,"original painted part tint preserved " + kind)
			if i < 3: check(spec.name != "head","intact body sheds tissue before full gib " + kind)
		check(heads == 1,"one species-appropriate authored head " + kind)
		authored_parts[kind] = {"native_atlas":atlas.texture.resource_path,"part_count":atlas.parts.size(),"heads":heads}
	evidence.authored_parts = authored_parts
	player.position = Vector3(0,1.5,5)
	var corpse: CharacterBody3D = combat.spawn_enemy(&"unsealed",Vector3(0,.85,0))
	corpse.set_physics_process(false)
	var data: Dictionary = manifest.enemies.unsealed
	corpse.configure_sprite_sheet(data.file,data.columns,data.directions,{},data.pixel_size,Vector2(data.foot_pivot[0],data.foot_pivot[1]),data.sprite_options)
	corpse.health = 20; combat.total_enemies = 6
	await fire(corpse,&"pistol")
	check(corpse.dead and not corpse.gibbed,"pistol leaves intact visible corpse")
	corpse.state_time = 1; corpse.update_presentation()
	await physics_frame; await physics_frame
	for body in corpse.hurt_shapes: check(body.collision_layer == 0,"dead live hurt layer disabled")
	check(not corpse.corpse_shapes.is_empty(),"visible corpse has separate cosmetic shapes")
	for body in corpse.corpse_shapes: check(body.collision_layer == 8 and body.collision_mask == 0,"corpse query is layer8 only")
	var point := aim_opaque(corpse)
	check(combat.ray(camera.global_position,point-camera.global_basis.z*.1,[],true).get("collider",null) != null,"weapon ray can query corpse")
	check(combat.ray(camera.global_position,point,[]).is_empty(),"AI/projectile ray cannot query corpse")
	await snapshot("intact-corpse")
	var integrity: float = corpse.corpse_integrity
	var barrier := block((camera.global_position+point)*.5,Vector3(3,3,.25))
	await fire(corpse,&"pistol")
	check(corpse.corpse_integrity == integrity,"world wall blocks corpse shot first")
	barrier.collision_layer = 0; barrier.queue_free()
	await physics_frame
	await fire(corpse,&"pistol")
	check(corpse.corpse_integrity < integrity and not corpse.gibbed,"actual pistol damages cosmetic integrity only")
	await fire(corpse,&"shotgun")
	check(corpse.gibbed and not corpse.sprite.visible and corpse.corpse_shapes.is_empty(),"shotgun breaks corpse and removes queries")
	check(combat.kills == 1 and combat.gore.death_count == 1,"corpse shots never increment kills/deaths")
	var corpse_gibs := 0; var corpse_hurts := 0
	for event in events:
		if event.type == &"corpse_gib": corpse_gibs += 1
		if event.type == &"corpse_hurt": corpse_hurts += 1
	check(corpse_gibs == 1 and corpse_hurts == 1,"shotgun pellet contacts aggregate to one corpse event")
	await snapshot("corpse-burst")
	var prior_parts: int = combat.gore.death_records[corpse.target_id].part_count
	await fire(corpse,&"shotgun")
	check(combat.gore.death_records[corpse.target_id].part_count == prior_parts,"fully gibbed cannot repeat bursts")
	evidence.corpse = {"kills":combat.kills,"deaths":combat.gore.death_count,"corpse_hurt":corpse_hurts,"corpse_gib":corpse_gibs,"parts_after_break":prior_parts,"world_blocks":true,"live_queries_disabled":true}
	var species: Dictionary = {}
	var corpse_species: Dictionary = {"unsealed":{"actual_weapon_break":true,"query_removed":true}}
	for kind in ["vessel","ironbound","censer","reaver","surveyor"]:
		var enemy: CharacterBody3D = combat.spawn_enemy(StringName(kind),Vector3(0,.85,0)); enemy.set_physics_process(false); enemy.health = 1
		var art: Dictionary = manifest.enemies[kind]
		enemy.rotation.y = PI
		enemy.configure_sprite_sheet(art.file,art.columns,art.directions,{},art.pixel_size,Vector2(art.foot_pivot[0],art.foot_pivot[1]),art.sprite_options)
		player.position = Vector3(0,1.5,1.8)
		await fire(enemy,&"shotgun")
		check(enemy.dead and enemy.gibbed,"actual shotgun gib " + kind)
		var record: Dictionary = combat.gore.death_records.get(enemy.target_id,{})
		check(record.get("part_count",0) == combat.gore.profile.gib_counts[kind],"species part count " + kind)
		check(enemy.corpse_shapes.is_empty(),"immediate gib has no corpse query " + kind)
		for tick in 6: await physics_frame
		await snapshot("species-burst-"+kind)
		species[kind] = record.get("part_count",0)
		# The actual final native corpse alpha is also queried by accepted shots.
		var body: CharacterBody3D = combat.spawn_enemy(StringName(kind),Vector3(4,.85,0))
		body.set_physics_process(false); body.rotation.y = PI; body.health = 20
		body.configure_sprite_sheet(art.file,art.columns,art.directions,{},art.pixel_size,Vector2(art.foot_pivot[0],art.foot_pivot[1]),art.sprite_options)
		player.position = Vector3(4,1.5,1.8)
		await fire(body,&"pistol")
		body.state_time = 1; body.update_presentation()
		check(body.dead and not body.gibbed and not body.corpse_shapes.is_empty(),"actual pistol leaves final native cosmetic corpse " + kind)
		var prior_kills: int = combat.kills; var prior_deaths: int = combat.gore.death_count
		var corpse_shots := 0
		while not body.gibbed and corpse_shots < 6:
			await fire(body,&"shotgun"); corpse_shots += 1
		check(body.gibbed and body.corpse_shapes.is_empty() and not body.sprite.visible,"accepted shotgun breaks actual native corpse alpha " + kind)
		check(combat.kills == prior_kills and combat.gore.death_count == prior_deaths,"species corpse has no extra live kill/death " + kind)
		var breaks := 0
		for event in events:
			if event.type == &"corpse_gib" and event.target_id == body.target_id: breaks += 1
		check(breaks == 1,"one cosmetic species corpse transition " + kind)
		corpse_species[kind] = {"native_final_frame":body.sprite_frame,"actual_weapon_break":body.gibbed,"query_removed":body.corpse_shapes.is_empty(),"shotguns_to_break":corpse_shots,"extra_kills":combat.kills-prior_kills,"corpse_gib_events":breaks}
		await snapshot("species-corpse-burst-"+kind)
	evidence.species = species
	evidence.all_native_corpses = corpse_species
	var start_draw := Engine.get_frames_drawn(); var start_time := Time.get_ticks_usec()
	for tick in 240: await physics_frame
	check(combat.gore.particles.is_empty(),"all tumbling parts settle within four seconds")
	var anatomical_names: Dictionary = {}
	var settled_signature: Array[String] = []
	for piece in combat.gore.remains:
		check(piece.get_meta("settled",false),"piece settled surface metadata")
		anatomical_names[piece.get_meta("anatomical_part","")] = true
		var at: Vector3 = piece.global_position
		settled_signature.append("%s:%s:%.3f:%.3f:%.3f" % [piece.get_meta("anatomical_part",""),piece.get_meta("cell",0),at.x,at.y,at.z])
	check(anatomical_names.size() >= 8,"anatomical and species hardware variety")
	settled_signature.sort()
	await snapshot("settled-parts")
	evidence.cadence = {"render_cap":cap,"physics_ticks":240,"rendered_frames":Engine.get_frames_drawn()-start_draw,"elapsed_seconds":(Time.get_ticks_usec()-start_time)/1000000.0,"settled_parts":combat.gore.remains.size(),"anatomical_names":anatomical_names.keys(),"settled_signature":JSON.stringify(settled_signature).sha256_text()}
	# A real wall fan and unsupported/stair-clipped patches.
	var rng := RandomNumberGenerator.new(); rng.seed = 441
	var before: int = combat.gore.stains.size(); combat.gore.spatter_behind(Vector3(0,1,-2),Vector3.FORWARD,.6,rng)
	check(combat.gore.stains.size() > before,"directional fan reaches real wall")
	check(combat.gore.surface_patch(Vector3(80,0,0),Vector3.UP,Vector2.ONE,combat.gore.profile.pools,2,2,0,4,0,false) == null,"unsupported stain rejected")
	var patch: MeshInstance3D = combat.gore.surface_patch(Vector3(6,.5,.5),Vector3.UP,Vector2(2,2),combat.gore.profile.pools,2,2,0,9,0,false)
	check(is_instance_valid(patch),"stair patch generated")
	if is_instance_valid(patch):
		var vertices: PackedVector3Array = patch.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(0,vertices.size(),3): check(absf(vertices[i].y-vertices[i+1].y)<.025 and absf(vertices[i].y-vertices[i+2].y)<.025,"stain triangles do not bridge stair risers")
	# Saturation at 44 deaths stays within published budgets.
	for i in 44:
		combat.gore.handle_event({"type":"enemy_death","target_id":"budget_%d"%i,"shot_id":1000+i,"weapon_id":"shotgun","enemy_kind":"censer","gibbed":true,"position":Vector3(0,.85,0),"direction":Vector3.FORWARD})
	check(combat.gore.particles.size() <= combat.gore.profile.max_particles,"active particle saturation bound")
	for tick in 240: await physics_frame
	check(combat.gore.remains.size() <= combat.gore.profile.max_remains and combat.gore.stains.size() <= combat.gore.profile.max_stains,"44-death settled/stain budget bound")
	combat.gore.burst(Vector3(0,1,0),Vector3.FORWARD,12,rng)
	var positions: Array[Vector3] = []
	for particle in combat.gore.particles: positions.append(particle.node.position)
	paused = true; await create_timer(.2,true).timeout
	for i in positions.size(): check(combat.gore.particles[i].node.position == positions[i],"pause freezes cosmetic physics")
	paused = false
	combat.reset()
	check(combat.gore.particles.is_empty() and combat.gore.stains.is_empty() and combat.gore.remains.is_empty() and combat.gore.death_records.is_empty(),"retry clears gore owner collections")
	check(combat.gore.material_cache.is_empty() and combat.gore.part_texture_cache.is_empty(),"retry clears bounded region/material caches")
	await physics_frame; await physics_frame
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,Vector3(0,0,0),8)
	check(arena.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"retry leaves no cosmetic query colliders")
	evidence.lifecycle = {"pause_frozen":true,"retry_no_queries":true,"saturation_particles":combat.gore.profile.max_particles,"saturation_remains":combat.gore.profile.max_remains,"saturation_stains":combat.gore.profile.max_stains}
	evidence.failures = failures
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var file := FileAccess.open(evidence_dir.path_join("contract-%d.json"%cap),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(evidence,"  ")); file.close()
	print("EXPANDED_GORE_CHECK_", "OK" if failures.is_empty() else "FAILED", " ", JSON.stringify(evidence))
	arena.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
