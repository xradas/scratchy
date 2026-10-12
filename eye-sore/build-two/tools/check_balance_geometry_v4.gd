extends SceneTree
## Native resolved-resource comparison; baseline scenes are git-show copies outside project.
const BASELINE := "/tmp/eyesore-geometry-v4-head/"
const AMMO := ["pistol","shells","rivets","rockets","shotgun","twin_shotgun","rivet_cannon","siege_launcher"]
var failures:Array[String]=[]
var records:Array[Dictionary]=[]
var cache:Dictionary={}
var current_root:Node3D
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	if not value:failures.append(message);push_error(message)
func encode(value:Variant)->Variant:
	if value is Resource:
		if value is Script or value is Shader or value is Texture2D and not value.resource_path.contains("::") and not value.resource_path.is_empty():return {"class":value.get_class(),"external":value.resource_path}
		var id:int=value.get_instance_id()
		if cache.has(id):return cache[id]
		var data:Dictionary={"class":value.get_class()};cache[id]=data
		for prop in value.get_property_list():
			var name:String=prop.name
			if not (int(prop.usage)&PROPERTY_USAGE_STORAGE) or name in ["resource_path","resource_name","resource_scene_unique_id","script"]:continue
			data[name]=encode(value.get(name))
		cache[id]=data;return data
	if value is Array:
		var result:Array=[]
		for item in value:result.append(encode(item))
		return result
	if value is Dictionary:
		var result:Dictionary={};var keys:Array=value.keys();keys.sort_custom(func(a,b):return str(a)<str(b))
		for key in keys:result[str(key)]=encode(value[key])
		return result
	if value is Object:return {"object_class":value.get_class()}
	if typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_STRING,TYPE_STRING_NAME,TYPE_NODE_PATH]:return str(value) if typeof(value) in [TYPE_STRING_NAME,TYPE_NODE_PATH] else value
	return {"type":typeof(value),"native_bytes":var_to_bytes(value).hex_encode()}
func snapshot(node:Node,path:String,result:Dictionary)->void:
	if node.has_meta("stage_pickup") and String(node.get_meta("stage_pickup")) in AMMO:return
	var data:Dictionary={"class":node.get_class(),"properties":{},"metadata":{}}
	for prop in node.get_property_list():
		var name:String=prop.name
		if not (int(prop.usage)&PROPERTY_USAGE_STORAGE) or name in ["script","owner","scene_file_path","unique_name_in_owner"]:continue
		data.properties[name]=encode(node.get(name))
	for key in node.get_meta_list():data.metadata[str(key)]=encode(node.get_meta(key))
	result[path]=data
	for index in node.get_child_count():
		var child:Node=node.get_child(index)
		var name:String=str(child.name)
		if name.begins_with("@"):name="auto_%s_%d" % [child.get_class(),index]
		snapshot(child,path+"/"+name,result)
func disable(node:Node)->void:
	node.set_physics_process(false);node.set_process(false)
	for child in node.get_children():disable(child)
func pickups(node:Node,result:Array[Node3D])->void:
	if node.has_meta("stage_pickup"):result.append(node)
	for child in node.get_children():pickups(child,result)
func press(held:bool)->void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_W;event.pressed=held;Input.parse_input_event(event)
func test_support(scene:Node3D)->Dictionary:
	root.add_child(scene);disable(scene)
	var actor:CharacterBody3D=scene.get_node("Player");actor.set_physics_process(true)
	var items:Array[Node3D]=[];pickups(scene,items)
	await physics_frame;await physics_frame
	var supports:Array[Dictionary]=[];var entry:Array[Node3D]=[]
	for item in items:
		var kind:String=item.get_meta("stage_pickup")
		if kind not in AMMO:continue
		var at:Vector3=item.global_position
		var query:=PhysicsRayQueryParameters3D.create(at+Vector3(0,.08,0),at-Vector3(0,2,0),1,[actor.get_rid()])
		var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty(),"Ammo pickup lacks nearby physical support: "+scene.name+"/"+item.name)
		if not hit.is_empty():
			check(hit.normal.y>.7,"Ammo pickup support not a walkable surface: "+scene.name+"/"+item.name)
			check(at.y-hit.position.y<=1.2,"Ammo pickup too high above floor: "+scene.name+"/"+item.name)
		supports.append({"name":str(item.name),"kind":kind,"position":encode(at),"floor":encode(hit.get("position",Vector3.ZERO)),"supported":not hit.is_empty()})
		if String(item.name).ends_with("_entry") and kind in ["pistol","shells","rivets","rockets"]:entry.append(item)
	var visited:Array[Dictionary]=[]
	for item in entry:
		var ticks:=0
		while Vector2(actor.position.x-item.position.x,actor.position.z-item.position.z).length()>.6 and ticks<180:
			var direction:Vector3=item.global_position-actor.global_position;direction.y=0
			actor.rotation.y=atan2(-direction.x,-direction.z);press(true);await physics_frame;ticks+=1
		press(false)
		for _tick in 8:await physics_frame
		var distance:float=actor.global_position.distance_to(item.global_position)
		check(distance<1.2 and actor.is_on_floor(),"Entry ammo unreachable by actual no-jump CharacterBody: "+scene.name+"/"+item.name)
		visited.append({"name":str(item.name),"physics_ticks":ticks,"distance":distance,"grounded":actor.is_on_floor(),"real_input":true})
	press(false);actor.set_physics_process(false)
	return {"ammo_support":supports,"entry_actual_movement":visited}
