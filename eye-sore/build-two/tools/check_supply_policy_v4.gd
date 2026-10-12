extends SceneTree
## Controlled inventory/physical pickup fixtures; not a campaign route or art review.
var failures: Array[String] = []
var records: Array[Dictionary] = []
var checks := 0
var events: Array[Dictionary] = []
const FIELDS := [&"ammo_pistol", &"ammo_shotgun", &"ammo_rivets", &"ammo_rockets"]
const KINDS := [&"pistol", &"shells", &"rivets", &"rockets"]
const LIMITS := [96, 40, 160, 12]

func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error("SUPPLY_POLICY_V4_FAILED: " + message)
func count(kind: StringName) -> int:
	var result := 0
	for event in events:
		if event.type == kind: result += 1
	return result
func attach_combat(world: Node3D, actor: CharacterBody3D) -> Node3D:
	var combat: Node3D = load("res://scripts/combat.gd").new()
	world.add_child(combat); combat.setup(world, actor); combat.set_physics_process(false)
	combat.combat_event.connect(func(event: Dictionary): events.append(event.duplicate()))
	for enemy in combat.enemies: enemy.set_physics_process(false)
	return combat
func bare_world(campaign: bool) -> Dictionary:
	var world := Node3D.new(); root.add_child(world)
	if campaign: world.set_meta("campaign_level_id", "inventory_fixture")
	var spawns := Node3D.new(); spawns.name = "EnemySpawns"; world.add_child(spawns)
	var actor := CharacterBody3D.new(); world.add_child(actor)
	var camera := Camera3D.new(); camera.name = "Camera3D"; actor.add_child(camera)
	return {"world":world,"actor":actor,"combat":attach_combat(world, actor)}
func full(combat: Node) -> void:
	for index in FIELDS.size(): combat.set(String(FIELDS[index]), LIMITS[index])
func pickup(world: Node, kind: String) -> Node3D:
	for item in world.pickups:
		if String(item.get_meta("stage_pickup")) == kind and int(item.get_meta("amount", 0)) >= 2: return item
	return null

