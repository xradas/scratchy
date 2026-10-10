extends SceneTree
## Called by check_theme_pack.py with the trusted pinned editor. --main-pack
## mounts the archived executable's embedded PCK before resource resolution.
## This external probe never runs the shipped executable or the game loop.
var expected: Dictionary
var report := {"checks": 0, "failures": [], "enemies": {}, "stages": {}, "audio": {}, "packed": false}
var output := ""
const KINDS := ["unsealed", "vessel", "ironbound", "censer", "reaver", "surveyor"]
const ROSTERS := {"pale_ward": ["unsealed", "vessel"], "ash_citadel": ["ironbound", "censer"], "occupied_line": ["reaver", "surveyor"]}

func _initialize() -> void:
	var input := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected="): input = arg.trim_prefix("--expected=")
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
		if arg == "--packed": report.packed = true
	expected = JSON.parse_string(FileAccess.get_file_as_string(input))
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	report.checks += 1
	if not condition: report.failures.append(message); print("THEME_PACK_FAILURE: " + message)
	return condition

func json_file(path: String) -> Dictionary:
	if not check(FileAccess.file_exists(path), "runtime JSON exists: " + path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(data is Dictionary, "runtime JSON object: " + path): return {}
	check(FileAccess.get_sha256(path) == expected.files.get(path.trim_prefix("res://"), ""), "packed/source JSON bytes: " + path)
	return data

func pixel_identity(image: Image) -> Dictionary:
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var rgba := image.get_data()
	var alpha := PackedByteArray(); alpha.resize(image.get_width() * image.get_height())
	var visible := PackedByteArray()
	var opaque := 0
	for index in alpha.size():
		var value := rgba[index * 4 + 3]; alpha[index] = value
		if value >= 128:
			visible.append_array(rgba.slice(index * 4, index * 4 + 4)); opaque += 1
	var a := HashingContext.new(); a.start(HashingContext.HASH_SHA256); a.update(alpha)
	var b := HashingContext.new(); b.start(HashingContext.HASH_SHA256); b.update(visible)
	return {"dimensions": [image.get_width(), image.get_height()], "alpha_sha256": a.finish().hex_encode(), "opaque_rgba_sha256": b.finish().hex_encode(), "opaque_pixels": opaque}

func image_matches(image: Image, record: Dictionary, label: String) -> void:
	var actual := pixel_identity(image)
	for key in ["dimensions", "alpha_sha256", "opaque_rgba_sha256", "opaque_pixels"]:
		var matches: bool = actual[key] == record[key]
		if key == "dimensions": matches = int(actual[key][0]) == int(record[key][0]) and int(actual[key][1]) == int(record[key][1])
		check(matches, label + " native " + key)

func inspect_enemies(art: Dictionary) -> void:
	if not check(art.get("enemies", {}).size() == 6, "six registered species"): return
	var player := CharacterBody3D.new(); var camera := Camera3D.new(); camera.name = "Camera3D"; player.add_child(camera); root.add_child(player)
	player.position = Vector3(0, .85, -3)
	for kind in KINDS:
		if not check(art.enemies.has(kind), kind + " manifest entry"): continue
		var initial_failures: int = report.failures.size()
		var entry: Dictionary = art.enemies[kind]
		var identity: Dictionary = expected.enemies[kind]
		check(String(entry.file) == identity.path, kind + " runtime atlas path")
		if entry.has("sha256"): check(String(entry.sha256) == identity.sha256, kind + " registered original PNG hash")
		var texture: Texture2D = load(entry.file)
		if not check(texture != null, kind + " packed texture loads"): continue
		image_matches(texture.get_image(), identity.image, kind + " full atlas")
		var definition: Resource = load("res://resources/enemies/%s.tres" % kind)
		if not check(definition != null, kind + " packed definition loads"): continue
		check(String(definition.get("identifier")) == kind, kind + " definition identifier")
		for key in identity.definition: check(definition.get(key) == identity.definition[key], kind + " definition " + key)
		var scene: PackedScene = load("res://scenes/combat_enemy.tscn")
		if not check(scene != null, "packed combat enemy scene"): continue
		var enemy: Node3D = scene.instantiate(); enemy.set_physics_process(false); enemy.set("player", player); enemy.set("definition", definition); root.add_child(enemy)
		var foot: Array = entry.foot_pivot
		enemy.call("configure_sprite_sheet", entry.file, int(entry.columns), int(entry.directions), {}, float(entry.pixel_size), Vector2(foot[0], foot[1]), entry.sprite_options)
		var sprite: Sprite3D = enemy.get("sprite")
		if not check(sprite != null, kind + " packed sprite adapter"): enemy.free(); continue
		var data: Dictionary = enemy.get("sprite_data")
		var originals: Dictionary = data.poses.duplicate(true)
		for frame in identity.frames.size():
			data.poses.pain = [frame]; enemy.set("state", &"pain"); enemy.set("state_time", 0.0); enemy.call("update_presentation")
			check(int(enemy.get("sprite_frame")) == frame, "%s cell%d selected" % [kind, frame])
			var pivot: Array = entry.sprite_options.frame_pivots[str(frame)]
			check(enemy.get("sprite_foot") == Vector2(pivot[0], pivot[1]), "%s cell%d registered foot" % [kind, frame])
			if kind not in ["unsealed", "vessel"]:
				var region: Array = entry.sprite_options.source_regions[str(frame)]
				check(sprite.texture is AtlasTexture and sprite.hframes == 1 and sprite.vframes == 1, "%s cell%d native rectangle texture" % [kind, frame])
				if sprite.texture is AtlasTexture:
					check((sprite.texture as AtlasTexture).region == Rect2(region[0], region[1], region[2], region[3]), "%s cell%d authored source rectangle" % [kind, frame])
					image_matches(sprite.texture.get_image(), identity.frames[frame], "%s cell%d" % [kind, frame])
			else:
				check(sprite.texture == texture and sprite.hframes == int(entry.columns) and sprite.vframes == int(entry.sprite_options.rows) and sprite.frame == frame, "%s cell%d original grid frame" % [kind, frame])
				var size := Vector2i(texture.get_width() / sprite.hframes, texture.get_height() / sprite.vframes)
				var rect := Rect2i(Vector2i(frame % sprite.hframes, frame / sprite.hframes) * size, size)
				image_matches(sprite.texture.get_image().get_region(rect), identity.frames[frame], "%s cell%d" % [kind, frame])
		data.poses = originals
		report.enemies[kind] = {"path": entry.file, "original_png_sha256": identity.sha256, "native_alpha_verified": initial_failures == report.failures.size(), "frames_checked": identity.frames.size(), "native_adapter": kind not in ["unsealed", "vessel"]}
		enemy.free()
	player.free()

func inspect_stages(catalog: Dictionary) -> void:
	if not check(catalog.get("stages", []).size() == 3, "three runtime catalog stages"): return
	var seen := {}
	for stage in catalog.stages:
		var id := String(stage.id); seen[id] = true
		if not check(ROSTERS.has(id), "recognized themed stage " + id): continue
		check(stage.enemy_kinds == ROSTERS[id], id + " exclusive catalog roster")
		var scene: PackedScene = load(stage.scene)
		if not check(scene != null, id + " embedded authored scene"): continue
		var level := scene.instantiate()
		var markers := level.get_node_or_null("EnemySpawns")
		var roster := {}; var arena := {}
		if check(markers != null, id + " EnemySpawns present"):
			for marker in markers.get_children():
				var kind := String(marker.get_meta("kind", ""))
				check(kind in ROSTERS[id], id + " authored spawn thematic exclusivity: " + kind)
				check(marker.has_meta("arena_id"), id + " authored arena membership")
				roster[kind] = int(roster.get(kind, 0)) + 1
				var group := String(marker.get_meta("arena_id", "")); arena[group] = int(arena.get(group, 0)) + 1
		var same_roster: bool = roster.size() == expected.stages[id].roster.size()
		for kind in roster: same_roster = same_roster and int(roster[kind]) == int(expected.stages[id].roster.get(kind, -1))
		check(same_roster, id + " packed/source authored counts")
		check(roster.size() == 2 and markers != null and markers.get_child_count() >= 32 and markers.get_child_count() <= 44, id + " two species/32-44 authored enemies")
		report.stages[id] = {"scene": stage.scene, "music": stage.music, "roster": roster, "arena_counts": arena}
		level.free()
	check(seen.size() == 3, "three distinct stage identifiers")

func ogg_packet_identity(stream: Resource) -> String:
	var sequence: Resource = stream.get("packet_sequence")
	if not check(sequence != null, "Ogg packet sequence available"): return ""
	var pages: Array = sequence.get("packet_data")
	var hashing := HashingContext.new(); hashing.start(HashingContext.HASH_SHA256)
	for page in pages:
		for packet in page:
			var length := PackedByteArray(); length.resize(8); length.encode_u64(0, packet.size())
			hashing.update(length); hashing.update(packet)
	return hashing.finish().hex_encode()

func ogg_channels(stream: Resource) -> int:
	var sequence: Resource = stream.get("packet_sequence")
	if sequence == null: return 0
	var pages: Array = sequence.get("packet_data")
	for page in pages:
		for packet in page:
			if packet.size() >= 30 and packet[0] == 1 and packet.slice(1, 7).get_string_from_ascii() == "vorbis": return int(packet[11])
	return 0

func inspect_audio(ledger: Dictionary) -> void:
	check(ledger.get("cues", {}).size() == 35, "35 runtime audio cues")
	var profile: Resource = load("res://resources/combat_audio.tres")
	if not check(profile != null, "packed combat audio profile"): return
	var cues: Array = profile.get("cues")
	check(cues.size() == 35, "35 profile cues")
	var seen := {}; var creature_paths := {}
	for cue in cues:
		var id := String(cue.get("identifier"))
		check(not seen.has(id), "distinct cue " + id); seen[id] = true
		if not check(expected.audio.has(id), "expected audio cue " + id): continue
		var record: Dictionary = expected.audio[id]
		var variations: Array = cue.get("variations")
		if not check(variations.size() == 1, id + " single registered stream"): continue
		var stream: Resource = variations[0]
		check(stream.resource_path == record.path, id + " packed source stream path")
		check(String(cue.get("bus")) == record.bus and bool(cue.get("spatial")) == record.spatial, id + " bus/spatial routing")
		check(stream.get_length() > 0 and ogg_packet_identity(stream) == record.packet_sha256, id + " exact original Vorbis packets")
		if id in expected.creature_cues:
			check(record.bus == "Creatures", id + " creature bus")
			check(ogg_channels(stream) == 1, id + " mono positional voice")
			creature_paths[stream.resource_path] = true
	check(creature_paths.size() == 18, "18 distinct creature paths for six species")
	for id in expected.music:
		var record: Dictionary = expected.music[id]
		var stream: Resource = load(record.path)
		if not check(stream != null, id + " packed music stream"): continue
		check(ogg_channels(stream) == 2 and stream.get_length() > 0, id + " stereo full track")
		check(ogg_packet_identity(stream) == record.packet_sha256, id + " exact original Vorbis packets")
	report.audio = {"cue_count": cues.size(), "creature_paths": creature_paths.keys(), "stereo_music_tracks": expected.music.keys()}

func inspect_engine_licenses() -> void:
	var license_text := Engine.get_license_text()
	var notices := "Bundled Godot component copyright records\n\n" + JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\n"
	var licenses := Engine.get_license_info()
	for name in licenses: notices += str(name) + "\n" + str(licenses[name]) + "\n\n"
	report.engine_license_sha256 = license_text.sha256_text(); report.engine_notices_sha256 = notices.sha256_text()
	if expected.has("engine_license_sha256"):
		check(report.engine_license_sha256 == expected.engine_license_sha256, "archived license equals trusted pinned Engine query")
		check(report.engine_notices_sha256 == expected.engine_notices_sha256, "archived component notices equal trusted pinned Engine query")

func same_resource_value(actual: Variant, wanted: Variant) -> bool:
	if actual is Texture2D: return actual.resource_path == wanted
	if actual is Vector2: actual = [actual.x, actual.y]
	elif actual is Rect2: actual = [actual.position.x, actual.position.y, actual.size.x, actual.size.y]
	elif actual is Color: actual = [actual.r, actual.g, actual.b, actual.a]
	if actual is Dictionary and wanted is Dictionary:
		if actual.size() != wanted.size(): return false
		for key in wanted:
			if not actual.has(key) or not same_resource_value(actual[key], wanted[key]): return false
		return true
	if actual is Array and wanted is Array:
		if actual.size() != wanted.size(): return false
		for index in wanted.size():
			if not same_resource_value(actual[index], wanted[index]): return false
		return true
	if (actual is int or actual is float) and (wanted is int or wanted is float): return absf(float(actual) - float(wanted)) < .00001
	return actual == wanted

func inspect_gore() -> void:
	var profile: Resource = load("res://resources/gore_profile.tres")
	if not check(profile != null, "packed runtime gore profile"): return
	for key in expected.gore.profile_properties:
		check(same_resource_value(profile.get(key), expected.gore.profile_properties[key]), "gore profile original property: " + key)
	check(same_resource_value(profile.get("pools"), expected.gore.pools) and same_resource_value(profile.get("remains"), expected.gore.remains), "original gore-v1 pool/remains fallbacks preserved")
	var species: Dictionary = profile.get("species_atlases")
	check(species.size() == 6, "six packed species gore atlas registrations")
	var parts := 0
	for kind in KINDS:
		if not check(species.has(kind), kind + " gore species registration"): continue
		check(same_resource_value(species[kind], expected.gore.species[kind]), kind + " exact native gore regions/parts/materials")
		check(species[kind].parts.size() == int(expected.gore.profile_properties.gib_counts[kind]), kind + " explicit gib-count part coverage")
		parts += species[kind].parts.size()
	for path in expected.gore.atlases:
		var texture: Texture2D = load(path)
		if not check(texture != null, "packed native gore atlas: " + path): continue
		image_matches(texture.get_image(), expected.gore.atlases[path].image, path)
	report.gore = {"species_count": species.size(), "registered_part_count": parts, "native_atlas_paths": expected.gore.atlases.keys(), "three_gore_v2_native_atlases": true, "runtime_profile_verified": true}

func run() -> void:
	var art := json_file("res://assets/combat_art.json")
	var catalog := json_file("res://resources/stages/catalog.json")
	var ledger := json_file("res://assets/audio/runtime-cues.json")
	if not art.is_empty(): inspect_enemies(art)
	if not catalog.is_empty(): inspect_stages(catalog)
	if not ledger.is_empty(): inspect_audio(ledger)
	inspect_gore()
	inspect_engine_licenses()
	report.pass = report.failures.is_empty()
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
	print("THEME_PACK_%s: %d checks; %d failures; packed=%s" % ["OK" if report.pass else "FAILED", report.checks, report.failures.size(), report.packed])
	quit(0 if report.pass else 1)
