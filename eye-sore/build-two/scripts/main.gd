extends Control

const SETTINGS_PATH := "user://calibration_settings.cfg"
var world_view: SubViewport
var world_image: TextureRect
var player: CharacterBody3D
var menu: PanelContainer
var crosshair: Control
var status: Label
var sensitivity: float = 0.002
var field_of_view: float = 90.0
var muted: bool = false
var started: bool = false
var smoke: bool = false
var automated_input: bool = false
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
var title_art: TextureRect
var weapon_layer: Control
var weapon_canvas: CanvasLayer
var muzzle_pending: bool = false
var automap: Control
var level_message: String = ""
var level_complete: bool = false
var stage_id := "pale_ward"
var stage_catalog: Array = []
var stage_selector: OptionButton
var campaign = preload("res://scripts/campaign_state.gd").new()
var campaign_mode := false
var campaign_button: Button
var stage_mode_button: Button
var campaign_transitioning := false
var weapon_hint := ""
var weapon_hint_time := 0.0

func selected_stage() -> Dictionary:
	for entry in stage_catalog:
		if entry.id == stage_id: return entry
	return {}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	var expansion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/stages/catalog.json"))
	stage_catalog = expansion.stages
	campaign.load_catalog("res://resources/campaign/catalog.json")
	var direct_campaign_level := ""
	var standalone_requested := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="):
			standalone_requested = true
			var requested := argument.trim_prefix("--stage=")
			for entry in stage_catalog:
				if entry.id == requested: stage_id = requested
		elif argument.begins_with("--campaign-level="):
			direct_campaign_level = argument.trim_prefix("--campaign-level=")
	if not direct_campaign_level.is_empty() and campaign.seek(direct_campaign_level):
		campaign_mode = true
		stage_id = String(campaign.current_level().theme)
	elif not standalone_requested and not campaign.levels.is_empty():
		var standalone_flags := ["--calibration", "--legacy-ward", "--release-route-test", "--smoke-test", "--automated-input"]
		var ordinary_launch := true
		for flag in standalone_flags:
			if flag in OS.get_cmdline_user_args(): ordinary_launch = false
		if ordinary_launch:
			campaign_mode = true
			stage_id = String(campaign.current_level().theme)
	update_window_title()
	load_settings()
	smoke = "--smoke-test" in OS.get_cmdline_user_args()
	# Automated fixtures call combat directly and do not verify physical mouse input.
	automated_input = smoke or "--automated-input" in OS.get_cmdline_user_args() or "--release-route-test" in OS.get_cmdline_user_args() or "--campaign-route-test" in OS.get_cmdline_user_args()
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
	if campaign_mode: campaign.entry_snapshot = campaign.capture(combat)
	world_image = TextureRect.new()
	world_image.texture = world_view.get_texture()
	world_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	world_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Reduce the complete world/weapon composite once, leaving window UI readable.
	var pixel_material := ShaderMaterial.new()
	pixel_material.shader = preload("res://shaders/concept_pixels.gdshader")
	if "--style-native-grid" in OS.get_cmdline_user_args():
		pixel_material.set_shader_parameter("virtual_resolution", Vector2(640, 360))
	world_image.material = pixel_material
	add_child(world_image)
	# Preserve the approved composition as the actual title artwork.
	if ResourceLoader.exists("res://assets/ui/pale-ward-title.png"):
		title_art = TextureRect.new()
		var title_texture := AtlasTexture.new()
		title_texture.atlas = load("res://assets/ui/pale-ward-title.png")
		# The static concept HUD is outside the title image's displayed region.
		title_texture.region = Rect2(0, 0, 640, 332)
		title_art.texture = title_texture
		title_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		title_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		title_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title_art)
		update_title_art()
	# One persistent presentation canvas shares the world render target. Retry
	# replaces the world only, so it cannot duplicate or orphan weapon overlays.
	weapon_canvas = CanvasLayer.new()
	weapon_canvas.name = "WeaponCanvas"
	weapon_canvas.layer = 1
	world_view.add_child(weapon_canvas)
	weapon_layer = Control.new()
	weapon_layer.name = "WeaponLayer"
	weapon_layer.clip_contents = true
	weapon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_canvas.add_child(weapon_layer)
	weapon_image = TextureRect.new()
	weapon_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_image.stretch_mode = TextureRect.STRETCH_SCALE
	weapon_layer.add_child(weapon_image)
	muzzle_image = TextureRect.new()
	muzzle_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	muzzle_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	muzzle_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	muzzle_image.visible = false
	weapon_layer.add_child(muzzle_image)
	damage_overlay = ColorRect.new()
	damage_overlay.color = Color(0.7, 0.07, 0.025, 0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_overlay)
	crosshair = preload("res://scripts/crosshair.gd").new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	status = Label.new()
	status.text = "WASD move · mouse look · left click fire · 1–6 weapons · Esc pause"
	status.position = Vector2(16, 12)
	status.add_theme_font_size_override("font_size", 16)
	add_child(status)
	hud = Label.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_theme_font_size_override("font_size", 18)
	var hud_frame := StyleBoxFlat.new()
	hud_frame.bg_color = Color(0.045, 0.065, 0.06, 0.93)
	hud_frame.border_color = Color(0.34, 0.40, 0.30)
	hud_frame.set_border_width_all(1)
	hud_frame.content_margin_left = 14
	hud_frame.content_margin_top = 8
	hud.add_theme_stylebox_override("normal", hud_frame)
	add_child(hud)
	automap = preload("res://scripts/ward_automap.gd").new()
	automap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	automap.visible = false
	add_child(automap)
	build_menu()
	setup_menu_music()
	resized.connect(layout_view)
	layout_view()
	set_paused(true)
	if smoke: call_deferred("run_smoke")
	elif "--release-route-test" in OS.get_cmdline_user_args():
		call_deferred("run_release_route_test")
	elif "--campaign-route-test" in OS.get_cmdline_user_args():
		call_deferred("run_campaign_route_test")

