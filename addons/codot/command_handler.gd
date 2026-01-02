@tool
extends Node
## Command handler for Codot AI agent integration.
##
## This class processes commands received from AI agents via WebSocket
## and executes corresponding actions in the Godot editor. It provides
## a comprehensive API for scene manipulation, file operations, testing,
## and runtime control.
##
## @tutorial: https://github.com/your-repo/codot
## @version: 0.1.0

## Reference to the EditorInterface for accessing editor functionality.
var editor_interface: EditorInterface = null

## Reference to the debugger plugin for capturing runtime errors.
var debugger_plugin: EditorDebuggerPlugin = null


## Main command routing function.
## [br][br]
## Routes incoming commands to their respective handler functions based
## on the command name. All commands follow a request/response pattern
## with JSON serialization.
## [br][br]
## [param command]: Dictionary containing:
## - id: Unique command identifier for matching responses
## - command: String name of the command to execute
## - params: Dictionary of command-specific parameters
## [br][br]
## Returns a response Dictionary with success/error status and results.
func handle_command(command: Dictionary) -> Dictionary:
	var cmd_id = command.get("id")
	var cmd_name: String = command.get("command", "")
	var params: Dictionary = command.get("params", {})
	
	if cmd_name.is_empty():
		return _error(cmd_id, "MISSING_COMMAND", "No command specified")
	
	match cmd_name:
		# Basic commands
		"ping":
			return _success(cmd_id, {"pong": true, "timestamp": Time.get_unix_time_from_system()})
		"get_status":
			return _cmd_get_status(cmd_id)
		
		# Game control
		"play", "play_main_scene":
			return _cmd_play_main_scene(cmd_id)
		"play_current", "play_current_scene":
			return _cmd_play_current_scene(cmd_id)
		"play_custom_scene":
			return _cmd_play_custom_scene(cmd_id, params)
		"stop", "stop_scene":
			return _cmd_stop_scene(cmd_id)
		"is_playing":
			return _cmd_is_playing(cmd_id)
		"get_debug_output":
			return _cmd_get_debug_output(cmd_id, params)
		"clear_debug_log":
			return _cmd_clear_debug_log(cmd_id)
		"get_debugger_status":
			return _cmd_get_debugger_status(cmd_id)
		"get_editor_log":
			return _cmd_get_editor_log(cmd_id, params)
		
		# Scene tree inspection
		"get_scene_tree":
			return _cmd_get_scene_tree(cmd_id, params)
		"get_node_info":
			return _cmd_get_node_info(cmd_id, params)
		"get_node_properties":
			return _cmd_get_node_properties(cmd_id, params)
		
		# File operations
		"get_project_files":
			return _cmd_get_project_files(cmd_id, params)
		"read_file":
			return _cmd_read_file(cmd_id, params)
		"write_file":
			return _cmd_write_file(cmd_id, params)
		"file_exists":
			return _cmd_file_exists(cmd_id, params)
		
		# Scene operations
		"open_scene":
			return await _cmd_open_scene(cmd_id, params)
		"save_scene":
			return await _cmd_save_scene(cmd_id)
		"save_all_scenes":
			return _cmd_save_all_scenes(cmd_id)
		"get_open_scenes":
			return _cmd_get_open_scenes(cmd_id)
		
		# Editor operations
		"get_selected_nodes":
			return _cmd_get_selected_nodes(cmd_id)
		"select_node":
			return _cmd_select_node(cmd_id, params)
		"get_editor_settings":
			return _cmd_get_editor_settings(cmd_id)
		"get_editor_state":
			return _cmd_get_editor_state(cmd_id)
		"get_unsaved_changes":
			return _cmd_get_unsaved_changes(cmd_id)
		
		# Script operations
		"get_script_errors":
			return _cmd_get_script_errors(cmd_id, params)
		"open_script":
			return _cmd_open_script(cmd_id, params)
		
		# Project info
		"get_project_settings":
			return _cmd_get_project_settings(cmd_id, params)
		"list_resources":
			return _cmd_list_resources(cmd_id, params)
		
		# Node manipulation
		"create_node":
			return _cmd_create_node(cmd_id, params)
		"delete_node":
			return _cmd_delete_node(cmd_id, params)
		"set_node_property":
			return _cmd_set_node_property(cmd_id, params)
		"rename_node":
			return _cmd_rename_node(cmd_id, params)
		"move_node":
			return _cmd_move_node(cmd_id, params)
		"duplicate_node":
			return _cmd_duplicate_node(cmd_id, params)
		
		# Scene creation
		"create_scene":
			return _cmd_create_scene(cmd_id, params)
		"new_inherited_scene":
			return _cmd_new_inherited_scene(cmd_id, params)
		
		# Input simulation
		"simulate_key":
			return _cmd_simulate_key(cmd_id, params)
		"simulate_mouse_button":
			return _cmd_simulate_mouse_button(cmd_id, params)
		"simulate_mouse_motion":
			return _cmd_simulate_mouse_motion(cmd_id, params)
		"simulate_action":
			return _cmd_simulate_action(cmd_id, params)
		"get_input_actions":
			return _cmd_get_input_actions(cmd_id)
		
		# GUT Testing Framework
		"gut_run_all":
			return _cmd_gut_run_all(cmd_id, params)
		"gut_run_script":
			return _cmd_gut_run_script(cmd_id, params)
		"gut_run_test":
			return _cmd_gut_run_test(cmd_id, params)
		"gut_get_results":
			return _cmd_gut_get_results(cmd_id, params)
		"gut_list_tests":
			return _cmd_gut_list_tests(cmd_id, params)
		"gut_create_test":
			return _cmd_gut_create_test(cmd_id, params)
		"gut_check_installed":
			return _cmd_gut_check_installed(cmd_id)
		
		# Signal operations
		"list_node_signals":
			return _cmd_list_node_signals(cmd_id, params)
		"emit_signal":
			return _cmd_emit_signal(cmd_id, params)
		
		# Method calling
		"call_method":
			return _cmd_call_method(cmd_id, params)
		"list_node_methods":
			return _cmd_list_node_methods(cmd_id, params)
		
		# Group operations
		"get_nodes_in_group":
			return _cmd_get_nodes_in_group(cmd_id, params)
		"add_node_to_group":
			return _cmd_add_node_to_group(cmd_id, params)
		"remove_node_from_group":
			return _cmd_remove_node_from_group(cmd_id, params)
		
		# Resource operations
		"load_resource":
			return _cmd_load_resource(cmd_id, params)
		"get_resource_info":
			return _cmd_get_resource_info(cmd_id, params)
		
		# Animation operations
		"list_animations":
			return _cmd_list_animations(cmd_id, params)
		"play_animation":
			return _cmd_play_animation(cmd_id, params)
		"stop_animation":
			return _cmd_stop_animation(cmd_id, params)
		
		# Audio operations
		"list_audio_buses":
			return _cmd_list_audio_buses(cmd_id)
		"set_audio_bus_volume":
			return _cmd_set_audio_bus_volume(cmd_id, params)
		"set_audio_bus_mute":
			return _cmd_set_audio_bus_mute(cmd_id, params)
		
		# Debug/Performance
		"get_performance_info":
			return _cmd_get_performance_info(cmd_id)
		"get_memory_info":
			return _cmd_get_memory_info(cmd_id)
		
		# Console/Output
		"print_to_console":
			return _cmd_print_to_console(cmd_id, params)
		"get_recent_errors":
			return _cmd_get_recent_errors(cmd_id)
		
		# Plugin management
		"enable_plugin":
			return _cmd_enable_plugin(cmd_id, params)
		"disable_plugin":
			return _cmd_disable_plugin(cmd_id, params)
		"get_plugins":
			return _cmd_get_plugins(cmd_id)
		"reload_project":
			return _cmd_reload_project(cmd_id)
		
		# Advanced testing and debugging
		"run_and_capture":
			return await _cmd_run_and_capture(cmd_id, params)
		"wait_for_output":
			return await _cmd_wait_for_output(cmd_id, params)
		"ping_game":
			return await _cmd_ping_game(cmd_id, params)
		"get_game_state":
			return _cmd_get_game_state(cmd_id)
		"take_screenshot":
			return await _cmd_take_screenshot(cmd_id, params)
		
		# Enhanced GUT commands
		"gut_run_and_wait":
			return await _cmd_gut_run_and_wait(cmd_id, params)
		"gut_get_summary":
			return _cmd_gut_get_summary(cmd_id)
		
		_:
			return _error(cmd_id, "UNKNOWN_COMMAND", "Unknown command: " + cmd_name)


## Create a successful response dictionary.
## [br][br]
## [param cmd_id]: The command ID for response matching.
## [param result]: Dictionary containing the result data.
## [br][br]
## Returns a properly formatted success response.
func _success(cmd_id: Variant, result: Dictionary) -> Dictionary:
	return {"id": cmd_id, "success": true, "result": result}


## Create an error response dictionary.
## [br][br]
## [param cmd_id]: The command ID for response matching.
## [param code]: Error code string (e.g., "MISSING_PARAM", "NO_EDITOR").
## [param message]: Human-readable error description.
## [br][br]
## Returns a properly formatted error response.
func _error(cmd_id: Variant, code: String, message: String) -> Dictionary:
	return {"id": cmd_id, "success": false, "error": {"code": code, "message": message}}


# =============================================================================
# STATUS & INFO COMMANDS
# =============================================================================

## Get comprehensive status information about Godot and the plugin.
## [br][br]
## Returns Godot version, plugin version, playing state, current scene,
## and project name.
func _cmd_get_status(cmd_id: Variant) -> Dictionary:
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


## Start playing the main scene defined in project settings.
## [br][br]
## Uses EditorInterface.play_main_scene() to launch the game.
func _cmd_play_main_scene(cmd_id: Variant) -> Dictionary:
	if editor_interface != null:
		editor_interface.play_main_scene()
	return _success(cmd_id, {"playing": true})


## Start playing the currently edited scene.
## [br][br]
## Uses EditorInterface.play_current_scene() to launch the active scene.
func _cmd_play_current_scene(cmd_id: Variant) -> Dictionary:
	if editor_interface != null:
		editor_interface.play_current_scene()
	return _success(cmd_id, {"playing": true})


## Stop the currently running game/scene.
## [br][br]
## Uses EditorInterface.stop_playing_scene() to terminate the running game.
func _cmd_stop_scene(cmd_id: Variant) -> Dictionary:
	if editor_interface != null:
		editor_interface.stop_playing_scene()
	return _success(cmd_id, {"stopped": true})


## Check if a scene is currently playing.
## [br][br]
## Returns whether the game is running in the editor.
func _cmd_is_playing(cmd_id: Variant) -> Dictionary:
	var is_playing: bool = false
	if editor_interface != null:
		is_playing = editor_interface.is_playing_scene()
	return _success(cmd_id, {"is_playing": is_playing})


