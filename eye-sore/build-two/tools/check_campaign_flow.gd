extends SceneTree

## Functional campaign fixture. It emits the real stage completion signal at each
## authored exit, without claiming to solve the nine physical routes.
var app: Control
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func require(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	require(app.campaign.levels.size() == 9, "catalog must contain nine connected levels")
	if app.campaign.levels.size() != 9:
		finish()
		return
	app.start_new_campaign()
	await process_frame
	require(app.campaign_mode and app.campaign.current_index == 0, "New Game starts at first level")
	require(app.campaign.entry_snapshot.owned_weapons.size() == 3, "normal campaign start owns three weapons")
	var locked_key := InputEventKey.new()
	locked_key.keycode = KEY_4
	locked_key.pressed = true
	app._input(locked_key)
	require(app.weapon_hint_time > 0.0 and "Ward Intake" in app.weapon_hint, "locked weapon shows its pickup location")
	app.combat.health = 72.0
	app.combat.armor = 19.0
	app.combat.ammo_pistol = 17
	app.combat.ammo_shotgun = 8
	app.combat.grant_weapon(&"twin_shotgun")
	app.combat.grant_weapon(&"rivet_cannon")
	app.combat.grant_weapon(&"siege_launcher")
	app.combat.ammo_rivets = 9
	app.combat.ammo_rockets = 3
	var old_world: Node = app.world
	for index in 9:
		var level: Dictionary = app.campaign.current_level()
		require(app.campaign.current_index == index, "sequence index %d" % index)
		require(app.world.scene_file_path == String(level.scene), "scene for " + String(level.id))
		require(String(app.world.get_meta("stage_id", "")) == String(level.theme), "theme metadata for " + String(level.id))
		var theme: Dictionary = app.selected_stage()
		require(app.combat_audio.profile.music.resource_path == String(theme.music), "music for " + String(level.id))
		for enemy in app.combat.enemies:
			require(String(enemy.definition.identifier) in theme.enemy_kinds, "creature theme for " + String(level.id))
		if index == 1:
			# Entry snapshot is made after the first transition. Death and retry must
			# discard damage/pickups from this attempt only.
			var entry: Dictionary = app.campaign.entry_snapshot.duplicate(true)
			app.combat.health = 1.0
			app.combat.ammo_pistol = 0
			app.combat.owned_weapons.erase(&"siege_launcher")
			app.restart_combat()
			await process_frame
			require(app.combat.health == entry.health and app.combat.ammo_pistol == entry.ammo_pistol and app.combat.has_weapon(&"siege_launcher"), "retry restores level-entry carry")
			require(app.campaign.current_index == index and app.world != old_world, "retry rebuilds same level")
		if index > 0:
			require(app.combat.health == 72.0 and app.combat.armor == 19.0, "vitals carry into " + String(level.id))
			require(app.combat.ammo_pistol == 17 and app.combat.ammo_shotgun == 8, "light ammo carries into " + String(level.id))
			require(app.combat.ammo_rivets == 9 and app.combat.ammo_rockets == 3, "heavy ammo carries into " + String(level.id))
			require(app.combat.has_weapon(&"twin_shotgun") and app.combat.has_weapon(&"rivet_cannon") and app.combat.has_weapon(&"siege_launcher"), "ownership carries into " + String(level.id))
		var prior_chapter: String = String(level.chapter_id)
		old_world = app.world
		var old_audio: Node = app.combat_audio
		app.world.completed.emit()
		await process_frame
		require(app.level_complete and paused, "clear pauses at " + String(level.id))
		app.world.completed.emit()
		require(app.campaign.current_index == index, "repeated completion does not advance " + String(level.id))
		if index == 8:
			require(app.resume_button.text == "New Game" and app.menu_title.text == "CAMPAIGN COMPLETE", "finale screen")
			break
		var next: Dictionary = app.campaign.next_level()
		require(app.resume_button.text == "Continue", "continue action at " + String(level.id))
		require(app.menu_title.text == ("CHAPTER CLEARED" if prior_chapter != String(next.chapter_id) else "LEVEL CLEARED"), "chapter boundary at " + String(level.id))
		app.enter_combat()
		await process_frame
		require(app.world != old_world and not paused and not app.level_complete, "transition rebuilds and resumes " + String(next.id))
		require(not is_instance_valid(old_world) and not is_instance_valid(old_audio), "old world/audio freed before " + String(next.id))
		require(app.automap.state.is_empty(), "fresh automap for " + String(next.id))
	app.enter_combat()
	await process_frame
	require(app.campaign.current_index == 0 and not app.level_complete, "New Game from finale restarts campaign")
	finish()

func finish() -> void:
	if failures.is_empty():
		print("CAMPAIGN_FLOW:PASS")
		await app.quit_game()
	else:
		for failure in failures: push_error("CAMPAIGN_FLOW: " + failure)
		quit(1)
