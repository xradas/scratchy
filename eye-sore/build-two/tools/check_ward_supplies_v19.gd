extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for id in ["pale_ward_01","pale_ward_02","pale_ward_03"]:
		var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/"+id+"-route.json"))
		var route_totals: Dictionary={}
		var room_kinds: Dictionary={}
		for supply in route.supplies:
			var kind: String=String(supply.kind)
			route_totals[kind]=int(route_totals.get(kind,0))+int(supply.amount)
			var kinds: Dictionary=room_kinds.get(String(supply.room),{})
			kinds[kind]=true
			room_kinds[String(supply.room)]=kinds
		for room in room_kinds:
			var kinds: Dictionary=room_kinds[room]
			if kinds.has("health"):
				for ammo in ["pistol","shells","rivets","rockets"]:
					if kinds.has(ammo):failures.append(id+" health/ammo clustered in "+room)
		if int(route_totals.get("health",0))!=181 or int(route_totals.get("armor",0))!=131:
			failures.append(id+" main route medical budget drifted")
		var world: Node3D=load("res://scenes/campaign/"+id+".tscn").instantiate()
		root.add_child(world);world.scan(world);world.set_physics_process(false)
		var player: CharacterBody3D=world.get_node("Player");player.set_physics_process(false)
		await physics_frame
		var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
		var capsule: CapsuleShape3D=player.get_node("CollisionShape3D").shape
		var checked:=0
		for item in world.pickups:
			if not String(item.name).begins_with("Supply_"):continue
			checked+=1
			var pos: Vector3=item.global_position
			var ray:=PhysicsRayQueryParameters3D.create(pos+Vector3.UP*.45,pos-Vector3.UP*1.1,1,[player.get_rid()])
			var hit: Dictionary=space.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y<.7:
				failures.append(id+" "+item.name+" unsupported")
				continue
			var reachable:=false
			for offset in [Vector3.ZERO,Vector3(.55,0,0),Vector3(-.55,0,0),Vector3(0,0,.55),Vector3(0,0,-.55)]:
				var stance: Vector3=Vector3(hit.position)+Vector3.UP*.87+offset
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule
				query.transform=Transform3D(Basis.IDENTITY,stance)
				query.collision_mask=1;query.exclude=[player.get_rid()]
				if space.intersect_shape(query,1).is_empty():reachable=true;break
			if not reachable:failures.append(id+" "+item.name+" blocked")
		print("WARD_SUPPLY_CLEARANCE ",id," checked=",checked)
		var amounts := {"health": {}, "armor": {}}
		var ordinary: Node3D
		var small: Node3D
		var overdrive: Node3D
		for item in world.pickups:
			var kind := String(item.get_meta("stage_pickup", ""))
			if kind not in amounts:continue
			var amount := int(item.get_meta("amount", 0))
			var scale_by_amount := {1:.68,5:.82,25:1.0,50:1.16,100:1.34}
			if scale_by_amount.has(amount) and not is_equal_approx(item.scale.x,float(scale_by_amount[amount])):
				failures.append(id+" "+item.name+" package size mismatch")
			if item.get_meta("overdrive", false):overdrive=item;continue
			if amount in [1,5,25,50]:amounts[kind][amount]=int(amounts[kind].get(amount,0))+1
			if ordinary==null and amount==25:ordinary=item
			if small==null and amount==5:small=item
		for kind in ["health","armor"]:
			for amount in [1,5,25,50]:
				if int(amounts[kind].get(amount,0))==0:failures.append(id+" missing "+kind+" +"+str(amount))
		if overdrive==null or int(overdrive.get_meta("amount",0))!=100:failures.append(id+" missing 100-point overdrive")
		var combat: Node3D=load("res://scripts/combat.gd").new()
		world.add_child(combat);combat.setup(world,player);combat.set_physics_process(false)
		world.setup(combat,player);world.set_physics_process(false)
		for enemy in combat.enemies:enemy.set_physics_process(false)
		if ordinary!=null:
			var ordinary_kind:=String(ordinary.get_meta("stage_pickup"))
			combat.set(ordinary_kind,99.0);world.collect(ordinary)
			if combat.get(ordinary_kind)!=100.0:failures.append(id+" ordinary cap failed")
		if small!=null:
			var small_kind:=String(small.get_meta("stage_pickup"))
			combat.set(small_kind,97.0);world.collect(small)
			if combat.get(small_kind)!=100.0:failures.append(id+" +5 cap failed")
		if overdrive!=null:
			var overdrive_kind:=String(overdrive.get_meta("stage_pickup"))
			combat.set(overdrive_kind,190.0);world.collect(overdrive)
			if combat.get(overdrive_kind)!=200.0 or overdrive.visible:failures.append(id+" overdrive cap failed")
		var ranged:=0
		for enemy in combat.enemies:
			if String(enemy.definition.identifier) in ["infected_security", "infected_security_shotgun"]:ranged+=1
		if ranged<(15 if id=="pale_ward_01" else 18 if id=="pale_ward_02" else 12):failures.append(id+" ranged promotion missing")
		world.queue_free();await process_frame
	for failure in failures:printerr(failure)
	print("WARD_SUPPLY_CLEARANCE passed=",failures.is_empty()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
