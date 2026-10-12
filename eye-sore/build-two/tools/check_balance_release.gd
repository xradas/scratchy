extends "check_campaign_release.gd"
## Actual loaded-resource balance layer. Setup and direct pickup contact fixtures
## are declared; inherited campaign/native-art/audio reader remains unchanged.
const CAP_FIELDS := {"pistol":"ammo_pistol","shells":"ammo_shotgun","rivets":"ammo_rivets","rockets":"ammo_rockets"}
const WEAPON_POOL := {"pistol":"pistol","shotgun":"shells","twin_shotgun":"shells","rivet_cannon":"rivets","siege_launcher":"rockets","melee":""}
var balance_events: Array[Dictionary] = []
var balance_messages: Array[String] = []

func record_balance_event(event: Dictionary) -> void: balance_events.append(event.duplicate(true))
func set_full(combat: Node) -> void:
	for kind in CAP_FIELDS: combat.set(CAP_FIELDS[kind],int(expected.balance.caps[kind]))
func amount_dict(combat: Node) -> Dictionary:
	var result := {}
	for kind in CAP_FIELDS: result[kind]=int(combat.get(CAP_FIELDS[kind]))
	return result
func frozen_actors(app: Control) -> void:
	app.automated_input=true;app.player.set_physics_process(false);app.player.velocity=Vector3.ZERO
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
func empty_totals() -> Dictionary: return {"pistol":0,"shells":0,"rivets":0,"rockets":0}
func add_total(totals: Dictionary, kind: String, amount: int) -> void:
	if totals.has(kind): totals[kind]+=amount

