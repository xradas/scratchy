extends Node3D
## A persistent physical reward owned by the dead actor, never by gore FX.
var owner_enemy: CharacterBody3D
var combat: Node3D
var weapon_id: StringName
var ammo: int
var bob_time := 0.0
var visual: Node3D

func setup(enemy: CharacterBody3D, controller: Node3D, id: StringName, amount: int) -> void:
	owner_enemy = enemy
	combat = controller
	weapon_id = id
	ammo = amount
	set_meta("weapon_drop", id)
	set_meta("pickup_id", "drop:" + enemy.target_id)
	build_visual()

func build_visual() -> void:
	visual = make_model(weapon_id)
	visual.name = "VisibleWeapon"
	add_child(visual)
	var light := OmniLight3D.new()
	light.name = "PickupGlint"
	light.light_color = {&"pistol":Color(0.7,0.72,0.58), &"shotgun":Color(0.72,0.44,0.18), &"twin_shotgun":Color(1.0,0.42,0.12), &"rivet_cannon":Color(0.12,0.8,0.9), &"siege_launcher":Color(0.95,0.15,0.14)}.get(weapon_id,Color.WHITE)
	light.light_energy = 0.32
	light.omni_range = 1.3
	add_child(light)

static func make_model(id: StringName) -> Node3D:
	var model := Node3D.new()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.19, 0.18)
	metal.metallic = 0.8
	metal.roughness = 0.32
	var accent := StandardMaterial3D.new()
	accent.albedo_color = {&"pistol":Color(0.7,0.72,0.58), &"shotgun":Color(0.72,0.44,0.18), &"twin_shotgun":Color(1.0,0.42,0.12), &"rivet_cannon":Color(0.12,0.8,0.9), &"siege_launcher":Color(0.95,0.15,0.14)}.get(id,Color.WHITE)
	accent.emission_enabled = true
	accent.emission = accent.albedo_color * 0.45
	var receiver := MeshInstance3D.new()
	receiver.name = "Receiver"
	var receiver_mesh := BoxMesh.new()
	receiver_mesh.size = Vector3(0.44 if id in [&"twin_shotgun",&"siege_launcher"] else 0.34 if id in [&"shotgun",&"rivet_cannon"] else 0.24, 0.15, 0.34)
	receiver.mesh = receiver_mesh
	receiver.material_override = metal
	model.add_child(receiver)
	var barrel_count := 2 if id == &"twin_shotgun" else 1
	for index in barrel_count:
		var barrel := MeshInstance3D.new()
		barrel.name = "Barrel_%d" % index
		var barrel_mesh := CylinderMesh.new()
		barrel_mesh.top_radius = 0.085 if id == &"siege_launcher" else 0.045 if id in [&"shotgun",&"twin_shotgun"] else 0.03
		barrel_mesh.bottom_radius = barrel_mesh.top_radius
		barrel_mesh.height = 0.72 if id in [&"twin_shotgun",&"rivet_cannon",&"siege_launcher"] else 0.58 if id == &"shotgun" else 0.3
		barrel.mesh = barrel_mesh
		barrel.rotation.x = PI / 2
		barrel.position = Vector3(-0.085 if index == 0 and barrel_count == 2 else 0.085 if barrel_count == 2 else 0, 0, -0.39)
		barrel.material_override = metal
		model.add_child(barrel)
	var stock := MeshInstance3D.new()
	stock.name = "Stock"
	var stock_mesh := BoxMesh.new()
	stock_mesh.size = Vector3(0.16, 0.1, 0.34 if id != &"pistol" else 0.18)
	stock.mesh = stock_mesh
	stock.position.z = 0.31 if id != &"pistol" else 0.2
	stock.material_override = accent
	model.add_child(stock)
	if id in [&"rivet_cannon",&"siege_launcher"]:
		var canister := MeshInstance3D.new()
		canister.name = "Magazine"
		var canister_mesh := BoxMesh.new()
		canister_mesh.size = Vector3(0.2, 0.26, 0.22)
		canister.mesh = canister_mesh
		canister.position = Vector3(0, -0.2, -0.05)
		canister.material_override = accent
		model.add_child(canister)
	return model

func _physics_process(delta: float) -> void:
	if get_tree().paused or not is_instance_valid(owner_enemy) or not is_instance_valid(combat) or combat.dead: return
	bob_time += delta
	visual.position.y = sin(bob_time * 2.7) * 0.055
	visual.rotation.y += delta * 0.45
	if not is_instance_valid(combat.player) or combat.player.global_position.distance_to(global_position) >= 1.15: return
	try_collect()

func try_collect() -> bool:
	if get_tree().paused or not is_instance_valid(owner_enemy) or not is_instance_valid(combat) or combat.dead or owner_enemy.drop_collected: return false
	var was_owned: bool = combat.has_weapon(weapon_id)
	var before: int = combat.ammo_amount(combat.weapons[weapon_id].ammo_key)
	if not combat.grant_weapon(weapon_id, ammo): return false
	var received: int = combat.ammo_amount(combat.weapons[weapon_id].ammo_key) - before
	owner_enemy.drop_collected = true
	visible = false
	set_physics_process(false)
	var ammo_kind: StringName = {&"pistol":&"pistol",&"shotgun":&"shells",&"twin_shotgun":&"shells",&"rivet_cannon":&"rivets",&"siege_launcher":&"rockets"}.get(weapon_id, &"pistol")
	combat.emit_event({"type": &"item_collected", "item_kind": &"weapon" if not was_owned else ammo_kind, "pickup_id": get_meta("pickup_id"), "amount": received, "new_weapon": not was_owned, "position": global_position})
	if combat.world.has_signal("message_changed"):
		combat.world.message_changed.emit("%s recovered · %d rounds" % [String(weapon_id).replace("_"," ").capitalize(), received] if not was_owned else "%s +%d" % [String(ammo_kind).capitalize(), received])
	queue_free()
	return true
