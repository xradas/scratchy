extends "check_arsenal_ambush_release.gd"
## External pinned-Godot source or --main-pack probe. The inherited reader checks
## original enemy/audio/gore bytes, all six native gun atlases, architecture and
## stage fixtures. This layer validates nine campaign resources and carry UI.

func inspect_loaded_native_alpha(image: Image, entry: Dictionary, id: String) -> Dictionary:
	# The generated new Rivet sheet has a few 1/255 separator pixels. The full
	# atlas identity is already checked byte-for-byte against source. Reject any
	# visible (>5/255) clipping while retaining the native PNG unchanged.
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var pixels := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var covered := PackedByteArray()
	covered.resize(width * height)
	var result := {"phases":{},"uncovered_visible_pixels":0,"source_dimensions":[width,height]}
	for phase in PHASES:
		var values: Array = entry.regions[phase]
		var x := int(values[0]); var y := int(values[1]); var w := int(values[2]); var h := int(values[3])
		if not check(x>=0 and y>=0 and w>0 and h>0 and x+w<=width and y+h<=height,id+" "+phase+" native rectangle inside loaded image"): continue
		var occupied := 0
		var visible_edge := {"left":0,"right":0,"top":0,"bottom":0}
		for yy in h:
			for xx in w:
				var offset := (y+yy)*width+x+xx
				covered[offset] = 1
				var alpha: int = pixels[offset*4+3]
				if alpha <= 5: continue
				occupied += 1
				if xx==0: visible_edge.left += 1
				if xx==w-1: visible_edge.right += 1
				if yy==0: visible_edge.top += 1
				if yy==h-1: visible_edge.bottom += 1
		check(occupied>0,id+" "+phase+" visible native alpha")
		for side in visible_edge:
			if side=="bottom" and y+h==height: continue
			check(visible_edge[side]==0,id+" "+phase+" no visible alpha clipped at "+side)
		result.phases[phase]={"region":values,"occupied_pixels_above_5":occupied,"visible_edge_pixels_above_5":visible_edge}
	for offset in covered.size():
		if covered[offset]==0 and pixels[offset*4+3]>5: result.uncovered_visible_pixels += 1
	check(result.uncovered_visible_pixels==0,id+" no visible alpha outside four native rectangles")
	return result

func inspect_campaign_resources() -> void:
	var catalog := json_file("res://resources/campaign/catalog.json")
	var seeds := json_file("res://resources/campaign/route-seeds.json")
	if catalog.is_empty() or seeds.is_empty(): return
	var levels: Array = []
	for chapter in catalog.chapters:
		for level in chapter.levels: levels.append(level)
	check(catalog.chapters.size()==3 and levels.size()==9,"packed 3-chapter/9-level catalog")
	check(seeds.get("seeds",{}).size()==9,"packed nine route seed records")
	report.campaign={"levels":{},"chapters":catalog.chapters.size(),"seed_records":seeds.get("seeds",{}).size()}
	for level in levels:
		var id := String(level.id)
		if not check(expected.campaign.levels.has(id),id+" expected source level"): continue
		var source: Dictionary = expected.campaign.levels[id]
		check(String(level.scene)==String(source.scene) and String(level.theme)==String(source.theme),id+" packed catalog identity")
		var route := json_file(String(source.route))
		var layout := json_file(String(source.layout))
		if route.is_empty() or layout.is_empty(): continue
		check(String(route.id)==id and String(layout.id)==id and String(layout.campaign_level_id)==id,id+" route/layout identity")
		check(route.rooms.size()==int(source.rooms) and route.portals.size()==int(source.portals),id+" exact authored route graph counts")
		var room_ids: Dictionary = route.rooms
		check(room_ids.has(String(route.exit.room)) and room_ids.has(String(layout.spawn_room)),id+" route entry/exit room")
		for portal in route.portals:
			check(room_ids.has(String(portal["from"])) and room_ids.has(String(portal.to)),id+" route portal endpoints")
		check(route.vertical_routes.size()>=1 and route.combat_paths.size()>=1,id+" authored vertical/combat routes")
		var board: Texture2D = load(String(source.board))
		check(board!=null and board.get_width()>0 and board.get_height()>0,id+" packed architecture board texture")
		var scene: PackedScene = load(String(source.scene))
		if not check(scene!=null,id+" packed native level scene loads"): continue
		var world: Node3D = scene.instantiate()
		root.add_child(world)
		check(String(world.get_meta("stage_id",""))==String(source.theme),id+" scene theme metadata")
		var spawns: Node = world.get_node_or_null("EnemySpawns")
		check(spawns!=null and spawns.get_child_count()>0,id+" populated runtime enemy spawns")
		var kinds := {}
		if spawns!=null:
			for spawn in spawns.get_children():
				var kind := String(spawn.get_meta("kind",""))
				kinds[kind]=true
				check(kind in ROSTERS[String(source.theme)],id+" theme-exclusive runtime spawn "+kind)
		for kind in source.enemy_kinds: check(kinds.has(kind),id+" source/packed species "+kind)
		world.free()
		report.campaign.levels[id]={"theme":source.theme,"rooms":route.rooms.size(),"portals":route.portals.size(),"species":kinds.keys()}

