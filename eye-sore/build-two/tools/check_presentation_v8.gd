extends SceneTree
## External, read-only checker: runs against source OR an embedded exported PCK.
var failures: Array[String] = []
var checks := 0
var expected: Dictionary
var report_path := ""
var nodes_compared := 0
var colliders_compared := 0
var material_count := 0
var floor_rays := 0
var shots: Array[Dictionary] = []
var floor_surveys: Array[Dictionary] = []
var layouts: Array[Dictionary] = []
var app: Control

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--expected="): expected = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--expected=")))
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("PRESENTATION_V8: " + label)

func pair(a: Node, b: Node) -> void:
	nodes_compared += 1
	check(a.get_class() == b.get_class(), "native node class " + String(a.name))
	if a is Node3D: check(a.transform == b.transform, "native local transform " + String(a.name))
	if a is CollisionObject3D:
		check(a.collision_layer == b.collision_layer and a.collision_mask == b.collision_mask, "native collision layers/masks " + String(a.name))
		check(a.get_meta("hit_material", "") == b.get_meta("hit_material", ""), "native semantic hit material " + String(a.name))
	if a is MeshInstance3D:
		check(a.mesh.get_class() == b.mesh.get_class(), "native mesh type " + String(a.name))
		if a.mesh is BoxMesh: check(a.mesh.size == b.mesh.size, "native visible box dimensions")
		elif a.mesh is CylinderMesh: check(a.mesh.height == b.mesh.height and a.mesh.top_radius == b.mesh.top_radius and a.mesh.bottom_radius == b.mesh.bottom_radius, "native visible cylinder dimensions")
	if a is CollisionShape3D:
		colliders_compared += 1
		check(a.disabled == b.disabled and a.shape.get_class() == b.shape.get_class(), "native collider type/enabled")
		if a.shape is BoxShape3D: check(a.shape.size == b.shape.size, "native box collider dimensions")
		elif a.shape is ConvexPolygonShape3D: check(a.shape.points == b.shape.points, "native polygon collider vertices")
		elif a.shape is CylinderShape3D or a.shape is CapsuleShape3D: check(a.shape.radius == b.shape.radius and a.shape.height == b.shape.height, "native round collider dimensions")
	check(a.get_child_count() == b.get_child_count(), "native exact child count " + String(a.name))
	if a.get_child_count() == b.get_child_count():
		for index in a.get_child_count(): pair(a.get_child(index), b.get_child(index))

func materials(world: Node3D) -> void:
	for binding in expected.bindings:
		var node := world.get_node_or_null(NodePath(binding.path))
		check(node != null, "native bound node exists " + binding.path)
		if node == null: continue
		var material: ShaderMaterial = node.get_meta("polygon_material") if binding.polygon else node.material_override
		check(material != null, "native family material present " + binding.path)
		if material == null: continue
		material_count += 1
		check(material.shader.resource_path == "res://shaders/room_surface_v8.gdshader", "native family shader " + binding.path)
		var source: Dictionary = expected.atlas_sources[binding.family]
		var rect: Array = source.regions[binding.role]
		check(material.get_shader_parameter("source_region_pixels") == Vector4(rect[0],rect[1],rect[2],rect[3]), "native exact source rectangle " + binding.path)
		var texture: Texture2D = material.get_shader_parameter("painted_surface")
		check(texture.resource_path == source.path and texture.get_size() == Vector2(1536,1024), "native correct imported family PNG " + binding.path)
		# Export serialization can omit an override equal to the shader default.
		# Query that actual shader default rather than treating null as a number.
		var density: Variant = material.get_shader_parameter("pixels_per_metre")
		if density == null: density = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), &"pixels_per_metre")
		check((density is float or density is int) and is_equal_approx(float(density), float(expected.pixels_per_metre)), "native constant texel density")

func vec(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])

