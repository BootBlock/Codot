@tool
extends "command_base.gd"
## File operation commands for Codot.
##
## Provides commands for:
## - Listing project files
## - Reading files
## - Writing files
## - Checking file existence


## Get a list of project files matching criteria.
func cmd_get_project_files(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "res://")
	var extension: String = params.get("extension", "")
	var recursive: bool = params.get("recursive", true)
	
	# Validate path is within project
	var path_err: Dictionary = _validate_path_in_project(path, cmd_id)
	if not path_err.is_empty():
		return path_err
	
	var files: Array = []
	_scan_directory(path, extension, recursive, files)
	return _success(cmd_id, {"files": files, "count": files.size()})


## Read the contents of a file.
func cmd_read_file(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	# Validate path is within project
	var path_err: Dictionary = _validate_path_in_project(path, cmd_id)
	if not path_err.is_empty():
		return path_err
	
	if not FileAccess.file_exists(path):
		return _error(cmd_id, "FILE_NOT_FOUND", "File not found: " + path)
	
	# Validate file size
	var size_err: Dictionary = _validate_file_size(path, cmd_id)
	if not size_err.is_empty():
		return size_err
	
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error(cmd_id, "FILE_ERROR", "Could not open file: " + path)
	
	var content: String = file.get_as_text()
	file.close()
	
	return _success(cmd_id, {"path": path, "content": content, "size": content.length()})


## Write content to a file.
func cmd_write_file(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var content: String = params.get("content", "")
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	# Validate path is within project
	var path_err: Dictionary = _validate_path_in_project(path, cmd_id)
	if not path_err.is_empty():
		return path_err
	
	# Validate content size
	var max_size: int = _get_max_file_size()
	if content.length() > max_size:
		return _error(cmd_id, "CONTENT_TOO_LARGE",
			"Content size (%d bytes) exceeds maximum allowed size (%d bytes)." % [content.length(), max_size])
	
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error(cmd_id, "FILE_ERROR", "Could not write file: " + path)
	
	file.store_string(content)
	file.close()
	
	return _success(cmd_id, {"path": path, "written": true, "size": content.length()})


## Check if a file or directory exists.
func cmd_file_exists(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	# Validate path is within project
	var path_err: Dictionary = _validate_path_in_project(path, cmd_id)
	if not path_err.is_empty():
		return path_err
	
	var exists: bool = FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
	return _success(cmd_id, {"path": path, "exists": exists})


## Create a directory (and any parent directories).
## [br][br]
## [param params]:
## - 'path' (String, required): Directory path to create (e.g., "res://new_folder/subfolder").
func cmd_create_directory(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	# Validate path is within project
	var path_err: Dictionary = _validate_path_in_project(path, cmd_id)
	if not path_err.is_empty():
		return path_err
	
	if DirAccess.dir_exists_absolute(path):
		return _success(cmd_id, {"path": path, "created": false, "already_exists": true})
	
	var err: Error = DirAccess.make_dir_recursive_absolute(path)
	if err != OK:
		return _error(cmd_id, "CREATE_FAILED", "Failed to create directory: " + path + " (error: " + str(err) + ")")
	
	return _success(cmd_id, {"path": path, "created": true, "already_exists": false})


## Delete a file.
## [br][br]
## [param params]:
## - 'path' (String, required): File path to delete.
func cmd_delete_file(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	# Validate path is within project
	var path_err: Dictionary = _validate_path_in_project(path, cmd_id)
	if not path_err.is_empty():
		return path_err
	
	if not FileAccess.file_exists(path):
		return _error(cmd_id, "FILE_NOT_FOUND", "File not found: " + path)
	
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return _error(cmd_id, "DIR_ERROR", "Cannot access directory: " + path.get_base_dir())
	
	var err := dir.remove(path.get_file())
	if err != OK:
		return _error(cmd_id, "DELETE_FAILED", "Failed to delete file: " + path + " (error: " + str(err) + ")")
	
	return _success(cmd_id, {"path": path, "deleted": true})


## Delete a directory (must be empty unless recursive=true).
## [br][br]
## [param params]:
## - 'path' (String, required): Directory path to delete.
## - 'recursive' (bool, default false): Delete all contents recursively.
func cmd_delete_directory(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var recursive: bool = params.get("recursive", false)
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	# Validate path is within project
	var path_err: Dictionary = _validate_path_in_project(path, cmd_id)
	if not path_err.is_empty():
		return path_err
	
	if not DirAccess.dir_exists_absolute(path):
		return _error(cmd_id, "DIR_NOT_FOUND", "Directory not found: " + path)
	
	if recursive:
		var deleted_count := _delete_directory_recursive(path)
		return _success(cmd_id, {"path": path, "deleted": true, "files_deleted": deleted_count})
	else:
		var dir := DirAccess.open(path.get_base_dir())
		if dir == null:
			return _error(cmd_id, "DIR_ERROR", "Cannot access parent directory")
		
		var err := dir.remove(path.get_file())
		if err != OK:
			return _error(cmd_id, "DELETE_FAILED", "Failed to delete directory (may not be empty): " + path)
		
		return _success(cmd_id, {"path": path, "deleted": true, "files_deleted": 0})


## Rename/move a file or directory.
## [br][br]
## [param params]:
## - 'from_path' (String, required): Source path.
## - 'to_path' (String, required): Destination path.
func cmd_rename_file(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var from_path: String = params.get("from_path", "")
	var to_path: String = params.get("to_path", "")
	
	if from_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'from_path' parameter")
	if to_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'to_path' parameter")
	
	# Validate both paths are within project
	var from_path_err: Dictionary = _validate_path_in_project(from_path, cmd_id)
	if not from_path_err.is_empty():
		return from_path_err
	
	var to_path_err: Dictionary = _validate_path_in_project(to_path, cmd_id)
	if not to_path_err.is_empty():
		return to_path_err
	
	var is_file: bool = FileAccess.file_exists(from_path)
	var is_dir: bool = DirAccess.dir_exists_absolute(from_path)
	
	if not is_file and not is_dir:
		return _error(cmd_id, "NOT_FOUND", "Source not found: " + from_path)
	
	var dir := DirAccess.open(from_path.get_base_dir())
	if dir == null:
		return _error(cmd_id, "DIR_ERROR", "Cannot access source directory")
	
	# Ensure destination directory exists
	var to_dir := to_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(to_dir):
		DirAccess.make_dir_recursive_absolute(to_dir)
	
	var err := dir.rename(from_path, to_path)
	if err != OK:
		return _error(cmd_id, "RENAME_FAILED", "Failed to rename: " + from_path + " -> " + to_path)
	
	return _success(cmd_id, {"from_path": from_path, "to_path": to_path, "renamed": true, "type": "directory" if is_dir else "file"})


## Copy a file.
## [br][br]
## [param params]:
## - 'from_path' (String, required): Source file path.
## - 'to_path' (String, required): Destination file path.
## - 'overwrite' (bool, default false): Overwrite if destination exists.
func cmd_copy_file(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var from_path: String = params.get("from_path", "")
	var to_path: String = params.get("to_path", "")
	var overwrite: bool = params.get("overwrite", false)
	
	if from_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'from_path' parameter")
	if to_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'to_path' parameter")
	
	# Validate both paths are within project
	var from_path_err: Dictionary = _validate_path_in_project(from_path, cmd_id)
	if not from_path_err.is_empty():
		return from_path_err
	
	var to_path_err: Dictionary = _validate_path_in_project(to_path, cmd_id)
	if not to_path_err.is_empty():
		return to_path_err
	
	if not FileAccess.file_exists(from_path):
		return _error(cmd_id, "FILE_NOT_FOUND", "Source file not found: " + from_path)
	
	if FileAccess.file_exists(to_path) and not overwrite:
		return _error(cmd_id, "FILE_EXISTS", "Destination file exists: " + to_path + " (use overwrite=true)")
	
	# Ensure destination directory exists
	var to_dir := to_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(to_dir):
		DirAccess.make_dir_recursive_absolute(to_dir)
	
	var dir := DirAccess.open(from_path.get_base_dir())
	if dir == null:
		return _error(cmd_id, "DIR_ERROR", "Cannot access source directory")
	
	var err := dir.copy(from_path, to_path)
	if err != OK:
		return _error(cmd_id, "COPY_FAILED", "Failed to copy file: " + from_path + " -> " + to_path)
	
	return _success(cmd_id, {"from_path": from_path, "to_path": to_path, "copied": true})


## Get file or directory information (size, modified time, etc.).
## [br][br]
## [param params]:
## - 'path' (String, required): File or directory path.
func cmd_get_file_info(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	# Validate path is within project
	var path_err: Dictionary = _validate_path_in_project(path, cmd_id)
	if not path_err.is_empty():
		return path_err
	
	var is_file: bool = FileAccess.file_exists(path)
	var is_dir: bool = DirAccess.dir_exists_absolute(path)
	
	if not is_file and not is_dir:
		return _error(cmd_id, "NOT_FOUND", "Path not found: " + path)
	
	var info := {
		"path": path,
		"type": "directory" if is_dir else "file",
		"name": path.get_file(),
		"extension": path.get_extension() if is_file else "",
		"base_dir": path.get_base_dir()
	}
	
	if is_file:
		info["size"] = FileAccess.get_file_as_bytes(path).size()
		info["modified_time"] = FileAccess.get_modified_time(path)
	
	return _success(cmd_id, info)


# Helper: Recursively delete a directory and its contents.
func _delete_directory_recursive(path: String) -> int:
	var count := 0
	var dir := DirAccess.open(path)
	if dir == null:
		return count
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := path.path_join(file_name)
			if dir.current_is_dir():
				count += _delete_directory_recursive(full_path)
			else:
				dir.remove(file_name)
				count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Now remove the empty directory
	var parent := DirAccess.open(path.get_base_dir())
	if parent != null:
		parent.remove(path.get_file())
	
	return count


#region Quick Find Commands

## Find files by name pattern (glob-like matching).
## [br][br]
## [param params]:
## - 'pattern' (String, required): Search pattern (e.g., "player", "*.gd", "test_*").
## - 'path' (String, default "res://"): Directory to search in.
## - 'extensions' (Array, optional): Limit to specific extensions (e.g., ["gd", "tscn"]).
## - 'max_results' (int, default 50): Maximum number of results.
## - 'case_sensitive' (bool, default false): Case-sensitive matching.
func cmd_find_file(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var pattern: String = params.get("pattern", "")
	if pattern.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'pattern' parameter")
	
	var search_path: String = params.get("path", "res://")
	var extensions: Array = params.get("extensions", [])
	var max_results: int = params.get("max_results", 50)
	var case_sensitive: bool = params.get("case_sensitive", false)
	
	var results: Array = []
	_find_files_matching(search_path, pattern, extensions, case_sensitive, max_results, results)
	
	return _success(cmd_id, {
		"pattern": pattern,
		"results": results,
		"count": results.size(),
		"truncated": results.size() >= max_results
	})


## Find all resources of a specific type in the project.
## [br][br]
## [param params]:
## - 'type' (String, required): Resource type to find (e.g., "Script", "PackedScene", "Texture2D").
## - 'path' (String, default "res://"): Directory to search in.
## - 'max_results' (int, default 100): Maximum number of results.
func cmd_find_resources_by_type(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var res_type: String = params.get("type", "")
	if res_type.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'type' parameter")
	
	var search_path: String = params.get("path", "res://")
	var max_results: int = params.get("max_results", 100)
	
	# Map type names to file extensions
	var type_extensions := {
		"Script": ["gd"],
		"GDScript": ["gd"],
		"PackedScene": ["tscn", "scn"],
		"Scene": ["tscn", "scn"],
		"Texture2D": ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga"],
		"Texture": ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga"],
		"AudioStream": ["wav", "ogg", "mp3"],
		"Audio": ["wav", "ogg", "mp3"],
		"Shader": ["gdshader", "shader"],
		"Material": ["tres", "material"],
		"Resource": ["tres", "res"],
		"Font": ["ttf", "otf", "fnt"],
		"Animation": ["anim", "tres"],
		"Mesh": ["obj", "gltf", "glb", "fbx"],
		"Theme": ["tres", "theme"]
	}
	
	var extensions: Array = type_extensions.get(res_type, [])
	if extensions.is_empty():
		# If not a known type, search .tres files and load to check type
		extensions = ["tres", "res"]
	
	var results: Array = []
	_find_files_by_extensions(search_path, extensions, max_results, results)
	
	# For generic Resource type searches, verify the actual type
	if res_type == "Resource" or not type_extensions.has(res_type):
		var filtered: Array = []
		for file_path: String in results:
			if ResourceLoader.exists(file_path):
				var res := load(file_path)
				if res != null:
					var res_class := res.get_class()
					if res_class == res_type or res_type == "Resource":
						filtered.append({"path": file_path, "type": res_class})
		results = filtered
	else:
		# Convert to array of dictionaries with type info
		var typed_results: Array = []
		for file_path: String in results:
			typed_results.append({"path": file_path, "type": res_type})
		results = typed_results
	
	return _success(cmd_id, {
		"type": res_type,
		"results": results,
		"count": results.size(),
		"truncated": results.size() >= max_results
	})


## Search for text within files.
## [br][br]
## [param params]:
## - 'query' (String, required): Text to search for.
## - 'path' (String, default "res://"): Directory to search in.
## - 'extensions' (Array, default ["gd", "tscn", "tres", "cfg", "json", "md", "txt"]).
## - 'case_sensitive' (bool, default false): Case-sensitive search.
## - 'max_results' (int, default 50): Maximum number of files with matches.
## - 'context_lines' (int, default 1): Lines of context around matches.
func cmd_search_in_files(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var query: String = params.get("query", "")
	if query.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'query' parameter")
	
	var search_path: String = params.get("path", "res://")
	var extensions: Array = params.get("extensions", ["gd", "tscn", "tres", "cfg", "json", "md", "txt"])
	var case_sensitive: bool = params.get("case_sensitive", false)
	var max_results: int = params.get("max_results", 50)
	var context_lines: int = params.get("context_lines", 1)
	
	var results: Array = []
	var total_matches := 0
	
	var files: Array = []
	_find_files_by_extensions(search_path, extensions, 1000, files)
	
	var search_query := query if case_sensitive else query.to_lower()
	
	for file_path: String in files:
		if results.size() >= max_results:
			break
		
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			continue
		
		var content := file.get_as_text()
		file.close()
		
		var search_content := content if case_sensitive else content.to_lower()
		
		if search_query in search_content:
			var lines := content.split("\n")
			var matches: Array = []
			
			for i in range(lines.size()):
				var line := lines[i]
				var search_line := line if case_sensitive else line.to_lower()
				
				if search_query in search_line:
					total_matches += 1
					var match_info := {
						"line_number": i + 1,
						"line": line.strip_edges(),
						"context": []
					}
					
					# Add context lines
					for ctx in range(maxi(0, i - context_lines), mini(lines.size(), i + context_lines + 1)):
						if ctx != i:
							match_info.context.append({
								"line_number": ctx + 1,
								"line": lines[ctx].strip_edges()
							})
					
					matches.append(match_info)
					
					if matches.size() >= 10:  # Limit matches per file
						break
			
			results.append({
				"path": file_path,
				"matches": matches,
				"match_count": matches.size()
			})
	
	return _success(cmd_id, {
		"query": query,
		"results": results,
		"files_with_matches": results.size(),
		"total_matches": total_matches,
		"truncated": results.size() >= max_results
	})


## Find nodes that use a specific script.
## [br][br]
## [param params]:
## - 'script_path' (String, required): Path to the script (e.g., "res://player.gd").
## - 'search_scenes' (Array, optional): Specific scenes to search, or all if not specified.
## - 'max_results' (int, default 50): Maximum number of results.
func cmd_find_nodes_by_script(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var script_path: String = params.get("script_path", "")
	if script_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'script_path' parameter")
	
	if not FileAccess.file_exists(script_path):
		return _error(cmd_id, "FILE_NOT_FOUND", "Script not found: " + script_path)
	
	var search_scenes: Array = params.get("search_scenes", [])
	var max_results: int = params.get("max_results", 50)
	
	# If no specific scenes, search all .tscn files
	if search_scenes.is_empty():
		_find_files_by_extensions("res://", ["tscn"], 500, search_scenes)
	
	var results: Array = []
	
	for scene_path: Variant in search_scenes:
		if results.size() >= max_results:
			break
		
		if not FileAccess.file_exists(scene_path as String):
			continue
		
		var file := FileAccess.open(scene_path as String, FileAccess.READ)
		if file == null:
			continue
		
		var content := file.get_as_text()
		file.close()
		
		# Look for script references in the scene file
		if script_path in content:
			# Parse to find node names
			var node_names: Array = []
			var lines := content.split("\n")
			var current_node := ""
			
			for line in lines:
				if line.begins_with("[node"):
					# Extract node name
					var name_match := RegEx.new()
					name_match.compile('name="([^"]+)"')
					var result := name_match.search(line)
					if result:
						current_node = result.get_string(1)
				
				if script_path in line and current_node:
					node_names.append(current_node)
			
			if node_names.size() > 0:
				results.append({
					"scene_path": scene_path,
					"nodes": node_names
				})
	
	return _success(cmd_id, {
		"script_path": script_path,
		"results": results,
		"count": results.size(),
		"truncated": results.size() >= max_results
	})


# Helper: Find files matching a pattern
func _find_files_matching(path: String, pattern: String, extensions: Array, case_sensitive: bool, max_results: int, results: Array) -> void:
	if results.size() >= max_results:
		return
	
	var dir := DirAccess.open(path)
	if dir == null:
		return
	
	var search_pattern := pattern if case_sensitive else pattern.to_lower()
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "" and results.size() < max_results:
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var full_path := path.path_join(file_name)
		
		if dir.current_is_dir():
			_find_files_matching(full_path, pattern, extensions, case_sensitive, max_results, results)
		else:
			var match_name := file_name if case_sensitive else file_name.to_lower()
			var ext := file_name.get_extension().to_lower()
			
			# Check extension filter
			if extensions.size() > 0 and ext not in extensions:
				file_name = dir.get_next()
				continue
			
			# Check pattern match
			var matches := false
			if "*" in search_pattern:
				# Simple glob matching
				if search_pattern.begins_with("*"):
					matches = match_name.ends_with(search_pattern.substr(1))
				elif search_pattern.ends_with("*"):
					matches = match_name.begins_with(search_pattern.substr(0, search_pattern.length() - 1))
				else:
					matches = search_pattern in match_name
			else:
				matches = search_pattern in match_name
			
			if matches:
				results.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


# Helper: Find files by extensions
func _find_files_by_extensions(path: String, extensions: Array, max_results: int, results: Array) -> void:
	if results.size() >= max_results:
		return
	
	var dir := DirAccess.open(path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "" and results.size() < max_results:
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var full_path := path.path_join(file_name)
		
		if dir.current_is_dir():
			_find_files_by_extensions(full_path, extensions, max_results, results)
		else:
			var ext := file_name.get_extension().to_lower()
			if ext in extensions:
				results.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

#endregion
