extends CharacterBody3D

var combat: Node3D
var player: CharacterBody3D
var definition: EnemyDefinition
var target_id: String
var health: float = 1.0
var dead: bool = false
var state: StringName = &"chase"
var state_time: float = 0.0
var attack_id: int = 0
var released: bool = false
var seen_shots: Dictionary = {}
var sprite_clips: Dictionary = {}
var sprite_directions: int = 1
var sprite: Sprite3D
var visual_rig: Node3D
var hurt_shapes: Array[StaticBody3D] = []

func setup(controller: Node3D, actor: CharacterBody3D, data: EnemyDefinition, id: String) -> void:
	combat = controller; player = actor; definition = data; target_id = id; health = definition.health
	set_meta("hit_material", definition.hit_material)
	$Visual.material_override = make_proxy_material(Color(0.53, 0.35, 0.3) if not definition.ranged else Color(0.33, 0.46, 0.4))

func make_proxy_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.9
	return material

func _physics_process(delta: float) -> void:
	if dead:
		state_time += delta
		update_presentation()
		return
	if not is_instance_valid(player) or combat.dead: return
	state_time += delta
	var offset := player.global_position - global_position
	var distance := Vector2(offset.x, offset.z).length()
	var visible := can_see_player()
	if state == &"pain":
		velocity.x = 0; velocity.z = 0
		if state_time >= definition.pain_seconds: change_state(&"chase")
	elif state == &"windup":
		velocity.x = 0; velocity.z = 0
		if state_time >= definition.windup_seconds:
			if visible and distance <= definition.attack_range + 0.2:
				release_attack()
			change_state(&"recovery")
	elif state == &"recovery":
		velocity.x = 0; velocity.z = 0
		if state_time >= definition.recovery_seconds: change_state(&"chase")
	else:
		if visible and distance <= definition.attack_range:
			rotation.y = atan2(-offset.x, -offset.z)
			attack_id += 1; released = false; change_state(&"windup")
			combat.emit_event({"type": &"enemy_attack_warning", "enemy_kind": definition.identifier, "target_id": target_id, "attack_id": attack_id, "position": global_position})
			velocity.x = 0; velocity.z = 0
		else:
			var direction := Vector3(offset.x, 0, offset.z).normalized()
			velocity.x = direction.x * definition.speed; velocity.z = direction.z * definition.speed
			if direction.length_squared() > 0.01: rotation.y = atan2(-direction.x, -direction.z)
	if not is_on_floor(): velocity.y -= 24.0 * delta
	else: velocity.y = 0.0
	move_and_slide()
	# Physical proxy pose makes warning/pain/recovery readable before directional art is installed.
	$Visual.rotation.z = 0.13 if state == &"windup" else (-0.12 if state == &"pain" else 0.0)
	update_presentation()

func change_state(next: StringName) -> void:
	state = next; state_time = 0.0
	update_presentation()

func can_see_player() -> bool:
	if dead or not is_instance_valid(player): return false
	var hit: Dictionary = combat.ray(global_position + Vector3(0, 0.45, 0), player.global_position + Vector3(0, 0.3, 0), [get_rid()])
	return not hit.is_empty() and hit.collider == player

func release_attack() -> void:
	if dead or released or state != &"windup": return
	released = true
	if definition.ranged:
		var origin := global_position + Vector3(0, 0.4, 0)
		if is_instance_valid(visual_rig) and visual_rig.has_method("get_projectile_origin"):
			origin = visual_rig.get_projectile_origin()
		var direction := (player.global_position + Vector3(0, 0.3, 0) - origin).normalized()
		combat.launch_projectile(self, origin + direction * 0.12, direction)
		combat.emit_event({"type": &"projectile_release", "enemy_kind": definition.identifier, "target_id": target_id, "attack_id": attack_id, "position": origin})
	else:
		combat.receive_player_damage(definition.damage, target_id, player.global_position)
		combat.emit_event({"type": &"enemy_melee_release", "enemy_kind": definition.identifier, "target_id": target_id, "attack_id": attack_id, "position": global_position})

