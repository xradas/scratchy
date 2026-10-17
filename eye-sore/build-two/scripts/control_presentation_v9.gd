extends Node3D
## Display-only switches and deferred generated-prism material binding.
## Main supplies actual stage snapshots; no polling, input or gameplay writes.
@export var target_path := NodePath("..")
@export var flag_key: StringName = &""
@export var required_flags := PackedStringArray()
@export var is_exit := false
@export var surface_material: Material
var active := false
var requirements_met := false
var _target: Node3D
var _stripe: MeshInstance3D
var _off_icon: Node3D
var _on_icon: Node3D
var _indicator_material: StandardMaterial3D
var _local_surface: Material
var _snapshot: Dictionary = {}

func _ready() -> void:
 _target = get_node_or_null(target_path)
 if not is_instance_valid(_target): return
 if not flag_key.is_empty() or is_exit:
  add_to_group("equipment_controls_v9")
 if not flag_key.is_empty() and not is_exit:
  _build_indicators()
 # StageLevel.setup/scan builds polygon meshes after scene child readiness.
 call_deferred("_apply_surface")
 set_display_state({})

func _apply_surface() -> void:
 if surface_material == null or not is_instance_valid(_target): return
 _local_surface = surface_material.duplicate()
 _local_surface.resource_local_to_scene = true
 var visual := _target.get_node_or_null("Visual")
 if visual is MeshInstance3D:
  visual.material_override = _local_surface
 else:
  # A generated prism has only the stage-generated body's mesh child here.
  for body in _target.get_children():
   if not body is StaticBody3D: continue
   for mesh in body.get_children():
    if mesh is MeshInstance3D: mesh.material_override = _local_surface
 set_display_state(_snapshot)

func set_display_state(stage: Dictionary) -> void:
 _snapshot = stage.duplicate(true)
 var flags: Dictionary = stage.get("flags", {})
 requirements_met = true
 for requirement in required_flags:
  if not bool(flags.get(requirement, false)): requirements_met = false
 active = requirements_met if is_exit else bool(flags.get(flag_key, false))
 if is_instance_valid(_stripe):
  _indicator_material.albedo_color = Color("8ab55f") if active else Color("bc613e")
  _indicator_material.emission = _indicator_material.albedo_color
  _off_icon.visible = not active
  _on_icon.visible = active
  # State differs in physical glyph and stripe extent as well as hue.
  _stripe.scale.x = 1.0 if active else 0.48
 if is_exit and _local_surface is ShaderMaterial:
  _local_surface.set_shader_parameter("engaged", active)

func _box(parent: Node3D, label: String, at: Vector3, dimensions: Vector3) -> MeshInstance3D:
 var mesh := BoxMesh.new()
 mesh.size = dimensions
 var visual := MeshInstance3D.new()
 visual.name = label
 visual.mesh = mesh
 visual.material_override = _indicator_material
 visual.position = at
 parent.add_child(visual)
 return visual

func _build_indicators() -> void:
 _indicator_material = StandardMaterial3D.new()
 _indicator_material.albedo_color = Color("bc613e")
 _indicator_material.roughness = 0.72
 _indicator_material.emission_enabled = true
 _indicator_material.emission_energy_multiplier = 0.35
 # Original body AABB is ±(.55,.75,.25); original Face extends to z=.33.
 # All new geometry stays within their original combined local AABB.
 _stripe = _box(self, "StateStripe", Vector3(0, -0.52, 0.258), Vector3(0.78, 0.07, 0.012))
 _off_icon = Node3D.new(); _off_icon.name = "InactiveGlyph"; add_child(_off_icon)
 _on_icon = Node3D.new(); _on_icon.name = "ActiveGlyph"; add_child(_on_icon)
 var corner := Vector3(0.40, 0.54, 0.258)
 for side in [-1, 1]:
  _box(_off_icon, "Horizontal" + str(side), corner + Vector3(0, side * 0.07, 0), Vector3(0.16, 0.024, 0.012))
  _box(_off_icon, "Vertical" + str(side), corner + Vector3(side * 0.07, 0, 0), Vector3(0.024, 0.12, 0.012))
 _box(_on_icon, "Stem", corner, Vector3(0.028, 0.16, 0.012))
 _box(_on_icon, "Bar", corner + Vector3(0, -0.065, 0), Vector3(0.14, 0.028, 0.012))
