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
var world: Node3D
var combat: Node3D
var combat_audio: Node3D
var menu_music: AudioStreamPlayer
var weapon_image: TextureRect
var hud: Label
var menu_title: Label
var menu_note: Label
var resume_button: Button
var damage_overlay: ColorRect
var texture_cache: Dictionary = {}
var music_started: bool = false
var damage_flash: float = 0.0
var muzzle_image: TextureRect
var muzzle_time: float = 0.0
var art_data: Dictionary = {}
var closing: bool = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	load_settings()
	smoke = "--smoke-test" in OS.get_cmdline_user_args()
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	world_view = SubViewport.new()
	world_view.size = Vector2i(640, 360)
	world_view.audio_listener_enable_3d = true
	world_view.handle_input_locally = false
	world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world_view)
	create_world()
	world_image = TextureRect.new()
	world_image.texture = world_view.get_texture()
	world_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world_image)
	weapon_image = TextureRect.new()
	weapon_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_image.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(weapon_image)
	muzzle_image = TextureRect.new()
	muzzle_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	muzzle_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	muzzle_image.visible = false
	add_child(muzzle_image)
	damage_overlay = ColorRect.new()
	damage_overlay.color = Color(0.7, 0.07, 0.025, 0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_overlay)
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_theme_font_size_override("font_size", 18)
	add_child(crosshair)
	status = Label.new()
	status.text = "COMBAT REVIEW   |   WASD move · mouse look · fire · 1 pistol / 2 shotgun / 3 melee · Esc pause"
	status.position = Vector2(16, 12)
	status.add_theme_font_size_override("font_size", 16)
	add_child(status)
	hud = Label.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_font_size_override("font_size", 18)
	add_child(hud)
	build_menu()
	setup_menu_music()
	resized.connect(layout_view)
	layout_view()
	set_paused(true)
	if smoke:
		enter_combat()
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
		await quit_game()

func layout_view() -> void:
	if not is_instance_valid(world_image): return
	var scale_factor := minf(size.x / 640.0, size.y / 360.0)
	# Whole-number enlargement preserves consistent pixel width whenever space allows.
	if scale_factor >= 1.0: scale_factor = floorf(scale_factor)
	world_image.size = Vector2(640, 360) * scale_factor
	world_image.position = (size - world_image.size) * 0.5
	weapon_image.size = world_image.size
	weapon_image.position = world_image.position
	damage_overlay.size = world_image.size
	damage_overlay.position = world_image.position
	hud.position = Vector2(16, size.y - 58)
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
	menu_title = Label.new()
	menu_title.text = "EYESORE · COMBAT REVIEW"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(menu_title)
	menu_note = Label.new()
	menu_note.text = "Pistol · shotgun · melee\nOne complete combat exchange before level expansion."
	menu_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(menu_note)
	resume_button = Button.new()
	resume_button.text = "Enter combat review"
	resume_button.pressed.connect(enter_combat)
	column.add_child(resume_button)
	var retry := Button.new()
	retry.text = "Restart combat review"
	retry.pressed.connect(restart_combat)
	column.add_child(retry)
	var title_screen := Button.new()
	title_screen.text = "Return to title"
	title_screen.pressed.connect(return_to_title)
	column.add_child(title_screen)
	add_slider(column, "Mouse sensitivity", 0.0005, 0.006, 0.0001, sensitivity, func(value: float): sensitivity = value; player.sensitivity = value; save_settings())
	add_slider(column, "Field of view", 60, 110, 1, field_of_view, func(value: float): field_of_view = value; player.get_node("Camera3D").fov = value; save_settings())
	var mute := CheckButton.new()
	mute.text = "Mute all audio"
	mute.button_pressed = muted
	mute.toggled.connect(func(value: bool): muted = value; AudioServer.set_bus_mute(0, value); save_settings())
	column.add_child(mute)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(quit_game)
	column.add_child(quit)
	menu.reset_size()

func create_world() -> void:
	world = preload("res://scenes/calibration.tscn").instantiate()
	world_view.add_child(world)
	player = world.get_node("Player")
	if "--view=annex" in OS.get_cmdline_user_args():
		player.transform = world.get_node("AnnexPreviewPose").transform
	player.sensitivity = sensitivity
	player.get_node("Camera3D").fov = field_of_view
	if ResourceLoader.exists("res://scripts/combat.gd"):
		combat = load("res://scripts/combat.gd").new()
		combat.name = "Combat"
		world.add_child(combat)
		combat.combat_event.connect(on_combat_event)
		combat.player_died.connect(on_player_died)
		combat.setup(world, player)
		if ResourceLoader.exists("res://resources/combat_audio.tres"):
			combat_audio = preload("res://scripts/combat_audio.gd").new()
			world.add_child(combat_audio)
			combat_audio.setup(load("res://resources/combat_audio.tres"), false)
		configure_combat_art()