func inspect_campaign_main() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if not check(scene!=null,"packed Main scene loads for campaign"): return
	var app: Control = scene.instantiate()
	root.add_child(app)
	app.automated_input=true
	check(app.campaign.levels.size()==9 and app.campaign_button.visible and app.campaign_button.text=="New Game","actual Main defaults to available nine-level campaign New Game")
	app.campaign_button.pressed.emit()
	check(app.campaign_mode and app.campaign.current_index==0 and String(app.world.scene_file_path)==String(expected.campaign.levels.pale_ward_01.scene),"New Game enters first authored level")
	for gun in NEW_GUNS: app.combat.grant_weapon(StringName(gun))
	app.combat.health=72.0;app.combat.armor=19.0;app.combat.ammo_pistol=17;app.combat.ammo_shotgun=8
	app.combat.ammo_rivets=9;app.combat.ammo_rockets=3
	app.world.completed.emit()
	await process_frame
	check(app.level_complete and paused and app.resume_button.text=="Continue","actual completed stage exposes Continue")
	app.enter_combat()
	await process_frame
	check(app.campaign.current_index==1 and not app.level_complete and String(app.world.scene_file_path)==String(expected.campaign.levels.pale_ward_02.scene),"Continue loads next authored scene")
	check(app.combat.health==72.0 and app.combat.armor==19.0 and app.combat.ammo_pistol==17 and app.combat.ammo_shotgun==8 and app.combat.ammo_rivets==9 and app.combat.ammo_rockets==3,"Continue carries actual vitals and four ammo families")
	for gun in NEW_GUNS: check(app.combat.has_weapon(StringName(gun)),"Continue carries ownership "+gun)
	var entry: Dictionary = app.campaign.entry_snapshot.duplicate(true)
	app.combat.health=1.0;app.combat.ammo_pistol=0;app.combat.owned_weapons.erase(&"rivet_cannon")
	app.restart_combat()
	await process_frame
	check(app.campaign.current_index==1 and String(app.world.scene_file_path)==String(expected.campaign.levels.pale_ward_02.scene),"Retry rebuilds same campaign scene")
	check(app.combat.health==entry.health and app.combat.ammo_pistol==entry.ammo_pistol and app.combat.has_weapon(&"rivet_cannon"),"Retry restores level-entry carry")
	report.campaign.main={"new_game_first_level":true,"continue_next_level":true,"carry_vitals_ammo_ownership":true,"retry_entry_snapshot":true}
	paused=false
	app.free()

func run() -> void:
	inspect_campaign_resources()
	await inspect_campaign_main()
	await super.run()