func apply_damage(amount: float, shot_id: int, weapon_id: StringName, hit_position: Vector3, impact_material: StringName = &"") -> Dictionary:
	if dead or amount <= 0.0 or seen_shots.has(shot_id): return {}
	seen_shots[shot_id] = true
	health = maxf(0.0, health - amount)
	var struck_material := definition.hit_material if impact_material == &"" else impact_material
	var event := {"type": &"enemy_hurt", "enemy_kind": definition.identifier, "target_id": target_id, "shot_id": shot_id, "weapon_id": weapon_id, "material": struck_material, "position": hit_position, "damage": amount}
	# Pain always cancels a pending unreleased strike; a fresh windup is needed after pain.
	released = true
	if health <= 0.0:
		dead = true; change_state(&"dead"); collision_layer = 0; collision_mask = 0; velocity = Vector3.ZERO
		for hurt_shape in hurt_shapes: hurt_shape.collision_layer = 0
		$Visual.rotation.z = PI / 2; $Visual.position.y = -0.5
		if is_instance_valid(sprite): update_sprite()
		event = {"type": &"enemy_death", "enemy_kind": definition.identifier, "target_id": target_id, "shot_id": shot_id, "weapon_id": weapon_id, "material": struck_material, "position": global_position}
		combat.emit_event(event)
		combat.enemy_killed(self)
	else:
		combat.emit_event(event)
		change_state(&"pain")
	return event

func configure_live_visual(scene_path: String) -> void:
	if is_instance_valid(visual_rig): visual_rig.queue_free()
	hurt_shapes.clear()
	visual_rig = (load(scene_path) as PackedScene).instantiate()
	add_child(visual_rig)
	visual_rig.configure(definition.identifier)
	$Visual.visible = false
	if is_instance_valid(sprite): sprite.visible = false
	attach_hurt_geometry(visual_rig)
	update_presentation()

func attach_hurt_geometry(node: Node3D) -> void:
	# Exact triangle surfaces follow the authored joints, preserving mouth/rib gaps.
	# These query-only bodies never push actors; the movement capsule is separate.
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh:
			var hurt_body := StaticBody3D.new()
			hurt_body.name = "HurtSurface"
			hurt_body.collision_layer = 4
			hurt_body.collision_mask = 0
			hurt_body.set_meta("combat_target", self)
			hurt_body.set_meta("hit_material", child.get_meta("hit_material", definition.hit_material))
			var shape := CollisionShape3D.new()
			shape.name = "HitSurface"
			shape.shape = child.mesh.create_trimesh_shape()
			shape.shape.backface_collision = true
			hurt_body.add_child(shape)
			child.add_child(hurt_body)
			hurt_shapes.append(hurt_body)
		elif child is Node3D:
			attach_hurt_geometry(child)

func update_presentation() -> void:
	if is_instance_valid(visual_rig):
		visual_rig.present(state, state_time, definition.windup_seconds, definition.recovery_seconds, definition.pain_seconds)
	update_sprite()

## Sheet convention: each direction is one row, animation frames occupy columns.
## clips maps chase/windup/recovery/pain/dead to Vector2i(first_column, frame_count).
func configure_sprite_sheet(path: String, columns: int, directions: int, clips: Dictionary, pixel_size: float = 0.015, foot_pivot: Vector2 = Vector2(-1, -1)) -> void:
	if is_instance_valid(sprite): sprite.queue_free()
	sprite = Sprite3D.new(); sprite.name = "VisualSprite"; sprite.texture = load(path)
	sprite.hframes = columns; sprite.vframes = directions; sprite_directions = directions; sprite_clips = clips
	sprite.pixel_size = pixel_size; sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	var frame_size := Vector2(sprite.texture.get_width() / float(columns), sprite.texture.get_height() / float(directions))
	if foot_pivot.x < 0: foot_pivot = Vector2(frame_size.x * 0.5, frame_size.y - 1)
	# Image-space foot pivot must land on the capsule's floor plane at local -0.85.
	sprite.position.y = -$CollisionShape3D.shape.height * 0.5 + (foot_pivot.y - frame_size.y * 0.5) * pixel_size
	sprite.offset.x = frame_size.x * 0.5 - foot_pivot.x
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(sprite); $Visual.visible = false; update_sprite()

func update_sprite() -> void:
	if not is_instance_valid(sprite): return
	var clip: Vector2i = sprite_clips.get(state, sprite_clips.get(&"chase", Vector2i(0, 1)))
	var frame_count := maxi(clip.y, 1)
	var frame_index: int
	if state == &"chase": frame_index = int(state_time * 8.0) % frame_count
	else:
		var duration := 0.65
		if state == &"windup": duration = definition.windup_seconds
		elif state == &"recovery": duration = definition.recovery_seconds
		elif state == &"pain": duration = definition.pain_seconds
		frame_index = mini(frame_count - 1, int(clampf(state_time / maxf(duration, 0.001), 0, 1) * frame_count))
	var direction := sprite_direction_row()
	sprite.frame = direction * sprite.hframes + clip.x + frame_index

## Row zero faces the camera with the actor's forward (-Z); subsequent rows turn clockwise.
func sprite_direction_row() -> int:
	var to_camera := player.global_position - global_position
	var angle := wrapf(atan2(-to_camera.x, -to_camera.z) - rotation.y, 0, TAU)
	return int(round(angle / TAU * sprite_directions)) % sprite_directions