func configure_combat_art() -> void:
	var manifest_path := "res://assets/combat_art.json"
	if not FileAccess.file_exists(manifest_path): return
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	art_data = art
	combat.configure_weapon_visuals(art.get("weapons", {}))
	for enemy in combat.enemies:
		var kind := String(enemy.definition.identifier)
		if not art.get("enemies", {}).has(kind): continue
		var data: Dictionary = art.enemies[kind]
		var clips := {}
		for clip in data.clips:
			clips[clip] = Vector2i(data.clips[clip][0], data.clips[clip][1])
		enemy.configure_sprite_sheet(data.file, data.columns, data.directions, clips, data.get("pixel_size", 0.015))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func quit_game() -> void:
	if closing: return
	closing = true
	set_paused(true)
	if is_instance_valid(menu_music):
		menu_music.stream_paused = false
		menu_music.stop()
		menu_music.stream = null
	if is_instance_valid(combat_audio): combat_audio.stop_all()
	# Playback is retired by the audio mix thread after stop, including paused music.
	await get_tree().create_timer(0.25, true).timeout
	get_tree().quit()

func setup_menu_music() -> void:
	var path := "res://assets/audio/music/menu_abelian.ogg"
	if not ResourceLoader.exists(path): return
	menu_music = AudioStreamPlayer.new()
	menu_music.name = "MenuAbelian"
	menu_music.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_music.bus = &"Music"
	var stream: AudioStreamOggVorbis = load(path).duplicate()
	stream.loop = true
	menu_music.stream = stream
	menu_music.volume_db = -3.0
	add_child(menu_music)
	menu_music.play()

func enter_combat() -> void:
	if is_instance_valid(combat) and combat.dead:
		restart_combat()
		return
	started = true
	if is_instance_valid(menu_music): menu_music.stop()
	if is_instance_valid(combat_audio): combat_audio.start_music()
	set_paused(false)

func restart_combat() -> void:
	set_paused(true)
	if is_instance_valid(combat_audio): combat_audio.stop_all()
	combat_audio = null
	combat = null
	world.free()
	create_world()
	damage_flash = 0
	muzzle_time = 0
	enter_combat()

func return_to_title() -> void:
	set_paused(true)
	if is_instance_valid(combat_audio): combat_audio.stop_all()
	combat_audio = null
	combat = null
	world.free()
	create_world()
	started = false
	damage_flash = 0
	muzzle_time = 0
	if is_instance_valid(menu_music): menu_music.play()
	set_paused(true)

func on_combat_event(event: Dictionary) -> void:
	if is_instance_valid(combat_audio): combat_audio.handle_event(event)
	if event.get("type") == &"player_hurt": damage_flash = 0.24
	if event.get("type") == &"shot" and event.get("weapon_id") != &"melee":
		muzzle_time = float(art_data.get("flash", {}).get("lifetime", 0.045))

func on_player_died() -> void:
	call_deferred("set_paused", true)

func _process(delta: float) -> void:
	if not is_instance_valid(hud): return
	if not is_instance_valid(combat):
		hud.text = "MOVEMENT PREVIEW"
		return
	var state: Dictionary = combat.get_hud_state()
	hud.text = "HEALTH %d    ARMOR %d    PISTOL %d    SHELLS %d\n%s    KILLS %d/%d" % [state.health, state.armor, state.ammo_pistol, state.ammo_shotgun, String(state.weapon_id).to_upper(), state.kills, state.total_enemies]
	var path: String = state.get("weapon_visual_path", "")
	if not path.is_empty():
		if not texture_cache.has(path): texture_cache[path] = load(path)
		weapon_image.texture = texture_cache[path]
	weapon_image.visible = started and not state.dead
	if not get_tree().paused:
		damage_flash = maxf(0.0, damage_flash - delta)
		muzzle_time = maxf(0.0, muzzle_time - delta)
	damage_overlay.color.a = damage_flash * 0.9
	muzzle_image.visible = muzzle_time > 0 and started and not state.dead
	if muzzle_image.visible and art_data.has("flash"):
		var flash: Dictionary = art_data.flash
		if muzzle_image.texture == null: muzzle_image.texture = load(flash.file)
		var anchors: Dictionary = flash.anchors.get(String(state.weapon_id), {})
		var anchor: Array = anchors.get(String(state.weapon_phase), anchors.get("fire", [160, 90]))
		var scale_factor := world_image.size / Vector2(320, 180)
		muzzle_image.size = Vector2(64, 64) * scale_factor
		muzzle_image.position = world_image.position + (Vector2(anchor[0], anchor[1]) - Vector2(32, 32)) * scale_factor

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
		if is_instance_valid(combat) and combat.dead:
			set_paused(true)
		elif started: set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif not get_tree().paused and event is InputEventMouseMotion:
		player._unhandled_input(event)
		get_viewport().set_input_as_handled()

func set_paused(value: bool) -> void:
	get_tree().paused = value
	menu.visible = value
	crosshair.visible = not value
	if is_instance_valid(menu_title):
		var dead: bool = is_instance_valid(combat) and combat.dead
		menu_title.text = "YOU DIED" if dead else ("PAUSED" if started else "EYESORE · COMBAT REVIEW")
		resume_button.text = "Retry" if dead else ("Resume" if started else "Enter combat review")
		menu_note.text = "Retry restores ammunition, enemies and all voices." if dead else "Pistol · shotgun · melee\nOne complete combat exchange before level expansion."
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
