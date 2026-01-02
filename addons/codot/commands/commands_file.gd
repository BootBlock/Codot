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
