extends Node3D
## The telegraph for a newly materialising ambush enemy. Gameplay owns the spawn;
## this node owns only its short visual and the matching combat audio event.
signal finished

const DURATION := 0.65
var age := 0.0
var rings: Array[MeshInstance3D] = []
var slits: Array[MeshInstance3D] = []

func start(position_value: Vector3, combat: Node) -> void:
	global_position = position_value
	_build_visuals()
	if is_instance_valid(combat):
		combat.emit_event({"type": &"ambush_arrival", "position": position_value})
	set_process(true)

func _process(delta: float) -> void:
	age += delta
	var phase := minf(1.0, age / DURATION)
	var opacity := 0.90 * (1.0 - phase) * (1.0 - phase)
	for i in rings.size():
		var ring := rings[i]
		if not is_instance_valid(ring): continue
		ring.scale = Vector3.ONE * (0.4 + phase * (1.4 + 0.18 * i))
		_set_opacity(ring, opacity * (1.0 - 0.14 * i))
	for i in slits.size():
		var slit := slits[i]
		if not is_instance_valid(slit): continue
		slit.scale.y = 0.2 + sin(phase * PI) * 0.8
		slit.rotation.y += delta * (2.0 if i % 2 == 0 else -2.3)
		_set_opacity(slit, opacity * 0.75)
	if age >= DURATION:
		set_process(false)
		finished.emit()
		queue_free()

func _build_visuals() -> void:
	for i in 3:
		var ring := MeshInstance3D.new()
		ring.name = "ArrivalRing%d" % i
		ring.mesh = _ring_mesh(0.52 + i * 0.09, 0.045, 32)
		ring.material_override = _glow_material(Color(0.40, 0.88, 0.36, 0.8) if i != 1 else Color(0.95, 0.17, 0.10, 0.8))
		ring.position.y = -0.7 + 0.07 * i
		add_child(ring)
		rings.append(ring)
	for i in 7:
		var slit := MeshInstance3D.new()
		slit.name = "ArrivalShred%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(0.055, 1.6 + (i % 3) * 0.31, 0.035)
		slit.mesh = box
		slit.material_override = _glow_material(Color(0.75, 0.98, 0.52, 0.68) if i % 3 else Color(0.92, 0.12, 0.08, 0.65))
		var angle := TAU * float(i) / 7.0
		slit.position = Vector3(cos(angle) * 0.47, 0.16, sin(angle) * 0.47)
		slit.rotation.y = angle
		add_child(slit)
		slits.append(slit)

func _ring_mesh(radius: float, width: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := Vector3(cos(a0), 0.0, sin(a0))
		var p1 := Vector3(cos(a1), 0.0, sin(a1))
		vertices.append_array(PackedVector3Array([p0 * radius, p1 * radius, p0 * (radius + width), p0 * (radius + width), p1 * radius, p1 * (radius + width)]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 1.8
	return material

func _set_opacity(instance: MeshInstance3D, amount: float) -> void:
	var material := instance.material_override as StandardMaterial3D
	var tint := material.albedo_color
	tint.a = amount
	material.albedo_color = tint
