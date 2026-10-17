extends SceneTree
func _initialize() -> void:
	var source=Image.load_from_file("res://assets/weapons/arsenal-v2/twin_shotgun-atlas-r2.png")
	var j: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json"))
	for phase in ["idle","fire","recover","switch"]:
		var r: Array=j.weapon_atlases.twin_shotgun.regions[phase]
		source.get_region(Rect2i(r[0],r[1],r[2],r[3])).save_png("res://verification/production-v8/twin/source-"+phase+".png")
	quit()
