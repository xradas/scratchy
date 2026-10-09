extends SceneTree
var app: Control
var impacts: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run_check")

func exclusions() -> Array:
	var result: Array = [app.player.get_rid()]
	for enemy in app.combat.enemies: result.append(enemy.get_rid())
	return result

func target_at(point: Vector3) -> Dictionary:
	var origin: Vector3 = app.player.camera.global_position
	return app.combat.ray(origin, origin + (point-origin).normalized()*30.0, exclusions(), true)

func run_check() -> void:
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	app.player.position = Vector3(0,0.87,14)
	app.player.rotation = Vector3.ZERO
	app.player.camera.rotation = Vector3.ZERO
	app.combat.combat_event.connect(func(event: Dictionary):
		if event.type == &"impact": impacts.append(event.duplicate()))
	var observed: Array[Dictionary] = []
	for index in 2:
		var target: CharacterBody3D = app.combat.enemies[index]
		for enemy in app.combat.enemies:
			enemy.set_physics_process(false)
			enemy.position = Vector3(6,0.87,3)
		target.position = Vector3(0,0.87,10)
		target.rotation.y = PI
		target.health = 1000
		target.state = &"chase"
		target.state_time = 0
		target.update_presentation()
		assert(is_instance_valid(target.visual_rig) and not target.get_node("Visual").visible)
		await physics_frame
		await physics_frame
		for body in target.hurt_shapes:
			var mesh_node: MeshInstance3D = body.get_parent()
			assert(body.get_node("HitSurface").shape.get_faces() == mesh_node.mesh.get_faces())
			assert(body.global_transform.is_equal_approx(mesh_node.global_transform))
		var points := {}
		var limb_point := Vector3.ZERO
		for xi in range(-12,13):
			for yi in range(-15,16):
				var point: Vector3 = target.global_position + Vector3(xi*0.05,yi*0.05,0)
				var hit := target_at(point)
				if hit.is_empty() or not hit.collider.has_meta("combat_target") or hit.collider.get_meta("combat_target") != target: continue
				var material: StringName = StringName(hit.collider.get_meta("hit_material"))
				if not points.has(material): points[material] = point
				if index == 0 and absf(xi*0.05) > 0.4: limb_point = point
		assert(points.has(&"flesh"))
		if index == 1: assert(points.has(&"armor"), "Vessel must expose both actual materials")
		if index == 0:
			assert(limb_point != Vector3.ZERO, "Visible limbs outside the capsule must be hittable")
			var gap_origin := target.global_position + Vector3(0.27,0.72,4)
			var gap_end := target.global_position + Vector3(0.27,0.72,-1)
			var gap: Dictionary = app.combat.ray(gap_origin,gap_end,exclusions(),true)
			assert(gap.is_empty() or not gap.collider.has_meta("combat_target") or gap.collider.get_meta("combat_target") != target, "Hidden capsule must not fill head silhouette gaps")
		for material in points:
			app.player.camera.look_at(points[material])
			app.combat.currentweapon = &"pistol"
			app.combat.cooldown = 0
			app.combat.weapon_phase = &"idle"
			var before: float = target.health
			impacts.clear()
			assert(app.combat.try_fire())
			assert(target.health == before-20 and impacts.size()==1 and impacts[0].material==material)
			observed.append({"enemy":target.definition.identifier,"material":material,"damage":before-target.health,"actual_mesh_contact":true})
		target.state = &"windup"
		target.state_time = target.definition.windup_seconds*0.8
		target.update_presentation()
		await physics_frame
		await physics_frame
		for body in target.hurt_shapes:
			var server_transform: Transform3D = PhysicsServer3D.body_get_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)
			assert(server_transform.is_equal_approx(body.get_parent().global_transform))
		if index == 0:
			for tick in 50:
				await physics_frame
				app.player.velocity = Vector3(0,-0.4,-8)
				app.player.move_and_slide()
			assert(app.player.position.z > 10.65 and app.player.position.z < 10.9, "Player must be blocked by the enemy actor")
			app.player.position = Vector3(0,0.87,14)
			app.player.velocity = Vector3.ZERO
			await physics_frame
		target.apply_damage(2000,200+index,&"pistol",target.global_position)
		assert(target.dead)
		for body in target.hurt_shapes: assert(body.collision_layer==0)
	var file := FileAccess.open("res://verification/combat/creature-contacts.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"contacts":observed,"rendered_faces_match_collision":true,"posed_physics_transforms_match":true,"visible_limb_hit":true,"invisible_capsule_ignored":true,"actor_collision_blocks_player":true,"dead_hurt_geometry_disabled":true},"  ")+"\n")
	file.close()
	print("CREATURE_CONTACTS_OK: exact posed mesh contacts; actual flesh/armor; visible limbs; no hidden capsule hits; dead geometry disabled")
	await app.quit_game()
