extends SceneTree
var events: Array[Dictionary] = []
var combat: Node3D
var player: CharacterBody3D
var world: Node3D

func _initialize() -> void: call_deferred("run_check")
func count_event(kind: StringName) -> int:
	var count := 0
	for event in events:
		if event.type == kind: count += 1
	return count
func run_check() -> void:
	world = Node3D.new(); root.add_child(world)
	player = CharacterBody3D.new(); world.add_child(player); player.position = Vector3(0,.87,0)
	var shape_node := CollisionShape3D.new(); var shape := CapsuleShape3D.new(); shape.height=1.7; shape.radius=.3; shape_node.shape=shape; player.add_child(shape_node)
	var camera := Camera3D.new(); camera.name="Camera3D"; camera.position.y=.4; player.add_child(camera)
	combat = load("res://scripts/combat.gd").new(); world.add_child(combat)
	combat.combat_event.connect(func(event: Dictionary): events.append(event.duplicate()))
	combat.setup(world,player); combat.set_physics_process(false)
	for enemy in combat.enemies: enemy.set_physics_process(false)
	var enemy: CharacterBody3D = combat.enemies[0]
	var ranged: CharacterBody3D = combat.enemies[1]
	enemy.position=Vector3(0,.87,-4); enemy.health=100; ranged.position=Vector3(10,.87,-4)
	await physics_frame; await physics_frame
	combat.currentweapon=&"shotgun"
	assert(combat.try_fire()); assert(combat.ammo_shotgun==11); assert(combat.shot_counter==1)
	assert(enemy.health==30.0, "Seven pellets must aggregate to exactly 70 damage")
	assert(count_event(&"shot")==1 and count_event(&"impact")==1 and count_event(&"enemy_hurt")==1)
	assert(not combat.try_fire()); assert(combat.ammo_shotgun==11)
	for i in range(70): combat._physics_process(1.0/60)
	assert(combat.cooldown==0.0 and combat.weapon_phase==&"idle")
	combat.ammo_shotgun=0; events.clear(); var before:float=enemy.health
	assert(not combat.try_fire() and not combat.try_fire()); assert(count_event(&"empty")==1 and enemy.health==before)
	# Pain cancels an unreleased windup; death is once and collision risk disappears.
	enemy.configure_sprite_sheet("res://assets/materials/concrete.png",4,8,{&"chase":Vector2i(0,4),&"windup":Vector2i(0,4),&"pain":Vector2i(0,4),&"dead":Vector2i(0,4)},.01,Vector2(16,15))
	enemy.rotation.y=0; var saved_position:=player.position
	player.position=enemy.position+Vector3(0,0,-3); assert(enemy.sprite_direction_row()==0)
	player.position=enemy.position+Vector3(0,0,3); assert(enemy.sprite_direction_row()==4)
	player.position=enemy.position+Vector3(3,0,0); assert(enemy.sprite_direction_row()==6)
	player.position=enemy.position+Vector3(0,0,-3); enemy.state=&"windup"; enemy.state_time=enemy.definition.windup_seconds*.5; enemy.update_sprite(); assert(enemy.sprite.frame==2)
	enemy.state_time=enemy.definition.windup_seconds*2; enemy.update_sprite(); assert(enemy.sprite.frame==3)
	assert(is_equal_approx(enemy.sprite.position.y+(8-15)*.01,-.85))
	player.position=saved_position
	enemy.state=&"windup"; enemy.released=false; events.clear(); var player_hp:float=combat.health
	enemy.apply_damage(1,99,&"pistol",enemy.position); enemy.release_attack()
	assert(enemy.state==&"pain" and combat.health==player_hp)
	enemy.apply_damage(1000,100,&"pistol",enemy.position); enemy.apply_damage(1000,101,&"pistol",enemy.position); enemy.release_attack()
	assert(enemy.dead and enemy.collision_layer==0 and enemy.collision_mask==0)
	assert(count_event(&"enemy_death")==1 and count_event(&"enemy_hurt")==1 and combat.health==player_hp)
	# Actual physics geometry blocks both sight/hitscan and swept projectile motion.
	ranged.position=Vector3(0,.87,-4)
	var wall:=StaticBody3D.new(); world.add_child(wall); wall.position=Vector3(0,1.4,-2); wall.set_meta("hit_material",&"hard")
	var wall_node:=CollisionShape3D.new(); var wall_shape:=BoxShape3D.new(); wall_shape.size=Vector3(3,3,.3); wall_node.shape=wall_shape; wall.add_child(wall_node)
	await physics_frame; await physics_frame
	assert(not ranged.can_see_player())
	combat.currentweapon=&"pistol"; combat.weapon_phase=&"idle"; combat.cooldown=0; events.clear(); before=ranged.health
	assert(combat.try_fire()); assert(ranged.health==before); assert(count_event(&"impact")==1)
	for event in events:
		if event.type==&"impact": assert(event.material==&"hard")
	var projectile:Node3D=combat.launch_projectile(ranged,Vector3(0,1.2,-3.5),Vector3(0,0,1)); projectile.set_physics_process(false)
	var resolved:=false
	for i in range(30):
		if not is_instance_valid(projectile): resolved=true; break
		projectile._physics_process(.05)
		if projectile.resolved: resolved=true
		await physics_frame
	assert(resolved and combat.health==player_hp, "Wall must block swept ranged projectile")
	# Removing obstruction permits the same swept projectile to hurt the player once.
	wall.queue_free(); await physics_frame; await physics_frame
	projectile = combat.launch_projectile(ranged,Vector3(0,1.2,-1.1),Vector3(0,0,1)); projectile.set_physics_process(false)
	var hurt_before := count_event(&"player_hurt")
	for i in range(20):
		if not is_instance_valid(projectile): break
		projectile._physics_process(.05)
		await physics_frame
	assert(combat.health < player_hp and count_event(&"player_hurt") == hurt_before + 1)
	combat.health = 100; combat.armor = 50
	# Short-range melee is ammo-free and resolves one actual contact on armor.
	ranged.position = Vector3(0,.87,-1.6)
	await physics_frame; await physics_frame
	combat.currentweapon=&"melee"; combat.weapon_phase=&"idle"; combat.cooldown=0; events.clear(); before=ranged.health
	var ammunition: int = combat.ammo_pistol + combat.ammo_shotgun
	assert(combat.try_fire() and ranged.health == before - 24)
	assert(combat.ammo_pistol + combat.ammo_shotgun == ammunition and count_event(&"impact") == 1)
	for event in events:
		if event.type == &"impact": assert(event.material == &"armor")
	# Armor absorbs a bounded share; death emits once, then reset restores state.
	combat.receive_player_damage(10,"fixture",Vector3.ZERO); assert(combat.armor==44 and combat.health==96)
	combat.receive_player_damage(1000,"fixture",Vector3.ZERO); combat.receive_player_damage(1000,"fixture",Vector3.ZERO)
	assert(count_event(&"player_death")==1)
	combat.reset(); combat.set_physics_process(false)
	for actor in combat.enemies: actor.set_physics_process(false)
	assert(combat.health==100 and combat.armor==50 and combat.ammo_pistol==36 and combat.ammo_shotgun==12)
	assert(not combat.dead and combat.kills==0 and combat.shot_counter==0 and combat.currentweapon==&"pistol")
	print("COMBAT_CHECK_OK: one-shell seven-pellet aggregation; rate-limited empty; finite cooldown; interrupted/dead attacks; wall-blocked rays/sweeps; unobstructed projectile hurts once; melee ammo-free armor contact; armor/death/reset")
	quit()
