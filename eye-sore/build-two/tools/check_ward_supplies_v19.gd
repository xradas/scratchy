extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for id in ["pale_ward_01","pale_ward_02","pale_ward_03"]:
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
		var overdrive: Node3D
		for item in world.pickups:
			var kind := String(item.get_meta("stage_pickup", ""))
			if kind not in amounts:continue
			if item.get_meta("overdrive", false):overdrive=item;continue
			var amount := int(item.get_meta("amount", 0))
			if amount in [1,25,50]:amounts[kind][amount]=int(amounts[kind].get(amount,0))+1
			if ordinary==null and amount==25:ordinary=item
		for kind in ["health","armor"]:
			for amount in [1,25,50]:
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
		if overdrive!=null:
			var overdrive_kind:=String(overdrive.get_meta("stage_pickup"))
			combat.set(overdrive_kind,190.0);world.collect(overdrive)
			if combat.get(overdrive_kind)!=200.0 or overdrive.visible:failures.append(id+" overdrive cap failed")
		var ranged:=0
		for enemy in combat.enemies:
			if String(enemy.definition.identifier)=="infected_security":ranged+=1
		if ranged<(15 if id=="pale_ward_01" else 18 if id=="pale_ward_02" else 12):failures.append(id+" ranged promotion missing")
		world.queue_free();await process_frame
	for failure in failures:printerr(failure)
	print("WARD_SUPPLY_CLEARANCE passed=",failures.is_empty()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
