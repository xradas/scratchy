extends "check_theme_pack.gd"
## Trusted external PCK reader. Inherits the original independent six-species,
## audio, gore, archive-resource probe, and adds native gun and stage mechanisms.
const GUNS := ["pistol", "shotgun", "melee", "twin_shotgun", "rivet_cannon", "siege_launcher"]
const NEW_GUNS := ["twin_shotgun", "rivet_cannon", "siege_launcher"]
const PHASES := ["idle", "fire", "recover", "switch"]
var fixture_app: Control

func inspect_arsenal(art: Dictionary) -> void:
	check(art.get("weapons", {}).size() == 6, "six packed weapon registrations")
	check(art.get("weapon_atlases", {}).size() == 6, "six packed native weapon atlas registrations")
	report.weapons = {}
	for id in GUNS:
		if not check(art.get("weapons", {}).has(id) and expected.weapons.has(id), id + " packed weapon registration"): continue
		var identity: Dictionary = expected.weapons[id]
		var texture: Texture2D = load(identity.path)
		if not check(texture != null, id + " native packed gun atlas"): continue
		image_matches(texture.get_image(), identity.image, id + " complete gun atlas")
		var definition: Resource = load("res://resources/weapons/%s.tres" % id)
		if not check(definition != null, id + " packed weapon resource"): continue
		for key in identity.definition:
			check(same_resource_value(definition.get(key), identity.definition[key]), id + " definition " + key)
		if id in NEW_GUNS: check(int(definition.get("ammo_cost")) > 0, id + " positive ammo_cost")
		var entry: Dictionary = art.weapon_atlases[id]
		check(same_resource_value(entry, identity.atlas), id + " exact authored native region/placement metadata")
		var alpha_record := {}
		if id in NEW_GUNS: alpha_record = inspect_loaded_native_alpha(texture.get_image(), entry, id)
		for phase in PHASES:
			check(art.weapons[id].get(phase, "") == identity.path, id + " " + phase + " source path")
			var values: Array = entry.regions[phase]
			var region := Rect2(values[0], values[1], values[2], values[3])
			var adapter := AtlasTexture.new(); adapter.atlas = texture; adapter.region = region; adapter.filter_clip = true
			image_matches(adapter.get_image(), identity.frames[phase], id + " " + phase + " native region")
			check(same_resource_value(art.flash.anchors[id].get(phase), identity.anchors.get(phase)), id + " " + phase + " flash marker")
		report.weapons[id] = {"source_path": identity.path, "source_sha256": identity.sha256, "phases": 4, "ammo_cost": definition.get("ammo_cost"), "native_alpha": alpha_record}

func inspect_loaded_native_alpha(image: Image, entry: Dictionary, id: String) -> Dictionary:
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var pixels := image.get_data()
	var width := image.get_width(); var height := image.get_height()
	var covered := PackedByteArray(); covered.resize(width * height)
	var result := {"phases": {}, "uncovered_visible_pixels": 0, "source_dimensions": [width, height]}
	for phase in PHASES:
		var values: Array = entry.regions[phase]
		var x := int(values[0]); var y := int(values[1]); var w := int(values[2]); var h := int(values[3])
		if not check(x >= 0 and y >= 0 and w > 0 and h > 0 and x+w <= width and y+h <= height, id + " " + phase + " native alpha region inside loaded image"): continue
		var exact := {"left": 0, "right": 0, "top": 0, "bottom": 0}
		var visible := {"left": 0, "right": 0, "top": 0, "bottom": 0}
		var minimum := Vector2i(w, h); var maximum := Vector2i(-1, -1); var occupied := 0
		for local_y in h:
			for local_x in w:
				var offset := (y+local_y)*width+x+local_x
				covered[offset] = 1
				var alpha: int = pixels[offset*4+3]
				if alpha > 5:
					occupied += 1
					minimum.x = mini(minimum.x,local_x); minimum.y = mini(minimum.y,local_y)
					maximum.x = maxi(maximum.x,local_x); maximum.y = maxi(maximum.y,local_y)
		for side in exact:
			var count: int = h if side in ["left", "right"] else w
			for edge_index in count:
				var edge_x: int = x if side == "left" else (x+w-1 if side == "right" else x+edge_index)
				var edge_y: int = y if side == "top" else (y+h-1 if side == "bottom" else y+edge_index)
				var alpha: int = pixels[(edge_y*width+edge_x)*4+3]
				if alpha > 0: exact[side] += 1
				if alpha > 5: visible[side] += 1
		var internal := {"left":x>0, "right":x+w<width, "top":y>0, "bottom":y+h<height}
		for side in internal:
			if internal[side]: check(exact[side] == 0, id + " " + phase + " loaded pixel internal " + side + " separator alpha-zero")
			elif side != "bottom": check(visible[side] == 0, id + " " + phase + " loaded pixel exterior " + side + " clear of visible clipping")
		check(occupied > 0, id + " " + phase + " loaded native alpha nonempty")
		result.phases[phase] = {"region":values, "alpha_bounds_local":[minimum.x,minimum.y,maximum.x-minimum.x+1,maximum.y-minimum.y+1], "occupied_pixels_above_5":occupied, "edge_exact_nonzero_pixels":exact, "edge_visible_pixels_above_5":visible, "internal_edges":internal}
	for offset in covered.size():
		if covered[offset] == 0 and pixels[offset*4+3] > 5: result.uncovered_visible_pixels += 1
	check(result.uncovered_visible_pixels == 0, id + " loaded image has no visible pixels excluded by phase regions")
	return result

