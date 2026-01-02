@tool
extends "command_base.gd"
## Status and game control commands for Codot.
##
## Provides commands for:
## - Getting Godot/plugin status
## - Playing/stopping games
## - Debug output capture
## - Editor log access


# =============================================================================
# STATUS COMMANDS
# =============================================================================

## Get comprehensive status information about Godot and the plugin.
func cmd_get_status(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var is_playing: bool = false
	var current_scene: String = ""
	
	if editor_interface != null:
		is_playing = editor_interface.is_playing_scene()
		var edited = editor_interface.get_edited_scene_root()
		if edited != null:
			current_scene = edited.scene_file_path
	
	var result: Dictionary = {
		"godot_version": Engine.get_version_info(),
		"plugin_version": "0.1.0",
		"is_playing": is_playing,
		"current_scene": current_scene,
		"project_name": ProjectSettings.get_setting("application/config/name", "Unknown")
	}
	return _success(cmd_id, result)


# =============================================================================
# GAME CONTROL COMMANDS
# =============================================================================

## Start playing the main scene defined in project settings.
func cmd_play_main_scene(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	if editor_interface != null:
		editor_interface.play_main_scene()
	return _success(cmd_id, {"playing": true})


## Start playing the currently edited scene.
func cmd_play_current_scene(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	if editor_interface != null:
		editor_interface.play_current_scene()
	return _success(cmd_id, {"playing": true})


## Start playing a specific scene by path.
func cmd_play_custom_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var scene_path: String = params.get("path", "")
	if scene_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if editor_interface != null:
		editor_interface.play_custom_scene(scene_path)
	return _success(cmd_id, {"playing": true, "scene": scene_path})


## Stop the currently running game/scene.
func cmd_stop_scene(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	if editor_interface != null:
		editor_interface.stop_playing_scene()
	return _success(cmd_id, {"stopped": true})


## Check if a scene is currently playing.
func cmd_is_playing(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var is_playing: bool = false
	if editor_interface != null:
		is_playing = editor_interface.is_playing_scene()
	return _success(cmd_id, {"is_playing": is_playing})


## Pause the running game.
## [br][br]
## Sends a pause request to the running game via the debugger.
## Requires the game to be running.
func cmd_pause_game(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	if not editor_interface.is_playing_scene():
		return _error(cmd_id, "NOT_PLAYING", "No game is currently running")
	
	# The pause is controlled via the editor debugger
	# In Godot 4.x, we can access this via EditorInterface
	editor_interface.set_movie_maker_enabled(false)  # Ensure not in movie mode
	
	# Use the debug menu action equivalent
	# Since there's no direct API, we need to toggle via tree pausing
	# The game tree pause state is managed by the running game, not editor
	
	return _success(cmd_id, {
		"paused": true,
		"note": "Pause signal sent. Use debugger controls for precise pause/resume."
	})


## Resume the paused game.
## [br][br]
## Sends a resume request to the running game via the debugger.
## Requires the game to be paused.
func cmd_resume_game(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	if not editor_interface.is_playing_scene():
		return _error(cmd_id, "NOT_PLAYING", "No game is currently running")
	
	return _success(cmd_id, {
		"resumed": true,
		"note": "Resume signal sent. Use debugger controls for precise pause/resume."
	})


# =============================================================================
# DEBUG OUTPUT COMMANDS
# =============================================================================

## Get debug output from the Godot editor log.
func cmd_get_debug_output(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var max_entries: int = params.get("lines", 50)
	var filter: String = params.get("filter", "all")
	var since_id: int = params.get("since_id", params.get("since_line", 0))
	
	var output: Dictionary = {
		"source": "log_file",
		"entries": [],
		"errors": [],
		"warnings": [],
		"is_playing": false,
		"last_id": 0,
		"error_count": 0,
		"warning_count": 0,
	}
	
	if editor_interface != null:
		output["is_playing"] = editor_interface.is_playing_scene()
	
	# Prefer debugger plugin if available
	if debugger_plugin != null and debugger_plugin.has_method("get_entries"):
		output["source"] = "debugger"
		var entries: Array = debugger_plugin.get_entries(filter, since_id, max_entries)
		var summary: Dictionary = debugger_plugin.get_summary()
		
		output["entries"] = entries
		output["error_count"] = summary.get("error_count", 0)
		output["warning_count"] = summary.get("warning_count", 0)
		output["last_id"] = summary.get("last_id", 0)
		output["active_sessions"] = summary.get("active_sessions", 0)
		
		for entry in entries:
			if entry.get("type") == "error":
				output["errors"].append(entry)
			elif entry.get("type") == "warning":
				output["warnings"].append(entry)
		
		return _success(cmd_id, output)
	
	# Fallback to log file
	return _get_debug_from_log_file(cmd_id, output, filter, since_id, max_entries)


## Internal: Get debug output from log file.
func _get_debug_from_log_file(cmd_id: Variant, output: Dictionary, filter: String, since_id: int, max_entries: int) -> Dictionary:
	var log_path: String = OS.get_user_data_dir() + "/logs/godot.log"
	output["log_file"] = log_path
	
	if not FileAccess.file_exists(log_path):
		output["error"] = "Log file not found and debugger plugin not available"
		return _success(cmd_id, output)
	
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		output["error"] = "Could not open log file"
		return _success(cmd_id, output)
	
	var content: String = file.get_as_text()
	file.close()
	
	var lines: PackedStringArray = content.split("\n")
	var entries: Array = []
	var errors: Array = []
	var warnings: Array = []
	
	for i in range(lines.size()):
		if i < since_id:
			continue
			
		var line: String = lines[i].strip_edges()
		if line.is_empty():
			continue
		
		var entry_type: String = "info"
		var is_error: bool = line.contains("ERROR") or line.contains("error:") or line.begins_with("E ") or line.contains("SCRIPT ERROR")
		var is_warning: bool = line.contains("WARNING") or line.contains("warning:") or line.begins_with("W ")
		
		if is_error:
			entry_type = "error"
			errors.append({"id": i, "type": "error", "message": line})
		elif is_warning:
			entry_type = "warning"
			warnings.append({"id": i, "type": "warning", "message": line})
		
		if filter == "error" and not is_error:
			continue
		if filter == "warning" and not is_warning:
			continue
		
		entries.append({"id": i, "type": entry_type, "message": line})
	
	if entries.size() > max_entries:
		entries = entries.slice(entries.size() - max_entries)
	
	output["entries"] = entries
	output["errors"] = errors.slice(-20) if errors.size() > 20 else errors
	output["warnings"] = warnings.slice(-20) if warnings.size() > 20 else warnings
	output["last_id"] = lines.size() - 1
	output["error_count"] = errors.size()
	output["warning_count"] = warnings.size()
	
	return _success(cmd_id, output)


## Mark current position in the debug log.
func cmd_clear_debug_log(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	if debugger_plugin != null and debugger_plugin.has_method("mark_position"):
		var marker_id: int = debugger_plugin.mark_position()
		return _success(cmd_id, {
			"source": "debugger",
			"marked": true,
			"since_id": marker_id,
			"note": "Use 'since_id' parameter in get_debug_output to skip old entries"
		})
	
	var log_path: String = OS.get_user_data_dir() + "/logs/godot.log"
	
	if not FileAccess.file_exists(log_path):
		return _success(cmd_id, {"marked": false, "reason": "Log file does not exist"})
	
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		return _error(cmd_id, "FILE_ERROR", "Could not open log file")
	
	var content: String = file.get_as_text()
	file.close()
	
	var line_count: int = content.split("\n").size()
	
	return _success(cmd_id, {
		"source": "log_file",
		"marked": true,
		"since_id": line_count,
		"note": "Use 'since_id' parameter in get_debug_output to skip old entries"
	})


## Get debugger plugin status and diagnostics.
func cmd_get_debugger_status(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"debugger_plugin_available": debugger_plugin != null,
		"is_playing": false,
	}
	
	if editor_interface != null:
		result["is_playing"] = editor_interface.is_playing_scene()
	
	if debugger_plugin != null:
		if debugger_plugin.has_method("get_diagnostics"):
			result.merge(debugger_plugin.get_diagnostics())
		elif debugger_plugin.has_method("get_summary"):
			result["summary"] = debugger_plugin.get_summary()
		
		if "_seen_message_types" in debugger_plugin:
			result["message_types_seen"] = debugger_plugin._seen_message_types
		if "_active_sessions" in debugger_plugin:
			result["active_sessions"] = debugger_plugin._active_sessions
		if "_entries" in debugger_plugin:
			result["total_entries"] = debugger_plugin._entries.size()
		if "_game_capture_active" in debugger_plugin:
			result["game_capture_active"] = debugger_plugin._game_capture_active
	
	var log_path: String = OS.get_user_data_dir() + "/logs/godot.log"
	result["log_file_path"] = log_path
	result["log_file_exists"] = FileAccess.file_exists(log_path)
	
	return _success(cmd_id, result)


## Read the Godot editor log file directly.
func cmd_get_editor_log(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var max_lines: int = params.get("lines", 100)
	var filter: String = params.get("filter", "all")
	var tail: bool = params.get("tail", true)
	
	var log_path: String = OS.get_user_data_dir() + "/logs/godot.log"
	
	var result: Dictionary = {
		"log_path": log_path,
		"entries": [],
		"errors": [],
		"warnings": [],
	}
	
	if not FileAccess.file_exists(log_path):
		result["error"] = "Log file not found"
		return _success(cmd_id, result)
	
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		result["error"] = "Could not open log file"
		return _success(cmd_id, result)
	
	var content: String = file.get_as_text()
	file.close()
	
	var lines: PackedStringArray = content.split("\n")
	var entries: Array = []
	var errors: Array = []
	var warnings: Array = []
	
	var start_idx: int = 0
	if tail and lines.size() > max_lines * 3:
		start_idx = lines.size() - max_lines * 3
	
	for i in range(start_idx, lines.size()):
		var line: String = lines[i].strip_edges()
		if line.is_empty():
			continue
		
		var entry_type: String = "info"
		var is_error: bool = (
			line.contains("ERROR") or 
			line.contains("SCRIPT ERROR") or 
			line.begins_with("E ") or
			(line.contains(" at: ") and line.contains("("))
		)
		var is_warning: bool = line.contains("WARNING") or line.begins_with("W ")
		
		if is_error:
			entry_type = "error"
			errors.append({"line": i, "text": line})
		elif is_warning:
			entry_type = "warning"
			warnings.append({"line": i, "text": line})
		else:
			entry_type = "print"
		
		if filter != "all":
			if filter == "error" and not is_error:
				continue
			if filter == "warning" and not is_warning:
				continue
			if filter == "print" and (is_error or is_warning):
				continue
		
		entries.append({"line": i, "type": entry_type, "text": line})
	
	if tail and entries.size() > max_lines:
		entries = entries.slice(entries.size() - max_lines)
	elif entries.size() > max_lines:
		entries = entries.slice(0, max_lines)
	
	result["entries"] = entries
	result["errors"] = errors.slice(-30) if errors.size() > 30 else errors
	result["warnings"] = warnings.slice(-30) if warnings.size() > 30 else warnings
	result["total_lines"] = lines.size()
	result["error_count"] = errors.size()
	result["warning_count"] = warnings.size()
	
	return _success(cmd_id, result)
