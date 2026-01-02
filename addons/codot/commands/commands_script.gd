## Script Operations Module
## Handles script editing and error checking.
extends "command_base.gd"


## Check a script for errors.
## [br][br]
## [param params]: Must contain 'path' (String) - script file path.
## [br][br]
## Note: In Godot 4, this loads the script to verify validity.
func cmd_get_script_errors(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	
	if path.is_empty():
		return _success(cmd_id, {"errors": [], "message": "No path specified, cannot check errors"})
	
	# Try to load the script to check for errors
	var script = load(path)
	if script == null:
		return _success(cmd_id, {"errors": [{"path": path, "error": "Failed to load script"}]})
	
	return _success(cmd_id, {"errors": [], "path": path, "valid": true})


## Open a script in the editor.
## [br][br]
## [param params]:
## - 'path' (String, required): Script file path.
## - 'line' (int, optional): Line number to jump to.
func cmd_open_script(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var path: String = params.get("path", "")
	var line: int = params.get("line", 0)
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var script = load(path)
	if script != null:
		editor_interface.edit_script(script, line)
		return _success(cmd_id, {"opened": path, "line": line})
	else:
		return _error(cmd_id, "SCRIPT_NOT_FOUND", "Could not load script: " + path)
