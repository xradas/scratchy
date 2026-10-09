extends SceneTree
## Export the pinned engine's own license/copyright records alongside a Linux build.
func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	assert(arguments.size() == 1, "Pass the package directory after --")
	var destination := arguments[0]
	assert(DirAccess.dir_exists_absolute(destination))
	var godot_license := FileAccess.open(destination.path_join("GODOT_LICENSE.txt"), FileAccess.WRITE)
	assert(godot_license != null)
	godot_license.store_string(Engine.get_license_text())
	godot_license.close()
	var notices := FileAccess.open(destination.path_join("GODOT_THIRD_PARTY_NOTICES.txt"), FileAccess.WRITE)
	assert(notices != null)
	notices.store_string("Bundled Godot component copyright records\n\n")
	notices.store_string(JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\n")
	var licenses := Engine.get_license_info()
	for name in licenses:
		notices.store_string(str(name) + "\n" + str(licenses[name]) + "\n\n")
	notices.close()
	print("ENGINE_LICENSES_OK: pinned engine license and component notices packaged")
	quit()