func budget_nodes(app: Control, id: String, entry: Dictionary) -> Dictionary:
	var main := empty_totals();var optional := {"shells":0,"health":0};var secret := {"shells":0,"health":0}
	var vital := {"health":0,"armor":0};var return_vital := {"health":0,"armor":0}
	var ordinary: Array[Node3D]=[];var baits: Array[Node3D]=[];var forward: Array[Dictionary]=[];var actual_sources := {};var vital_seen := {}
	var world: Node3D=app.world
	for item in world.pickups:
		var name := String(item.name);var kind := String(item.get_meta("stage_pickup",""));var offered := int(item.get_meta("amount",0))
		var room: String=world.room_at(item.global_position)
		check(offered>=0,id+" finite nonnegative pickup "+name)
		if kind in ["health","armor"]:
			vital_seen[name]=true
			var old: Dictionary=expected.balance.vital_pickups[id].get(name,{})
			check(not old.is_empty(),id+" original vital pickup retained "+name)
			if not old.is_empty():
				check(kind==String(old.kind) and offered==int(old.amount),id+" original vital amount/kind "+name)
				check(item.position.distance_to(Vector3(old.position[0],old.position[1],old.position[2]))<.0001,id+" original vital position "+name)
		if name=="FirstGunCache" or name.begins_with("Bait_"):
			var definition: Resource=app.combat.weapons.get(StringName(kind))
			check(definition!=null and WEAPON_POOL.has(kind),id+" native cache Resource "+name)
			var pool: String=WEAPON_POOL.get(kind,"")
			if definition!=null: check(String(definition.ammo_key)==CAP_FIELDS.get(pool,""),id+" cache Resource ammo pool "+name)
			add_total(main,pool,offered)
			var source: Dictionary=entry.sources.first_weapon if name=="FirstGunCache" else entry.sources.arena_baits.get(name.trim_prefix("Bait_"),{})
			check(not source.is_empty() and String(source.get("weapon",""))==kind and String(source.get("ammo",""))==pool and int(source.get("amount",-1))==offered,id+" actual cache matches budget "+name)
			actual_sources[name]=true
			if name.begins_with("Bait_"): baits.append(item)
		elif name.begins_with("Supply_"):
			var source: Dictionary=entry.sources.supply_cases.get(name,{})
			check(not source.is_empty() and String(source.get("kind",""))==kind and int(source.get("amount",-1))==offered,id+" actual ordinary case matches budget "+name)
			actual_sources[name]=true
			var expected_room := name.trim_prefix("Supply_"+kind+"_")
			check(room==expected_room,id+" actual supply room geometry "+name+" got "+room)
			if CAP_FIELDS.has(kind):
				check(room not in entry.optional.rooms and room not in entry.secret.rooms and room!="return_store",id+" main ammunition excludes optional/secret rooms "+name)
				add_total(main,kind,offered);ordinary.append(item)
				if room=="entry":
					var offset: Vector3=item.global_position-app.player.global_position
					var forward_distance: float=offset.dot(-app.player.global_basis.z)
					check(forward_distance>.5 and forward_distance<6,id+" entry ammo lies ahead of actual PlayerStart "+name)
					forward.append({"item":name,"position":[item.position.x,item.position.y,item.position.z],"forward_distance":forward_distance})
			elif vital.has(kind):
				vital[kind]+=offered
				if room=="return_store":return_vital[kind]+=offered
		elif name.begins_with("Bonus_") or name.begins_with("BonusHealth_"):
			var expected_room := name.trim_prefix("BonusHealth_").trim_prefix("Bonus_")
			check(room==expected_room,id+" optional/secret reward actual room "+name)
			if room in entry.optional.rooms:add_total(optional,kind,offered)
			elif room in entry.secret.rooms:add_total(secret,kind,offered)
			else:check(false,id+" bonus outside authored optional/secret rooms "+name)
			if CAP_FIELDS.has(kind):ordinary.append(item)
		else:check(name.begins_with("Key_"),id+" all actual pickups classified "+name)
	check(same_resource_value(main,entry.main_route_actual) and same_resource_value(main,entry.main_route_target),id+" actual main pickup totals equal budget/target")
	check(same_resource_value(optional,entry.optional.bonus) and same_resource_value(secret,entry.secret.bonus),id+" optional/secret supplies separately accounted")
	check(vital.health==int(entry.placed_health_total) and vital.armor==int(entry.placed_armor_total),id+" all ordinary vital totals exact")
	check(vital.health-return_vital.health==int(entry.main_route_health) and vital.armor-return_vital.armor==int(entry.main_route_armor),id+" main vitals exclude return-store bonus")
	check(vital_seen.size()==expected.balance.vital_pickups[id].size(),id+" exact prior vital pickup identity/count")
	check(baits.size()==3,id+" three actual bait caches")
	var expected_source_count: int=entry.sources.supply_cases.size()+entry.sources.arena_baits.size()+(1 if entry.sources.first_weapon is Dictionary else 0)
	check(actual_sources.size()==expected_source_count,id+" all declared budget sources present")
	return {"main":main,"optional":optional,"secret":secret,"ordinary":ordinary,"baits":baits,"forward_entry":forward,"vital_count":vital_seen.size(),"weapon_cache_count":baits.size()+(1 if actual_sources.has("FirstGunCache") else 0)}

