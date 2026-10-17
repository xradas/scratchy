extends SceneTree
## Independent actual Main placement, ownership and native resource fixture.
var app: Control
var expected: Dictionary
var output := ""
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
func find_flicker(node: Node) -> CheckButton:
	if node is CheckButton and node.text=="Damaged light flicker": return node
	for child in node.get_children():
		var found := find_flicker(child)
		if found!=null: return found
	return null
func world_lights() -> Array:
	var result := []
	for fixture in get_nodes_in_group("intake_lighting_v11"):
		if app.world.is_ancestor_of(fixture): result.append(fixture)
	return result
func lighting_checks() -> void:
	var fixtures := world_lights(); var toggle := find_flicker(app)
	check(fixtures.size()==56,"actual Main56 mounted fixture components")
	check(toggle!=null,"actual accessibility flicker checkbox exists")
	if toggle==null: return
	toggle.button_pressed=false
	check(not app.light_flicker_enabled,"actual checkbox updates Main flicker flag")
	var config := ConfigFile.new()
	check(config.load(app.SETTINGS_PATH)==OK and config.get_value("display","light_flicker",true)==false,"flicker false persisted to temporary user profile")
	app.light_flicker_enabled=true; app.load_settings()
	check(not app.light_flicker_enabled,"Main loads persisted flicker false")
	for fixture in fixtures:
		var state: Dictionary=fixture.lighting_state()
		check(not state.enabled and is_equal_approx(float(state.factor),1.0),"actual group binding immediately steady "+String(fixture.name))
	toggle.button_pressed=true
	await frames(3)
	var prior := []
	for fixture in fixtures: prior.append(fixture.lighting_state().elapsed)
	app.set_paused(true); await create_timer(.12,true).timeout
	for i in fixtures.size(): check(fixtures[i].lighting_state().elapsed==prior[i],"actual Main pause freezes light phase "+String(fixtures[i].name))
	app.set_paused(false); toggle.button_pressed=false
	observations.append({"actual_mounted_lights":fixtures.size(),"flicker_persisted":false,"profile_isolation":"Temporary XDG_DATA_HOME supplied by checker wrapper"})
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected="): expected = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--expected=")))
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("STAFF_V11: "+label)
func frames(n: int) -> void:
	for i in n: await physics_frame
