extends RefCounted
## Only writes beneath Smoke's isolated runtime directory, never the game's external/.


func check(global_data: Node, runtime_dir: String) -> Dictionary:
	var results: Dictionary = {}
	var fixture_root: String = runtime_dir.path_join("loader-json-filter-%d" % Time.get_ticks_usec())
	var data_dir: String = "external/mods/filter/colors/"
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(fixture_root.path_join(data_dir + "nested.json/"))
	results["FileLoader fixture directory can be created"] = directory_error == OK
	if directory_error != OK:
		return results
	var fixture_files: Dictionary = {
		"external/mod_list.json": JSON.stringify({"properties": {"mod_load_data": {
			"external/mods/filter/": {"enabled": true, "load_priority": 0}
		}}}),
		"external/mods/filter/mod_info.json": JSON.stringify({"properties": {
			"object_id": "loader_filter_mod",
			"mod_folder_to_load_data": {data_dir: {"class_name": "ColorData", "table_name": "_id_to_color_data"}}
		}}),
		data_dir + "10_first.json": _color_json("loader_filter_order", "first"),
		data_dir + "20_upper.JSON": _color_json("loader_filter_upper", "uppercase"),
		data_dir + "90_last.json": _color_json("loader_filter_order", "last"),
		data_dir + "notes.txt": _color_json("loader_filter_notes", "must not load"),
		data_dir + "backup.json.bak": _color_json("loader_filter_backup", "must not load"),
		data_dir + "editor.json~": _color_json("loader_filter_editor", "must not load"),
		data_dir + ".gitkeep": "",
		data_dir + "README.md": "This ordinary file is deliberately not JSON.",
		data_dir + "nested.json/inside.json": _color_json("loader_filter_nested", "must not load"),
	}
	for relative_path: String in fixture_files:
		var written: bool = _write_file(fixture_root.path_join(relative_path), fixture_files[relative_path])
		results["FileLoader fixture writes " + relative_path] = written
		if not written:
			return results

	var loader: Node = load("res://autoload/FileLoader.gd").new()
	loader._EXTERNAL_FILE_PREFIX = fixture_root + "/"
	# Keep the original dictionary and resources intact; use a private typed table for this call.
	var original_table: Dictionary[String, ColorData] = global_data._id_to_color_data
	var fixture_table: Dictionary[String, ColorData] = {}
	global_data._id_to_color_data = fixture_table
	var listed: PackedStringArray = loader.get_files_in_directory(data_dir)
	results["FileLoader fixture enumerates ordinary non-JSON files"] = listed.has("notes.txt") and listed.has("README.md") and listed.has("backup.json.bak")
	results["FileLoader directory enumeration excludes directories ending in .json"] = not listed.has("nested.json")
	# Do not mock load_json or enumeration: invalid non-JSON files must never reach JSON parsing.
	loader.load_read_only_data()
	results["FileLoader accepts lowercase JSON and preserves sorted patch order"] = fixture_table.has("loader_filter_order") and fixture_table["loader_filter_order"].color_name == "last"
	results["FileLoader accepts uppercase JSON extension"] = fixture_table.has("loader_filter_upper") and fixture_table["loader_filter_upper"].color_name == "uppercase"
	results["FileLoader ignores non-JSON notes and backup files"] = not fixture_table.has("loader_filter_notes") and not fixture_table.has("loader_filter_backup") and not fixture_table.has("loader_filter_editor")
	results["FileLoader does not recursively load nested JSON"] = not fixture_table.has("loader_filter_nested")
	results["FileLoader registers only the two expected fixture objects"] = fixture_table.size() == 2
	global_data._id_to_color_data = original_table
	results["FileLoader probe restores the original global color table"] = is_same(global_data._id_to_color_data, original_table)
	loader.free()
	return results


func _color_json(object_id: String, color_name: String) -> String:
	return JSON.stringify({"properties": {"object_id": object_id, "color_name": color_name}})


func _write_file(path: String, contents: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	return FileAccess.get_file_as_string(path) == contents