func actual_pickup_checks(app: Control, id: String, nodes: Dictionary) -> Dictionary:
	var records: Array[Dictionary]=[];var bait_records: Array[Dictionary]=[]
	paused=false
	for item in nodes.ordinary:
		var kind:=String(item.get_meta("stage_pickup"));var offered:=int(item.get_meta("amount"))
		set_full(app.combat);balance_events.clear();balance_messages.clear()
		app.world.collect(item)
		check(item.visible and not app.world.collected.has(item.get_instance_id()) and balance_events.is_empty(),id+" full ordinary case remains with no false event "+String(item.name))
		var room_left:=mini(5,offered)
		app.combat.set(CAP_FIELDS[kind],int(expected.balance.caps[kind])-room_left)
		app.world.collect(item)
		var accepted:=0;var events:=0
		for event in balance_events:
			if String(event.get("type",""))=="ammo_added":accepted+=int(event.amount);events+=1
		check(not item.visible and app.world.collected.has(item.get_instance_id()) and accepted==room_left and events==1 and app.combat.ammo_amount(StringName(kind))==int(expected.balance.caps[kind]),id+" partial ordinary exact accepted amount "+String(item.name))
		check(balance_messages.has("%s +%d" % [kind.capitalize(),room_left]),id+" ordinary feedback reports actual accepted ammo "+String(item.name))
		records.append({"item":String(item.name),"kind":kind,"offered":offered,"full_retained":true,"budget_scope":"main" if String(item.name).begins_with("Supply_") else "optional_or_secret","deficit":room_left,"accepted":accepted,"events":events})
	for item in nodes.baits:
		set_full(app.combat)
		var arena:=String(item.get_meta("bait_arena"));var weapon:=StringName(item.get_meta("stage_pickup"))
		check(app.combat.has_weapon(weapon),id+" owned full bait setup "+arena)
		balance_events.clear();app.player.global_position=item.global_position
		app.world.update_player(app.player,app.combat)
		check(not item.visible and app.world.traps[arena].triggered,id+" full bait contact still consumed and triggered "+arena)
		var grants:=0
		for event in balance_events:
			if String(event.get("type","")) in ["ammo_added","weapon_granted"]:grants+=1
		check(grants==0 and same_resource_value(amount_dict(app.combat),expected.balance.caps),id+" full bait produces no false ammunition/grant "+arena)
		for tick in 105:await physics_frame
		check(app.world.traps[arena].latched and app.world.traps[arena].shutters_open and app.world.is_arena_active(arena),id+" full bait native entry latch/shutters/activation "+arena)
		bait_records.append({"arena":arena,"weapon":String(weapon),"false_grants":grants,"state":app.world.traps[arena].duplicate(true)})
	return {"ordinary":records,"baits":bait_records}

func inspect_balance() -> void:
	var budget:=json_file(String(expected.balance.budget_path))
	var policy: Resource=load(String(expected.balance.policy_path))
	if not check(not budget.is_empty() and policy!=null,"packed balance budget and capacity Resource load"):return
	for kind in CAP_FIELDS:
		check(int(policy.get(kind+"_capacity"))==int(expected.balance.caps[kind]),"native cap Resource "+kind)
		check(policy.capacity(StringName(kind))==int(expected.balance.caps[kind]),"native capacity method "+kind)
	report.balance={"caps":expected.balance.caps,"levels":{},"main_ordinary_cases":0,"bonus_ordinary_cases":0,"ordinary_cases":0,"weapon_caches":0,"total_ammo_weapon_nodes":0,"preserved_source_commit":expected.balance.preserved_source_commit,"preserved_files":expected.balance.preserved_file_count}
	var app: Control=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	app.automated_input=true
	var snapshot: Dictionary=app.campaign.capture(app.combat)
	for kind in CAP_FIELDS:snapshot[CAP_FIELDS[kind]]=int(expected.balance.caps[kind])+13
	snapshot.owned_weapons={&"pistol":true,&"shotgun":true,&"melee":true,&"twin_shotgun":true,&"rivet_cannon":true,&"siege_launcher":true}
	for level in app.campaign.levels:
		paused=true;app.campaign_mode=true;app.level_complete=false;app.campaign.seek(String(level.id));app.stage_id=String(level.theme)
		app.replace_world(snapshot);frozen_actors(app);app.campaign.entry_snapshot=app.campaign.capture(app.combat)
		var id:=String(level.id)
		check(same_resource_value(amount_dict(app.combat),expected.balance.caps),id+" actual carried overfill clamped")
		for kind in CAP_FIELDS:check(app.combat.ammo_capacity(StringName(kind))==int(expected.balance.caps[kind]),id+" actual Main capacity "+kind)
		var nodes:=budget_nodes(app,id,expected.balance.levels[id])
		app.combat.combat_event.connect(record_balance_event);app.world.message_changed.connect(func(message: String):balance_messages.append(message))
		var pickups:=await actual_pickup_checks(app,id,nodes)
		for item in nodes.ordinary:
			if String(item.name).begins_with("Supply_"):report.balance.main_ordinary_cases+=1
			else:report.balance.bonus_ordinary_cases+=1
		report.balance.ordinary_cases+=nodes.ordinary.size()
		report.balance.weapon_caches+=nodes.weapon_cache_count
		report.balance.total_ammo_weapon_nodes+=nodes.ordinary.size()+nodes.weapon_cache_count
		for kind in CAP_FIELDS:app.combat.set(CAP_FIELDS[kind],0)
		app.restart_combat();frozen_actors(app)
		check(same_resource_value(amount_dict(app.combat),expected.balance.caps),id+" actual Retry restores normalized entry ammo")
		var hud_states:= {}
		paused=true
		for gun in GUNS:
			app.combat.currentweapon=StringName(gun);app._process(0.0)
			var pool: String=WEAPON_POOL[gun]
			var expected_text: String="READY" if pool.is_empty() else "AMMO %d/%d" % [int(expected.balance.caps[pool]),int(expected.balance.caps[pool])]
			check(app.hud.text.contains(gun.replace("_"," ").to_upper()) and app.hud.text.contains(expected_text),id+" selected actual Main ammo/capacity HUD "+gun)
			hud_states[gun]=app.hud.text
		var record: Dictionary={"actual_main_totals":nodes.main,"optional":nodes.optional,"secret":nodes.secret,"forward_entry":nodes.forward_entry,"prior_vital_pickups":nodes.vital_count,"pickup_acceptance":pickups,"clamped_entry_and_retry":true,"selected_hud":hud_states}
		report.balance.levels[id]=record
		print("BALANCE_NATIVE_LEVEL_OK: ",id)
	paused=false;app.free()
	report.balance.scope="Loaded actual Main nine-scene budget/Resource/pickup/carry/retry/HUD probes. Declared overfilled owned snapshots, AI/player physics frozen, direct ordinary collect calls and actor teleport bait contacts; native doors advance on physics ticks. Continuous physical routes, ordinary combat and human acceptance are separate."

