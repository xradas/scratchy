extends Node3D
## Mounted, non-colliding visual kit. Local -Z is the lens/emitter direction.
## Time is local and deterministic; no RNG, timers, audio or gameplay ownership.
@export_enum("tube", "surgical", "warning") var fixture_kind := "tube"
@export var existing_lens_path: NodePath
@export var energy := 1.2
@export var reach := 10.0
@export var cone_angle := 58.0
@export var lamp_color := Color(.82,.86,.76,1)
@export var cast_shadow := false
@export var damaged := false
@export var flicker_period := 19.0
@export var flicker_offset := 0.0
@export var flicker_depth := .14
var flicker_enabled := true
var elapsed := 0.0
var light: Light3D
var lens_material: StandardMaterial3D
var lens_visuals: Array[MeshInstance3D] = []
const HOUSING = preload("res://resources/materials/lighting-v11/housing.tres")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("intake_lighting_v11")
	lens_material = StandardMaterial3D.new()
	lens_material.albedo_color = lamp_color
	lens_material.emission_enabled = true
	lens_material.emission = lamp_color
	lens_material.emission_energy_multiplier = 1.15
	lens_material.roughness = .72
	if not existing_lens_path.is_empty():
		var lens := get_node_or_null(existing_lens_path) as MeshInstance3D
		assert(lens != null, "Mounted fixture requires its actual existing lens")
		lens.material_override = lens_material
		lens_visuals.append(lens)
	else:
		build_housing()
	light = OmniLight3D.new() if fixture_kind == "tube" else SpotLight3D.new()
	light.name = "LensEmitter"
	# Lens front is localZ-.035; the emitter is2cm beyond it, not inside metal.
	light.position = Vector3(0,0,-.055)
	light.light_color = lamp_color
	light.light_energy = energy
	if light is SpotLight3D:
		light.spot_range = reach
		light.spot_angle = cone_angle
		light.spot_attenuation = 1.15
	else:
		light.omni_range = reach
		light.omni_attenuation = 1.15
	light.shadow_enabled = cast_shadow
	light.shadow_bias = .025
	light.shadow_normal_bias = .35
	add_child(light)
	reset_lighting()

func box(name_: String, at: Vector3, size_: Vector3, material: Material = HOUSING) -> void:
	var visual := MeshInstance3D.new(); visual.name = name_; visual.position = at
	var mesh := BoxMesh.new(); mesh.size = size_; visual.mesh = mesh
	visual.material_override = material; visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

func cylinder(name_: String, at: Vector3, radius: float, length: float, rotation_: Vector3, material: Material) -> void:
	var visual := MeshInstance3D.new(); visual.name = name_; visual.position = at; visual.rotation_degrees = rotation_
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = length; mesh.radial_segments = 12
	visual.mesh = mesh; visual.material_override = material; visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	if material == lens_material: lens_visuals.append(visual)

func build_housing() -> void:
	if fixture_kind == "warning":
		box("WallMount",Vector3(0,0,.09),Vector3(.58,.42,.18))
		box("Recess",Vector3(0,0,.005),Vector3(.46,.31,.06))
		box("AmberLens",Vector3(0,0,-.026),Vector3(.36,.21,.018),lens_material)
		lens_visuals.append(get_node("AmberLens"))
	elif fixture_kind == "surgical":
		cylinder("CeilingMount",Vector3(0,0,.145),.18,.07,Vector3(90,0,0),HOUSING)
		cylinder("SealedHead",Vector3(0,0,.07),.37,.14,Vector3(90,0,0),HOUSING)
		cylinder("Diffuser",Vector3(0,0,-.021),.30,.025,Vector3(90,0,0),lens_material)
	else:
		box("CeilingBack",Vector3(0,0,.11),Vector3(1.8,.46,.14))
		for side in [-1,1]:
			box("SideRail"+str(side),Vector3(0,side*.215,.04),Vector3(1.8,.04,.12))
			box("EndCap"+str(side),Vector3(side*.86,0,.045),Vector3(.08,.42,.13))
			cylinder("Tube"+str(side),Vector3(0,side*.105,0),.035,1.55,Vector3(0,0,90),lens_material)

func intensity_at(time: float) -> float:
	if not damaged or not flicker_enabled: return 1.0
	var phase := fposmod(time+flicker_offset,maxf(flicker_period,12.0))
	# One smooth0.42second sag per19–23seconds, ≤14%; never black or rapid flash.
	var distance := absf(phase-13.0)
	if distance >= .21: return 1.0
	var blend := .5+.5*cos(PI*distance/.21)
	return 1.0-clampf(flicker_depth,0.0,.18)*blend

func apply_intensity() -> void:
	if not is_instance_valid(light): return
	var factor := intensity_at(elapsed)
	light.light_energy = energy*factor
	lens_material.emission_energy_multiplier = 1.15*factor

func _process(delta: float) -> void:
	if get_tree() == null or get_tree().paused: return
	elapsed += maxf(0.0,delta)
	if damaged: apply_intensity()

func set_flicker_enabled(enabled: bool) -> void:
	flicker_enabled = enabled
	apply_intensity()

func reset_lighting() -> void:
	elapsed = 0.0
	apply_intensity()

func lighting_state() -> Dictionary:
	return {"elapsed":elapsed,"enabled":flicker_enabled,"damaged":damaged,"factor":intensity_at(elapsed),"energy":light.light_energy,"lens_emission":lens_material.emission_energy_multiplier}
