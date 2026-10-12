extends SceneTree
## Read-only trusted previous embedded PCK snapshot; never invokes its ELF.
func value(v: Variant) -> Variant:
	if v is Resource:return v.resource_path
	if v is StringName or v is NodePath:return String(v)
	if v is Array:
		var a: Array=[]
		for item in v:a.append(value(item))
		return a
	return v
func properties(resource: Resource) -> Dictionary:
	var result: Dictionary={}
	for p in resource.get_property_list():
		if int(p.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE and int(p.usage)&PROPERTY_USAGE_STORAGE:
			if String(p.name)!="cues":result[String(p.name)]=value(resource.get(p.name))
	return result
func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/catalog.json"))
	var levels: Dictionary={}
	for chapter in catalog.chapters:
		for level in chapter.levels:
			var path: String="res://resources/campaign/"+String(level.id)+"-layout.json"
			var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
			levels[level.id]={"rooms":data.rooms,"keys":data.keys,"layout_sha256":FileAccess.get_sha256(path)}
	var profile: Resource=load("res://resources/combat_audio.tres")
	var cues: Array=[]
	for cue in profile.cues:cues.append(properties(cue))
	var ledger_path: String="res://assets/audio/runtime-cues.json"
	var result: Dictionary={"source":"Externally pinned Godot reading verified v5 r2 embedded PCK; no archived ELF executed.","levels":levels,"profile_properties":properties(profile),"profile_cues":cues,"cue_ledger":JSON.parse_string(FileAccess.get_file_as_string(ledger_path)),"cue_ledger_sha256":FileAccess.get_sha256(ledger_path)}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();quit()
