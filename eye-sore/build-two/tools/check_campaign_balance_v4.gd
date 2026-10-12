extends SceneTree
## Bounded Main flow fixture. Real combat routes are checked separately.
var app: Control
var failures: Array[String] = []
var observations: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func require(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func ammo() -> Dictionary:
	return {"pistol": app.combat.ammo_pistol, "shells": app.combat.ammo_shotgun, "rivets": app.combat.ammo_rivets, "rockets": app.combat.ammo_rockets}

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.start_new_campaign()
	await process_frame
	var caps := {"pistol": app.combat.ammo_capacity(&"pistol"), "shells": app.combat.ammo_capacity(&"shells"), "rivets": app.combat.ammo_capacity(&"rivets"), "rockets": app.combat.ammo_capacity(&"rockets")}
	require(caps == {"pistol": 96, "shells": 40, "rivets": 160, "rockets": 12}, "campaign capacity Resource differs")
	# Entry snapshot precedes ordinary nearby-item contact on the first frame.
	var initial: Dictionary = app.campaign.entry_snapshot.duplicate(true)
	require(initial.health == 100.0 and initial.armor == 50.0 and initial.ammo_pistol == 36 and initial.ammo_shotgun == 12 and initial.ammo_rivets == 0 and initial.ammo_rockets == 0 and initial.owned_weapons.size() == 3, "New Game is not normal initial loadout")
	# Simulate a legacy/overfilled carried state at the boundary. Completion
	# and Continue are real Main methods; the new combat world must normalize.
	app.combat.ammo_pistol = 109
	app.combat.ammo_shotgun = 53
	app.combat.ammo_rivets = 173
	app.combat.ammo_rockets = 25
	app.combat.health = 72
	app.combat.armor = 19
	app.world.completed.emit()
	await process_frame
	require(app.level_complete and paused, "Main completion did not pause")
	app.enter_combat()
	require(app.campaign.entry_snapshot.health == 72.0 and app.campaign.entry_snapshot.armor == 19.0, "health/armor exit carry not saved at next-level entry")
	await process_frame
	require(app.campaign.current_index == 1 and not paused, "Continue did not load Ward 02")
	require(ammo() == caps, "carried ammo was not normalized in new campaign world")
	var entry: Dictionary = app.campaign.entry_snapshot.duplicate(true)
	require(entry.ammo_pistol == 96 and entry.ammo_shotgun == 40 and entry.ammo_rivets == 160 and entry.ammo_rockets == 12, "retry snapshot predates normalization")
	app.combat.ammo_pistol = 0
	app.combat.ammo_shotgun = 0
	app.combat.ammo_rivets = 0
	app.combat.ammo_rockets = 0
	app.restart_combat()
	require(app.combat.health == entry.health and app.combat.armor == entry.armor, "Retry failed to restore level-entry health/armor before ordinary pickups")
	await process_frame
	require(ammo() == caps and app.campaign.current_index == 1, "Retry failed to restore normalized level-entry state")
	require(not app.combat.add_ammo(&"rockets", 8), "full campaign ammo accepted a pickup")
	app.combat.ammo_rockets = 11
	require(app.combat.add_ammo(&"rockets", 8) and app.combat.ammo_rockets == 12, "partial campaign ammo was not clamped to remaining capacity")
	app.combat.currentweapon = &"siege_launcher"
	app._process(0.0)
	require("SIEGE LAUNCHER    AMMO 12/12" in app.hud.text, "campaign HUD lacks selected gun ammo/cap")
	var sizes: Array = [Vector2(320, 180), Vector2(640, 360), Vector2(800, 600), Vector2(1280, 720)]
	var measured: Array = []
	for dimensions in sizes:
		app.size = dimensions
		app.layout_view()
		app._process(0.0)
		var font: Font = app.hud.get_theme_font("font")
		var font_size: int = app.hud.get_theme_font_size("font_size")
		var text_size: Vector2 = font.get_multiline_string_size(app.hud.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		measured.append({"window": dimensions, "hud_width": app.hud.size.x, "hud_height": app.hud.size.y, "text_width": text_size.x, "text_height": text_size.y, "font_size": font_size})
		require(text_size.x <= app.hud.size.x - 28.0, "HUD clipped horizontally at " + str(dimensions))
		require(text_size.y <= app.hud.size.y - 8.0, "HUD clipped vertically at " + str(dimensions))
	observations = {"initial": initial, "caps": caps, "normalized_entry": entry, "ammo_after_retry": ammo(), "hud": measured}
	finish()

func finish() -> void:
	var result := {"status": "passed" if failures.is_empty() else "failed", "failures": failures, "observations": observations, "scope": "Main New Game/Continue/Retry normalization and selected-weapon HUD bounds; deliberate overfill probes transition policy, not gameplay-earned supplies or a physical level route."}
	var path := ProjectSettings.globalize_path("res://verification/combat-balance-v4/flow.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  "))
		file.close()
	if failures.is_empty():
		print("CAMPAIGN_BALANCE_FLOW:PASS ", path)
		await app.quit_game()
	else:
		for failure in failures: push_error("CAMPAIGN_BALANCE_FLOW: " + failure)
		quit(1)