func vector(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
func arena_counts_match() -> bool:
	if app.world.arena_remaining.size()!=expected.arena_counts.size(): return false
	for arena in expected.arena_counts:
		if not app.world.arena_remaining.has(arena) or int(app.world.arena_remaining[arena])!=int(expected.arena_counts[arena]): return false
	return true
func freeze() -> void:
	app.player.set_physics_process(false); app.combat.set_physics_process(false); app.world.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
func native_audio() -> void:
	var before: Resource = load(expected.baseline_profile_path)
	var current: Resource = load("res://resources/combat_audio.tres")
	var old := {}; var actual := {}
	for cue in before.cues: old[String(cue.identifier)] = cue
	for cue in current.cues: actual[String(cue.identifier)] = cue
	check(old.size()==57 and actual.size()==63,"57 original native cue objects plus6 voice aliases")
	for id in actual:
		var original: Resource = old[expected.aliases[id]] if expected.aliases.has(id) else old.get(id)
		check(original!=null,"known native cue "+id)
		if original==null: continue
		var cue: Resource = actual[id]
		check(cue.bus==original.bus and cue.gain_db==original.gain_db and cue.spatial==original.spatial,"native cue properties preserved/reused "+id)
		var paths := []; var prior := []
		for stream in cue.variations: paths.append(stream.resource_path)
		for stream in original.variations: prior.append(stream.resource_path)
		check(paths==prior,"native exact original stream family "+id)
	check(current.music.resource_path==before.music.resource_path and current.music_gain_db==before.music_gain_db,"native music registration/gain preserved")
func frame_checks() -> void:
	for selected_index in [9,2]:
		var enemy: Node3D=app.combat.enemies[selected_index]
		var original_rotation: Vector3=enemy.rotation
		var original_player: Vector3=app.player.global_position
		app.player.global_position=enemy.global_position+Vector3(0,0,3)
		var image: Image=enemy.sprite_source_texture.get_image()
		if image.is_compressed(): image.decompress()
		var visited := {}; var material_hits := {}; var flash_probes := 0
		for direction in 8:
			enemy.rotation.y=PI-float(direction)*TAU/8
			for column in 8:
				enemy.state=&"chase"; enemy.state_time=float(column)/8
				if column==3: enemy.state=&"windup"; enemy.state_time=0
				if column==4: enemy.state=&"recovery"; enemy.state_time=0
				if column==5: enemy.state=&"pain"; enemy.state_time=0
				if column>=6: enemy.state=&"dead"; enemy.state_time=0 if column==6 else .65
				enemy.update_sprite(); await physics_frame
				var frame: int=enemy.sprite_frame; var wanted := direction*8+column
				check(frame==wanted,"actual native direction/state selection %s frame%d"%[enemy.definition.identifier,wanted])
				visited[frame]=true
				var region: Rect2i=enemy.SpriteHurt.frame_region(enemy.sprite_source_texture,8,8,frame,enemy.sprite_data)
				check((enemy.sprite.texture as AtlasTexture).region==Rect2(region),"renderer exact unequal native source region frame%d"%frame)
				check(enemy.sprite_foot==enemy.foot_for_frame(frame),"per-frame measured foot pivot frame%d"%frame)
				for body in enemy.sprite_bodies.values():
					if body.collision_layer!=4 or body.get_node("HitSurface").shape==null: continue
					var faces: PackedVector3Array=body.get_node("HitSurface").shape.get_faces()
					check(not faces.is_empty(),"native active query surface frame%d"%frame)
					if faces.is_empty(): continue
					var point: Vector3=body.to_global((faces[0]+faces[1]+faces[2])/3)
					var normal: Vector3=enemy.sprite_pivot.global_basis.z
					var ray := PhysicsRayQueryParameters3D.create(point+normal*.04,point-normal*.04,4)
					var hit: Dictionary=enemy.get_world_3d().direct_space_state.intersect_ray(ray)
					check(not hit.is_empty() and hit.collider==body,"actual physics ray hits opaque %s frame%d"%[body.get_meta("hit_material"),frame])
					if not hit.is_empty(): material_hits[String(hit.collider.get_meta("hit_material"))]=true
				if selected_index==2 and column==4:
					for uv in [Vector2(.82,.12),Vector2(.9,.12),Vector2(.82,.3),Vector2(.9,.3),Vector2(.82,.45),Vector2(.9,.45)]:
						var pixel := region.position+Vector2i(Vector2(region.size)*uv)
						if image.get_pixelv(pixel).a<.5: continue
						var local := Vector3((uv.x*region.size.x-enemy.sprite_foot.x)*enemy.sprite.pixel_size,(enemy.sprite_foot.y-uv.y*region.size.y)*enemy.sprite.pixel_size,0)
						var point: Vector3=enemy.sprite_pivot.to_global(local); var normal: Vector3=enemy.sprite_pivot.global_basis.z
						var ray := PhysicsRayQueryParameters3D.create(point+normal*.04,point-normal*.04,4)
						var hit: Dictionary=enemy.get_world_3d().direct_space_state.intersect_ray(ray)
						check(hit.is_empty() or hit.collider.get_meta("combat_target",null)!=enemy,"painted flash excluded from actual physics contact frame%d"%frame)
						flash_probes+=1
		check(visited.size()==64,"all64 native state/direction frames visited "+String(enemy.definition.identifier))
		check(material_hits.has("flesh"),"native staff flesh contacts "+String(enemy.definition.identifier))
		if selected_index==2:
			check(material_hits.has("armor"),"native security armor contacts")
			check(flash_probes>0,"opaque release flash probes exercised")
		observations.append({"kind":enemy.definition.identifier,"frames_visited":visited.size(),"actual_physics_materials":material_hits.keys(),"opaque_flash_noncontact_probes":flash_probes})
		enemy.rotation=original_rotation; enemy.state=&"chase"; enemy.state_time=0; app.player.global_position=original_player; enemy.update_sprite()
func verify_roster(label: String) -> void:
	check(app.combat.enemies.size()==36 and app.combat.total_enemies==36,label+" exact36 actors")
	observations.append({"phase":label,"actual_arena_counts":app.world.arena_remaining.duplicate(),"expected_arena_counts":expected.arena_counts})
	check(arena_counts_match(),label+" original arena5/5/6 counts")
	var chosen := {}
	for item in expected.placements: chosen[int(item.index)] = item
	var markers: Node = app.world.get_node("EnemySpawns")
	for record in expected.baseline_roster:
		var index := int(record.index); var marker: Node3D = markers.get_child(index); var enemy: Node3D = app.combat.enemies[index]
		var kind: String = chosen[index].new_kind if chosen.has(index) else record.kind
		check(String(marker.name)==record.marker and marker.position.is_equal_approx(vector(record.position)),label+" marker/position "+record.marker)
		check(String(marker.get_meta("kind"))==kind and String(enemy.definition.identifier)==kind,label+" loaded actual kind "+record.marker)
		check(enemy.global_position.is_equal_approx(vector(record.position)),label+" actual actor position "+record.marker)
		check(String(enemy.get_meta("arena_id"))==record.arena_id and String(enemy.get_meta("activate_room"))==record.activate_room,label+" arena/activation metadata "+record.marker)
		check(enemy.target_id=="enemy_%s_%d"%[kind,index],label+" stable index unique derived target ID "+record.marker)
		if chosen.has(index):
			check(not enemy.awake and not enemy.dead,label+" selected actor starts asleep/alive "+record.marker)
			check(is_instance_valid(enemy.sprite) and enemy.sprite_directions==8,label+" actual8-direction staff sheet "+record.marker)
			check(not enemy.hurt_shapes.is_empty(),label+" opaque sprite hurt geometry "+record.marker)
			var ray := PhysicsRayQueryParameters3D.create(enemy.global_position,enemy.global_position+Vector3.DOWN*2,1)
			check(not enemy.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),label+" native floor below "+record.marker)
			var query := PhysicsShapeQueryParameters3D.new(); query.shape=enemy.get_node("CollisionShape3D").shape; query.transform=enemy.global_transform; query.collision_mask=1
			check(enemy.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),label+" original capsule clear of native solids "+record.marker)
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.automated_input=true; app.campaign_mode=true; app.campaign.seek("pale_ward_01"); app.stage_id="pale_ward"; app.replace_world({})
	app.campaign.entry_snapshot=app.campaign.capture(app.combat); app.enter_combat(); freeze()
	await frames(3)
	native_audio(); verify_roster("initial")
	await frame_checks()
	await lighting_checks()
	# Visit each existing staff room through the actual room activation API.
	for item in expected.placements:
		var room: Node3D=app.world.get_node("Room_"+String(item.activate_room))
		var actor: Node3D=app.combat.enemies[int(item.index)]
		app.player.global_position=room.global_position-Vector3(0,1.63,0)
		check(app.world.room_at(app.player.global_position)==item.activate_room,"authored room routing "+String(item.marker))
		app.world.update_player(app.player,app.combat)
		check(actor.awake,"existing room activation wakes staff "+String(item.marker))
		check(arena_counts_match(),"non-arena staff activation preserves arena ownership")
		observations.append({"marker":item.marker,"kind":actor.definition.identifier,"position":str(actor.global_position),"room":item.activate_room,"can_see_room_centre":actor.can_see_player(),"ranged":actor.definition.ranged,"health":actor.health})
	# The existing first cache still exclusively opens shutters before arena wake.
	var bait: Node3D
	for pickup in app.world.pickups:
		if pickup.name=="Bait_arena_one": bait=pickup
	check(bait!=null,"authored triage cache lure exists")
	if bait!=null:
		app.player.global_position=Vector3(0,-.13,-76)
		check(not app.world.is_arena_active("arena_one"),"triage arena not activated by unrelated staff room visits")
		app.world.collect(bait)
		for i in 180:
			app.world.update_player(app.player,app.combat); await physics_frame
			if app.world.is_arena_active("arena_one"): break
		check(app.world.is_arena_active("arena_one"),"actual cache shutters finish opening and wake original arena")
		for arena in expected.arena_counts:
			var members := []
			for enemy in app.combat.enemies:
				if String(enemy.get_meta("arena_id"))==arena: members.append(enemy)
			check(members.size()==int(expected.arena_counts[arena]),"unchanged live arena roster "+arena)
			if members.is_empty(): continue
			var first: Node3D=members[0]
			first.apply_damage(first.health,91000+int(first.get_instance_id()%10000),&"pistol",first.global_position)
			var remaining: int=app.world.arena_remaining[arena]
			app.world.notify_enemy_death(first.target_id)
			check(app.world.arena_remaining[arena]==remaining and remaining==members.size()-1,"duplicate actual death owns one arena decrement "+arena)
			check(not app.world.flags.get("clear_"+arena,false),"populated arena cannot clear early "+arena)
			for enemy in members.slice(1): enemy.apply_damage(enemy.health,92000+int(enemy.get_instance_id()%10000),&"pistol",enemy.global_position)
			check(app.world.arena_remaining[arena]==0 and app.world.flags.get("clear_"+arena,false),"last unique live actor clears original arena "+arena)
	var old_combat: Node=app.combat; var old_id := old_combat.get_instance_id()
	app.restart_combat(); freeze(); await frames(3)
	check(not is_instance_valid(old_combat) and app.combat.get_instance_id()!=old_id,"Retry destroys original combat ownership")
	check(app.combat.kills==0 and app.world.dead_ids.is_empty() and app.world.flags.is_empty(),"Retry resets kills, deaths and progression")
	verify_roster("Retry")
	check(not app.light_flicker_enabled,"Retry preserves persisted flicker preference")
	check(world_lights().size()==56,"Retry rebuilds56 world-owned fixtures")
	for fixture in world_lights():
		var state: Dictionary=fixture.lighting_state()
		check(not state.enabled and is_equal_approx(float(state.factor),1.0),"Retry applies steady saved setting "+String(fixture.name))
		check(float(state.elapsed)<.2,"Retry resets phase to level start "+String(fixture.name))
	var report := {"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"observations":observations,"scope":"Controlled actual Main authored Intake. Native resource/position/capsule/floor/presentation checks; actual room activation/cache shutters and real actor apply_damage/death ownership; Retry. Player repositioned, other physics frozen. No live route traversal, balance, human visual approval or listening claim."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	app.combat_audio.stop_all(); app.menu_music.stop(); app.menu_music.stream=null
	await create_timer(.3,true).timeout
	app.queue_free(); app=null
	await frames(3)
	preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear()
	preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	await frames(3)
	print("STAFF_INTAKE_V11 ",report.status," ",checks," ",failures)
	call_deferred("quit",0 if failures.is_empty() else 1)