func run_release_route_test() -> void:
	# Explicit verification mode; ordinary play never creates the route driver.
	var driver := preload("res://scripts/release_stage_playtest.gd").new()
	add_child(driver)
	driver.setup(self)

func run_campaign_route_test() -> void:
	# Explicit native/export fixture; never instantiated in ordinary play.
	var driver := preload("res://scripts/campaign_route_playtest.gd").new()
	add_child(driver)
	driver.setup(self)

func run_smoke() -> void:
	get_tree().root.set_flag(Window.FLAG_NO_FOCUS,true)
	enter_combat()
	if not smoke_require(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Automated combat attempted pointer capture"): return
	if "--gore-smoke" in OS.get_cmdline_user_args():
		# Exercise embedded art and actual resolved damage in the release template.
		player.set_physics_process(false)
		player.position = Vector3(0,.87,11)
		for enemy in combat.enemies:
			enemy.set_physics_process(false); enemy.position.x = 80
		var victim: CharacterBody3D = combat.enemies[0]
		victim.position = Vector3(0,.87,9.5); victim.health = 80
		# Fixed approved idle torso pixel, registered through the real native sprite.
		# Close-range fixture keeps the authored seven-pellet spread within torso tissue.
		victim.update_presentation()
		var torso_pixel := Vector2(192,235)
		var torso_alpha: float = victim.sprite.texture.get_image().get_pixelv(Vector2i(torso_pixel)).a
		if not smoke_require(victim.sprite.frame == 0 and torso_alpha >= .5, "Gore fixture aim is not opaque idle torso"): return
		var torso_world: Vector3 = victim.sprite_pivot.to_global(Vector3((torso_pixel.x-victim.sprite_foot.x)*victim.sprite.pixel_size,(victim.sprite_foot.y-torso_pixel.y)*victim.sprite.pixel_size,0))
		player.camera.look_at(torso_world)
		combat.currentweapon = &"shotgun"
		await get_tree().physics_frame; await get_tree().physics_frame
		var gore_events: Array[Dictionary] = []
		combat.combat_event.connect(func(event: Dictionary) -> void: gore_events.append(event.duplicate(true)))
		var health_before: float = victim.health
		var accepted: bool = combat.try_fire()
		var contact_pellets := 0
		var resolved_damage := 0.0
		var actual_overkill := 0.0
		for event in gore_events:
			if event.get("target_id", "") != victim.target_id: continue
			if event.type == &"impact": contact_pellets += int(event.pellets)
			if event.type in [&"enemy_hurt", &"enemy_death"]:
				resolved_damage += float(event.damage)
				actual_overkill = float(event.get("overkill", 0.0))
		var diagnostics := {"accepted": accepted, "configured_pellets": combat.weapons[&"shotgun"].pellets, "victim_contact_pellets": contact_pellets, "resolved_damage": resolved_damage, "overkill": actual_overkill, "victim_health_before": health_before, "victim_health_after": victim.health, "victim_dead": victim.dead, "victim_gibbed": victim.gibbed, "distance": player.position.distance_to(victim.position), "torso_pixel": [torso_pixel.x,torso_pixel.y], "torso_alpha": torso_alpha, "torso_world": torso_world, "events": gore_events}
		print("GORE_SMOKE_DIAGNOSTICS: ", JSON.stringify(diagnostics))
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--capture-prefix="):
				var diagnostic_path := argument.trim_prefix("--capture-prefix=") + "-diagnostic.json"
				var diagnostic_file := FileAccess.open(diagnostic_path, FileAccess.WRITE)
				if not smoke_require(diagnostic_file != null, "Cannot write gore diagnostic: " + diagnostic_path): return
				diagnostic_file.store_string(JSON.stringify(diagnostics, "  ") + "\n")
				diagnostic_file.close()
		if not smoke_require(accepted and victim.dead and victim.gibbed,"Actual shotgun shot did not gib victim"): return
		if not smoke_require(health_before == 80 and combat.weapons[&"shotgun"].pellets == 7 and contact_pellets == 7 and actual_overkill >= 16,"Close torso fixture did not resolve seven real pellets with required overkill"): return
		await get_tree().create_timer(4.0).timeout
		var expected_parts: int = combat.gore.profile.gib_counts.get(String(victim.definition.identifier), 12)
		if not smoke_require(combat.gore.remains.size() == expected_parts and combat.gore.particles.is_empty(),"Gore did not settle into species-authored pieces"): return
		player.camera.look_at(Vector3(0,.2,9.5))
		if not await capture_smoke_frame("gore"): return
		restart_combat()
		if not smoke_require(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Automated retry attempted pointer capture"): return
		if not smoke_require(combat.gore.stains.is_empty() and combat.gore.remains.is_empty(),"Retry retained gore"): return
		print("GORE_EXPORT_SMOKE_OK: actual shotgun kill, ", expected_parts, " grounded parts, embedded textures and retry reset")
	await get_tree().create_timer(0.5).timeout
	if not await capture_smoke_frame("gameplay"): return
	set_paused(true)
	if not smoke_require(get_tree().paused,"Pause did not activate"): return
	var paused_position := player.position
	await get_tree().create_timer(0.2).timeout
	if not smoke_require(player.position == paused_position,"Player moved while paused"): return
	if not await capture_smoke_frame("menu"): return
	AudioServer.set_bus_mute(0, true)
	set_paused(false)
	if not smoke_require(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Automated resume attempted pointer capture"): return
	if not smoke_require(not get_tree().paused and AudioServer.is_bus_mute(0),"Resume/mute ownership failed"): return
	AudioServer.set_bus_mute(0, muted)
	set_paused(true)
	if not smoke_require(AudioServer.bus_count == 6 and AudioServer.get_bus_name(1) == "Weapons" and AudioServer.get_bus_name(5) == "UI","Audio bus layout differs"): return
	if not smoke_require(world_view.size == Vector2i(640,360) and player.get_node("Camera3D").fov == field_of_view,"Viewport/settings differ"): return
	print("FOUNDATION_SMOKE_OK: scene instantiated; fixed viewport; settings applied; pause active; buses=", AudioServer.bus_count)
	await quit_game()

func smoke_require(condition: bool, message: String) -> bool:
	# Release templates omit assert expressions entirely; checks must execute here.
	if not condition:
		push_error("SMOKE_FAILED: " + message)
		get_tree().quit(1)
	return condition

func layout_view() -> void:
	if not is_instance_valid(world_image): return
	var scale_factor := minf(size.x / 640.0, size.y / 360.0)
	# Whole-number enlargement preserves consistent pixel width whenever space allows.
	if scale_factor >= 1.0: scale_factor = floorf(scale_factor)
	world_image.size = Vector2(640, 360) * scale_factor
	world_image.position = (size - world_image.size) * 0.5
	if is_instance_valid(title_art):
		title_art.size = world_image.size
		title_art.position = world_image.position
	weapon_layer.position = Vector2.ZERO
	weapon_layer.size = Vector2(world_view.size)
	weapon_image.size = weapon_layer.size
	weapon_image.position = Vector2.ZERO
	damage_overlay.size = world_image.size
	damage_overlay.position = world_image.position
	hud.position = world_image.position + Vector2(12, world_image.size.y - 68)
	hud.size = Vector2(world_image.size.x - 24, 58)
	crosshair.size = Vector2(24, 24)
	crosshair.position = world_image.position + world_image.size * 0.5 - crosshair.size * 0.5
	if is_instance_valid(automap):
		automap.position = world_image.position
		automap.size = world_image.size
	menu.position = (size - menu.size) * 0.5

func build_menu() -> void:
	menu = PanelContainer.new()
	menu.custom_minimum_size = Vector2(420, 0)
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.025, 0.035, 0.027, 0.95)
	menu_style.border_color = Color(0.4, 0.42, 0.28)
	menu_style.set_border_width_all(2)
	menu_style.content_margin_left = 24
	menu_style.content_margin_right = 24
	menu_style.content_margin_top = 18
	menu_style.content_margin_bottom = 18
	menu.add_theme_stylebox_override("panel", menu_style)
	add_child(menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	menu.add_child(column)
	menu_title = Label.new()
	menu_title.text = "EYESORE / THE PALE WARD"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(menu_title)
	menu_note = Label.new()
	menu_note.text = "WASD move · mouse look · left click fire · E use · Tab map\n1 pistol · 2 shotgun · 3 melee · 4 twin shotgun · 5 rivet cannon · 6 siege launcher\nFind the heavy weapons in each stage."
	menu_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(menu_note)
	campaign_button = Button.new()
	campaign_button.text = "New Game"
	campaign_button.visible = not campaign.levels.is_empty()
	campaign_button.pressed.connect(start_new_campaign)
	column.add_child(campaign_button)
	stage_mode_button = Button.new()
	stage_mode_button.text = "Stage Select / Playtest"
	stage_mode_button.pressed.connect(switch_to_stage_select)
	column.add_child(stage_mode_button)
	stage_selector = OptionButton.new()
	for entry in stage_catalog:
		stage_selector.add_item(entry.title)
		if entry.id == stage_id: stage_selector.select(stage_selector.item_count - 1)
	stage_selector.item_selected.connect(select_stage)
	column.add_child(stage_selector)
	resume_button = Button.new()
	resume_button.text = "Play"
	resume_button.pressed.connect(enter_combat)
	column.add_child(resume_button)
	var retry := Button.new()
	retry.text = "Restart"
	retry.pressed.connect(restart_combat)
	column.add_child(retry)
	var title_screen := Button.new()
	title_screen.text = "Return to title"
	title_screen.pressed.connect(return_to_title)
	column.add_child(title_screen)
	var credits_button := Button.new()
	credits_button.text = "Credits"
	credits_button.pressed.connect(show_credits)
	column.add_child(credits_button)
	add_slider(column, "Mouse sensitivity", 0.0005, 0.006, 0.0001, sensitivity, func(value: float): sensitivity = value; player.sensitivity = value; save_settings())
	add_slider(column, "Horizontal field of view", 60, 110, 1, field_of_view, func(value: float): field_of_view = value; player.get_node("Camera3D").fov = value; save_settings())
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

func show_credits() -> void:
	var credits := AcceptDialog.new()
	credits.title = "Eyesore / credits"
	credits.dialog_text = "Eyesore — The Pale Ward / The Ash Citadel / The Occupied Line\nOriginal environment geometry and gameplay: Eyesore project\nVisual assets adapted from the approved theme boards with OpenAI imagegen\n\nMusic: Zander Noriega\nAbelian — menu (CC BY 3.0)\nBestial Paragon Interface — Ward / Line (CC BY 3.0)\nDragged Through Hellfire (Abomination) — Citadel (CC BY 4.0)\n\nFirearms: Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney\nOther sound sources: qubodup, rubberduck, HaelDB (CC0)\nGodot Engine 4.7.2 — MIT\n\nFull source links, licenses and edits accompany the portable package."
	credits.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(credits)
	credits.confirmed.connect(credits.queue_free)
	credits.canceled.connect(credits.queue_free)
	credits.popup_centered(Vector2i(660, 470))

func select_stage(index: int) -> void:
	campaign_mode = false
	stage_id = String(stage_catalog[index].id)
	return_to_title()
	update_title_art()
	update_window_title()

func switch_to_stage_select() -> void:
	campaign_mode = false
	stage_id = "pale_ward"
	return_to_title()

func update_window_title() -> void:
	var title := String(campaign.current_level().get("title", "")) if campaign_mode else String(selected_stage().get("title", "Eyesore"))
	DisplayServer.window_set_title("Eyesore / " + title)

func current_level_label() -> String:
	if not campaign_mode: return String(selected_stage().get("title", ""))
	var level: Dictionary = campaign.current_level()
	return "%s · %d/%d · %s" % [String(level.get("chapter_title", "")), int(level.get("chapter_index", 0)) + 1, int(level.get("chapter_length", 1)), String(level.get("title", ""))]

func update_title_art() -> void:
	if not is_instance_valid(title_art): return
	var entry := selected_stage()
	var region: Array = entry.title_region
	var image := AtlasTexture.new()
	image.atlas = load(entry.title_board)
	image.region = Rect2(region[0], region[1], region[2], region[3])
	image.filter_clip = true
	title_art.texture = image

func create_world() -> void:
	var scene_path: String = selected_stage().scene
	if campaign_mode: scene_path = String(campaign.current_level().scene)
	if "--calibration" in OS.get_cmdline_user_args(): scene_path = "res://scenes/calibration.tscn"
	elif "--legacy-ward" in OS.get_cmdline_user_args(): scene_path = "res://scenes/pale_ward.tscn"
	world = (load(scene_path) as PackedScene).instantiate()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world_view.add_child(world)
	player = world.get_node("Player")
	player.collision_layer = 2
	player.collision_mask = 3
	if "--view=annex" in OS.get_cmdline_user_args() and world.has_node("AnnexPreviewPose"):
		player.transform = world.get_node("AnnexPreviewPose").transform
	player.sensitivity = sensitivity
	player.get_node("Camera3D").keep_aspect = Camera3D.KEEP_WIDTH
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
			var audio_profile: CombatAudioProfile = load("res://resources/combat_audio.tres").duplicate()
			audio_profile.music = load(selected_stage().music)
			combat_audio.setup(audio_profile, false)
		configure_combat_art()
		if world.has_method("setup"):
			world.setup(combat, player)
			world.completed.connect(on_level_completed)
			world.message_changed.connect(func(text: String): level_message = text)

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
		if data.has("rig_scene"):
			enemy.configure_live_visual(data.rig_scene)
			continue
		var clips := {}
		for clip in data.clips:
			clips[clip] = Vector2i(data.clips[clip][0], data.clips[clip][1])
		var pivot_data: Array = data.get("foot_pivot", [-1, -1])
		enemy.configure_sprite_sheet(data.file, data.columns, data.directions, clips, data.get("pixel_size", 0.015), Vector2(pivot_data[0], pivot_data[1]), data.get("sprite_options", {}))

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
	if campaign_mode and level_complete:
		if campaign.next_level().is_empty():
			start_new_campaign()
		else:
			continue_campaign()
		return
	if level_complete or (is_instance_valid(combat) and combat.dead):
		restart_combat()
		return
	started = true
	if is_instance_valid(menu_music): menu_music.stop()
	if is_instance_valid(combat_audio): combat_audio.start_music()
	set_paused(false)

func restart_combat() -> void:
	var restore_snapshot: Dictionary = campaign.entry_snapshot.duplicate(true) if campaign_mode else {}
	set_paused(true)
	level_complete = false
	level_message = ""
	replace_world(restore_snapshot)
	enter_combat()

func return_to_title() -> void:
	set_paused(true)
	level_complete = false
	level_message = ""
	campaign.reset()
	if campaign_mode: stage_id = String(campaign.current_level().theme)
	for index in stage_catalog.size():
		if String(stage_catalog[index].id) == stage_id:
			stage_selector.select(index)
			break
	replace_world({})
	if campaign_mode: campaign.entry_snapshot = campaign.capture(combat)
	started = false
	if is_instance_valid(menu_music): menu_music.play()
	update_title_art()
	update_window_title()
	set_paused(true)

func start_new_campaign() -> void:
	if campaign.levels.is_empty(): return
	set_paused(true)
	campaign.reset()
	campaign_mode = true
	stage_id = String(campaign.current_level().theme)
	level_complete = false
	level_message = ""
	replace_world({})
	campaign.entry_snapshot = campaign.capture(combat)
	started = false
	update_title_art()
	update_window_title()
	enter_combat()

func continue_campaign() -> void:
	if campaign_transitioning or not campaign_mode or not level_complete: return
	if campaign.next_level().is_empty(): return
	campaign_transitioning = true
	var carried := campaign.capture(combat)
	set_paused(true)
	menu_title.text = "LOADING " + String(campaign.next_level().title).to_upper()
	campaign.advance()
	stage_id = String(campaign.current_level().theme)
	level_complete = false
	level_message = ""
	replace_world(carried)
	campaign.entry_snapshot = campaign.capture(combat)
	update_title_art()
	update_window_title()
	campaign_transitioning = false
	enter_combat()

func replace_world(snapshot: Dictionary) -> void:
	if is_instance_valid(combat_audio): combat_audio.stop_all()
	combat_audio = null
	combat = null
	if is_instance_valid(world): world.free()
	create_world()
	if campaign_mode and not snapshot.is_empty(): campaign.restore(combat, snapshot)
	damage_flash = 0
	muzzle_time = 0
	muzzle_pending = false
	if is_instance_valid(automap):
		automap.visible = false
		automap.state.clear()
	weapon_hint_time = 0.0

func on_combat_event(event: Dictionary) -> void:
	if event.get("type") in [&"enemy_hurt", &"enemy_death"]:
		crosshair.confirm_hit()
	if is_instance_valid(combat_audio): combat_audio.handle_event(event)
	if event.get("type") == &"player_hurt": damage_flash = 0.24
	if event.get("type") == &"shot" and event.get("weapon_id") != &"melee":
		muzzle_time = float(art_data.get("flash", {}).get("lifetime", 0.045))
		muzzle_pending = true

func on_player_died() -> void:
	call_deferred("set_paused", true)

func on_level_completed() -> void:
	if level_complete or campaign_transitioning: return
	level_complete = true
	if campaign_mode and is_instance_valid(combat_audio): combat_audio.stop_all()
	call_deferred("set_paused", true)

func _process(delta: float) -> void:
	if not get_tree().paused: weapon_hint_time = maxf(0.0, weapon_hint_time - delta)
	if not is_instance_valid(hud): return
	if not is_instance_valid(combat):
		hud.text = "MOVEMENT PREVIEW"
		return
	var state: Dictionary = combat.get_hud_state()
	if is_instance_valid(title_art): title_art.visible = not started
	hud.visible = started
	status.visible = started and not get_tree().paused
	if world.has_method("get_level_state"):
		var level_state: Dictionary = world.get_level_state()
		status.text = current_level_label() + "\n" + String(level_state.get("objective", "")) + "\n" + String(level_state.get("prompt", ""))
		if not level_message.is_empty(): status.text += "\n" + level_message
		if weapon_hint_time > 0.0: status.text += "\n" + weapon_hint
		if automap.visible:
			automap.update_map(level_state, player.global_position, player.rotation.y)
	var heavy_ammo := ""
	if state.owned_weapons.has("rivet_cannon"): heavy_ammo += "    RIVETS %d" % state.ammo_rivets
	if state.owned_weapons.has("siege_launcher"): heavy_ammo += "    ROCKETS %d" % state.ammo_rockets
	hud.text = "HEALTH %d    ARMOR %d    PISTOL %d    SHELLS %d\n%s    KILLS %d/%d%s" % [state.health, state.armor, state.ammo_pistol, state.ammo_shotgun, String(state.weapon_id).replace("_", " ").to_upper(), state.kills, state.total_enemies, heavy_ammo]
	var path: String = state.get("weapon_visual_path", "")
	var atlas_definition: Dictionary = art_data.get("weapon_atlases", {}).get(String(state.weapon_id), {})
	if not path.is_empty():
		var cache_key := path
		if not atlas_definition.is_empty(): cache_key += "#" + String(state.weapon_phase)
		if not texture_cache.has(cache_key):
			var texture: Texture2D = load(path)
			if not atlas_definition.is_empty():
				var columns: int = atlas_definition.columns
				var rows: int = atlas_definition.rows
				var cell: int = atlas_definition.cells.get(String(state.weapon_phase), 0)
				var cell_size := texture.get_size() / Vector2(columns, rows)
				var region := AtlasTexture.new()
				region.atlas = texture
				region.region = Rect2(Vector2(cell % columns, cell / columns) * cell_size, cell_size)
				if atlas_definition.has("regions"):
					var coordinates: Array = atlas_definition.regions[String(state.weapon_phase)]
					region.region = Rect2(coordinates[0], coordinates[1], coordinates[2], coordinates[3])
				region.filter_clip = true
				texture = region
			texture_cache[cache_key] = texture
		weapon_image.texture = texture_cache[cache_key]
	weapon_image.visible = started and not state.dead
	weapon_image.size = weapon_layer.size
	if not atlas_definition.is_empty() and weapon_image.texture:
		var frame_size := weapon_image.texture.get_size()
		weapon_image.size.x = minf(weapon_layer.size.x, weapon_layer.size.y * frame_size.x / frame_size.y)
	weapon_image.position = Vector2((weapon_layer.size.x - weapon_image.size.x) * 0.5, combat.recoil_remaining * weapon_layer.size.y / 180.0)
	var projected_weapon_pose: Dictionary = {}
	if atlas_definition.has("placement"):
		# Authored region/marker registration consumes the untouched generated atlas.
		var pose: Dictionary = atlas_definition.placement[String(state.weapon_phase)]
		projected_weapon_pose = preload("res://scripts/weapon_presentation.gd").pose(pose, weapon_image.texture.get_size(), float(atlas_definition.get("source_canvas_height", 768)), weapon_layer.size, combat.recoil_remaining)
		weapon_image.size = projected_weapon_pose.size
		weapon_image.position = projected_weapon_pose.position
	if not get_tree().paused:
		damage_flash = maxf(0.0, damage_flash - delta)
		# An accepted shot must reach one render before its lifetime is decremented.
		if muzzle_pending: muzzle_pending = false
		else: muzzle_time = maxf(0.0, muzzle_time - delta)
	damage_overlay.color.a = damage_flash * 0.9
	muzzle_image.visible = muzzle_time > 0 and started and not state.dead and state.weapon_id != &"melee"
	if muzzle_image.visible and art_data.has("flash"):
		var flash: Dictionary = art_data.flash
		if muzzle_image.texture == null: muzzle_image.texture = load(flash.file)
		var anchors: Dictionary = flash.anchors.get(String(state.weapon_id), {})
		var anchor: Array = anchors.get(String(state.weapon_phase), anchors.get("fire", [160, 90]))
		var scale_factor := weapon_image.size / Vector2(320, 180)
		muzzle_image.size = Vector2(64, 64) * scale_factor
		if not atlas_definition.is_empty():
			muzzle_image.size = Vector2.ONE * float(flash.get("world_size", 36)) * weapon_layer.size.y / 360.0
		muzzle_image.position = projected_weapon_pose.muzzle - muzzle_image.size * 0.5 if projected_weapon_pose.has("muzzle") else weapon_image.position + Vector2(anchor[0], anchor[1]) * scale_factor - muzzle_image.size * 0.5

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
	elif event is InputEventKey and event.pressed and not event.echo and started and not get_tree().paused:
		if event.keycode == KEY_E and world.has_method("interact"):
			world.interact()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			automap.visible = not automap.visible
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_4, KEY_5, KEY_6]:
			var locked_id: StringName = {KEY_4: &"twin_shotgun", KEY_5: &"rivet_cannon", KEY_6: &"siege_launcher"}[event.keycode]
			if not combat.has_weapon(locked_id):
				var location: String = {&"twin_shotgun": "Ward Intake", &"rivet_cannon": "Ward Containment", &"siege_launcher": "Ward Breach"}[locked_id]
				weapon_hint = "%s locked · find its cache%s." % [String(locked_id).replace("_", " ").capitalize(), " in " + location if campaign_mode else ""]
				weapon_hint_time = 3.0
	elif not get_tree().paused and event is InputEventMouseMotion:
		player._unhandled_input(event)
		get_viewport().set_input_as_handled()

func set_paused(value: bool) -> void:
	get_tree().paused = value
	if value and is_instance_valid(automap): automap.visible = false
	menu.visible = value
	crosshair.visible = not value
	if is_instance_valid(menu_title):
		var dead: bool = is_instance_valid(combat) and combat.dead
		if campaign_mode:
			var next: Dictionary = campaign.next_level()
			var chapter_end := campaign.is_chapter_end()
			menu_title.text = ("CAMPAIGN COMPLETE" if next.is_empty() else ("CHAPTER CLEARED" if chapter_end else "LEVEL CLEARED")) if level_complete else ("YOU DIED" if dead else ("PAUSED" if started else "EYESORE / CAMPAIGN"))
			resume_button.text = ("New Game" if next.is_empty() else "Continue") if level_complete else ("Retry" if dead else ("Resume" if started else "Play " + String(campaign.current_level().title)))
			if level_complete:
				menu_note.text = "%s cleared.\n%s" % [current_level_label(), "The occupation is broken." if next.is_empty() else ("Next chapter: " + String(next.chapter_title) if chapter_end else "Next: " + String(next.title))]
			else:
				menu_note.text = "%s\n%s" % [current_level_label(), "Retry from this level's entrance." if dead else "WASD move · mouse look · left click fire\n1–6 weapons · E use · Tab map"]
		else:
			menu_title.text = "STAGE COMPLETE" if level_complete else ("YOU DIED" if dead else ("PAUSED" if started else "EYESORE / " + String(selected_stage().title).to_upper()))
			resume_button.text = "Play again" if level_complete else ("Retry" if dead else ("Resume" if started else "Play"))
			menu_note.text = ("%s completed.\nKills %d/%d" % [selected_stage().title, combat.kills, combat.total_enemies]) if level_complete else ("Retry from the start." if dead else "WASD move · mouse look · left click fire\n1–6 weapons · E use · Tab map")
		stage_selector.visible = not campaign_mode
		campaign_button.visible = not started and not campaign.levels.is_empty()
		stage_mode_button.visible = not started and campaign_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or automated_input else Input.MOUSE_MODE_CAPTURED

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
	config.set_value("display", "fov_axis", "horizontal")
	config.set_value("audio", "muted", muted)
	var error := config.save(SETTINGS_PATH)
	if error != OK: push_warning("Could not save calibration settings: " + error_string(error))

func capture_smoke_frame(label: String) -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-prefix="):
			if not smoke_require(DisplayServer.get_name() != "headless", "Capture requires a native renderer"): return false
			var force_offscreen := "--force-offscreen-draw" in OS.get_cmdline_user_args()
			var offscreen_required := false
			if force_offscreen:
				# force_draw emits frame_post_draw synchronously; never await it afterward.
				# Process-frame warm-up lets the world SubViewport reach the root texture.
				for i in 3:
					await get_tree().process_frame
					offscreen_required = offscreen_required or not DisplayServer.window_can_draw()
					RenderingServer.force_draw(false)
			else:
				await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--capture-prefix=") + "-" + label + ".png"
			var captured := get_viewport().get_texture().get_image()
			if not smoke_require(captured != null and not captured.is_empty(), "Empty native capture: " + path): return false
			var error := captured.save_png(path)
			if not smoke_require(error == OK, "Capture save failed: " + path + " (" + error_string(error) + ")"): return false
			print("SMOKE_CAPTURE_OK: label=", label, " forced_offscreen=", force_offscreen, " offscreen_required=", offscreen_required, " path=", path)
	return true
