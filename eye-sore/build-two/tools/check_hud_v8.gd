extends SceneTree
## Actual Main state + isolated display consumer. Does not claim visual approval.
## Native optional capture: tools/godot.sh --no-focus --position 20000,20000
##   --script res://tools/check_hud_v8.gd -- --automated-input --capture-hud-v8
const HUD = preload("res://scripts/industrial_hud_v8.gd")
var failures: Array[String] = []
var checks := 0
var app: Control
var hud: Control
var layouts: Array[Dictionary] = []
var capture := false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("HUD_V8: " + label)

func run() -> void:
	capture = "--capture-hud-v8" in OS.get_cmdline_user_args()
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	if not app.campaign_mode: app.start_new_campaign()
	else: app.enter_combat()
	await physics_frame; await physics_frame
	app._process(0)
	app.set_process(false)
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	app.world.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	app.hud.hide()
	hud = HUD.new()
	app.add_child(hud)
	var capacities := {}
	for kind in [&"pistol", &"shells", &"rivets", &"rockets"]: capacities[kind] = app.combat.ammo_capacity(kind)
	var stage: Dictionary = app.world.get_level_state()
	var original_stage := stage.duplicate(true)
	var original_combat: Dictionary = app.combat.get_hud_state().duplicate(true)
	check(app.campaign_mode and app.campaign.current_level().id == "pale_ward_01", "actual Main Intake campaign selected")
	hud.set_display_state(original_combat, stage, capacities)
	check(hud.text.contains("HEALTH %d" % original_combat.health), "actual Main health consumed")
	check(hud.text.contains("AMMO %d/%d" % [original_combat.ammo_pistol, capacities.pistol]), "actual Main ammo and capacity consumed")
	check(stage == original_stage and app.combat.get_hud_state() == original_combat, "display never mutates authoritative state")
	check(hud.inventory_slots().map(func(slot): return slot.weapon_id) == [&"pistol", &"shotgun", &"melee", &"twin_shotgun", &"rivet_cannon", &"siege_launcher"], "real hotkeys1–6 preserve actual arsenal order")
	check(hud.inventory_slots().filter(func(slot): return slot.selected).size() == 1, "one selected slot")
	check(not hud.inventory_slots()[3].owned and not hud.inventory_slots()[4].owned and not hud.inventory_slots()[5].owned, "unowned heavy weapons remain dark")
	for id in [&"shotgun", &"twin_shotgun", &"rivet_cannon", &"siege_launcher"]: app.combat.grant_weapon(id, 7)
	app.combat.currentweapon = &"twin_shotgun"
	app.combat.health = 67
	app.combat.armor = 42
	hud.set_display_state(app.combat.get_hud_state(), stage, capacities)
	check(hud.inventory_slots()[3].owned and hud.inventory_slots()[3].selected, "actual Twin acquisition/switch lights owned selected4")
	check(hud.inventory_slots()[4].owned and not hud.inventory_slots()[4].selected, "owned Rivet differs from selected Twin")
	check(hud.text.contains("HEALTH 67") and hud.text.contains("ARMOR 42"), "damage/armor snapshot refresh")
	var previous_ammo: int = app.combat.ammo_shotgun
	app.combat.ammo_shotgun = maxi(0, previous_ammo - 2)
	hud.set_display_state(app.combat.get_hud_state(), stage, capacities)
	check(hud.active_ammunition().amount == app.combat.ammo_shotgun and hud.active_ammunition().capacity == capacities.shells, "partial shell use follows real shared Twin reserve")
	app.combat.currentweapon = &"melee"
	hud.set_display_state(app.combat.get_hud_state(), stage, capacities)
	check(hud.text.ends_with("READY") and hud.active_ammunition().kind == &"", "melee uses READY instead of fictional ammunition")
	# Deliberately hostile UI fixture: unvisited positive flag, visited false flag,
	# secrets/enemies/pickups, distant geometry. Consumer must filter and clip.
	var private_stage := {"visited_rooms": ["seen", "false_seen"], "map_rooms": [{"id": "seen", "visited": true, "rect": Rect2(-100, -100, 200, 200)}, {"id": "unvisited_secret", "visited": true, "rect": Rect2(-3, -3, 6, 6)}, {"id": "false_seen", "visited": false, "rect": Rect2(-4, -4, 8, 8)}], "brass_key": true, "red_key": false, "enemies": [Vector3.ZERO], "secret_found": true}
	hud.set_display_state(app.combat.get_hud_state(), private_stage, capacities)
	hud.update_map(private_stage, Vector3.ZERO, 0)
	check(hud.visible_map_rooms().size() == 1 and hud.visible_map_rooms()[0].id == "seen", "mini-map requires visited identity and visited flag; no secret reveal")
	check(hud.held_keys() == ["brass"], "brass icon appears only with actual supplied held flag")
	private_stage.red_key = true
	hud.set_display_state(app.combat.get_hud_state(), private_stage, capacities)
	check(hud.held_keys() == ["brass", "red"], "both held key icons visible")
	private_stage.brass_key = false; private_stage.red_key = false
	hud.set_display_state(app.combat.get_hud_state(), private_stage, capacities)
	check(hud.held_keys().is_empty(), "keys disappear immediately on clear/retry snapshot")
	var sizes := [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1440, 900), Vector2i(800, 600), Vector2i(640, 360)]
	for window_size in sizes:
		root.size = window_size
		await process_frame
		app.layout_view()
		hud.set_world_rect(Rect2(app.world_image.position, app.world_image.size))
		var layout: Dictionary = hud.layout_snapshot()
		var bounds := Rect2(Vector2.ZERO, hud.size)
		if window_size == Vector2i(1024, 768) or window_size == Vector2i(800, 600):
			check(hud.position.y >= app.world_image.position.y + app.world_image.size.y and hud.position.y + hud.size.y <= window_size.y, "%s uses lower letterbox without hiding weapon" % window_size)
		if window_size == Vector2i(640, 360):
			check(hud.size.y <= 56 and hud.position.y >= 304, "minimum native window reserves receiver/grip clearance with56pxbar")
		var names := ["health", "armor", "ammo", "inventory", "utility", "map"]
		for name in names:
			check(bounds.encloses(layout[name]), "%s %s stays within HUD" % [window_size, name])
		for i in names.size():
			for j in range(i + 1, names.size()): check(not layout[names[i]].intersects(layout[names[j]]), "%s %s/%s do not overlap" % [window_size, names[i], names[j]])
		check(layout.inventory.size.x / 6 >= (23 if layout.micro else 43), "%s six readable slot widths" % window_size)
		var screen: Rect2 = layout.map.grow(-10)
		screen.position.y += 17; screen.size.y -= 17
		for room in hud.minimap_geometry(): check(screen.encloses(room), "%s projected architecture clips to mini-map" % window_size)
		var before: Dictionary = hud.layout_snapshot()
		hud.set_minimap_enabled(false)
		check(not hud.minimap_enabled and before == hud.layout_snapshot(), "%s mini-map toggle never reflows status" % window_size)
		hud.set_minimap_enabled(true)
		layouts.append({"window": window_size, "world_rect": Rect2(app.world_image.position, app.world_image.size), "layout": layout})
		if capture:
			app.combat.currentweapon = &"twin_shotgun"
			app._process(0)
			app.hud.hide()
			var display_stage := stage.duplicate(true)
			display_stage.brass_key = true; display_stage.red_key = true
			hud.set_display_state(app.combat.get_hud_state(), display_stage, capacities)
			hud.update_map(display_stage, app.player.global_position, app.player.rotation.y)
			await process_frame; await process_frame
			RenderingServer.force_draw(false)
			var capture_path := "res://verification/production-v8/hud/fixture-%dx%d.png" % [window_size.x, window_size.y]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_path.get_base_dir()))
			root.get_texture().get_image().save_png(capture_path)
	# A new source state mimics retry without retaining any display-owned state.
	hud.set_display_state(original_combat, original_stage, capacities)
	check(hud.inventory_slots()[3].owned == original_combat.owned_weapons.has(&"twin_shotgun") and hud.held_keys().is_empty(), "fresh run snapshot clears previous inventory/key presentation")
	app.combat.currentweapon = &"twin_shotgun"
	var paused_state: Dictionary = app.combat.get_hud_state().duplicate(true)
	app.set_paused(true)
	hud.set_display_state(paused_state, app.world.get_level_state(), capacities)
	await process_frame
	check(app.combat.get_hud_state() == paused_state, "pause UI leaves combat state untouched")
	app.set_paused(false)
	var carried: Dictionary = app.campaign.capture(app.combat)
	app.level_complete = true
	app.continue_campaign()
	app.set_paused(true)
	hud.set_display_state(app.combat.get_hud_state(), app.world.get_level_state(), capacities)
	hud.update_map(app.world.get_level_state(), app.player.global_position, app.player.rotation.y)
	check(app.campaign.current_level().id == "pale_ward_02", "actual Main campaign transition exercised")
	check(hud.inventory_slots()[3].owned and hud.inventory_slots()[3].selected and hud.active_ammunition().amount == carried.ammo_shotgun, "actual level carry retains Twin ownership/selection/reserve")
	check(hud.held_keys().is_empty(), "actual next-level key flags do not leak")
	app.combat.health = 1
	app.combat.currentweapon = &"pistol"
	app.restart_combat()
	app.set_paused(true)
	hud.set_display_state(app.combat.get_hud_state(), app.world.get_level_state(), capacities)
	hud.update_map(app.world.get_level_state(), app.player.global_position, app.player.rotation.y)
	check(hud.text.contains("HEALTH %d" % carried.health) and hud.inventory_slots()[3].selected, "actual Retry redraws saved level-entry health and weapon")
	check(hud.visible_map_rooms().size() <= 1, "actual Retry mini-map clears previously visited architecture")
	hud.text = "MOVEMENT PREVIEW"
	check(hud.text == "MOVEMENT PREVIEW", "legacy movement preview setter remains compatible")
	var report := {"status": "passed" if failures.is_empty() else "failed", "checks": checks, "failures": failures, "layouts": layouts, "scope": "Actual source Main get_hud_state/get_level_state + read-only isolated UI. Controlled weapon grants, ammo and damage; actual pause, campaign continue and Retry. Synthetic privacy/key edge cases. Four native-window sizes across three aspect ratios. Not human visual acceptance or live traversal."}
	var path := "res://verification/production-v8/hud/checks.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("HUD_V8 ", report.status, " ", checks, " ", failures)
	await app.quit_game()
	quit(0 if failures.is_empty() else 1)