## Get debug output from the Godot editor log.
## [br][br]
## [param params]: Optional parameters:
## - 'lines' (int): Number of lines to return (default: 50)
## - 'filter' (String): Filter for "error", "warning", or "all" (default: "all")
## - 'since_line' (int): Only return lines after this line number
## [br][br]
## Reads from the debugger plugin (preferred) or godot.log file as fallback.
func _cmd_get_debug_output(cmd_id: Variant, params: Dictionary) -> Dictionary:
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
	
	# Prefer debugger plugin if available (more reliable, structured data)
	if debugger_plugin != null and debugger_plugin.has_method("get_entries"):
		output["source"] = "debugger"
		var entries: Array = debugger_plugin.get_entries(filter, since_id, max_entries)
		var summary: Dictionary = debugger_plugin.get_summary()
		
		output["entries"] = entries
		output["error_count"] = summary.get("error_count", 0)
		output["warning_count"] = summary.get("warning_count", 0)
		output["last_id"] = summary.get("last_id", 0)
		output["active_sessions"] = summary.get("active_sessions", 0)
		
		# Separate out errors and warnings for convenience
		for entry in entries:
			if entry.get("type") == "error":
				output["errors"].append(entry)
			elif entry.get("type") == "warning":
				output["warnings"].append(entry)
		
		return _success(cmd_id, output)
	
	# Fallback to log file parsing
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
		
		# Apply filter
		if filter == "error" and not is_error:
			continue
		if filter == "warning" and not is_warning:
			continue
		
		entries.append({
			"id": i,
			"type": entry_type,
			"message": line
		})
	
	# Return last N entries
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
## [br][br]
## Returns an ID to use with get_debug_output to only see new entries.
func _cmd_clear_debug_log(cmd_id: Variant) -> Dictionary:
	# Prefer debugger plugin if available
	if debugger_plugin != null and debugger_plugin.has_method("mark_position"):
		var marker_id: int = debugger_plugin.mark_position()
		return _success(cmd_id, {
			"source": "debugger",
			"marked": true,
			"since_id": marker_id,
			"note": "Use 'since_id' parameter in get_debug_output to skip old entries"
		})
	
	# Fallback to log file
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


## Get status of the debugger plugin including what message types have been seen.
## Useful for diagnosing if the debugger is working correctly.
func _cmd_get_debugger_status(cmd_id: Variant) -> Dictionary:
	var result: Dictionary = {
		"debugger_plugin_available": debugger_plugin != null,
		"is_playing": false,
	}
	
	if editor_interface != null:
		result["is_playing"] = editor_interface.is_playing_scene()
	
	if debugger_plugin != null:
		# Use the get_diagnostics() method if available
		if debugger_plugin.has_method("get_diagnostics"):
			result.merge(debugger_plugin.get_diagnostics())
		elif debugger_plugin.has_method("get_summary"):
			result["summary"] = debugger_plugin.get_summary()
		
		# Get message types seen (if available)
		if "_seen_message_types" in debugger_plugin:
			result["message_types_seen"] = debugger_plugin._seen_message_types
		
		# Get active sessions
		if "_active_sessions" in debugger_plugin:
			result["active_sessions"] = debugger_plugin._active_sessions
		
		# Get total entries
		if "_entries" in debugger_plugin:
			result["total_entries"] = debugger_plugin._entries.size()
		
		# Get game capture status
		if "_game_capture_active" in debugger_plugin:
			result["game_capture_active"] = debugger_plugin._game_capture_active
	
	# Also check if log file is available
	var log_path: String = OS.get_user_data_dir() + "/logs/godot.log"
	result["log_file_path"] = log_path
	result["log_file_exists"] = FileAccess.file_exists(log_path)
	
	return _success(cmd_id, result)


## Read the Godot editor log file directly.
## This is a fallback/alternative to the debugger plugin.
## [br][br]
## [param params]:
## - 'lines' (int, optional): Maximum lines to return (default 100)
## - 'filter' (String, optional): "all", "error", "warning", "print"
## - 'tail' (bool, optional): If true, return last N lines (default true)
func _cmd_get_editor_log(cmd_id: Variant, params: Dictionary) -> Dictionary:
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
	
	# If tail mode, start from end
	var start_idx: int = 0
	if tail and lines.size() > max_lines * 3:  # Look at more lines to find enough matches
		start_idx = lines.size() - max_lines * 3
	
	for i in range(start_idx, lines.size()):
		var line: String = lines[i].strip_edges()
		if line.is_empty():
			continue
		
		# Detect type
		var entry_type: String = "info"
		var is_error: bool = (
			line.contains("ERROR") or 
			line.contains("SCRIPT ERROR") or 
			line.begins_with("E ") or
			line.contains(" at: ") and line.contains("(")  # Stack trace line
		)
		var is_warning: bool = (
			line.contains("WARNING") or 
			line.begins_with("W ")
		)
		
		if is_error:
			entry_type = "error"
			errors.append({"line": i, "text": line})
		elif is_warning:
			entry_type = "warning"
			warnings.append({"line": i, "text": line})
		else:
			entry_type = "print"
		
		# Apply filter
		if filter != "all":
			if filter == "error" and not is_error:
				continue
			if filter == "warning" and not is_warning:
				continue
			if filter == "print" and (is_error or is_warning):
				continue
		
		entries.append({
			"line": i,
			"type": entry_type,
			"text": line
		})
	
	# Trim to max_lines
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


# =============================================================================
# Game Control Commands
# =============================================================================

## Start playing a specific scene by path.
## [br][br]
## [param params]: Must contain 'path' (String) - the scene file path (e.g., "res://scenes/main.tscn")
func _cmd_play_custom_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var scene_path: String = params.get("path", "")
	if scene_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if editor_interface != null:
		editor_interface.play_custom_scene(scene_path)
	return _success(cmd_id, {"playing": true, "scene": scene_path})


# =============================================================================
# Scene Tree Commands
# =============================================================================

## Get the scene tree structure as a nested dictionary.
## [br][br]
## [param params]: Optional 'max_depth' (int) - maximum tree depth to traverse (default: 10)
## [br][br]
## Returns a hierarchical representation of the currently edited scene.
func _cmd_get_scene_tree(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _success(cmd_id, {"tree": null, "message": "No scene open"})
	
	var max_depth: int = params.get("max_depth", 10)
	var tree_data: Dictionary = _node_to_dict(root, 0, max_depth)
	return _success(cmd_id, {"tree": tree_data})


## Convert a node and its children to a dictionary representation.
## [br][br]
## [param node]: The node to convert.
## [param depth]: Current recursion depth.
## [param max_depth]: Maximum depth to traverse.
## [br][br]
## Returns dictionary with name, type, path, script, and children.
func _node_to_dict(node: Node, depth: int, max_depth: int) -> Dictionary:
	var data: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}
	
	# Add script info if present
	var script = node.get_script()
	if script != null:
		data["script"] = script.resource_path
	
	# Add children if not at max depth
	if depth < max_depth:
		var children: Array = []
		for child in node.get_children():
			children.append(_node_to_dict(child, depth + 1, max_depth))
		if children.size() > 0:
			data["children"] = children
	
	return data


## Get detailed information about a specific node.
## [br][br]
## [param params]: Must contain 'path' (String) - node path relative to scene root.
## [br][br]
## Returns node name, type, path, script, child count, and transform info
## (position, rotation, scale for Node2D/Node3D/Control).
func _cmd_get_node_info(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var info: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"owner": str(node.owner.get_path()) if node.owner else null,
		"child_count": node.get_child_count(),
	}
	
	var script = node.get_script()
	if script != null:
		info["script"] = script.resource_path
	
	# Add type-specific info
	if node is Node2D:
		info["position"] = {"x": node.position.x, "y": node.position.y}
		info["rotation"] = node.rotation
		info["scale"] = {"x": node.scale.x, "y": node.scale.y}
	elif node is Node3D:
		info["position"] = {"x": node.position.x, "y": node.position.y, "z": node.position.z}
		info["rotation"] = {"x": node.rotation.x, "y": node.rotation.y, "z": node.rotation.z}
		info["scale"] = {"x": node.scale.x, "y": node.scale.y, "z": node.scale.z}
	elif node is Control:
		info["position"] = {"x": node.position.x, "y": node.position.y}
		info["size"] = {"x": node.size.x, "y": node.size.y}
	
	return _success(cmd_id, info)


