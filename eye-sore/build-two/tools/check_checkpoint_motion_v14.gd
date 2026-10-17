extends SceneTree
## Focused real-body snapshot regression, not a campaign traversal fixture.
class QuietCombat extends Node:
	var enemies:Array=[]
var stage:Node3D
var door:AnimatableBody3D
var checks:Array[Dictionary]=[]
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks.append({"check":label,"passed":ok})
	if not ok:failed+=1;push_error(label)
func frames(count:int)->void:
	for i in count:await physics_frame
func blocked()->bool:
	var ray:=PhysicsRayQueryParameters3D.create(stage.to_global(Vector3(0,1.5,2)),stage.to_global(Vector3(0,1.5,-2)),1)
	return not stage.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func aligned()->bool:
	var physical:Transform3D=PhysicsServer3D.body_get_state(door.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)
	return physical.is_equal_approx(door.global_transform)
func run()->void:
	stage=load("res://scripts/stage_level.gd").new()
	stage.objective_profile=load("res://scripts/stage_objective_profile.gd").from_dictionary({"level_id":"checkpoint_motion_component"})
	stage.position=Vector3(10,2,-5);stage.rotation.y=PI/2;root.add_child(stage);stage.set_physics_process(false)
	var combat:=QuietCombat.new();stage.add_child(combat);stage.combat=combat
	door=load("res://scripts/stage_door.gd").new();door.name="ReserveDoor";door.position=Vector3(0,1.7,0);door.open_offset=Vector3(0,4,0)
	door.set_meta("stage_door","reserve");door.set_meta("stable_id","component.reserve")
	var collision:=CollisionShape3D.new();collision.name="Collision";var box:=BoxShape3D.new();box.size=Vector3(4,3.4,.25);collision.shape=box;door.add_child(collision);stage.add_child(door)
	stage.scan(stage);stage.reset();await frames(2)
	var closed:Dictionary=stage.capture_checkpoint_state()
	check(door.is_closed() and blocked() and aligned(),"Initial closed physical collider on translated/rotated stage")
	for paused_restore in [false,true]:
		door.activate();await frames(32)
		check(door.opened and not door.is_open() and not blocked(),"Real mid-rise collider clears ray before restore paused="+str(paused_restore))
		paused=paused_restore
		check(stage.restore_checkpoint_state(closed),"Mid-motion snapshot accepted paused="+str(paused_restore))
		check(door.is_closed() and door.sync_to_physics,"Closed logical pose and synchronization restored immediately paused="+str(paused_restore))
		paused=false;await frames(3)
		check(door.is_closed() and aligned() and blocked(),"Closed body remains aligned and blocks ray after physics paused="+str(paused_restore))
		await frames(8)
		check(door.is_closed() and blocked(),"No stale motion target resurrects after later ticks paused="+str(paused_restore))
	door.activate();await frames(75)
	var opened:Dictionary=stage.capture_checkpoint_state()
	check(door.is_open() and not blocked(),"Fully open real body clears ray")
	check(stage.restore_checkpoint_state(closed),"Open-to-closed snapshot accepted");await frames(3)
	check(door.is_closed() and aligned() and blocked(),"Open-to-closed body and collision persist")
	check(stage.restore_checkpoint_state(opened),"Closed-to-open snapshot accepted");await frames(3)
	check(door.is_open() and aligned() and not blocked(),"Closed-to-open body and collision persist")
	check(stage.restore_checkpoint_state(closed),"Closed snapshot before unsynchronized case accepted");await frames(3)
	door.sync_to_physics=false;door.activate();await frames(32)
	check(stage.restore_checkpoint_state(closed),"Unsynchronized mid-motion snapshot accepted");await frames(3)
	check(not door.sync_to_physics and door.is_closed() and aligned() and blocked(),"Restore preserves original false synchronization policy")
	var folder:="res://verification/ward-spatial-v14/runtime";DirAccess.make_dir_recursive_absolute(folder)
	var suffix:="headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open(folder+"/checkpoint-motion-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"scope":"Real production StageLevel/StageDoor/checkpoint helper and physical ray contacts. Empty combat stub; not actual campaign, reward or actor acceptance."},"  "))
	print("CHECKPOINT_MOTION_V14 checks=%d failed=%d"%[checks.size(),failed]);quit(1 if failed else 0)
