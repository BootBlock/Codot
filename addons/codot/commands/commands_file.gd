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
	
	var files: Array = []
	_scan_directory(path, extension, recursive, files)
	return _success(cmd_id, {"files": files, "count": files.size()})


## Read the contents of a file.
func cmd_read_file(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not FileAccess.file_exists(path):
		return _error(cmd_id, "FILE_NOT_FOUND", "File not found: " + path)
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error(cmd_id, "FILE_ERROR", "Could not open file: " + path)
	
	var content = file.get_as_text()
	file.close()
	
	return _success(cmd_id, {"path": path, "content": content, "size": content.length()})


## Write content to a file.
func cmd_write_file(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var content: String = params.get("content", "")
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var file = FileAccess.open(path, FileAccess.WRITE)
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
	
	var exists = FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
	return _success(cmd_id, {"path": path, "exists": exists})


## Create a directory (and any parent directories).
## [br][br]
## [param params]:
## - 'path' (String, required): Directory path to create (e.g., "res://new_folder/subfolder").
func cmd_create_directory(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if DirAccess.dir_exists_absolute(path):
		return _success(cmd_id, {"path": path, "created": false, "already_exists": true})
	
	var err := DirAccess.make_dir_recursive_absolute(path)
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
	
	var is_file := FileAccess.file_exists(from_path)
	var is_dir := DirAccess.dir_exists_absolute(from_path)
	
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
	
	var is_file := FileAccess.file_exists(path)
	var is_dir := DirAccess.dir_exists_absolute(path)
	
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