func floors(world: Node3D, route: Dictionary) -> void:
	var flags: Dictionary = {}
	for portal in route.portals:
		for need in portal.requires: flags[String(need)] = true
	for node in world.get_children():
		if node.has_method("activate") and (node.has_meta("stage_door") or node.has_meta("trap_entry") or node.has_meta("trap_shutter")): node.activate(flags)
	for tick in 120: await physics_frame
	for index in [0,1,2,3,4,5,6,14,15]:
		var portal: Dictionary = route.portals[index]
		var start := vec(portal.start)
		var end := vec(portal.end)
		var direction := end-start; direction.y = 0; direction = direction.normalized()
		var cross_axis := Vector3(-direction.z,0,direction.x)
		var first := start-direction; var last := end+direction
		var longitudinal := maxi(1,int(ceil(Vector2(last.x-first.x,last.z-first.z).length()/.25)))
		var lateral := maxi(1,int(ceil((float(portal.width)-.64)/.5)))
		var missing := 0; var grade := 0; var rays := 0
		for i in range(longitudinal+1):
			for j in range(lateral+1):
				var point := first.lerp(last,float(i)/longitudinal) + cross_axis * (-(float(portal.width)/2-.32)+(float(portal.width)-.64)*float(j)/lateral)
				var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP,1)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
				floor_rays += 1; rays += 1
				if hit.is_empty(): missing += 1
				elif absf(float(hit.position.y)-point.y) > .4: grade += 1
		check(missing == 0 and grade == 0, "native corridor floor continuity/grade %d" % index)
		floor_surveys.append({"index":index,"from":portal.from,"to":portal.to,"rays":rays,"missing":missing,"grade_deviations":grade})

func freeze() -> void:
	app.set_process(false)
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	app.world.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)

func observe(event: Dictionary) -> void:
	if String(event.get("type", "")) == "shot": shots.append(event.duplicate(true))

func display_checks() -> void:
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.automated_input = true
	if not app.campaign_mode: app.start_new_campaign()
	else: app.enter_combat()
	freeze()
	check(app.campaign.current_level().id == "pale_ward_01", "actual Main Intake selected")
	check(app.hud.get_script().resource_path == "res://scripts/industrial_hud_v8.gd", "actual Main owns integrated industrial HUD")
	if not app.hud.has_method("inventory_slots"): return
	app.combat.grant_weapon(&"twin_shotgun",8)
	app.combat.currentweapon = &"twin_shotgun"; app.combat.weapon_phase = &"idle"; app.combat.cooldown = 0
	app.combat.combat_event.connect(observe)
	var before_ammo: int = app.combat.ammo_shotgun
	var before_shots: int = app.combat.shot_counter
	var camera_before: Transform3D = app.combat.camera.global_transform
	check(app.combat.try_fire(), "actual Twin accepts one shot")
	check(not app.combat.try_fire(), "Twin immediate duplicate fire denied by real cooldown")
	app._process(0)
	check(shots.size() == 1 and app.combat.shot_counter == before_shots+1, "two visual flashes still own one shot event")
	check(before_ammo-app.combat.ammo_shotgun == app.combat.weapons[&"twin_shotgun"].ammo_cost, "Twin one real shell cost")
	check(app.combat.camera.global_transform == camera_before, "Twin display cannot move aiming camera")
	check(app.muzzle_image.visible and app.muzzle_image_secondary.visible, "actual Main renders both Twin muzzle flashes")
	var atlas: Dictionary = app.art_data.weapon_atlases.twin_shotgun
	var registration: Dictionary = atlas.placement.fire
	var factor: float = app.weapon_image.size.x / app.weapon_image.texture.get_size().x
	var centers: Array[Vector2] = [app.muzzle_image.position+app.muzzle_image.size*.5, app.muzzle_image_secondary.position+app.muzzle_image_secondary.size*.5]
	check(centers[0].distance_to(centers[1]) > 2, "Twin two flash origins distinct")
	for i in 2:
		var source: Array = registration.bores[i].muzzle
		var projected: Vector2 = app.weapon_image.position + Vector2(source[0],source[1])*factor
		check(projected.distance_to(centers[i]) < .01, "flash registered to actual painted barrel %d" % i)
		var rear: Array = registration.bores[i].breech
		var breech: Vector2 = app.weapon_image.position+Vector2(rear[0],rear[1])*factor
		var aim_y: float = app.weapon_layer.size.y*.5
		var aim_x := projected.x+(aim_y-projected.y)*(projected.x-breech.x)/(projected.y-breech.y)
		check(absf(aim_x-app.weapon_layer.size.x*.5) < .01, "painted barrel axis converges on actual camera aim %d" % i)
	var snapshot: Dictionary = app.combat.get_hud_state().duplicate(true)
	app._process(0)
	check(app.combat.get_hud_state() == snapshot, "Main display update never mutates combat state")
	check(app.hud.active_ammunition().amount == app.combat.ammo_shotgun, "actual integrated HUD displays post-shot ammo")
	check(app.hud.inventory_slots()[3].owned and app.hud.inventory_slots()[3].selected, "actual integrated HUD owns/selects slot4")
	app._process(.1); app._process(.1)
	check(not app.muzzle_image.visible and not app.muzzle_image_secondary.visible, "both flashes expire")
	app.combat.currentweapon = &"pistol"; app.combat.weapon_phase = &"idle"; app.combat.cooldown = 0
	check(app.combat.try_fire(), "actual pistol still fires")
	app._process(0)
	check(app.muzzle_image.visible and not app.muzzle_image_secondary.visible, "non-Twin still uses one flash")
	for window in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(800,600),Vector2i(640,360)]:
		root.size = window; await process_frame
		app.layout_view(); app._process(0)
		var layout: Dictionary = app.hud.layout_snapshot()
		var bounds := Rect2(Vector2.ZERO,app.hud.size)
		var names := ["health","armor","ammo","inventory","utility","map"]
		for name in names: check(bounds.encloses(layout[name]), "integrated HUD section in bounds %s %s" % [window,name])
		for i in names.size():
			for j in range(i+1,names.size()): check(not layout[names[i]].intersects(layout[names[j]]), "integrated HUD sections distinct %s" % window)
		layouts.append({"window":[window.x,window.y],"hud_position":[app.hud.position.x,app.hud.position.y],"hud_size":[app.hud.size.x,app.hud.size.y]})
	var minimap: bool = app.hud.minimap_enabled
	var before_layout: Dictionary = app.hud.layout_snapshot()
	app.hud.set_minimap_enabled(not minimap)
	check(before_layout == app.hud.layout_snapshot(), "mini-map visibility toggle preserves HUD layout")
	app.hud.set_minimap_enabled(minimap)
	app.set_paused(true); app._process(0)
	check(paused and app.hud.active_ammunition().amount == app.combat.ammo_pistol, "pause retains actual displayed reserve")
	app.set_paused(false)
	app.restart_combat(); freeze(); app._process(0)
	check(app.combat.shot_counter == 0 and not app.hud.inventory_slots()[3].owned, "Retry restores real entrance inventory and shot ownership")

