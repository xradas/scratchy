extends SceneTree
var records: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("run")
func xyz(p: Vector3)->Array:return [p.x,p.y,p.z]
func key(down: bool)->void:
 var e:=InputEventKey.new();e.keycode=KEY_W;e.physical_keycode=KEY_W;e.pressed=down;Input.parse_input_event(e)
func run()->void:
 var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://verification/pickups-rooms-v6/physics/room-clearance-candidate.json"))
 for candidate in receipt.contacts:
  var world: Node3D=load(String(candidate.scene)).instantiate();root.add_child(world)
  world.set_physics_process(false)
  var actor: CharacterBody3D=world.get_node("Player")
  actor.set_physics_process(false)
  var point:=Vector3(candidate.position[0],candidate.position[1],candidate.position[2])
  actor.position=point-Vector3(2,0,0);actor.rotation.y=-PI/2;actor.velocity=Vector3.ZERO
  await physics_frame;await physics_frame;actor.set_physics_process(true)
  for n in 3:await physics_frame
  var initial:=actor.position;var trace: Array=[];var bodies: Dictionary={}
  key(true)
  for n in 70:
   await physics_frame
   for i in actor.get_slide_collision_count():
    var body:=actor.get_slide_collision(i).get_collider()
    if body is Node:bodies[String(body.get_path())]=true
   if n%10==0:trace.append({"position":xyz(actor.position),"grounded":actor.is_on_floor()})
   if actor.position.x>point.x+1.5:break
  key(false)
  for n in 16:await physics_frame
  records.append({"scene":candidate.scene,"scene_sha256":FileAccess.get_sha256(candidate.scene),"lane":candidate.lane,"contact":candidate.contacts,"initial":xyz(initial),"terminal":xyz(actor.position),"crossed_candidate":actor.position.x>point.x+1.2,"grounded":actor.is_on_floor(),"colliders":bodies.keys(),"trace":trace})
  world.free();await physics_frame
 var f:=FileAccess.open("res://verification/pickups-rooms-v6/physics/room-connector-walk-candidate.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"Independent real CharacterBody eastward W crossing of eight coarse capsule-query contacts. Initial positions declared 2m west of first contact. No combat setup or enemies. Fixed60 process/physics clock. Not whole campaign route proof.","trials":records},"  "))
 print("ROOM_CONNECTOR_WALK ",JSON.stringify(records));quit()
