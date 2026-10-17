extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var world:Node3D=load("res://scenes/campaign/pale_ward_01.tscn").instantiate();root.add_child(world);world.scan(world);world.get_node("Player").set_physics_process(false)
 await physics_frame;await physics_frame
 var shape:=CapsuleShape3D.new();shape.radius=.38;shape.height=1.7
 var results:=[]
 for start in [Vector3(-38,.87,-9),Vector3(-41.5,.87,-7.4)]:
  var target:=Vector3(-14.8,.87,0);var end:Vector3=start+(target-start)*((-5.5-start.z)/(target.z-start.z))
  var q:=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform=Transform3D(Basis.IDENTITY,start);q.motion=end-start;q.collision_mask=1;q.exclude=[world.get_node("Door_v14_records_reserve").get_rid()];q.margin=.001
  var result:=world.get_world_3d().direct_space_state.cast_motion(q)
  results.append({"from":str(start),"to":str(end),"fractions":Array(result),"clear":result[0]>.999})
 print(JSON.stringify(results,"  "));world.free();quit()