func inspect_clamped_continue() -> void:
	var app: Control=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	app.start_new_campaign();frozen_actors(app);paused=true
	for gun in NEW_GUNS:app.combat.grant_weapon(StringName(gun))
	for kind in CAP_FIELDS:app.combat.set(CAP_FIELDS[kind],int(expected.balance.caps[kind])+13)
	app.combat.health=72.0;app.combat.armor=19.0
	app.world.completed.emit();paused=true
	await process_frame
	check(app.level_complete and app.resume_button.text=="Continue","overfilled actual completion exposes Continue")
	app.enter_combat();frozen_actors(app);paused=true
	var entry: Dictionary=app.campaign.entry_snapshot.duplicate(true)
	check(app.campaign.current_index==1,"overfilled actual Continue advances to Ward02")
	check(same_resource_value(amount_dict(app.combat),expected.balance.caps),"actual Continue clamps all four carried ammo families")
	for kind in CAP_FIELDS:check(int(entry[CAP_FIELDS[kind]])==int(expected.balance.caps[kind]),"actual Continue records normalized retry snapshot "+kind)
	check(entry.health==72.0 and entry.armor==19.0,"actual Continue preserves carried vitals before ordinary contact")
	for kind in CAP_FIELDS:app.combat.set(CAP_FIELDS[kind],0)
	app.restart_combat();frozen_actors(app);paused=true
	check(same_resource_value(amount_dict(app.combat),expected.balance.caps),"actual Retry restores Continue normalized entry")
	report.balance.clamped_continue={"entry_snapshot":entry,"retry_ammo":amount_dict(app.combat),"scope":"Deliberate overfilled owned exit fixture; actual Main completion/Continue/Retry, paused before ordinary contact. No route or earned-inventory claim."}
	paused=false;app.free()

