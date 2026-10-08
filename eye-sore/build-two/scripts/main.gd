extends Control

const SETTINGS_PATH := "user://calibration_settings.cfg"
var world_view: SubViewport
var world_image: TextureRect
var player: CharacterBody3D
var menu: PanelContainer
var crosshair: Label
var status: Label
var sensitivity: float = 0.002
var field_of_view: float = 90.0
var muted: bool = false
var started: bool = false
var smoke: bool = false

func _ready() -> void:
	load_settings()
	smoke = "--smoke-test" in OS.get_cmdline_user_args()
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	world_view = SubViewport.new()
	world_view.size = Vector2i(640, 360)
	world_view.handle_input_locally = false
	world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world_view)
	var world := preload("res://scenes/calibration.tscn").instantiate()
	world_view.add_child(world)
	player = world.get_node("Player")
	if "--view=annex" in OS.get_cmdline_user_args():
		player.transform = world.get_node("AnnexPreviewPose").transform
	player.sensitivity = sensitivity
	player.get_node("Camera3D").fov = field_of_view
	world_image = TextureRect.new()
	world_image.texture = world_view.get_texture()
	world_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world_image)
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_theme_font_size_override("font_size", 18)
	add_child(crosshair)
	status = Label.new()
	status.text = "CALIBRATION ONLY · identity selection pending   |   WASD move · mouse look · Esc pause"
	status.position = Vector2(16, 12)
	status.add_theme_font_size_override("font_size", 16)
	add_child(status)
	build_menu()
	resized.connect(layout_view)
	layout_view()
	set_paused(true)
	if smoke:
		started = true
		set_paused(false)
		await get_tree().create_timer(0.5).timeout
		await capture_smoke_frame("gameplay")
		set_paused(true)
		assert(get_tree().paused)
		var paused_position := player.position
		await get_tree().create_timer(0.2).timeout
		assert(player.position == paused_position)
		await capture_smoke_frame("menu")
		AudioServer.set_bus_mute(0, true)
		set_paused(false)
		assert(not get_tree().paused)
		assert(AudioServer.is_bus_mute(0))
		AudioServer.set_bus_mute(0, muted)
		set_paused(true)
		assert(AudioServer.bus_count == 6)
		assert(AudioServer.get_bus_name(1) == "Weapons")
		assert(AudioServer.get_bus_name(5) == "UI")
		assert(world_view.size == Vector2i(640, 360))
		assert(player.get_node("Camera3D").fov == field_of_view)
		print("FOUNDATION_SMOKE_OK: scene instantiated; fixed viewport; settings applied; pause active; buses=", AudioServer.bus_count)
		get_tree().quit()

func layout_view() -> void:
	if not is_instance_valid(world_image): return
	var scale_factor := minf(size.x / 640.0, size.y / 360.0)
	# Whole-number enlargement preserves consistent pixel width whenever space allows.
	if scale_factor >= 1.0: scale_factor = floorf(scale_factor)
	world_image.size = Vector2(640, 360) * scale_factor
	world_image.position = (size - world_image.size) * 0.5
	crosshair.size = Vector2(24, 24)
	crosshair.position = size * 0.5 - crosshair.size * 0.5
	menu.position = (size - menu.size) * 0.5

func build_menu() -> void:
	menu = PanelContainer.new()
	menu.custom_minimum_size = Vector2(420, 0)
	add_child(menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	menu.add_child(column)
	var title := Label.new()
	title.text = "CALIBRATION FOUNDATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var note := Label.new()
	note.text = "Neutral movement and display preview.
Identity selection is required before production."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	var resume := Button.new()
	resume.text = "Enter / resume calibration"
	resume.pressed.connect(func(): started = true; set_paused(false))
	column.add_child(resume)
	add_slider(column, "Mouse sensitivity", 0.0005, 0.006, 0.0001, sensitivity, func(value: float): sensitivity = value; player.sensitivity = value; save_settings())
	add_slider(column, "Field of view", 60, 110, 1, field_of_view, func(value: float): field_of_view = value; player.get_node("Camera3D").fov = value; save_settings())
	var mute := CheckButton.new()
	mute.text = "Mute all audio"
	mute.button_pressed = muted
	mute.toggled.connect(func(value: bool): muted = value; AudioServer.set_bus_mute(0, value); save_settings())
	column.add_child(mute)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	column.add_child(quit)
	menu.reset_size()

func add_slider(parent: VBoxContainer, title: String, minimum: float, maximum: float, step: float, value: float, changed: Callable) -> void:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(changed)
	parent.add_child(slider)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if started: set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif not get_tree().paused and event is InputEventMouseMotion:
		player._unhandled_input(event)
		get_viewport().set_input_as_handled()

func set_paused(value: bool) -> void:
	get_tree().paused = value
	menu.visible = value
	crosshair.visible = not value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		sensitivity = clampf(float(config.get_value("input", "sensitivity", sensitivity)), 0.0005, 0.006)
		field_of_view = clampf(float(config.get_value("display", "fov", field_of_view)), 60, 110)
		muted = bool(config.get_value("audio", "muted", false))
	AudioServer.set_bus_mute(0, muted)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("input", "sensitivity", sensitivity)
	config.set_value("display", "fov", field_of_view)
	config.set_value("audio", "muted", muted)
	var error := config.save(SETTINGS_PATH)
	if error != OK: push_warning("Could not save calibration settings: " + error_string(error))

func capture_smoke_frame(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-prefix="):
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture-prefix=") + "-" + label + ".png"
			var error := get_viewport().get_texture().get_image().save_png(path)
			assert(error == OK)