func inventory_checks() -> void:
	var fixture := bare_world(true); var combat: Node = fixture.combat
	for index in KINDS.size():
		check(combat.ammo_capacity(KINDS[index]) == LIMITS[index] and combat.ammo_capacity(FIELDS[index]) == LIMITS[index], "campaign capacity and property alias: " + String(KINDS[index]))
	check(combat.ammo_capacity(&"shotgun") == 40, "shotgun alias shares shells")
	for index in KINDS.size():
		combat.set(String(FIELDS[index]), LIMITS[index] - 3); events.clear()
		check(combat.add_ammo(KINDS[index], 20) and combat.ammo_amount(KINDS[index]) == LIMITS[index], "partial acceptance clamps " + String(KINDS[index]))
		check(count(&"ammo_added") == 1 and events[0].amount == 3 and events[0].ammo_kind == FIELDS[index], "actual three-unit event delta: " + String(KINDS[index]))
		events.clear()
		check(not combat.add_ammo(KINDS[index], 1) and events.is_empty(), "full cap rejects with no event: " + String(KINDS[index]))
	check(not combat.add_ammo(&"unknown", 10) and not combat.add_ammo(&"pistol", 0) and not combat.add_ammo(&"pistol", -2), "invalid supply requests rejected")
	for gun in [&"twin_shotgun", &"rivet_cannon", &"siege_launcher"]:
		events.clear()
		check(combat.grant_weapon(gun, 500) and combat.has_weapon(gun), "new ownership granted at full: " + String(gun))
		check(count(&"ammo_added") == 0 and count(&"weapon_granted") == 1 and events[0].ammo == 0, "full ownership event reports zero accepted ammo")
		events.clear()
		check(not combat.grant_weapon(gun, 500) and events.is_empty(), "duplicate full grant changes no inventory or event")
	await physics_frame
	for gun in [&"pistol", &"twin_shotgun", &"rivet_cannon", &"siege_launcher"]:
		combat.currentweapon = gun; combat.cooldown = 0.0; combat.weapon_phase = &"idle"; events.clear()
		var definition: Resource = combat.weapons[gun]
		var key := StringName(definition.ammo_key)
		check(combat.try_fire() and count(&"shot") == 1 and combat.ammo_amount(key) == combat.ammo_capacity(key) - int(definition.ammo_cost), "actual campaign shot creates carrying room: " + String(gun))
		check(combat.add_ammo(key, 20) and combat.ammo_amount(key) == combat.ammo_capacity(key), "actual campaign shot can be refilled exactly to capacity")
		check(count(&"ammo_added") == 1 and events[-1].amount == int(definition.ammo_cost), "refill event equals actual shot cost: " + String(gun))
	var policy: Resource = combat.supply_policy.duplicate()
	policy.pistol_capacity = 7; combat.supply_policy = policy; events.clear()
	combat.normalize_ammo()
	check(combat.ammo_pistol == 7 and combat.ammo_capacity(&"pistol") == 7 and events.is_empty(), "runtime capacity comes from Resource, normalization is silent")
	combat.supply_policy = load("res://resources/campaign/supply_policy.tres")
	var campaign = load("res://scripts/campaign_state.gd").new()
	var snapshot: Dictionary = campaign.capture(combat)
	snapshot.ammo_pistol = 300; snapshot.ammo_shotgun = 250; snapshot.ammo_rivets = 500; snapshot.ammo_rockets = 90
	snapshot.health = 72.0; snapshot.armor = 19.0; snapshot.currentweapon = &"siege_launcher"
	campaign.restore(combat, snapshot); combat.normalize_ammo()
	check(combat.ammo_pistol == 96 and combat.ammo_shotgun == 40 and combat.ammo_rivets == 160 and combat.ammo_rockets == 12, "carried oversupply normalized after actual campaign restore")
	check(combat.health == 72 and combat.armor == 19 and combat.has_weapon(&"siege_launcher") and combat.currentweapon == &"siege_launcher" and events.is_empty(), "normalize preserves carried vitals/ownership/selection, emits nothing")
	combat.ammo_pistol = -5; combat.normalize_ammo()
	check(combat.ammo_pistol == 0, "malformed negative campaign carry normalized")
	combat.reset()
	check(combat.ammo_pistol == 36 and combat.ammo_shotgun == 12 and combat.ammo_rivets == 0 and combat.ammo_rockets == 0 and combat.owned_weapons.size() == 3, "ordinary reset inventory preserved")
	fixture.world.queue_free(); await process_frame
	fixture = bare_world(false); combat = fixture.combat
	for index in KINDS.size():
		check(combat.ammo_capacity(KINDS[index]) == -1, "standalone unlimited sentinel")
		check(combat.add_ammo(KINDS[index], 1000) and combat.ammo_amount(KINDS[index]) >= 1000, "standalone legacy supplies exceed campaign limits")
	var before: Dictionary = combat.get_hud_state(); combat.normalize_ammo()
	check(combat.get_hud_state() == before, "standalone/calibration normalization is no-op")
	fixture.world.set_meta("campaign_level_id", "")
	check(combat.ammo_capacity(&"pistol") == -1, "empty campaign identity remains unlimited")
	fixture.world.queue_free(); await process_frame

