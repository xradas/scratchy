extends SceneTree
## Actual combat.launch_projectile resources; only physics ticking is disabled.
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error(message)
func selected(projectile: Node3D) -> StandardMaterial3D:
	var visual: MeshInstance3D = projectile.get_node("Visual")
	return visual.material_override if visual.material_override else visual.mesh.surface_get_material(0)
func run() -> void:
	var controller: Node3D = load("res://scripts/combat.gd").new(); controller.set_physics_process(false); root.add_child(controller)
	var palette := {"vessel": Color(.65, .8, .42), "censer": Color(1, .3, .045), "surveyor": Color(.08, .72, .9)}
	var owners := {}; var projectiles: Array[Node3D] = []
	for kind in palette:
		var owner: CharacterBody3D = load("res://scenes/combat_enemy.tscn").instantiate()
		owner.set_physics_process(false); owner.definition = load("res://resources/enemies/%s.tres" % kind); root.add_child(owner); owners[kind] = owner
	for kind in ["vessel", "censer", "surveyor", "censer", "vessel", "surveyor"]:
		var projectile: Node3D = controller.launch_projectile(owners[kind], Vector3.ZERO, Vector3.FORWARD); projectile.set_physics_process(false); projectiles.append(projectile)
		var material := selected(projectile)
		check(material.albedo_color.is_equal_approx(palette[kind]), kind + " actual projectile color")
		check(projectile.velocity == Vector3.FORWARD * owners[kind].definition.projectile_speed, kind + " motion unchanged")
		check(is_equal_approx(projectile.damage, owners[kind].definition.damage) and is_equal_approx(projectile.sweep_shape.radius, .12), kind + " damage/sweep unchanged")
		if kind != "vessel": check(material.emission.is_equal_approx(palette[kind]), kind + " species emission")
	var shared: Material = projectiles[0].get_node("Visual").mesh.surface_get_material(0)
	for projectile in projectiles:
		check(projectile.get_node("Visual").mesh.surface_get_material(0) == shared, "shared source material retained")
	check(shared.albedo_color.is_equal_approx(palette.vessel) and shared.emission.is_equal_approx(Color(.5, .8, .2)), "shared Vessel material untouched")
	check(projectiles[1].get_node("Visual").material_override != projectiles[2].get_node("Visual").material_override and projectiles[1].get_node("Visual").material_override != projectiles[3].get_node("Visual").material_override, "all new species overrides are per instance")
	# Reconfiguration cannot leave the previous species' visual override behind.
	for kind in ["surveyor", "vessel", "censer"]:
		projectiles[1].setup(controller, owners[kind], Vector3.FORWARD, 12)
		check(selected(projectiles[1]).albedo_color.is_equal_approx(palette[kind]), "reused projectile " + kind + " does not inherit prior color")
	check(selected(projectiles[0]).albedo_color.is_equal_approx(palette.vessel) and selected(projectiles[2]).albedo_color.is_equal_approx(palette.surveyor), "existing instances never cross-recolor")
	for owner in owners.values(): owner.free()
	controller.free()
	var result := {"pass": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Actual launch resources, six alternating instances and reuse; shared Vessel material, velocity/damage/sweep retained. No physics behavior change."}
	var path := "res://verification/expansion-v1/enemies/projectile-palette.json"
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_string(JSON.stringify(result, "  ") + "\n"); file.close()
	print("PROJECTILE_SPECIES_%s: %d checks; %d failures" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size()]); quit(0 if failures.is_empty() else 1)
