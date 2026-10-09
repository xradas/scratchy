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
var sprite_pivot: Node3D
var sprite_data: Dictionary = {}
var sprite_foot: Vector2
var sprite_base_foot: Vector2
var sprite_frame: int = -1
var sprite_bodies: Dictionary = {}
const SpriteHurt := preload("res://scripts/sprite_hurt_geometry.gd")
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
		elif is_instance_valid(sprite_pivot):
			origin = sprite_projectile_origin()
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
	clear_hurt_surfaces()
	if is_instance_valid(sprite_pivot): sprite_pivot.queue_free(); sprite_pivot = null; sprite = null
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

## Legacy direction-row sheets remain supported. Optional data.layout="poses" uses
## row-major cells with explicit data.poses; columns/rows retain original atlas size.
## data.foot_pivot_normalized=[x,y], hurt_resolution<=128x192, alpha_threshold,
## hurt_material_regions={frame:[{material,rect:[u,v,w,h]} or {material,polygon:[[u,v],...]}]}.
func configure_sprite_sheet(path: String, columns: int, rows: int, clips: Dictionary, pixel_size: float = 0.015, foot_pivot: Vector2 = Vector2(-1, -1), data: Dictionary = {}) -> void:
	var texture: Texture2D = load(path)
	if texture == null: push_warning("Missing enemy sprite atlas: " + path); return
	configure_sprite_texture(texture, columns, rows, clips, pixel_size, foot_pivot, data)

## Also accepts a native ImageTexture for isolated alpha/collision acceptance fixtures.
func configure_sprite_texture(texture: Texture2D, columns: int, rows: int, clips: Dictionary, pixel_size: float = 0.015, foot_pivot: Vector2 = Vector2(-1, -1), data: Dictionary = {}) -> void:
	assert(columns > 0 and rows > 0)
	rows = int(data.get("rows", rows))
	clear_hurt_surfaces()
	if is_instance_valid(visual_rig): visual_rig.queue_free(); visual_rig = null
	if is_instance_valid(sprite_pivot): sprite_pivot.queue_free()
	elif is_instance_valid(sprite): sprite.queue_free()
	sprite_data = data.duplicate(true)
	if sprite_data.has("pose_frames"):
		sprite_data.layout = "poses"
		var poses: Dictionary = sprite_data.pose_frames.duplicate(true)
		if poses.has("chase"):
			var chase: Array = poses.chase
			poses.idle = [chase[0]]
			poses.walk = chase.slice(1) if chase.size() > 1 else [chase[0]]
		sprite_data.poses = poses
	if sprite_data.has("material_regions"): sprite_data.hurt_material_regions = sprite_data.material_regions
	sprite_frame = -1; sprite_bodies.clear()
	sprite_pivot = Node3D.new(); sprite_pivot.name = "SpriteHurtPivot"
	sprite_pivot.position.y = -$CollisionShape3D.shape.height * 0.5
	add_child(sprite_pivot)
	sprite = Sprite3D.new(); sprite.name = "VisualSprite"; sprite.texture = texture
	sprite.hframes = columns; sprite.vframes = rows; sprite_directions = rows; sprite_clips = clips
	sprite.pixel_size = pixel_size; sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = float(data.get("alpha_threshold", 0.5))
	sprite.shaded = bool(data.get("shaded", false))
	var frame_size := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	if data.has("foot_pivot_normalized"):
		var normalized: Array = data.foot_pivot_normalized
		foot_pivot = Vector2(normalized[0], normalized[1]) * frame_size
	elif foot_pivot.x < 0: foot_pivot = Vector2(frame_size.x * 0.5, frame_size.y - 1)
	sprite_base_foot = foot_pivot
	sprite_foot = foot_pivot
	sprite.position.y = (foot_pivot.y - frame_size.y * 0.5) * pixel_size
	sprite.offset.x = frame_size.x * 0.5 - foot_pivot.x
	sprite_pivot.add_child(sprite)
	# A transparent pose must still tell combat to exclude the movement capsule.
	var sentinel := StaticBody3D.new();sentinel.name="SpriteQueryOwner";sentinel.collision_layer=0;sentinel.collision_mask=0
	sentinel.set_meta("combat_target",self);sprite_pivot.add_child(sentinel);hurt_shapes.append(sentinel)
	if bool(sprite_data.get("precache_frames",sprite_data.has("pose_frames"))):
		for frame in range(columns*rows):
			SpriteHurt.build(texture,columns,rows,frame,sprite.pixel_size,foot_for_frame(frame),sprite_data)
	$Visual.visible = false; update_sprite()

func foot_for_frame(frame: int) -> Vector2:
	var pivots: Dictionary = sprite_data.get("frame_pivots",{})
	var anchor: Variant = pivots.get(str(frame),pivots.get(frame,pivots.get("%s.0" % frame,null)))
	if anchor is Vector2: return anchor
	if anchor is Array: return Vector2(anchor[0],anchor[1])
	return sprite_base_foot