func inspect_standalone_scope() -> void:
	var app: Control=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	var records:= {}
	for index in app.stage_catalog.size():
		paused=true;app.stage_selector.select(index);app.stage_selector.item_selected.emit(index);frozen_actors(app)
		app.enter_combat();frozen_actors(app)
		var id:=String(app.stage_id)
		for kind in CAP_FIELDS:check(app.combat.ammo_capacity(StringName(kind))==-1,id+" standalone has no campaign cap "+kind)
		app.combat.ammo_pistol=int(expected.balance.caps.pistol)
		check(app.combat.add_ammo(&"pistol",7) and app.combat.ammo_pistol==int(expected.balance.caps.pistol)+7,id+" standalone retains legacy over-cap acceptance")
		app.combat.normalize_ammo()
		check(app.combat.ammo_pistol==int(expected.balance.caps.pistol)+7,id+" standalone normalization bypasses policy")
		records[id]={"campaign_policy_applied":false,"pistol_after_add":app.combat.ammo_pistol}
	paused=false;app.free();report.balance.standalone=records

func inspect_campaign_main() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if not check(scene!=null,"packed Main scene loads for campaign"): return
	var app: Control = scene.instantiate()
	root.add_child(app)
	app.automated_input=true
	check(app.campaign.levels.size()==9 and app.campaign_button.visible and app.campaign_button.text=="New Game","actual Main defaults to available nine-level campaign New Game")
	app.campaign_button.pressed.emit()
	frozen_actors(app)
	check(app.campaign_mode and app.campaign.current_index==0 and String(app.world.scene_file_path)==String(expected.campaign.levels.pale_ward_01.scene),"New Game enters first authored level")
	for gun in NEW_GUNS: app.combat.grant_weapon(StringName(gun))
	app.combat.health=72.0;app.combat.armor=19.0;app.combat.ammo_pistol=17;app.combat.ammo_shotgun=8
	app.combat.ammo_rivets=9;app.combat.ammo_rockets=3
	app.world.completed.emit()
	# Completion signal is injected, so isolate its deferred pause from one
	# extra old-world pickup tick before Continue snapshots the exit state.
	paused=true
	await process_frame
	check(app.level_complete and paused and app.resume_button.text=="Continue","actual completed stage exposes Continue")
	app.enter_combat()
	frozen_actors(app)
	# Sample carry before ordinary entry contact. Continue already completed
	# synchronously; pausing here isolates its inherited exact-value assertion.
	var carried_before_contact: Dictionary=app.campaign.capture(app.combat)
	paused=true
	await process_frame
	check(app.campaign.current_index==1 and not app.level_complete and String(app.world.scene_file_path)==String(expected.campaign.levels.pale_ward_02.scene),"Continue loads next authored scene")
	check(app.combat.health==72.0 and app.combat.armor==19.0 and app.combat.ammo_pistol==17 and app.combat.ammo_shotgun==8 and app.combat.ammo_rivets==9 and app.combat.ammo_rockets==3,"Continue carries actual vitals and four ammo families")
	for gun in NEW_GUNS: check(app.combat.has_weapon(StringName(gun)),"Continue carries ownership "+gun)
	var entry: Dictionary = app.campaign.entry_snapshot.duplicate(true)
	app.combat.health=1.0;app.combat.ammo_pistol=0;app.combat.owned_weapons.erase(&"rivet_cannon")
	app.restart_combat()
	frozen_actors(app)
	paused=true
	await process_frame
	check(app.campaign.current_index==1 and String(app.world.scene_file_path)==String(expected.campaign.levels.pale_ward_02.scene),"Retry rebuilds same campaign scene")
	check(app.combat.health==entry.health and app.combat.ammo_pistol==entry.ammo_pistol and app.combat.has_weapon(&"rivet_cannon"),"Retry restores level-entry carry")
	report.campaign.main={"new_game_first_level":true,"continue_next_level":true,"carry_vitals_ammo_ownership":true,"retry_entry_snapshot":true,"carried_before_ordinary_contact":carried_before_contact,"fixture":"Same original Main assertions, with AI/player frozen and tree paused immediately after synchronous Continue/Retry to prevent ordinary entry pickup contact from racing exact carried-value checks."}
	paused=false
	app.free()


func run() -> void:
	await inspect_balance()
	await inspect_clamped_continue()
	inspect_standalone_scope()
	await super.run()