func architecture_materials(node: Node, regions: Dictionary, path: String, used: Dictionary) -> void:
	var materials: Array = []
	if node is MeshInstance3D:
		if node.material_override != null: materials.append(node.material_override)
		if node.mesh != null:
			for surface in node.mesh.get_surface_count():
				var material: Material = node.get_surface_override_material(surface)
				if material == null: material = node.mesh.surface_get_material(surface)
				if material != null: materials.append(material)
	if node.has_meta("polygon_material"): materials.append(node.get_meta("polygon_material"))
	for material in materials:
		var actual_region := Rect2()
		var actual_path := ""
		if material is ShaderMaterial:
			var painted: Variant = material.get_shader_parameter("painted_surface")
			var native: Variant = material.get_shader_parameter("source_region_pixels")
			if painted is Texture2D and native is Vector4:
				actual_path = painted.resource_path
				actual_region = Rect2(native.x,native.y,native.z,native.w)
		elif material is BaseMaterial3D:
			var texture: Texture2D = material.albedo_texture
			if texture is AtlasTexture and texture.atlas != null:
				actual_path = texture.atlas.resource_path; actual_region = texture.region
		if actual_path != path: continue
		for name in ["floor", "wall", "ceiling"]:
			var values: Array = regions[name]
			if actual_region == Rect2(values[0], values[1], values[2], values[3]): used[name] = true
	for child in node.get_children(): architecture_materials(child, regions, path, used)

func inspect_audio(ledger: Dictionary) -> void:
	check(ledger.get("cues", {}).size() == int(expected.audio_cue_count) and expected.audio_cue_count >= 48, "original35 plus at least13 new runtime audio cues")
	var profile: Resource = load("res://resources/combat_audio.tres")
	if not check(profile != null, "packed combat audio profile"): return
	var cues: Array = profile.get("cues")
	check(cues.size() == int(expected.audio_cue_count), "full runtime profile cue count")
	var seen := {}; var creature_paths := {}
	for cue in cues:
		var id := String(cue.get("identifier"))
		check(not seen.has(id), "distinct cue " + id); seen[id] = true
		if not check(expected.audio.has(id), "expected audio cue " + id): continue
		var record: Dictionary = expected.audio[id]
		if expected.legacy_audio.profile_cues.has(id):
			for key in expected.legacy_audio.profile_cues[id]:
				check(same_resource_value(cue.get(key), expected.legacy_audio.profile_cues[id][key]), id + " original cue property " + key)
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
	report.audio = {"cue_count": cues.size(), "original_cues_retained": expected.legacy_audio.cues.size(), "new_cue_count": cues.size()-expected.legacy_audio.cues.size(), "creature_paths": creature_paths.keys(), "stereo_music_tracks": expected.music.keys()}


func inspect_architecture() -> void:
	var contract := json_file(expected.architecture.manifest)
	if contract.is_empty(): return
	report.architecture = {}
	for id in expected.architecture.stages:
		var identity: Dictionary = expected.architecture.stages[id]
		var texture: Texture2D = load(identity.path)
		if not check(texture != null, id + " native architecture PNG atlas loads"): continue
		image_matches(texture.get_image(), identity.image, id + " architecture complete native atlas")
		for name in ["floor", "wall", "ceiling"]:
			var values: Array = identity.regions[name]
			var adapter := AtlasTexture.new(); adapter.atlas = texture; adapter.region = Rect2(values[0], values[1], values[2], values[3]); adapter.filter_clip = true
			image_matches(adapter.get_image(), identity.cells[name], id + " architecture " + name + " native cell")
		report.architecture[id] = {"atlas": identity.path, "regions": identity.regions, "source_sha256": identity.sha256}