func run() -> void:
	check(not expected.is_empty(), "external baseline/expectations supplied")
	if expected.is_empty(): await finish(); return
	check(FileAccess.get_sha256(expected.baseline_scene) == expected.baseline_scene_sha256, "external committed baseline fixture pinned")
	var before: Node3D = load(expected.baseline_scene).instantiate()
	var current: Node3D = load("res://scenes/campaign/pale_ward_01.tscn").instantiate()
	before.scan(before); current.scan(current)
	pair(before,current)
	materials(current)
	before.free()
	root.add_child(current)
	current.get_node("Player").set_physics_process(false)
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/pale_ward_01-route.json"))
	await floors(current,route)
	current.free()
	await display_checks()
	await finish()

func finish() -> void:
	var report := {"schema_version":1,"passed":failures.is_empty(),"checks":checks,"failures":failures,"engine":Engine.get_version_info(),"executable":OS.get_executable_path(),"editor_feature":OS.has_feature("editor"),"res_root":ProjectSettings.globalize_path("res://"),"display_server":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"baseline_commit":expected.get("baseline_commit",""),"nodes_compared":nodes_compared,"colliders_compared":colliders_compared,"native_material_bindings":material_count,"floor_rays":floor_rays,"floor_surveys":floor_surveys,"accepted_shots":shots,"layouts":layouts,"scope":"Actual runtime collider pair versus committed v7; isolated all-access corridor floor survey; controlled actual Main HUD/shot/flash/pause/Retry.","limits":["Direct fixture grants/state setup isolate presentation. No continuous live route or human visual/listening claim.","Mini-map visibility tested without writing user settings; persistence roundtrip not exercised.","Checker script and v7 baseline supplied externally so production export need not include tools."]}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
	if is_instance_valid(app):
		app.menu_music.stop(); app.menu_music.stream = null
		app.combat_audio.stop_all(); app.free()
	print("PRESENTATION_V8_%s: %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