## Get all editable properties of a node.
## [br][br]
## [param params]: Must contain 'path' (String) - node path relative to scene root.
## [br][br]
## Returns all properties marked with PROPERTY_USAGE_EDITOR, serialized to JSON.
func _cmd_get_node_properties(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var properties: Dictionary = {}
	var prop_list = node.get_property_list()
	
	for prop in prop_list:
		var prop_name: String = prop["name"]
		# Skip internal properties
		if prop_name.begins_with("_"):
			continue
		# Only include exported/editable properties
		if prop["usage"] & PROPERTY_USAGE_EDITOR:
			var value = node.get(prop_name)
			properties[prop_name] = _value_to_json(value)
	
	return _success(cmd_id, {"path": node_path, "properties": properties})


## Convert a Godot Variant value to JSON-compatible format.
## [br][br]
## Handles Vector2, Vector3, Color, Rect2, Objects, Arrays, and Dictionaries.
## [br][br]
## [param value]: The Godot Variant to convert.
## Returns a JSON-serializable value.
func _value_to_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_RECT2:
			return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
		TYPE_OBJECT:
			if value == null:
				return null
			if value is Resource:
				return value.resource_path if not value.resource_path.is_empty() else str(value)
			return str(value)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var arr: Array = []
			for item in value:
				arr.append(_value_to_json(item))
			return arr
		TYPE_DICTIONARY:
			var dict: Dictionary = {}
			for key in value.keys():
				dict[str(key)] = _value_to_json(value[key])
			return dict
		_:
			return value


# =============================================================================
# File Operations
# =============================================================================

## Get a list of project files matching criteria.
## [br][br]
## [param params]: 
## - 'path' (String, default "res://"): Starting directory.
## - 'extension' (String, optional): Filter by file extension.
## - 'recursive' (bool, default true): Search subdirectories.
func _cmd_get_project_files(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "res://")
	var extension: String = params.get("extension", "")
	var recursive: bool = params.get("recursive", true)
	
	var files: Array = []
	_scan_directory(path, extension, recursive, files)
	return _success(cmd_id, {"files": files, "count": files.size()})


## Recursively scan a directory for files.
## [br][br]
## [param path]: Directory path to scan.
## [param extension]: File extension filter (empty for all files).
## [param recursive]: Whether to scan subdirectories.
## [param files]: Array to populate with found file paths.
func _scan_directory(path: String, extension: String, recursive: bool, files: Array) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var full_path = path.path_join(file_name)
		
		if dir.current_is_dir():
			if recursive:
				_scan_directory(full_path, extension, recursive, files)
		else:
			if extension.is_empty() or file_name.ends_with(extension):
				files.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


func _cmd_read_file(cmd_id: Variant, params: Dictionary) -> Dictionary:
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


func _cmd_write_file(cmd_id: Variant, params: Dictionary) -> Dictionary:
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


func _cmd_file_exists(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var exists = FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
	return _success(cmd_id, {"path": path, "exists": exists})


# =============================================================================
# Scene Operations
# =============================================================================

func _cmd_open_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not FileAccess.file_exists(path) and not path.begins_with("res://"):
		path = "res://" + path
	
	if not FileAccess.file_exists(path.replace("res://", "")) and not ResourceLoader.exists(path):
		return _error(cmd_id, "FILE_NOT_FOUND", "Scene file not found: " + path)
	
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	editor_interface.open_scene_from_path(path)
	
	# Verify the scene was opened
	await get_tree().process_frame
	var opened_scenes = Array(editor_interface.get_open_scenes())
	var was_opened = path in opened_scenes
	
	return _success(cmd_id, {
		"opened": was_opened,
		"path": path,
		"open_scenes": opened_scenes
	})


## Save the currently edited scene.
## [br][br]
## Returns success status and scene path. Checks for various error conditions.
func _cmd_save_scene(cmd_id: Variant) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene is currently open")
	
	var scene_path: String = root.scene_file_path
	if scene_path.is_empty():
		return _error(cmd_id, "UNSAVED_SCENE", "Scene has never been saved. Use create_scene with a path first.")
	
	# Get file modification time before save
	var mod_time_before: int = 0
	if FileAccess.file_exists(scene_path.replace("res://", "")):
		mod_time_before = FileAccess.get_modified_time(scene_path)
	
	# Attempt to save
	var error: int = editor_interface.save_scene()
	
	if error != OK:
		return _error(cmd_id, "SAVE_FAILED", "Failed to save scene. Error code: " + str(error))
	
	# Verify the save by checking if file modification time changed
	await get_tree().process_frame
	var mod_time_after: int = 0
	if FileAccess.file_exists(scene_path.replace("res://", "")):
		mod_time_after = FileAccess.get_modified_time(scene_path)
	
	var file_was_updated: bool = mod_time_after > mod_time_before or mod_time_before == 0
	
	return _success(cmd_id, {
		"saved": error == OK,
		"path": scene_path,
		"file_updated": file_was_updated,
		"error_code": error
	})


## Save all open scenes in the editor.
## [br][br]
## Returns status for each open scene.
func _cmd_save_all_scenes(cmd_id: Variant) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var open_scenes = Array(editor_interface.get_open_scenes())
	if open_scenes.is_empty():
		return _error(cmd_id, "NO_SCENES", "No scenes are currently open")
	
	editor_interface.save_all_scenes()
	
	return _success(cmd_id, {
		"saved": true,
		"scene_count": open_scenes.size(),
		"scenes": open_scenes
	})


## Get list of all currently open scenes in the editor.
## [br][br]
## Returns array of scene file paths.
func _cmd_get_open_scenes(cmd_id: Variant) -> Dictionary:
	var scenes: Array = []
	if editor_interface != null:
		scenes = Array(editor_interface.get_open_scenes())
	return _success(cmd_id, {"scenes": scenes, "count": scenes.size()})


# =============================================================================
# Editor Operations
# =============================================================================

## Get information about currently selected nodes in the editor.
## [br][br]
## Returns array of selected node info (name, type, path).
func _cmd_get_selected_nodes(cmd_id: Variant) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var selection = editor_interface.get_selection()
	var selected: Array = []
	
	for node in selection.get_selected_nodes():
		selected.append({
			"name": node.name,
			"type": node.get_class(),
			"path": str(node.get_path())
		})
	
	return _success(cmd_id, {"selected": selected, "count": selected.size()})


## Select a node in the editor by path.
## [br][br]
## [param params]: Must contain 'path' (String) - node path to select.
func _cmd_select_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var selection = editor_interface.get_selection()
	selection.clear()
	selection.add_node(node)
	
	return _success(cmd_id, {"selected": node_path})


## Get current editor settings.
## [br][br]
## Returns theme preset and font size settings.
func _cmd_get_editor_settings(cmd_id: Variant) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var settings = editor_interface.get_editor_settings()
	var result: Dictionary = {
		"theme": settings.get_setting("interface/theme/preset"),
		"font_size": settings.get_setting("interface/editor/main_font_size"),
	}
	return _success(cmd_id, result)


## Get comprehensive editor state.
## [br][br]
## Returns information about open scenes, modified files, current selection, etc.
func _cmd_get_editor_state(cmd_id: Variant) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var state: Dictionary = {
		"is_playing": editor_interface.is_playing_scene(),
		"open_scenes": Array(editor_interface.get_open_scenes()),
		"current_scene": "",
		"current_scene_modified": false,
		"selected_nodes": [],
		"has_unsaved_changes": false,
		"modified_scenes": [],
	}
	
	# Get current scene info
	var root = editor_interface.get_edited_scene_root()
	if root != null:
		state["current_scene"] = root.scene_file_path
		# Check if scene has unsaved changes by comparing to disk
		# Unfortunately Godot doesn't expose this directly, so we check if the file exists
		if root.scene_file_path.is_empty():
			state["current_scene_modified"] = true  # New unsaved scene
			state["has_unsaved_changes"] = true
	
	# Get selected nodes
	var selection = editor_interface.get_selection()
	for node in selection.get_selected_nodes():
		state["selected_nodes"].append({
			"name": node.name,
			"type": node.get_class(),
			"path": str(root.get_path_to(node)) if root else str(node.get_path())
		})
	
	return _success(cmd_id, state)


## Check for unsaved changes in open scenes.
## [br][br]
## Returns list of scenes that may have unsaved modifications.
func _cmd_get_unsaved_changes(cmd_id: Variant) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var result: Dictionary = {
		"has_unsaved": false,
		"unsaved_scenes": [],
		"current_scene_path": "",
		"current_scene_is_new": false,
	}
	
	var root = editor_interface.get_edited_scene_root()
	if root != null:
		result["current_scene_path"] = root.scene_file_path
		if root.scene_file_path.is_empty():
			result["current_scene_is_new"] = true
			result["has_unsaved"] = true
			result["unsaved_scenes"].append("(new unsaved scene)")
	
	# Note: Godot doesn't expose a direct API to check if a scene is modified
	# The best we can do is check if the file exists and if it's a new scene
	
	return _success(cmd_id, result)


# =============================================================================
# Script Operations
# =============================================================================

## Check a script for errors.
## [br][br]
## [param params]: Must contain 'path' (String) - script file path.
## [br][br]
## Note: In Godot 4, this loads the script to verify validity.
func _cmd_get_script_errors(cmd_id: Variant, params: Dictionary) -> Dictionary:
	# Note: In Godot 4, there's no direct API to get script errors
	# This would need to be implemented via the debugger or by parsing
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
func _cmd_open_script(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var line: int = params.get("line", 0)
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if editor_interface != null:
		var script = load(path)
		if script != null:
			editor_interface.edit_script(script, line)
			return _success(cmd_id, {"opened": path, "line": line})
		else:
			return _error(cmd_id, "SCRIPT_NOT_FOUND", "Could not load script: " + path)
	
	return _error(cmd_id, "NO_EDITOR", "Editor interface not available")


# =============================================================================
# Project Info
# =============================================================================

## Get project settings values.
## [br][br]
## [param params]: Optional 'keys' (Array) - specific settings to retrieve.
## If empty, returns common settings (name, description, version, main_scene, icon).
func _cmd_get_project_settings(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var keys: Array = params.get("keys", [])
	
	var result: Dictionary = {}
	
	if keys.is_empty():
		# Return common project settings
		result = {
			"name": ProjectSettings.get_setting("application/config/name", ""),
			"description": ProjectSettings.get_setting("application/config/description", ""),
			"version": ProjectSettings.get_setting("application/config/version", ""),
			"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
			"icon": ProjectSettings.get_setting("application/config/icon", ""),
		}
	else:
		for key in keys:
			result[key] = ProjectSettings.get_setting(key, null)
	
	return _success(cmd_id, result)


## List resources of a specific type in the project.
## [br][br]
## [param params]:
## - 'type' (String): Resource type (scene, script, texture, audio, shader, resource).
## - 'path' (String, default "res://"): Directory to search.
func _cmd_list_resources(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var resource_type: String = params.get("type", "")
	var path: String = params.get("path", "res://")
	
	var extensions: Array = []
	match resource_type:
		"scene", "scenes":
			extensions = [".tscn", ".scn"]
		"script", "scripts":
			extensions = [".gd", ".cs"]
		"texture", "textures", "image", "images":
			extensions = [".png", ".jpg", ".jpeg", ".webp", ".svg"]
		"audio", "sound", "sounds":
			extensions = [".ogg", ".wav", ".mp3"]
		"shader", "shaders":
			extensions = [".gdshader", ".shader"]
		"resource", "resources":
			extensions = [".tres", ".res"]
		_:
			extensions = []  # All files
	
	var files: Array = []
	
	for ext in extensions if extensions.size() > 0 else [""]:
		var ext_files: Array = []
		_scan_directory(path, ext, true, ext_files)
		files.append_array(ext_files)
	
	return _success(cmd_id, {"resources": files, "type": resource_type, "count": files.size()})


# =============================================================================
# Node Manipulation
# =============================================================================

## Create a new node in the scene tree.
## [br][br]
## [param params]:
## - 'type' (String, required): Node class name (e.g., "Node2D", "Sprite2D").
## - 'name' (String, optional): Node name (auto-generated if empty).
## - 'parent' (String, default "."): Parent node path.
func _cmd_create_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_type: String = params.get("type", "")
	var node_name: String = params.get("name", "")
	var parent_path: String = params.get("parent", ".")
	
	if node_type.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'type' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	# Find parent node
	var parent: Node = root if parent_path == "." else root.get_node_or_null(parent_path)
	if parent == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Parent node not found: " + parent_path)
	
	# Create the node
	var new_node: Node = null
	if ClassDB.class_exists(node_type):
		new_node = ClassDB.instantiate(node_type)
	else:
		return _error(cmd_id, "INVALID_TYPE", "Unknown node type: " + node_type)
	
	if new_node == null:
		return _error(cmd_id, "CREATE_FAILED", "Failed to create node of type: " + node_type)
	
	# Set name if provided
	if not node_name.is_empty():
		new_node.name = node_name
	
	# Add to parent
	parent.add_child(new_node)
	new_node.owner = root
	
	return _success(cmd_id, {
		"created": true,
		"name": new_node.name,
		"type": node_type,
		"path": str(new_node.get_path())
	})


func _cmd_delete_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	# Don't allow deleting the root node
	if node_path == "." or node_path == str(root.get_path()):
		return _error(cmd_id, "INVALID_OPERATION", "Cannot delete the root node")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var deleted_name = node.name
	node.queue_free()
	
	return _success(cmd_id, {"deleted": true, "name": deleted_name})


func _cmd_set_node_property(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	var property: String = params.get("property", "")
	var value = params.get("value")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if property.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'property' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	# Convert value if needed (e.g., dict to Vector2/Vector3)
	var converted_value = _convert_value(value, node, property)
	
	node.set(property, converted_value)
	
	return _success(cmd_id, {
		"set": true,
		"path": node_path,
		"property": property,
		"value": _value_to_json(node.get(property))
	})


func _convert_value(value: Variant, node: Node, property: String) -> Variant:
	# Handle resource path strings - if value is a string starting with "res://" and property expects a Resource
	if value is String and value.begins_with("res://"):
		var loaded_resource = load(value)
		if loaded_resource != null:
			return loaded_resource
	
	# Handle inline resource creation via dictionary with "_type" key
	if value is Dictionary and value.has("_type"):
		return _create_resource_from_dict(value)
	
	# Get the expected type from the node's property
	var prop_list = node.get_property_list()
	for prop in prop_list:
		if prop["name"] == property:
			var prop_type = prop["type"]
			if prop_type == TYPE_VECTOR2 and value is Dictionary:
				return Vector2(value.get("x", 0), value.get("y", 0))
			elif prop_type == TYPE_VECTOR3 and value is Dictionary:
				return Vector3(value.get("x", 0), value.get("y", 0), value.get("z", 0))
			elif prop_type == TYPE_COLOR and value is Dictionary:
				return Color(value.get("r", 0), value.get("g", 0), value.get("b", 0), value.get("a", 1))
			elif prop_type == TYPE_OBJECT and value is String and value.begins_with("res://"):
				# Property expects an object (likely a Resource), try to load it
				var res = load(value)
				if res != null:
					return res
			break
	return value


## Create a Resource from a dictionary specification.
## [br][br]
## Supports creating common resource types inline, e.g.:
## {"_type": "ShaderMaterial", "shader": "res://my_shader.gdshader"}
## {"_type": "ParticleProcessMaterial", "emission_shape": 1}
func _create_resource_from_dict(spec: Dictionary) -> Resource:
	var type_name: String = spec.get("_type", "")
	if type_name.is_empty():
		return null
	
	var resource: Resource = null
	
	# Create the resource based on type
	match type_name:
		"ShaderMaterial":
			resource = ShaderMaterial.new()
		"ParticleProcessMaterial":
			resource = ParticleProcessMaterial.new()
		"StandardMaterial3D":
			resource = StandardMaterial3D.new()
		"CanvasItemMaterial":
			resource = CanvasItemMaterial.new()
		"Gradient":
			resource = Gradient.new()
		"GradientTexture1D":
			resource = GradientTexture1D.new()
		"GradientTexture2D":
			resource = GradientTexture2D.new()
		"Curve":
			resource = Curve.new()
		"CurveTexture":
			resource = CurveTexture.new()
		_:
			# Try to create via ClassDB
			if ClassDB.class_exists(type_name) and ClassDB.is_parent_class(type_name, "Resource"):
				resource = ClassDB.instantiate(type_name)
	
	if resource == null:
		return null
	
	# Set properties on the resource
	for key in spec.keys():
		if key == "_type":
			continue
		
		var prop_value = spec[key]
		
		# Recursively convert nested resources/values
		if prop_value is String and prop_value.begins_with("res://"):
			prop_value = load(prop_value)
		elif prop_value is Dictionary:
			if prop_value.has("_type"):
				prop_value = _create_resource_from_dict(prop_value)
			elif prop_value.has("x") and prop_value.has("y"):
				if prop_value.has("z"):
					prop_value = Vector3(prop_value.x, prop_value.y, prop_value.z)
				else:
					prop_value = Vector2(prop_value.x, prop_value.y)
			elif prop_value.has("r") and prop_value.has("g") and prop_value.has("b"):
				prop_value = Color(prop_value.r, prop_value.g, prop_value.b, prop_value.get("a", 1.0))
		
		if resource.has_method("set"):
			resource.set(key, prop_value)
	
	return resource


func _cmd_rename_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	var new_name: String = params.get("name", "")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if new_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'name' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var old_name = node.name
	node.name = new_name
	
	return _success(cmd_id, {
		"renamed": true,
		"old_name": old_name,
		"new_name": node.name,
		"new_path": str(node.get_path())
	})


func _cmd_move_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	var new_parent_path: String = params.get("new_parent", "")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if new_parent_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'new_parent' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var new_parent = root if new_parent_path == "." else root.get_node_or_null(new_parent_path)
	if new_parent == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "New parent not found: " + new_parent_path)
	
	# Don't allow moving root or to a child of itself
	if node == root:
		return _error(cmd_id, "INVALID_OPERATION", "Cannot move the root node")
	if new_parent.is_ancestor_of(node) or node == new_parent:
		return _error(cmd_id, "INVALID_OPERATION", "Cannot move node to itself or a descendant")
	
	node.reparent(new_parent)
	
	return _success(cmd_id, {
		"moved": true,
		"new_path": str(node.get_path())
	})


func _cmd_duplicate_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	var new_name: String = params.get("new_name", "")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var duplicate = node.duplicate()
	
	# Generate a proper name for the duplicate
	if new_name.is_empty():
		new_name = _generate_unique_name(node.name, node.get_parent())
	duplicate.name = new_name
	
	node.get_parent().add_child(duplicate)
	duplicate.owner = root
	
	# Set ownership for all children recursively
	_set_owner_recursive(duplicate, root)
	
	return _success(cmd_id, {
		"duplicated": true,
		"original": node_path,
		"new_path": str(duplicate.get_path()),
		"new_name": duplicate.name
	})


func _generate_unique_name(base_name: String, parent: Node) -> String:
	# Extract base name and number suffix (e.g., "Enemy1" -> "Enemy", 1)
	var regex = RegEx.new()
	regex.compile("^(.+?)(\\d+)$")
	var result = regex.search(base_name)
	
	var name_part: String
	var start_num: int
	
	if result:
		name_part = result.get_string(1)
		start_num = int(result.get_string(2)) + 1
	else:
		name_part = base_name
		start_num = 2
	
	# Find a unique name
	var candidate = name_part + str(start_num)
	while parent.has_node(candidate):
		start_num += 1
		candidate = name_part + str(start_num)
	
	return candidate


## Set owner recursively for node hierarchy.
## [br][br]
## Required after duplicating nodes so they save properly with the scene.
func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)


# =============================================================================
# Scene Creation
# =============================================================================

## Create a new scene file with a specified root node type.
## [br][br]
## [param params]:
## - 'path' (String, required): Save path for the scene (.tscn).
## - 'root_type' (String, default "Node2D"): Root node class name.
## - 'root_name' (String, optional): Name for root node (uses filename if empty).
func _cmd_create_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var root_type: String = params.get("root_type", "Node2D")
	var root_name: String = params.get("root_name", "")
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not path.ends_with(".tscn") and not path.ends_with(".scn"):
		path += ".tscn"
	
	# Create root node
	var root_node: Node = null
	if ClassDB.class_exists(root_type):
		root_node = ClassDB.instantiate(root_type)
	else:
		return _error(cmd_id, "INVALID_TYPE", "Unknown node type: " + root_type)
	
	if root_node == null:
		return _error(cmd_id, "CREATE_FAILED", "Failed to create root node")
	
	if not root_name.is_empty():
		root_node.name = root_name
	else:
		# Use filename as node name
		root_node.name = path.get_file().get_basename()
	
	# Create and save the scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(root_node)
	
	var error = ResourceSaver.save(packed_scene, path)
	root_node.queue_free()
	
	if error != OK:
		return _error(cmd_id, "SAVE_FAILED", "Failed to save scene: " + str(error))
	
	# Open the new scene
	if editor_interface != null:
		editor_interface.open_scene_from_path(path)
	
	return _success(cmd_id, {
		"created": true,
		"path": path,
		"root_type": root_type,
		"root_name": root_node.name
	})


## Create a new scene that inherits from an existing scene.
## [br][br]
## [param params]:
## - 'base_scene' (String, required): Path to the base scene to inherit from.
## - 'path' (String, required): Save path for the new inherited scene.
func _cmd_new_inherited_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var base_scene: String = params.get("base_scene", "")
	var path: String = params.get("path", "")
	
	if base_scene.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'base_scene' parameter")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not FileAccess.file_exists(base_scene):
		return _error(cmd_id, "FILE_NOT_FOUND", "Base scene not found: " + base_scene)
	
	# Load the base scene
	var base_packed = load(base_scene) as PackedScene
	if base_packed == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load base scene")
	
	# Instance it
	var instance = base_packed.instantiate()
	if instance == null:
		return _error(cmd_id, "INSTANCE_FAILED", "Failed to instance base scene")
	
	# Create a new packed scene from this instance
	var new_scene = PackedScene.new()
	new_scene.pack(instance)
	
	if not path.ends_with(".tscn") and not path.ends_with(".scn"):
		path += ".tscn"
	
	var error = ResourceSaver.save(new_scene, path)
	instance.queue_free()
	
	if error != OK:
		return _error(cmd_id, "SAVE_FAILED", "Failed to save inherited scene: " + str(error))
	
	if editor_interface != null:
		editor_interface.open_scene_from_path(path)
	
	return _success(cmd_id, {
		"created": true,
		"path": path,
		"base_scene": base_scene
	})


# =============================================================================
# Input Simulation
# =============================================================================

## Simulate a keyboard key event.
## [br][br]
## [param params]:
## - 'key' (String, required): Key name (e.g., "A", "SPACE", "ESCAPE").
## - 'pressed' (bool, default true): Whether key is pressed or released.
## - 'echo' (bool, default false): Whether this is a key repeat.
## - 'shift', 'ctrl', 'alt', 'meta' (bool): Modifier key states.
func _cmd_simulate_key(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var keycode: String = params.get("key", "")
	var pressed: bool = params.get("pressed", true)
	var echo: bool = params.get("echo", false)
	
	if keycode.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'key' parameter")
	
	var key_const = _key_name_to_code(keycode)
	if key_const == KEY_NONE:
		return _error(cmd_id, "INVALID_KEY", "Invalid key name: " + keycode)
	
	var event = InputEventKey.new()
	event.keycode = key_const
	event.physical_keycode = key_const
	event.pressed = pressed
	event.echo = echo
	
	# Check for modifiers in params
	if params.get("shift", false):
		event.shift_pressed = true
	if params.get("ctrl", false):
		event.ctrl_pressed = true
	if params.get("alt", false):
		event.alt_pressed = true
	if params.get("meta", false):
		event.meta_pressed = true
	
	Input.parse_input_event(event)
	
	return _success(cmd_id, {
		"simulated": true,
		"type": "key",
		"key": keycode,
		"pressed": pressed
	})


func _cmd_simulate_mouse_button(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var button: int = params.get("button", MOUSE_BUTTON_LEFT)
	var pressed: bool = params.get("pressed", true)
	var position_x: float = params.get("x", 0.0)
	var position_y: float = params.get("y", 0.0)
	var double_click: bool = params.get("double_click", false)
	
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(position_x, position_y)
	event.global_position = Vector2(position_x, position_y)
	event.double_click = double_click
	
	Input.parse_input_event(event)
	
	return _success(cmd_id, {
		"simulated": true,
		"type": "mouse_button",
		"button": button,
		"pressed": pressed,
		"position": {"x": position_x, "y": position_y}
	})


func _cmd_simulate_mouse_motion(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var position_x: float = params.get("x", 0.0)
	var position_y: float = params.get("y", 0.0)
	var relative_x: float = params.get("relative_x", 0.0)
	var relative_y: float = params.get("relative_y", 0.0)
	
	var event = InputEventMouseMotion.new()
	event.position = Vector2(position_x, position_y)
	event.global_position = Vector2(position_x, position_y)
	event.relative = Vector2(relative_x, relative_y)
	
	# Check for button mask
	var button_mask: int = params.get("button_mask", 0)
	event.button_mask = button_mask
	
	Input.parse_input_event(event)
	
	return _success(cmd_id, {
		"simulated": true,
		"type": "mouse_motion",
		"position": {"x": position_x, "y": position_y},
		"relative": {"x": relative_x, "y": relative_y}
	})


func _cmd_simulate_action(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action", "")
	var pressed: bool = params.get("pressed", true)
	var strength: float = params.get("strength", 1.0)
	
	if action_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'action' parameter")
	
	if not InputMap.has_action(action_name):
		return _error(cmd_id, "INVALID_ACTION", "Action not found: " + action_name)
	
	var event = InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = strength
	
	Input.parse_input_event(event)
	
	return _success(cmd_id, {
		"simulated": true,
		"type": "action",
		"action": action_name,
		"pressed": pressed,
		"strength": strength
	})


func _cmd_get_input_actions(cmd_id: Variant) -> Dictionary:
	var actions: Array = []
	
	for action in InputMap.get_actions():
		# Skip built-in UI actions if desired
		var action_str: String = str(action)
		var events: Array = []
		
		for event in InputMap.action_get_events(action):
			events.append(event.as_text())
		
		actions.append({
			"name": action_str,
			"events": events
		})
	
	return _success(cmd_id, {
		"actions": actions,
		"count": actions.size()
	})


func _key_name_to_code(key_name: String) -> int:
	# Map common key names to Godot key constants
	var key_upper = key_name.to_upper()
	
	match key_upper:
		# Letters
		"A": return KEY_A
		"B": return KEY_B
		"C": return KEY_C
		"D": return KEY_D
		"E": return KEY_E
		"F": return KEY_F
		"G": return KEY_G
		"H": return KEY_H
		"I": return KEY_I
		"J": return KEY_J
		"K": return KEY_K
		"L": return KEY_L
		"M": return KEY_M
		"N": return KEY_N
		"O": return KEY_O
		"P": return KEY_P
		"Q": return KEY_Q
		"R": return KEY_R
		"S": return KEY_S
		"T": return KEY_T
		"U": return KEY_U
		"V": return KEY_V
		"W": return KEY_W
		"X": return KEY_X
		"Y": return KEY_Y
		"Z": return KEY_Z
		
		# Numbers
		"0": return KEY_0
		"1": return KEY_1
		"2": return KEY_2
		"3": return KEY_3
		"4": return KEY_4
		"5": return KEY_5
		"6": return KEY_6
		"7": return KEY_7
		"8": return KEY_8
		"9": return KEY_9
		
		# Function keys
		"F1": return KEY_F1
		"F2": return KEY_F2
		"F3": return KEY_F3
		"F4": return KEY_F4
		"F5": return KEY_F5
		"F6": return KEY_F6
		"F7": return KEY_F7
		"F8": return KEY_F8
		"F9": return KEY_F9
		"F10": return KEY_F10
		"F11": return KEY_F11
		"F12": return KEY_F12
		
		# Special keys
		"SPACE": return KEY_SPACE
		"ENTER", "RETURN": return KEY_ENTER
		"ESCAPE", "ESC": return KEY_ESCAPE
		"TAB": return KEY_TAB
		"BACKSPACE": return KEY_BACKSPACE
		"DELETE", "DEL": return KEY_DELETE
		"INSERT": return KEY_INSERT
		"HOME": return KEY_HOME
		"END": return KEY_END
		"PAGEUP", "PAGE_UP": return KEY_PAGEUP
		"PAGEDOWN", "PAGE_DOWN": return KEY_PAGEDOWN
		
		# Arrow keys
		"UP": return KEY_UP
		"DOWN": return KEY_DOWN
		"LEFT": return KEY_LEFT
		"RIGHT": return KEY_RIGHT
		
		# Modifiers
		"SHIFT": return KEY_SHIFT
		"CTRL", "CONTROL": return KEY_CTRL
		"ALT": return KEY_ALT
		"META", "SUPER", "WIN", "CMD": return KEY_META
		"CAPSLOCK", "CAPS_LOCK": return KEY_CAPSLOCK
		
	return KEY_NONE


# =============================================================================
# GUT Testing Framework
# =============================================================================

## Stores GUT process ID for async operations.
var _gut_process: int = -1

## Stores GUT console output.
var _gut_output: String = ""


## Check if GUT testing framework is installed.
## [br][br]
## Returns installation status and version if available.
func _cmd_gut_check_installed(cmd_id: Variant) -> Dictionary:
	var gut_path = "res://addons/gut/gut.gd"
	var installed = FileAccess.file_exists(gut_path)
	
	var version = ""
	if installed:
		# Try to get version from plugin.cfg
		var cfg_path = "res://addons/gut/plugin.cfg"
		if FileAccess.file_exists(cfg_path):
			var cfg = ConfigFile.new()
			if cfg.load(cfg_path) == OK:
				version = cfg.get_value("plugin", "version", "unknown")
	
	return _success(cmd_id, {
		"installed": installed,
		"version": version,
		"gut_path": gut_path
	})


## Run all GUT tests in specified directories.
## [br][br]
## [param params]:
## - 'dirs' (Array, default ["res://test/unit/"]): Test directories.
## - 'log_level' (int, default 1): GUT log verbosity level.
## - 'include_subdirs' (bool, default true): Include subdirectories.
## - 'output_file' (String): JUnit XML output file path.
func _cmd_gut_run_all(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var gut_check = _cmd_gut_check_installed(cmd_id)
	if not gut_check["result"]["installed"]:
		return _error(cmd_id, "GUT_NOT_INSTALLED", "GUT testing framework is not installed")
	
	var test_dirs: Array = params.get("dirs", ["res://test/unit/"])
	var log_level: int = params.get("log_level", 1)
	var include_subdirs: bool = params.get("include_subdirs", true)
	var output_file: String = params.get("output_file", "user://gut_results.xml")
	
	# Build GUT command line arguments
	var args: Array = [
		"-d", "-s", "addons/gut/gut_cmdln.gd",
		"-gexit",
		"-glog=" + str(log_level),
		"-gjunit_xml_file=" + output_file
	]
	
	for dir in test_dirs:
		args.append("-gdir=" + str(dir))
	
	if include_subdirs:
		args.append("-ginclude_subdirs")
	
	# Get Godot executable path
	var godot_path = OS.get_executable_path()
	
	# Run the tests
	var output: Array = []
	var exit_code = OS.execute(godot_path, args, output, true)
	
	return _success(cmd_id, {
		"started": true,
		"exit_code": exit_code,
		"output": "\n".join(output),
		"results_file": output_file,
		"message": "Tests completed. Use gut_get_results to parse the XML results."
	})


## Run all tests in a specific test script.
## [br][br]
## [param params]:
## - 'script' (String, required): Path to test script.
## - 'log_level' (int, default 1): GUT log verbosity level.
## - 'output_file' (String): JUnit XML output file path.
func _cmd_gut_run_script(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var gut_check = _cmd_gut_check_installed(cmd_id)
	if not gut_check["result"]["installed"]:
		return _error(cmd_id, "GUT_NOT_INSTALLED", "GUT testing framework is not installed")
	
	var script: String = params.get("script", "")
	if script.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'script' parameter")
	
	var log_level: int = params.get("log_level", 1)
	var output_file: String = params.get("output_file", "user://gut_results.xml")
	
	var args: Array = [
		"-d", "-s", "addons/gut/gut_cmdln.gd",
		"-gexit",
		"-glog=" + str(log_level),
		"-gtest=" + script,
		"-gjunit_xml_file=" + output_file
	]
	
	var godot_path = OS.get_executable_path()
	var output: Array = []
	var exit_code = OS.execute(godot_path, args, output, true)
	
	return _success(cmd_id, {
		"started": true,
		"script": script,
		"exit_code": exit_code,
		"output": "\n".join(output),
		"results_file": output_file
	})


## Run a specific test function within a test script.
## [br][br]
## [param params]:
## - 'script' (String, required): Path to test script.
## - 'test_name' (String, required): Name of test function to run.
## - 'log_level' (int, default 1): GUT log verbosity level.
## - 'output_file' (String): JUnit XML output file path.
func _cmd_gut_run_test(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var gut_check = _cmd_gut_check_installed(cmd_id)
	if not gut_check["result"]["installed"]:
		return _error(cmd_id, "GUT_NOT_INSTALLED", "GUT testing framework is not installed")
	
	var script: String = params.get("script", "")
	var test_name: String = params.get("test_name", "")
	
	if script.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'script' parameter")
	if test_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'test_name' parameter")
	
	var log_level: int = params.get("log_level", 1)
	var output_file: String = params.get("output_file", "user://gut_results.xml")
	
	var args: Array = [
		"-d", "-s", "addons/gut/gut_cmdln.gd",
		"-gexit",
		"-glog=" + str(log_level),
		"-gtest=" + script,
		"-gunit_test_name=" + test_name,
		"-gjunit_xml_file=" + output_file
	]
	
	var godot_path = OS.get_executable_path()
	var output: Array = []
	var exit_code = OS.execute(godot_path, args, output, true)
	
	return _success(cmd_id, {
		"started": true,
		"script": script,
		"test_name": test_name,
		"exit_code": exit_code,
		"output": "\n".join(output),
		"results_file": output_file
	})


## Get and parse GUT test results from JUnit XML file.
## [br][br]
## [param params]:
## - 'file' (String, default "user://gut_results.xml"): Results file path.
## [br][br]
## Returns parsed test results with totals and per-test details.
func _cmd_gut_get_results(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var results_file: String = params.get("file", "user://gut_results.xml")
	
	# Convert user:// to actual path
	var actual_path = results_file
	if results_file.begins_with("user://"):
		actual_path = OS.get_user_data_dir() + "/" + results_file.substr(7)
	
	if not FileAccess.file_exists(results_file):
		return _error(cmd_id, "FILE_NOT_FOUND", "Results file not found: " + results_file)
	
	var file = FileAccess.open(results_file, FileAccess.READ)
	if file == null:
		return _error(cmd_id, "READ_ERROR", "Failed to read results file")
	
	var xml_content = file.get_as_text()
	file.close()
	
	# Parse the JUnit XML
	var results = _parse_junit_xml(xml_content)
	
	return _success(cmd_id, results)


## Parse JUnit XML format into a dictionary.
## [br][br]
## [param xml_content]: Raw XML string from GUT results file.
## Returns structured test results dictionary.
func _parse_junit_xml(xml_content: String) -> Dictionary:
	var parser = XMLParser.new()
	var error = parser.open_buffer(xml_content.to_utf8_buffer())
	
	if error != OK:
		return {"error": "Failed to parse XML", "raw": xml_content}
	
	var results = {
		"total_tests": 0,
		"total_failures": 0,
		"total_skipped": 0,
		"test_suites": []
	}
	
	var current_suite: Dictionary = {}
	var current_test: Dictionary = {}
	var in_failure = false
	var failure_text = ""
	
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node_name = parser.get_node_name()
				
				if node_name == "testsuites":
					for i in range(parser.get_attribute_count()):
						var attr_name = parser.get_attribute_name(i)
						if attr_name == "tests":
							results["total_tests"] = int(parser.get_attribute_value(i))
						elif attr_name == "failures":
							results["total_failures"] = int(parser.get_attribute_value(i))
				
				elif node_name == "testsuite":
					current_suite = {
						"name": "",
						"tests": 0,
						"failures": 0,
						"skipped": 0,
						"testcases": []
					}
					for i in range(parser.get_attribute_count()):
						var attr_name = parser.get_attribute_name(i)
						var attr_value = parser.get_attribute_value(i)
						if attr_name == "name":
							current_suite["name"] = attr_value
						elif attr_name == "tests":
							current_suite["tests"] = int(attr_value)
						elif attr_name == "failures":
							current_suite["failures"] = int(attr_value)
						elif attr_name == "skipped":
							current_suite["skipped"] = int(attr_value)
				
				elif node_name == "testcase":
					current_test = {
						"name": "",
						"status": "pass",
						"assertions": 0,
						"failure_message": ""
					}
					for i in range(parser.get_attribute_count()):
						var attr_name = parser.get_attribute_name(i)
						var attr_value = parser.get_attribute_value(i)
						if attr_name == "name":
							current_test["name"] = attr_value
						elif attr_name == "status":
							current_test["status"] = attr_value
						elif attr_name == "assertions":
							current_test["assertions"] = int(attr_value)
				
				elif node_name == "failure":
					in_failure = true
					failure_text = ""
				
				elif node_name == "skipped":
					current_test["status"] = "pending"
			
			XMLParser.NODE_TEXT:
				if in_failure:
					failure_text += parser.get_node_data()
			
			XMLParser.NODE_ELEMENT_END:
				var node_name = parser.get_node_name()
				
				if node_name == "testsuite":
					results["test_suites"].append(current_suite)
					results["total_skipped"] += current_suite["skipped"]
				
				elif node_name == "testcase":
					current_suite["testcases"].append(current_test)
				
				elif node_name == "failure":
					in_failure = false
					current_test["failure_message"] = failure_text.strip_edges()
	
	return results


func _cmd_gut_list_tests(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var test_dirs: Array = params.get("dirs", ["res://test/"])
	var prefix: String = params.get("prefix", "test_")
	var suffix: String = params.get("suffix", ".gd")
	
	var test_files: Array = []
	
	for dir in test_dirs:
		_find_test_files(dir, prefix, suffix, test_files)
	
	# Parse each test file to find test functions
	var tests: Array = []
	for file_path in test_files:
		var test_info = _parse_test_file(file_path)
		if test_info != null:
			tests.append(test_info)
	
	return _success(cmd_id, {
		"test_files": test_files,
		"tests": tests,
		"count": tests.size()
	})


func _find_test_files(dir_path: String, prefix: String, suffix: String, results: Array) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_find_test_files(dir_path.path_join(file_name), prefix, suffix, results)
		else:
			if file_name.begins_with(prefix) and file_name.ends_with(suffix):
				results.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	
	dir.list_dir_end()


func _parse_test_file(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	
	var content = file.get_as_text()
	file.close()
	
	var test_functions: Array = []
	var lines = content.split("\n")
	
	for line in lines:
		var stripped = line.strip_edges()
		if stripped.begins_with("func test_"):
			# Extract function name
			var paren_pos = stripped.find("(")
			if paren_pos > 0:
				var func_name = stripped.substr(5, paren_pos - 5)  # Remove "func "
				test_functions.append(func_name)
	
	return {
		"file": file_path,
		"test_count": test_functions.size(),
		"tests": test_functions
	}


func _cmd_gut_create_test(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var file_path: String = params.get("path", "")
	var test_name: String = params.get("name", "")
	var class_to_test: String = params.get("class_to_test", "")
	
	if file_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not file_path.ends_with(".gd"):
		file_path += ".gd"
	
	# Ensure it follows naming convention
	var file_name = file_path.get_file()
	if not file_name.begins_with("test_"):
		var dir_part = file_path.get_base_dir()
		file_path = dir_part.path_join("test_" + file_name)
	
	# Create test file content
	var content = "extends GutTest\n\n"
	
	if not class_to_test.is_empty():
		content += "# Testing: " + class_to_test + "\n"
		content += "var _class_script = load(\"" + class_to_test + "\")\n\n"
	
	content += "func before_each():\n"
	content += "\t# Setup before each test\n"
	content += "\tpass\n\n"
	
	content += "func after_each():\n"
	content += "\t# Cleanup after each test\n"
	content += "\tpass\n\n"
	
	if not test_name.is_empty():
		var func_name = test_name
		if not func_name.begins_with("test_"):
			func_name = "test_" + func_name
		content += "func " + func_name + "():\n"
		content += "\t# TODO: Implement test\n"
		content += "\tpending(\"Not yet implemented\")\n"
	else:
		content += "func test_example():\n"
		content += "\t# Example test\n"
		content += "\tassert_true(true, \"This test passes\")\n"
	
	# Ensure directory exists
	var dir_path = file_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Write the file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return _error(cmd_id, "WRITE_ERROR", "Failed to create test file: " + str(FileAccess.get_open_error()))
	
	file.store_string(content)
	file.close()
	
	return _success(cmd_id, {
		"created": true,
		"path": file_path,
		"content": content
	})


# =============================================================================
# Signal Operations
# =============================================================================

## List all signals on a node.
## [br][br]
## [param params]: Must contain 'path' (String) - node path.
## [br][br]
## Returns array of signal definitions with names and argument types.
func _cmd_list_node_signals(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var signals: Array = []
	for sig in node.get_signal_list():
		var signal_info = {
			"name": sig["name"],
			"args": []
		}
		for arg in sig["args"]:
			signal_info["args"].append({
				"name": arg["name"],
				"type": type_string(arg["type"])
			})
		signals.append(signal_info)
	
	return _success(cmd_id, {
		"path": node_path,
		"signals": signals,
		"count": signals.size()
	})


## Emit a signal on a node.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'signal' (String, required): Signal name to emit.
## - 'args' (Array, optional): Arguments to pass to signal handlers.
func _cmd_emit_signal(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	var signal_name: String = params.get("signal", "")
	var args: Array = params.get("args", [])
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if signal_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'signal' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node.has_signal(signal_name):
		return _error(cmd_id, "SIGNAL_NOT_FOUND", "Signal not found: " + signal_name)
	
	node.emit_signal(signal_name, args)
	
	return _success(cmd_id, {
		"emitted": true,
		"path": node_path,
		"signal": signal_name
	})


# =============================================================================
# Method Calling
# =============================================================================

## Call a method on a node.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'method' (String, required): Method name to call.
## - 'args' (Array, optional): Arguments to pass to the method.
## [br][br]
## Returns the method's return value (stringified).
func _cmd_call_method(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	var method_name: String = params.get("method", "")
	var args: Array = params.get("args", [])
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if method_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'method' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node.has_method(method_name):
		return _error(cmd_id, "METHOD_NOT_FOUND", "Method not found: " + method_name)
	
	var result = node.callv(method_name, args)
	
	return _success(cmd_id, {
		"called": true,
		"path": node_path,
		"method": method_name,
		"result": str(result) if result != null else null
	})


## List methods on a node.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'include_inherited' (bool, default false): Include inherited/engine methods.
## [br][br]
## Returns array of method definitions with names, arguments, and return types.
func _cmd_list_node_methods(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	var include_inherited: bool = params.get("include_inherited", false)
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var methods: Array = []
	for method in node.get_method_list():
		# Filter to script methods only if not including inherited
		if not include_inherited:
			# Script methods typically have different flags
			var flags = method.get("flags", 0)
			if flags & 64 == 0:  # METHOD_FLAG_FROM_SCRIPT = 64
				continue
		
		var method_info = {
			"name": method["name"],
			"args": [],
			"return_type": type_string(method.get("return", {}).get("type", TYPE_NIL))
		}
		for arg in method.get("args", []):
			method_info["args"].append({
				"name": arg["name"],
				"type": type_string(arg["type"])
			})
		methods.append(method_info)
	
	return _success(cmd_id, {
		"path": node_path,
		"methods": methods,
		"count": methods.size()
	})


# =============================================================================
# Group Operations
# =============================================================================

## Get all nodes that belong to a specific group.
## [br][br]
## [param params]: Must contain 'group' (String) - group name.
## [br][br]
## Returns array of node paths in the group.
func _cmd_get_nodes_in_group(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var group_name: String = params.get("group", "")
	if group_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'group' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var nodes_in_group: Array = []
	_find_nodes_in_group(root, group_name, nodes_in_group)
	
	var paths: Array = []
	for node in nodes_in_group:
		paths.append(str(root.get_path_to(node)))
	
	return _success(cmd_id, {
		"group": group_name,
		"nodes": paths,
		"count": paths.size()
	})


## Recursively find nodes in a group.
## [br][br]
## Helper function for _cmd_get_nodes_in_group.
func _find_nodes_in_group(node: Node, group: String, results: Array) -> void:
	if node.is_in_group(group):
		results.append(node)
	for child in node.get_children():
		_find_nodes_in_group(child, group, results)


## Add a node to a group.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'group' (String, required): Group name to add to.
## - 'persistent' (bool, default true): Whether group membership saves with scene.
func _cmd_add_node_to_group(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	var group_name: String = params.get("group", "")
	var persistent: bool = params.get("persistent", true)
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if group_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'group' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	node.add_to_group(group_name, persistent)
	
	return _success(cmd_id, {
		"added": true,
		"path": node_path,
		"group": group_name
	})


## Remove a node from a group.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'group' (String, required): Group name to remove from.
func _cmd_remove_node_from_group(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	var group_name: String = params.get("group", "")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if group_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'group' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	node.remove_from_group(group_name)
	
	return _success(cmd_id, {
		"removed": true,
		"path": node_path,
		"group": group_name
	})


# =============================================================================
# Resource Operations
# =============================================================================

## Load a resource and return basic info.
## [br][br]
## [param params]: Must contain 'path' (String) - resource path.
## [br][br]
## Returns resource type and name.
func _cmd_load_resource(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not ResourceLoader.exists(path):
		return _error(cmd_id, "RESOURCE_NOT_FOUND", "Resource not found: " + path)
	
	var resource = load(path)
	if resource == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load resource: " + path)
	
	return _success(cmd_id, {
		"loaded": true,
		"path": path,
		"type": resource.get_class(),
		"resource_name": resource.resource_name if resource.resource_name else ""
	})


## Get detailed information about a resource.
## [br][br]
## [param params]: Must contain 'path' (String) - resource path.
## [br][br]
## Returns resource properties visible in editor.
func _cmd_get_resource_info(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not ResourceLoader.exists(path):
		return _error(cmd_id, "RESOURCE_NOT_FOUND", "Resource not found: " + path)
	
	var resource = load(path)
	if resource == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load resource: " + path)
	
	var properties: Dictionary = {}
	for prop in resource.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_EDITOR:
			var value = resource.get(prop["name"])
			properties[prop["name"]] = _safe_value(value)
	
	return _success(cmd_id, {
		"path": path,
		"type": resource.get_class(),
		"resource_name": resource.resource_name if resource.resource_name else "",
		"properties": properties
	})


## Safely convert values to JSON-compatible format.
## [br][br]
## Handles objects, resources, callables, and signals specially.
func _safe_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_OBJECT:
			if value is Resource:
				return {"_type": "Resource", "path": value.resource_path}
			return {"_type": value.get_class() if value else "null"}
		TYPE_CALLABLE, TYPE_SIGNAL:
			return {"_type": type_string(typeof(value))}
		_:
			return value


# =============================================================================
# Animation Operations
# =============================================================================

## List all animations in an AnimationPlayer.
## [br][br]
## [param params]: Must contain 'path' (String) - AnimationPlayer node path.
## [br][br]
## Returns array of animation names with length and loop status.
func _cmd_list_animations(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter (AnimationPlayer node)")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node is AnimationPlayer:
		return _error(cmd_id, "INVALID_NODE", "Node is not an AnimationPlayer")
	
	var anim_player: AnimationPlayer = node
	var animations: Array = []
	
	for anim_name in anim_player.get_animation_list():
		var anim = anim_player.get_animation(anim_name)
		animations.append({
			"name": anim_name,
			"length": anim.length,
			"loop_mode": anim.loop_mode,
			"track_count": anim.get_track_count()
		})
	
	return _success(cmd_id, {
		"path": node_path,
		"animations": animations,
		"current": anim_player.current_animation,
		"is_playing": anim_player.is_playing()
	})


func _cmd_play_animation(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	var animation_name: String = params.get("animation", "")
	var custom_blend: float = params.get("blend", -1.0)
	var custom_speed: float = params.get("speed", 1.0)
	var from_end: bool = params.get("from_end", false)
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if animation_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'animation' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node is AnimationPlayer:
		return _error(cmd_id, "INVALID_NODE", "Node is not an AnimationPlayer")
	
	var anim_player: AnimationPlayer = node
	
	if not anim_player.has_animation(animation_name):
		return _error(cmd_id, "ANIMATION_NOT_FOUND", "Animation not found: " + animation_name)
	
	anim_player.play(animation_name, custom_blend, custom_speed, from_end)
	
	return _success(cmd_id, {
		"playing": true,
		"path": node_path,
		"animation": animation_name
	})


## Stop animation on an AnimationPlayer.
## [br][br]
## [param params]:
## - 'path' (String, required): AnimationPlayer node path.
## - 'keep_state' (bool, default true): Keep current animation pose.
func _cmd_stop_animation(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	
	var node_path: String = params.get("path", "")
	var keep_state: bool = params.get("keep_state", true)
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node is AnimationPlayer:
		return _error(cmd_id, "INVALID_NODE", "Node is not an AnimationPlayer")
	
	var anim_player: AnimationPlayer = node
	anim_player.stop(keep_state)
	
	return _success(cmd_id, {
		"stopped": true,
		"path": node_path
	})


# =============================================================================
# Audio Operations
# =============================================================================

## List all audio buses.
## [br][br]
## Returns array of bus info including name, volume, mute status, and effect count.
func _cmd_list_audio_buses(cmd_id: Variant) -> Dictionary:
	var buses: Array = []
	
	for i in range(AudioServer.bus_count):
		buses.append({
			"index": i,
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"mute": AudioServer.is_bus_mute(i),
			"solo": AudioServer.is_bus_solo(i),
			"bypass_effects": AudioServer.is_bus_bypassing_effects(i),
			"effect_count": AudioServer.get_bus_effect_count(i)
		})
	
	return _success(cmd_id, {
		"buses": buses,
		"count": buses.size()
	})


## Set volume of an audio bus.
## [br][br]
## [param params]:
## - 'bus' (String, default "Master"): Audio bus name.
## - 'volume_db' (float, default 0.0): Volume in decibels.
func _cmd_set_audio_bus_volume(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var bus_name: String = params.get("bus", "Master")
	var volume_db: float = params.get("volume_db", 0.0)
	
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return _error(cmd_id, "BUS_NOT_FOUND", "Audio bus not found: " + bus_name)
	
	AudioServer.set_bus_volume_db(bus_idx, volume_db)
	
	return _success(cmd_id, {
		"set": true,
		"bus": bus_name,
		"volume_db": volume_db
	})


## Set mute status of an audio bus.
## [br][br]
## [param params]:
## - 'bus' (String, default "Master"): Audio bus name.
## - 'mute' (bool, default true): Whether to mute the bus.
func _cmd_set_audio_bus_mute(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var bus_name: String = params.get("bus", "Master")
	var mute: bool = params.get("mute", true)
	
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return _error(cmd_id, "BUS_NOT_FOUND", "Audio bus not found: " + bus_name)
	
	AudioServer.set_bus_mute(bus_idx, mute)
	
	return _success(cmd_id, {
		"set": true,
		"bus": bus_name,
		"mute": mute
	})


# =============================================================================
# Debug/Performance
# =============================================================================

## Get performance metrics.
## [br][br]
## Returns FPS, process times, object counts, render stats, and memory usage.
func _cmd_get_performance_info(cmd_id: Variant) -> Dictionary:
	var info: Dictionary = {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_time": Performance.get_monitor(Performance.TIME_PROCESS),
		"physics_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"navigation_time": Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"object_resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"object_node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"render_total_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_total_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"render_total_draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
		"memory_static_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
	}
	
	return _success(cmd_id, info)


## Get memory usage information.
## [br][br]
## Returns static memory, object counts, and orphan node count.
func _cmd_get_memory_info(cmd_id: Variant) -> Dictionary:
	var info: Dictionary = {
		"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		"static_memory_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	}
	
	return _success(cmd_id, info)


# =============================================================================
# Console/Output
# =============================================================================

## Print a message to the Godot console.
## [br][br]
## [param params]:
## - 'message' (String): Message to print.
## - 'level' (String, default "info"): Log level ("info", "warning", "error").
func _cmd_print_to_console(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var message: String = params.get("message", "")
	var level: String = params.get("level", "info")
	
	match level:
		"error":
			push_error(message)
		"warning":
			push_warning(message)
		_:
			print(message)
	
	return _success(cmd_id, {
		"printed": true,
		"message": message,
		"level": level
	})


## Get recent errors.
## [br][br]
## Reads the Godot editor log file to find recent errors and warnings.
## Returns parsed log entries with timestamps.
func _cmd_get_recent_errors(cmd_id: Variant) -> Dictionary:
	var log_entries: Array = []
	var errors: Array = []
	var warnings: Array = []
	
	# Try to read from the Godot log file
	var log_path: String = OS.get_user_data_dir() + "/logs/godot.log"
	
	if FileAccess.file_exists(log_path):
		var file = FileAccess.open(log_path, FileAccess.READ)
		if file != null:
			var content: String = file.get_as_text()
			file.close()
			
			# Parse log entries - get last 100 lines
			var lines: PackedStringArray = content.split("\n")
			var start_idx: int = max(0, lines.size() - 100)
			
			for i in range(start_idx, lines.size()):
				var line: String = lines[i].strip_edges()
				if line.is_empty():
					continue
				
				var entry: Dictionary = {"line": line, "type": "info"}
				
				# Categorize by type
				if line.contains("ERROR") or line.contains("error:") or line.begins_with("E "):
					entry["type"] = "error"
					errors.append(line)
				elif line.contains("WARNING") or line.contains("warning:") or line.begins_with("W "):
					entry["type"] = "warning"
					warnings.append(line)
				elif line.contains("SCRIPT ERROR") or line.contains("Script error"):
					entry["type"] = "script_error"
					errors.append(line)
				
				log_entries.append(entry)
	
	return _success(cmd_id, {
		"log_file": log_path,
		"total_entries": log_entries.size(),
		"error_count": errors.size(),
		"warning_count": warnings.size(),
		"errors": errors,
		"warnings": warnings,
		"recent_entries": log_entries.slice(-50),  # Last 50 entries
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	})


# =============================================================================
# PLUGIN MANAGEMENT COMMANDS
# =============================================================================

## Enable an editor plugin by its name or folder name.
## [br][br]
## [param params]: Parameters dictionary
## - 'name' (String, required): Plugin name or folder name (e.g., "Codot", "gut")
func _cmd_enable_plugin(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "EditorInterface not available")
	
	var plugin_name: String = params.get("name", "")
	if plugin_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'name' parameter")
	
	# Find the plugin path
	var plugin_path := _find_plugin_cfg(plugin_name)
	if plugin_path.is_empty():
		return _error(cmd_id, "PLUGIN_NOT_FOUND", "Plugin not found: " + plugin_name)
	
	# Check if already enabled
	if editor_interface.is_plugin_enabled(plugin_path):
		return _success(cmd_id, {
			"plugin": plugin_path,
			"enabled": true,
			"was_already_enabled": true,
		})
	
	# Enable it
	editor_interface.set_plugin_enabled(plugin_path, true)
	
	return _success(cmd_id, {
		"plugin": plugin_path,
		"enabled": true,
		"was_already_enabled": false,
	})


## Disable an editor plugin by its name or folder name.
## [br][br]
## [param params]: Parameters dictionary
## - 'name' (String, required): Plugin name or folder name (e.g., "Codot", "gut")
func _cmd_disable_plugin(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "EditorInterface not available")
	
	var plugin_name: String = params.get("name", "")
	if plugin_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'name' parameter")
	
	# Find the plugin path
	var plugin_path := _find_plugin_cfg(plugin_name)
	if plugin_path.is_empty():
		return _error(cmd_id, "PLUGIN_NOT_FOUND", "Plugin not found: " + plugin_name)
	
	# Check if already disabled
	if not editor_interface.is_plugin_enabled(plugin_path):
		return _success(cmd_id, {
			"plugin": plugin_path,
			"enabled": false,
			"was_already_disabled": true,
		})
	
	# Disable it
	editor_interface.set_plugin_enabled(plugin_path, false)
	
	return _success(cmd_id, {
		"plugin": plugin_path,
		"enabled": false,
		"was_already_disabled": false,
	})


## List all available editor plugins and their enabled status.
func _cmd_get_plugins(cmd_id: Variant) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "EditorInterface not available")
	
	var plugins: Array[Dictionary] = []
	var addons_dir := DirAccess.open("res://addons")
	
	if addons_dir != null:
		addons_dir.list_dir_begin()
		var folder_name := addons_dir.get_next()
		
		while folder_name != "":
			if addons_dir.current_is_dir() and not folder_name.begins_with("."):
				var plugin_cfg_path := "res://addons/" + folder_name + "/plugin.cfg"
				
				if FileAccess.file_exists(plugin_cfg_path):
					var cfg := ConfigFile.new()
					if cfg.load(plugin_cfg_path) == OK:
						var plugin_info := {
							"folder": folder_name,
							"path": plugin_cfg_path,
							"name": cfg.get_value("plugin", "name", folder_name),
							"description": cfg.get_value("plugin", "description", ""),
							"author": cfg.get_value("plugin", "author", ""),
							"version": cfg.get_value("plugin", "version", ""),
							"enabled": editor_interface.is_plugin_enabled(plugin_cfg_path),
						}
						plugins.append(plugin_info)
			
			folder_name = addons_dir.get_next()
		
		addons_dir.list_dir_end()
	
	return _success(cmd_id, {
		"plugins": plugins,
		"count": plugins.size(),
	})


## Reload the current project (restarts the editor).
## Note: This will close and reopen the project.
func _cmd_reload_project(cmd_id: Variant) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "EditorInterface not available")
	
	# Get the project path before restarting
	var project_path := ProjectSettings.globalize_path("res://")
	
	# Use restart_editor() if available, otherwise use OS.shell_open
	if editor_interface.has_method("restart_editor"):
		# Schedule restart (returns immediately, restart happens after)
		print("[Codot] Restarting editor...")
		
		# First return success, then restart
		# Use call_deferred to restart after response is sent
		call_deferred("_do_restart_editor", true)
		
		return _success(cmd_id, {
			"restarting": true,
			"project_path": project_path,
			"note": "Editor will restart momentarily. Connection will be lost.",
		})
	else:
		return _error(cmd_id, "NOT_SUPPORTED", "Editor restart not supported in this Godot version")


func _do_restart_editor(with_project: bool) -> void:
	## Deferred restart to allow response to be sent first.
	await get_tree().create_timer(0.5).timeout
	editor_interface.restart_editor(with_project)


## Find a plugin.cfg path by plugin name or folder name.
## Returns empty string if not found.
func _find_plugin_cfg(name_or_folder: String) -> String:
	var lower_name := name_or_folder.to_lower()
	
	# First, try direct folder match
	var direct_path := "res://addons/" + name_or_folder + "/plugin.cfg"
	if FileAccess.file_exists(direct_path):
		return direct_path
	
	# Try lowercase folder match
	var lower_path := "res://addons/" + lower_name + "/plugin.cfg"
	if FileAccess.file_exists(lower_path):
		return lower_path
	
	# Search by plugin name in cfg files
	var addons_dir := DirAccess.open("res://addons")
	if addons_dir == null:
		return ""
	
	addons_dir.list_dir_begin()
	var folder_name := addons_dir.get_next()
	
	while folder_name != "":
		if addons_dir.current_is_dir() and not folder_name.begins_with("."):
			var plugin_cfg_path := "res://addons/" + folder_name + "/plugin.cfg"
			
			if FileAccess.file_exists(plugin_cfg_path):
				var cfg := ConfigFile.new()
				if cfg.load(plugin_cfg_path) == OK:
					var cfg_name: String = cfg.get_value("plugin", "name", "")
					if cfg_name.to_lower() == lower_name:
						addons_dir.list_dir_end()
						return plugin_cfg_path
		
		folder_name = addons_dir.get_next()
	
	addons_dir.list_dir_end()
	return ""


# =============================================================================
# ADVANCED TESTING & DEBUGGING COMMANDS
# =============================================================================

## Run a scene and capture output for a specified duration.
## [br][br]
## [param params]: Parameters dictionary
## - 'scene' (String, optional): Scene path to run. If not specified, runs current scene.
## - 'duration' (float, optional): How long to run in seconds (default: 2.0)
## - 'filter' (String, optional): Filter output by "all", "error", "warning" (default: "all")
## - 'stop_on_error' (bool, optional): Stop immediately if an error is detected (default: false)
func _cmd_run_and_capture(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "EditorInterface not available")
	
	var scene_path: String = params.get("scene", "")
	var duration: float = params.get("duration", 2.0)
	var filter: String = params.get("filter", "all")
	var stop_on_error: bool = params.get("stop_on_error", false)
	
	# Open scene if specified
	if not scene_path.is_empty():
		if not FileAccess.file_exists(scene_path) and not scene_path.begins_with("res://"):
			scene_path = "res://" + scene_path
		if FileAccess.file_exists(scene_path.replace("res://", "")):
			editor_interface.open_scene_from_path(scene_path)
	
	# Mark debug log position
	var start_id: int = 0
	if debugger_plugin != null and debugger_plugin.has_method("mark_position"):
		start_id = debugger_plugin.mark_position()
	
	# Start playing
	if scene_path.is_empty():
		editor_interface.play_current_scene()
	else:
		editor_interface.play_current_scene()
	
	# Wait for the specified duration, checking for errors if stop_on_error
	var elapsed: float = 0.0
	var check_interval: float = 0.25
	var stopped_early: bool = false
	var stop_reason: String = ""
	
	while elapsed < duration:
		await get_tree().create_timer(check_interval).timeout
		elapsed += check_interval
		
		# Check if game is still running
		if not editor_interface.is_playing_scene():
			stopped_early = true
			stop_reason = "Game stopped unexpectedly"
			break
		
		# Check for errors if stop_on_error is enabled
		if stop_on_error and debugger_plugin != null:
			if debugger_plugin.has_new_errors():
				stopped_early = true
				stop_reason = "Error detected"
				editor_interface.stop_playing_scene()
				break
	
	# Stop the game if still running
	if editor_interface.is_playing_scene():
		editor_interface.stop_playing_scene()
	
	# Small delay to let final messages arrive
	await get_tree().create_timer(0.2).timeout
	
	# Collect output
	var output: Dictionary = {
		"scene": scene_path if not scene_path.is_empty() else "current",
		"duration_requested": duration,
		"duration_actual": elapsed,
		"stopped_early": stopped_early,
		"stop_reason": stop_reason,
		"entries": [],
		"errors": [],
		"warnings": [],
		"error_count": 0,
		"warning_count": 0,
	}
	
	if debugger_plugin != null and debugger_plugin.has_method("get_entries"):
		var entries: Array = debugger_plugin.get_entries(filter, start_id, 200)
		output["entries"] = entries
		
		for entry in entries:
			var etype: String = entry.get("type", "")
			if etype == "error" or etype == "script_error":
				output["errors"].append(entry)
			elif etype == "warning":
				output["warnings"].append(entry)
		
		output["error_count"] = output["errors"].size()
		output["warning_count"] = output["warnings"].size()
	
	return _success(cmd_id, output)


## Wait for specific output from the running game.
## [br][br]
## [param params]: Parameters dictionary
## - 'timeout' (float, optional): Maximum time to wait in seconds (default: 5.0)
## - 'wait_for' (String, optional): Wait for "error", "warning", "any", or a specific message substring
## - 'poll_interval' (float, optional): How often to check in seconds (default: 0.25)
func _cmd_wait_for_output(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if debugger_plugin == null:
		return _error(cmd_id, "NO_DEBUGGER", "Debugger plugin not available")
	
	var timeout: float = params.get("timeout", 5.0)
	var wait_for: String = params.get("wait_for", "any")
	var poll_interval: float = params.get("poll_interval", 0.25)
	
	# Mark current position
	var start_id: int = debugger_plugin.mark_position() if debugger_plugin.has_method("mark_position") else 0
	
	var elapsed: float = 0.0
	var found: bool = false
	var matched_entry: Dictionary = {}
	
	while elapsed < timeout:
		await get_tree().create_timer(poll_interval).timeout
		elapsed += poll_interval
		
		# Check for new entries
		if debugger_plugin.has_method("get_entries"):
			var entries: Array = debugger_plugin.get_entries("all", start_id, 50)
			
			for entry in entries:
				var etype: String = entry.get("type", "")
				var message: String = entry.get("message", "")
				
				match wait_for:
					"error":
						if etype == "error" or etype == "script_error":
							found = true
							matched_entry = entry
					"warning":
						if etype == "warning":
							found = true
							matched_entry = entry
					"any":
						if not entries.is_empty():
							found = true
							matched_entry = entry
					_:
						# Treat as substring match
						if message.contains(wait_for):
							found = true
							matched_entry = entry
				
				if found:
					break
		
		if found:
			break
	
	return _success(cmd_id, {
		"found": found,
		"wait_for": wait_for,
		"elapsed": elapsed,
		"timeout": timeout,
		"matched_entry": matched_entry,
	})


## Ping the running game to verify the capture system is working.
## [br][br]
## [param params]: Parameters dictionary
## - 'timeout' (float, optional): Maximum time to wait for pong (default: 2.0)
func _cmd_ping_game(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if debugger_plugin == null:
		return _error(cmd_id, "NO_DEBUGGER", "Debugger plugin not available")
	
	if editor_interface == null or not editor_interface.is_playing_scene():
		return _error(cmd_id, "NOT_PLAYING", "No game is currently running")
	
	var timeout: float = params.get("timeout", 2.0)
	
	# Get session and send ping
	var sessions: Array = debugger_plugin.get_sessions()
	if sessions.is_empty():
		return _error(cmd_id, "NO_SESSION", "No debugger session available")
	
	var session = sessions[0]
	if not session.is_active():
		return _error(cmd_id, "SESSION_INACTIVE", "Debugger session is not active")
	
	# Send ping
	var ping_time: float = Time.get_unix_time_from_system()
	session.send_message("codot:ping", [{"time": ping_time}])
	
	# Wait for pong (check _seen_message_types)
	var start_time: float = Time.get_unix_time_from_system()
	var pong_count_before: int = debugger_plugin._seen_message_types.get("codot:pong", 0)
	
	while Time.get_unix_time_from_system() - start_time < timeout:
		await get_tree().create_timer(0.1).timeout
		var pong_count_after: int = debugger_plugin._seen_message_types.get("codot:pong", 0)
		if pong_count_after > pong_count_before:
			return _success(cmd_id, {
				"pong": true,
				"latency": Time.get_unix_time_from_system() - ping_time,
			})
	
	return _success(cmd_id, {
		"pong": false,
		"timeout": true,
	})


## Get the current state of the running game.
func _cmd_get_game_state(cmd_id: Variant) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "EditorInterface not available")
	
	var is_playing: bool = editor_interface.is_playing_scene()
	
	var state: Dictionary = {
		"is_playing": is_playing,
		"debugger_available": debugger_plugin != null,
	}
	
	if debugger_plugin != null:
		if debugger_plugin.has_method("get_diagnostics"):
			state.merge(debugger_plugin.get_diagnostics())
		elif debugger_plugin.has_method("get_summary"):
			state["summary"] = debugger_plugin.get_summary()
	
	return _success(cmd_id, state)


## Take a screenshot of the running game.
## [br][br]
## [param params]: Parameters dictionary
## - 'path' (String, optional): Where to save the screenshot (default: user://screenshot.png)
## - 'delay' (float, optional): Wait before taking screenshot (default: 0.0)
func _cmd_take_screenshot(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "EditorInterface not available")
	
	if not editor_interface.is_playing_scene():
		return _error(cmd_id, "NOT_PLAYING", "No game is currently running")
	
	var save_path: String = params.get("path", "user://screenshot.png")
	var delay: float = params.get("delay", 0.0)
	
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	
	# For screenshots, we need to use the running game's viewport
	# This requires the game to have the capture autoload
	# Send a screenshot request via debugger
	if debugger_plugin == null:
		return _error(cmd_id, "NO_DEBUGGER", "Debugger plugin not available")
	
	var sessions: Array = debugger_plugin.get_sessions()
	if sessions.is_empty() or not sessions[0].is_active():
		return _error(cmd_id, "NO_SESSION", "No active debugger session")
	
	# Request screenshot from game
	sessions[0].send_message("codot:screenshot", [{"path": save_path}])
	
	# Wait briefly for response
	await get_tree().create_timer(0.5).timeout
	
	# Check if file was created
	var global_path: String = ProjectSettings.globalize_path(save_path)
	var exists: bool = FileAccess.file_exists(save_path)
	
	return _success(cmd_id, {
		"path": save_path,
		"global_path": global_path,
		"exists": exists,
		"note": "Screenshot requested from game. Check 'exists' to confirm.",
	})


# =============================================================================
# ENHANCED GUT TESTING COMMANDS
# =============================================================================

## Run GUT tests and wait for results.
## [br][br]
## [param params]: Parameters dictionary
## - 'script' (String, optional): Specific test script to run
## - 'test' (String, optional): Specific test function to run
## - 'timeout' (float, optional): Maximum time to wait (default: 30.0)
## - 'include_output' (bool, optional): Include captured output (default: true)
func _cmd_gut_run_and_wait(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "EditorInterface not available")
	
	var script_path: String = params.get("script", "")
	var test_name: String = params.get("test", "")
	var timeout: float = params.get("timeout", 30.0)
	var include_output: bool = params.get("include_output", true)
	
	# Check if GUT is installed
	if not FileAccess.file_exists("res://addons/gut/plugin.cfg"):
		return _error(cmd_id, "GUT_NOT_FOUND", "GUT testing framework is not installed")
	
	# Mark debug log position
	var start_id: int = 0
	if debugger_plugin != null and debugger_plugin.has_method("mark_position"):
		start_id = debugger_plugin.mark_position()
	
	# Build GUT command line args
	var gut_script := "res://addons/gut/gut_cmdln.gd"
	var args: PackedStringArray = ["-d", "-s", gut_script]
	
	if not script_path.is_empty():
		args.append("-gtest=" + script_path)
	if not test_name.is_empty():
		args.append("-gunit_test_name=" + test_name)
	
	args.append("-gexit")
	args.append("-gdir=res://test/")
	
	# Play the GUT scene
	# Note: GUT has its own scene that runs tests
	var gut_scene := "res://addons/gut/GutScene.tscn"
	if FileAccess.file_exists(gut_scene.replace("res://", "")):
		editor_interface.open_scene_from_path(gut_scene)
		editor_interface.play_current_scene()
	else:
		# Try running via main scene with GUT autoload
		editor_interface.play_main_scene()
	
	# Wait for tests to complete (look for codot:test_complete or timeout)
	var elapsed: float = 0.0
	var poll_interval: float = 0.5
	var test_complete: bool = false
	
	while elapsed < timeout:
		await get_tree().create_timer(poll_interval).timeout
		elapsed += poll_interval
		
		# Check if game stopped (tests finished)
		if not editor_interface.is_playing_scene():
			test_complete = true
			break
		
		# Check for test_complete message
		if debugger_plugin != null and "_seen_message_types" in debugger_plugin:
			if debugger_plugin._seen_message_types.has("codot:test_complete"):
				test_complete = true
				break
	
	# Stop if still running
	if editor_interface.is_playing_scene():
		editor_interface.stop_playing_scene()
	
	await get_tree().create_timer(0.3).timeout
	
	# Gather results
	var result: Dictionary = {
		"completed": test_complete,
		"elapsed": elapsed,
		"timeout": not test_complete and elapsed >= timeout,
	}
	
	# Get captured output
	if include_output and debugger_plugin != null and debugger_plugin.has_method("get_entries"):
		var entries: Array = debugger_plugin.get_entries("all", start_id, 500)
		result["entries"] = entries
		
		# Parse for test results
		var passed: int = 0
		var failed: int = 0
		var errors: Array = []
		
		for entry in entries:
			var msg: String = entry.get("message", "")
			var etype: String = entry.get("type", "")
			
			if msg.contains("PASSED") or msg.contains("passed"):
				passed += 1
			if msg.contains("FAILED") or msg.contains("failed"):
				failed += 1
			if etype == "error" or etype == "script_error":
				errors.append(entry)
		
		result["passed_count"] = passed
		result["failed_count"] = failed
		result["errors"] = errors
		result["success"] = failed == 0 and errors.is_empty()
	
	return _success(cmd_id, result)


## Get a summary of the last GUT test run.
func _cmd_gut_get_summary(cmd_id: Variant) -> Dictionary:
	if debugger_plugin == null:
		return _error(cmd_id, "NO_DEBUGGER", "Debugger plugin not available")
	
	# Get recent entries and look for GUT output patterns
	var entries: Array = []
	if debugger_plugin.has_method("get_entries"):
		entries = debugger_plugin.get_entries("all", 0, 500)
	
	var summary: Dictionary = {
		"total_entries": entries.size(),
		"passed": 0,
		"failed": 0,
		"pending": 0,
		"errors": 0,
		"scripts_run": [],
		"failed_tests": [],
	}
	
	var current_script: String = ""
	
	for entry in entries:
		var msg: String = entry.get("message", "")
		var etype: String = entry.get("type", "")
		
		# Look for script being run
		if msg.contains("Running:") and msg.contains(".gd"):
			current_script = msg.get_slice("Running:", 1).strip_edges()
			if current_script not in summary["scripts_run"]:
				summary["scripts_run"].append(current_script)
		
		# Count results
		if msg.contains("[PASSED]") or msg.contains("PASSED"):
			summary["passed"] += 1
		if msg.contains("[FAILED]") or msg.contains("FAILED"):
			summary["failed"] += 1
			summary["failed_tests"].append({
				"script": current_script,
				"message": msg,
			})
		if msg.contains("[PENDING]") or msg.contains("PENDING"):
			summary["pending"] += 1
		if etype == "error":
			summary["errors"] += 1
	
	summary["success"] = summary["failed"] == 0 and summary["errors"] == 0
	
	return _success(cmd_id, summary)
