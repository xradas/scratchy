extends SceneTree
## Focused, campaign-layout-independent staff presentation and wake-up check.
## Run: tools/godot.sh --headless --script res://tools/check_staff_v19.gd

class CombatSink extends Node3D:
	var events: Array[Dictionary] = []
	var camera: Camera3D
	func emit_event(event: Dictionary) -> void:
		events.append(event)

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("STAFF_V19: " + label)

func make_staff(kind: String, player: CharacterBody3D) -> CharacterBody3D:
	var enemy: CharacterBody3D = preload("res://scenes/combat_enemy.tscn").instantiate()
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.player = player
	enemy.definition = load("res://resources/enemies/%s.tres" % kind)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json"))
	var data: Dictionary = manifest.enemies[kind]
	var clips := {}
	for key in data.clips:
		clips[StringName(key)] = Vector2i(data.clips[key][0], data.clips[key][1])
	enemy.configure_sprite_sheet(data.file, data.columns, data.directions, clips, data.pixel_size, Vector2(data.foot_pivot[0], data.foot_pivot[1]), data.sprite_options)
	return enemy

func check_walk(enemy: CharacterBody3D, kind: String) -> void:
	var expected := [1, 0, 2, 0]
	for i in expected.size():
		enemy.state = &"chase"
		enemy.state_time = float(i) / 9.0 + 0.001
		enemy.update_sprite()
		check(enemy.sprite_frame == expected[i], "%s left/neutral/right/neutral phase %d" % [kind, i])

func run() -> void:
	var player := CharacterBody3D.new()
	root.add_child(player)
	player.global_position = Vector3(0, 0, -4)
	var scientist := make_staff("infected_scientist", player)
	check_walk(scientist, "scientist")
	var security := make_staff("infected_security", player)
	check_walk(security, "security")
	security.state = &"windup"
	security.state_time = 0.0
	security.update_sprite()
	check(security.sprite_frame == 3, "front windup selects frame 3")
	check((security.sprite.texture as AtlasTexture).atlas.resource_path.ends_with("infected_security-front-attack.png"), "front windup uses player-facing art")
	check(absf(security.sprite_projectile_origin().x) < 0.05, "front windup muzzle centred")
	security.state = &"recovery"
	security.update_sprite()
	check(security.sprite_frame == 4, "front release selects frame 4")
	check((security.sprite.texture as AtlasTexture).atlas.resource_path.ends_with("infected_security-front-attack.png"), "front release uses player-facing art")
	check(absf(security.sprite_projectile_origin().x) < 0.05, "front release muzzle centred")
	player.global_position = Vector3(-4, 0, 0)
	security.state = &"windup"
	security.update_sprite()
	check(security.sprite_frame == 19, "side windup selects original directional row")
	check((security.sprite.texture as AtlasTexture).atlas.resource_path.ends_with("infected_security-atlas.png"), "side view restores original atlas")
	var sink := CombatSink.new()
	root.add_child(sink)
	sink.camera = Camera3D.new()
	sink.add_child(sink.camera)
	security.combat = sink
	security.awake = false
	security.announce_detection()
	check(sink.events.is_empty(), "asleep enemy has no detection cue")
	security.awake = true
	security.announce_detection()
	security.announce_detection()
	check(sink.events.size() == 1 and sink.events[0].type == &"enemy_detect", "wake emits exactly one detection cue")
	sink.events.clear()
	security.detection_emitted = false
	security.awake = false
	security.health = 100.0
	security.apply_damage(1.0, 17, &"pistol", security.global_position)
	check(sink.events.size() == 2 and sink.events[0].type == &"enemy_detect" and sink.events[1].type == &"enemy_hurt", "nonlethal wake cue precedes hurt")
	sink.events.clear()
	security.dead = true
	security.detection_emitted = false
	security.announce_detection()
	check(sink.events.is_empty(), "dead enemy cannot detect")
	if failures.is_empty():
		print("STAFF_V19 PASS: %d checks" % checks)
		quit(0)
	else:
		print("STAFF_V19 FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)
