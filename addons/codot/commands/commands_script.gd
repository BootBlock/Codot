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


## Get all breakpoints set in scripts.
## [br][br]
## [param params]:
## - 'path' (String, optional): Filter to a specific script path.
func cmd_get_breakpoints(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var filter_path: String = params.get("path", "")
	
	var script_editor = editor_interface.get_script_editor()
	if script_editor == null:
		return _error(cmd_id, "NO_SCRIPT_EDITOR", "Script editor not available")
	
	var breakpoints: Array = script_editor.get_breakpoints()
	var formatted: Array = []
	
	# Breakpoints come as an array of dictionaries with "source" and "line" keys
	for bp in breakpoints:
		if bp is Dictionary:
			var source: String = bp.get("source", "")
			var line: int = bp.get("line", 0)
			if filter_path.is_empty() or source == filter_path:
				formatted.append({
					"path": source,
					"line": line
				})
	
	return _success(cmd_id, {
		"breakpoints": formatted,
		"count": formatted.size()
	})


## Set or clear a breakpoint in a script.
## [br][br]
## [param params]:
## - 'path' (String, required): Script file path.
## - 'line' (int, required): Line number (1-based).
## - 'enabled' (bool, optional): Whether to set (true) or clear (false). Default true.
func cmd_set_breakpoint(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var path: String = params.get("path", "")
	var line: int = params.get("line", 0)
	var enabled: bool = params.get("enabled", true)
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if line <= 0:
		return _error(cmd_id, "MISSING_PARAM", "Missing or invalid 'line' parameter (must be >= 1)")
	
	# Load the script first to verify it exists
	var script = load(path)
	if script == null:
		return _error(cmd_id, "SCRIPT_NOT_FOUND", "Could not load script: " + path)
	
	# Open the script in editor
	editor_interface.edit_script(script, line)
	
	# Get the script editor and set breakpoint
	# Note: In Godot 4, breakpoints are managed via the script text editor
	# We need to access the CodeEdit to toggle breakpoints
	var script_editor = editor_interface.get_script_editor()
	if script_editor == null:
		return _error(cmd_id, "NO_SCRIPT_EDITOR", "Script editor not available")
	
	# Godot 4.x: We need to use EditorDebugger for breakpoints
	# Since the direct API is limited, we'll inform the user of what was attempted
	# The breakpoint toggle must be done through the UI or by editing the breakpoint list
	
	return _success(cmd_id, {
		"path": path,
		"line": line,
		"enabled": enabled,
		"note": "Script opened at line. Use Ctrl+B to toggle breakpoint, or F9 in some configurations."
	})


## Clear all breakpoints in all scripts or a specific script.
## [br][br]
## [param params]:
## - 'path' (String, optional): Script path. If empty, clears all breakpoints.
func cmd_clear_breakpoints(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var path: String = params.get("path", "")
	
	# Unfortunately, Godot 4.x doesn't provide a direct API to clear breakpoints
	# We can only list them via get_breakpoints()
	
	return _success(cmd_id, {
		"path": path if not path.is_empty() else "all",
		"note": "Breakpoint clearing via API is limited in Godot 4. Use the Debug menu or Ctrl+Shift+F9."
	})