func freeze_actors() -> void:
	fixture_app.automated_input = true
	fixture_app.player.set_physics_process(false)
	for enemy in fixture_app.combat.enemies: enemy.set_physics_process(false)

func inspect_actual_main_fixtures() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	if not check(main_scene != null, "packed actual Main loads"): return
	fixture_app = main_scene.instantiate(); root.add_child(fixture_app)
	freeze_actors()
	report.ambushes = {}
	for index in fixture_app.stage_catalog.size():
		fixture_app.stage_selector.select(index); fixture_app.stage_selector.item_selected.emit(index)
		freeze_actors()
		fixture_app.enter_combat(); freeze_actors()
		var id: String = fixture_app.stage_id
		var world: Node3D = fixture_app.world
		var combat: Node = fixture_app.combat
		for owned in expected.ownership.starts_owned: check(combat.has_weapon(StringName(owned)), id + " starting owned " + owned)
		for unowned in expected.ownership.starts_unowned: check(not combat.has_weapon(StringName(unowned)), id + " starts unowned " + unowned)
		var native_arch: Dictionary = expected.architecture.stages[id]
		var used := {}; architecture_materials(world, native_arch.regions, native_arch.path, used)
		for name in ["floor", "wall", "ceiling"]: check(used.has(name), id + " physical architecture uses distinct " + name + " cell")
		var route := json_file("res://resources/stages/%s-route.json" % id)
		check(route.get("vertical_routes", {}).size() >= 1, id + " authored elevation route")
		check(route.get("combat_paths", {}).size() >= 1, id + " authored combat route splits")
		var trap_records := {}
		check(world.traps.size() == 3, id + " three runtime bait traps")
		for arena in ["arena_one", "arena_two", "final_arena"]:
			if not check(world.traps.has(arena), id + " trap " + arena): continue
			var bait: Node3D
			for item in world.pickups:
				if String(item.get_meta("bait_arena", "")) == arena: bait = item
			if not check(bait != null, id + " " + arena + " physical bait pickup"): continue
			var weapon := String(bait.get_meta("stage_pickup", ""))
			check(weapon in NEW_GUNS, id + " " + arena + " bait has new gun")
			check(not world.traps[arena].triggered, id + " " + arena + " starts untriggered")
			check(world.trap_entries[arena].is_open(), id + " " + arena + " initial entry raised")
			for shutter in world.trap_shutters.get(arena, []): check(shutter.is_closed(), id + " " + arena + " initial closet shutter closed")
			check(world.trap_entries.has(arena) and world.trap_shutters.get(arena, []).size() >= 2, id + " " + arena + " physical entry and closet shutters")
			fixture_app.player.global_position = bait.global_position
			world.update_player(fixture_app.player, combat)
			check(world.traps[arena].triggered and not bait.visible, id + " " + arena + " actual collection triggers trap")
			check(combat.has_weapon(StringName(weapon)), id + " " + arena + " actual collection grants ownership")
			for tick in 125:
				await physics_frame
			check(world.traps[arena].shutters_open, id + " " + arena + " triggered shutters open")
			check(world.traps[arena].latched, id + " " + arena + " triggered entry latched")
			check(world.is_arena_active(arena), id + " " + arena + " enemies activated after opening")
			var awake := 0
			for enemy in combat.enemies:
				check(String(enemy.definition.identifier) in ROSTERS[id], id + " theme-exclusive runtime threat")
				if String(enemy.get_meta("arena_id", "")) == arena and enemy.awake: awake += 1
			check(awake > 0, id + " " + arena + " actual trapped roster awake")
			trap_records[arena] = {"weapon": weapon, "physical_bait_hidden": not bait.visible, "ownership": combat.has_weapon(StringName(weapon)), "trap_state": world.traps[arena].duplicate(true), "awake_enemies": awake}
		report.ambushes[id] = {"traps": trap_records, "architecture_cells_used": used.keys(), "enemy_count": combat.enemies.size()}
	paused = true
	fixture_app.free()
	report.fixture_scope = "Actual Main, physical authored bait collections and timed mechanism state; camera/actor teleport fixtures and enemy AI physics disabled. Does not establish input-driven route completion or ordinary combat."

func run() -> void:
	var art := json_file("res://assets/combat_art.json")
	if not art.is_empty(): inspect_arsenal(art)
	inspect_architecture()
	await inspect_actual_main_fixtures()
	super.run()