func sprite_projectile_origin() -> Vector3:
	if sprite_data.has("projectile_origin_local"):
		var point: Array = sprite_data.projectile_origin_local
		return sprite_pivot.to_global(Vector3(point[0], point[1], point[2]))
	var frame_origins: Dictionary = sprite_data.get("frame_projectile_origins_uv", {})
	var selected_uv: Variant = frame_origins.get(str(sprite_frame), sprite_data.get("projectile_origin_uv", null))
	if selected_uv is Array:
		var uv: Array = selected_uv
		var size := Vector2(sprite.texture.get_width() / float(sprite.hframes), sprite.texture.get_height() / float(sprite.vframes))
		return sprite_pivot.to_global(Vector3((uv[0] * size.x - sprite_foot.x) * sprite.pixel_size, (sprite_foot.y - uv[1] * size.y) * sprite.pixel_size, 0.0))
	return global_position + Vector3(0, 0.4, 0)

func clear_hurt_surfaces() -> void:
	for body in hurt_shapes:
		if is_instance_valid(body): body.collision_layer = 0; body.queue_free()
	hurt_shapes.clear()
	sprite_bodies.clear()

func update_sprite() -> void:
	if not is_instance_valid(sprite): return
	var camera: Node3D = player.get_node_or_null("Camera3D") if is_instance_valid(player) else null
	if camera != null:
		var offset := camera.global_position - sprite_pivot.global_position
		sprite_pivot.global_rotation = Vector3(0, atan2(offset.x, offset.z), 0)
	var selected: int
	if sprite_data.get("layout", "directions") == "poses":
		var poses: Dictionary = sprite_data.get("poses", {"idle":[0],"walk":[1,2],"windup":[3],"recovery":[4],"pain":[5],"dead":[6,7]})
		var pose := String(state)
		if state == &"chase": pose = "walk" if Vector2(velocity.x,velocity.z).length() > 0.05 else "idle"
		var frames: Array = poses.get(pose, [0])
		var index := 0
		if pose == "walk": index = int(state_time * float(sprite_data.get("walk_fps",8.0))) % frames.size()
		elif frames.size() > 1:
			var duration := float(sprite_data.get("death_seconds",0.65))
			if state == &"windup": duration = definition.windup_seconds
			elif state == &"recovery": duration = definition.recovery_seconds
			elif state == &"pain": duration = definition.pain_seconds
			index = mini(frames.size()-1,int(clampf(state_time/maxf(duration,.001),0,1)*frames.size()))
		selected = int(frames[index])
	else:
		var clip: Vector2i = sprite_clips.get(state, sprite_clips.get(&"chase", Vector2i(0, 1)))
		var count := maxi(clip.y, 1)
		var index: int
		if state == &"chase": index = int(state_time * 8.0) % count
		else:
			var duration := 0.65
			if state == &"windup": duration = definition.windup_seconds
			elif state == &"recovery": duration = definition.recovery_seconds
			elif state == &"pain": duration = definition.pain_seconds
			index = mini(count-1,int(clampf(state_time/maxf(duration,.001),0,1)*count))
		selected = sprite_direction_row() * sprite.hframes + clip.x + index
	if selected != sprite_frame:
		assert(selected >= 0 and selected < sprite.hframes * sprite.vframes)
		sprite.frame = selected; sprite_frame = selected
		sprite_foot = foot_for_frame(selected)
		var frame_size := Vector2(sprite.texture.get_width()/float(sprite.hframes),sprite.texture.get_height()/float(sprite.vframes))
		sprite.position.y = (sprite_foot.y-frame_size.y*.5)*sprite.pixel_size
		sprite.offset.x = frame_size.x*.5-sprite_foot.x
		var geometry: Dictionary = SpriteHurt.build(sprite.texture,sprite.hframes,sprite.vframes,selected,sprite.pixel_size,sprite_foot,sprite_data)
		for body in sprite_bodies.values(): body.collision_layer = 0; body.get_node("HitSurface").shape = null
		for material in geometry.shapes:
			var body: StaticBody3D
			if sprite_bodies.has(material): body = sprite_bodies[material]
			else:
				body = StaticBody3D.new(); body.name = "SpriteHurt_" + String(material)
				body.collision_mask = 0; body.set_meta("combat_target",self);body.set_meta("hit_material",material)
				var collision := CollisionShape3D.new();collision.name="HitSurface";body.add_child(collision)
				sprite_pivot.add_child(body);sprite_bodies[material]=body;hurt_shapes.append(body)
			body.get_node("HitSurface").shape = geometry.shapes[material]
			body.collision_layer = 0 if dead else 4
	if dead:
		for body in hurt_shapes: body.collision_layer = 0

## Row zero faces the camera with the actor's forward (-Z); subsequent rows turn clockwise.
func sprite_direction_row() -> int:
	var to_camera := player.global_position - global_position
	var angle := wrapf(atan2(-to_camera.x, -to_camera.z) - rotation.y, 0, TAU)
	return int(round(angle / TAU * sprite_directions)) % sprite_directions