func physical_level_checks(level: Dictionary) -> void:
	var world: Node3D = load(String(level.scene)).instantiate(); root.add_child(world)
	var actor: CharacterBody3D = world.get_node("Player"); actor.set_physics_process(false)
	var combat := attach_combat(world, actor); world.setup(combat, actor); world.set_physics_process(false)
	combat.health = 100.0; combat.armor = 100.0
	await physics_frame
	full(combat)
	var tested_kinds: Array[String] = []
	for index in KINDS.size():
		var item := pickup(world, String(KINDS[index]))
		# Early chapter maps intentionally omit supplies for not-yet-introduced guns.
		if not is_instance_valid(item): continue
		tested_kinds.append(String(KINDS[index]))
		events.clear(); actor.global_position = item.global_position
		world.update_player(actor, combat)
		check(item.visible and not world.collected.has(item.get_instance_id()) and count(&"ammo_added") == 0, "physical full supply remains available: " + String(level.id) + "/" + String(KINDS[index]))
		combat.set(String(FIELDS[index]), LIMITS[index] - 1); events.clear()
		world.update_player(actor, combat)
		check(not item.visible and world.collected.has(item.get_instance_id()) and combat.ammo_amount(KINDS[index]) == LIMITS[index], "physical partial supply accepted: " + String(KINDS[index]))
		check(count(&"ammo_added") == 1 and events[0].amount == 1, "physical supply event reports only one accepted unit")
	# A contact at a real authored bait position must spring the real closet doors,
	# even when ownership and its ammo are already carried at capacity.
	var bait: Node3D = null
	for item in world.pickups:
		if item.has_meta("bait_arena"): bait = item; break
	check(is_instance_valid(bait), String(level.id) + " real weapon bait exists")
	if is_instance_valid(bait):
		var gun := StringName(bait.get_meta("stage_pickup")); var arena := String(bait.get_meta("bait_arena"))
		combat.grant_weapon(gun); full(combat); events.clear()
		actor.global_position = bait.global_position; paused = true
		check(not combat.try_fire(), "paused authoritative shot rejected")
		world.collect(bait); world.update_player(actor, combat)
		check(bait.visible and not world.traps[arena].triggered and events.is_empty(), "paused physical bait contact does not mutate trap/inventory")
		paused = false; world.update_player(actor, combat)
		check(not bait.visible and world.collected.has(bait.get_instance_id()) and world.traps[arena].triggered, "full carried bait still triggers physical ambush")
		check(count(&"ammo_added") == 0 and count(&"weapon_granted") == 0, "full duplicate bait has no false ammo/grant events")
		for tick in 130: await physics_frame
		world.update_player(actor, combat)
		var opened := true
		for shutter in world.trap_shutters[arena]: opened = opened and shutter.is_open()
		check(opened and world.traps[arena].shutters_open and world.is_arena_active(arena), "full-capacity bait exposes actual closets and activates arena")
		records.append({"level":level.id,"ordinary_full_pickup_kinds":tested_kinds,"ordinary_full_pickups_retained":true,"partial_accepted_delta":1,"bait_weapon":String(gun),"bait_triggered_at_full":world.traps[arena].triggered,"physical_shutters_open":opened,"arena_active":world.is_arena_active(arena)})
	# Health/armor retain their existing caps and full-pickup retention.
	for kind in ["health", "armor"]:
		var item := pickup(world, kind)
		if not is_instance_valid(item): continue
		combat.set(kind, 100.0); world.collect(item)
		check(item.visible and not world.collected.has(item.get_instance_id()), "full " + kind + " cap behavior unchanged")
		combat.set(kind, 99.0); world.collect(item)
		check(combat.get(kind) == 100.0 and not item.visible, kind + " accepted pickup clamps at existing 100")
	world.queue_free(); await process_frame

func run() -> void:
	await inventory_checks()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/catalog.json"))
	for index in catalog.chapters.size(): await physical_level_checks(catalog.chapters[index].levels[index])
	check(records.size() == 3 and records[0].bait_weapon == "twin_shotgun" and records[1].bait_weapon == "rivet_cannon" and records[2].bait_weapon == "siege_launcher", "actual full-capacity bait tested for all three heavy guns/themes")
	var receipt := {"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"capacities":{"pistol":96,"shells":40,"rivets":160,"rockets":12},"unlimited_sentinel":-1,"levels":records,"scope":"Release-safe real Combat/Stage/CampaignState fixtures; actual accepted pistol/twin/rivet/siege shots and exact refill deltas, controlled physical player positions and frozen enemies isolate pickup/trap behavior on one authored campaign level per theme. Actual animated closet doors and contact range; not ordinary route, balance completion, art, listening or human-play acceptance."}
	DirAccess.make_dir_recursive_absolute("res://verification/combat-balance-v4")
	var output := FileAccess.open("res://verification/combat-balance-v4/supply-policy.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(receipt, "  ") + "\n")
	print("SUPPLY_POLICY_V4 ", JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