func run()->void:
	DirAccess.make_dir_recursive_absolute(BASELINE)
	var files:PackedStringArray=DirAccess.get_files_at("res://scenes/campaign");files.sort()
	for file in files:
		if not file.ends_with(".tscn"):continue
		cache.clear()
		var baseline_output:Array=[]
		var status:int=OS.execute("git",["-C",ProjectSettings.globalize_path("res://"),"show","6d3dc8b5b984ec3acb9809bbf32e8c65afbbedb5:eye-sore/build-two/scenes/campaign/"+file],baseline_output)
		check(status==0,"Could not extract preserved revision: "+file)
		if status!=0:quit(1);return
		var baseline_file:=FileAccess.open(BASELINE+file,FileAccess.WRITE);baseline_file.store_string(String(baseline_output[0]));baseline_file.close()
		var old:Node3D=load(BASELINE+file).instantiate();var current:Node3D=load("res://scenes/campaign/"+file).instantiate()
		old.scan(old);current.scan(current)
		var before:Dictionary={};var after:Dictionary={}
		snapshot(old,"world",before);cache.clear();snapshot(current,"world",after)
		var changes:Array[Dictionary]=[];var keys:Array=before.keys()
		for key in after:if not keys.has(key):keys.append(key)
		keys.sort()
		for key in keys:
			if before.get(key)!=after.get(key):
				var diff:Array[String]=[]
				if before.has(key) and after.has(key):
					for category in ["class","properties","metadata"]:
						if before[key][category]!=after[key][category]:diff.append(category)
				changes.append({"node":key,"categories":diff,"before":before.get(key),"after":after.get(key)})
		check(changes.is_empty(),"Preserved resolved world properties differ: "+file+" nodes="+str(changes.size()))
		old.free();cache.clear()
		var support:Dictionary=await test_support(current)
		records.append({"scene":file,"baseline_nodes":before.size(),"current_nodes":after.size(),"native_resolved_equal":changes.is_empty(),"differences":changes,"support":support,"current_sha256":FileAccess.get_sha256("res://scenes/campaign/"+file),"baseline_sha256":FileAccess.get_sha256(BASELINE+file)})
		current.free();await process_frame
		print("GEOMETRY_SCENE ",file," preserved=",changes.is_empty()," support_pickups=",support.ammo_support.size()," physically_reached_entry=",support.entry_actual_movement.size())
	var initial:Variant=JSON.parse_string(FileAccess.get_file_as_string(BASELINE+"initial-health-armor-defects.json")) if FileAccess.file_exists(BASELINE+"initial-health-armor-defects.json") else []
	var output:=FileAccess.open("res://verification/combat-balance-v4/geometry.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"baseline_revision":"6d3dc8b5b984ec3acb9809bbf32e8c65afbbedb5","records":records,"failures":failures,"initial_health_armor_findings":initial,"comparison":"Native instantiated nodes and runtime-built polygon bodies, shapes, meshes, materials, lights, room/door/lift/spawn metadata. Resource identifiers excluded; resource values and binary native math/packed-array data compared. Only intentional ammo/weapon-pickup subtrees excluded. Health/armor/key/control preserved.","reachability_scope":"All authored ammo pickups support checked by physical downward rays; entry supplies reached with actual player W input and no jumping. Actors not spawned; no combat survival claim."},"  "));output.close()
	print("BALANCE_GEOMETRY_V4_OK" if failures.is_empty() else "BALANCE_GEOMETRY_V4_FAILED")
	quit(0 if failures.is_empty() else 1)
