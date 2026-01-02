## Debug Operations Module
## Handles performance monitoring, memory info, console output, and advanced debug/testing.
extends "command_base.gd"


# =============================================================================
# Performance & Memory
# =============================================================================

## Get performance metrics.
func cmd_get_performance_info(cmd_id: Variant, _params: Dictionary) -> Dictionary:
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
func cmd_get_memory_info(cmd_id: Variant, _params: Dictionary) -> Dictionary:
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
func cmd_print_to_console(cmd_id: Variant, params: Dictionary) -> Dictionary:
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


## Get recent errors from the Godot log file.
func cmd_get_recent_errors(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var log_entries: Array = []
	var errors: Array = []
	var warnings: Array = []
	
	var log_path: String = OS.get_user_data_dir() + "/logs/godot.log"
	
	if FileAccess.file_exists(log_path):
		var file = FileAccess.open(log_path, FileAccess.READ)
		if file != null:
			var content: String = file.get_as_text()
			file.close()
			
			var lines: PackedStringArray = content.split("\n")
			var start_idx: int = max(0, lines.size() - 100)
			
			for i in range(start_idx, lines.size()):
				var line: String = lines[i].strip_edges()
				if line.is_empty():
					continue
				
				var entry: Dictionary = {"line": line, "type": "info"}
				
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
		"recent_entries": log_entries.slice(-50),
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	})


# =============================================================================
# Advanced Testing & Debug
# =============================================================================

## Run a scene and capture output for a specified duration.
## [br][br]
## [param params]:
## - 'scene' (String, optional): Scene path to run. If not specified, runs current scene.
## - 'duration' (float, optional): How long to run in seconds (default: 2.0)
## - 'filter' (String, optional): Filter output by "all", "error", "warning" (default: "all")
## - 'stop_on_error' (bool, optional): Stop immediately if an error is detected (default: false)
func cmd_run_and_capture(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
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
	
	# Wait for the specified duration
	var elapsed: float = 0.0
	var check_interval: float = 0.25
	var stopped_early: bool = false
	var stop_reason: String = ""
	
	while elapsed < duration:
		await tree.create_timer(check_interval).timeout
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
	await tree.create_timer(0.2).timeout
	
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
## [param params]:
## - 'timeout' (float, optional): Maximum time to wait in seconds (default: 5.0)
## - 'wait_for' (String, optional): Wait for "error", "warning", "any", or a specific message substring
## - 'poll_interval' (float, optional): How often to check in seconds (default: 0.25)
func cmd_wait_for_output(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if debugger_plugin == null:
		return _error(cmd_id, "NO_DEBUGGER", "Debugger plugin not available")
	
	var timeout: float = params.get("timeout", 5.0)
	var wait_for: String = params.get("wait_for", "any")
	var poll_interval: float = params.get("poll_interval", 0.25)
	
	var start_id: int = debugger_plugin.mark_position() if debugger_plugin.has_method("mark_position") else 0
	
	var elapsed: float = 0.0
	var found: bool = false
	var matched_entry: Dictionary = {}
	
	while elapsed < timeout:
		await tree.create_timer(poll_interval).timeout
		elapsed += poll_interval
		
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
## [param params]:
## - 'timeout' (float, optional): Maximum time to wait for pong (default: 2.0)
func cmd_ping_game(cmd_id: Variant, params: Dictionary) -> Dictionary:
	if debugger_plugin == null:
		return _error(cmd_id, "NO_DEBUGGER", "Debugger plugin not available")
	
	if editor_interface == null or not editor_interface.is_playing_scene():
		return _error(cmd_id, "NOT_PLAYING", "No game is currently running")
	
	var timeout: float = params.get("timeout", 2.0)
	
	var sessions: Array = debugger_plugin.get_sessions()
	if sessions.is_empty():
		return _error(cmd_id, "NO_SESSION", "No debugger session available")
	
	var session = sessions[0]
	if not session.is_active():
		return _error(cmd_id, "SESSION_INACTIVE", "Debugger session is not active")
	
	var ping_time: float = Time.get_unix_time_from_system()
	session.send_message("codot:ping", [{"time": ping_time}])
	
	var start_time: float = Time.get_unix_time_from_system()
	var pong_count_before: int = debugger_plugin._seen_message_types.get("codot:pong", 0)
	
	while Time.get_unix_time_from_system() - start_time < timeout:
		await tree.create_timer(0.1).timeout
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
func cmd_get_game_state(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
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
## [param params]:
## - 'path' (String, optional): Where to save the screenshot (default: user://screenshot.png)
## - 'delay' (float, optional): Wait before taking screenshot (default: 0.0)
func cmd_take_screenshot(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	if not editor_interface.is_playing_scene():
		return _error(cmd_id, "NOT_PLAYING", "No game is currently running")
	
	var save_path: String = params.get("path", "user://screenshot.png")
	var delay: float = params.get("delay", 0.0)
	
	if delay > 0:
		await tree.create_timer(delay).timeout
	
	if debugger_plugin == null:
		return _error(cmd_id, "NO_DEBUGGER", "Debugger plugin not available")
	
	var sessions: Array = debugger_plugin.get_sessions()
	if sessions.is_empty() or not sessions[0].is_active():
		return _error(cmd_id, "NO_SESSION", "No active debugger session")
	
	sessions[0].send_message("codot:screenshot", [{"path": save_path}])
	
	await tree.create_timer(0.5).timeout
	
	var global_path: String = ProjectSettings.globalize_path(save_path)
	var exists: bool = FileAccess.file_exists(save_path)
	
	return _success(cmd_id, {
		"path": save_path,
		"global_path": global_path,
		"exists": exists,
		"note": "Screenshot requested from game. Check 'exists' to confirm.",
	})


# =============================================================================
# Enhanced GUT Testing
# =============================================================================

## Run GUT tests and wait for results.
## [br][br]
## [param params]:
## - 'script' (String, optional): Specific test script to run
## - 'test' (String, optional): Specific test function to run
## - 'timeout' (float, optional): Maximum time to wait (default: 30.0)
## - 'include_output' (bool, optional): Include captured output (default: true)
func cmd_gut_run_and_wait(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var script_path: String = params.get("script", "")
	var test_name: String = params.get("test", "")
	var timeout: float = params.get("timeout", 30.0)
	var include_output: bool = params.get("include_output", true)
	
	if not FileAccess.file_exists("res://addons/gut/plugin.cfg"):
		return _error(cmd_id, "GUT_NOT_FOUND", "GUT testing framework is not installed")
	
	var start_id: int = 0
	if debugger_plugin != null and debugger_plugin.has_method("mark_position"):
		start_id = debugger_plugin.mark_position()
	
	var gut_scene := "res://addons/gut/GutScene.tscn"
	if FileAccess.file_exists(gut_scene.replace("res://", "")):
		editor_interface.open_scene_from_path(gut_scene)
		editor_interface.play_current_scene()
	else:
		editor_interface.play_main_scene()
	
	var elapsed: float = 0.0
	var poll_interval: float = 0.5
	var test_complete: bool = false
	
	while elapsed < timeout:
		await tree.create_timer(poll_interval).timeout
		elapsed += poll_interval
		
		if not editor_interface.is_playing_scene():
			test_complete = true
			break
		
		if debugger_plugin != null and "_seen_message_types" in debugger_plugin:
			if debugger_plugin._seen_message_types.has("codot:test_complete"):
				test_complete = true
				break
	
	if editor_interface.is_playing_scene():
		editor_interface.stop_playing_scene()
	
	await tree.create_timer(0.3).timeout
	
	var data: Dictionary = {
		"completed": test_complete,
		"elapsed": elapsed,
		"timeout": not test_complete and elapsed >= timeout,
	}
	
	if include_output and debugger_plugin != null and debugger_plugin.has_method("get_entries"):
		var entries: Array = debugger_plugin.get_entries("all", start_id, 500)
		data["entries"] = entries
		
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
		
		data["passed_count"] = passed
		data["failed_count"] = failed
		data["errors"] = errors
		data["success"] = failed == 0 and errors.is_empty()
	
	return _success(cmd_id, data)


## Get a summary of the last GUT test run.
func cmd_gut_get_summary(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	if debugger_plugin == null:
		return _error(cmd_id, "NO_DEBUGGER", "Debugger plugin not available")
	
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
		
		if msg.contains("Running:") and msg.contains(".gd"):
			current_script = msg.get_slice("Running:", 1).strip_edges()
			if current_script not in summary["scripts_run"]:
				summary["scripts_run"].append(current_script)
		
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


# =============================================================================
# Profiler & Memory Analysis
# =============================================================================

## Get profiler data from Performance monitors.
## [br][br]
## [param params]:
## - 'category' (String, optional): Filter by category (time, memory, object, physics, rendering).
func cmd_get_profiler_data(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var category: String = params.get("category", "")
	
	var data: Dictionary = {
		"time": {
			"fps": Performance.get_monitor(Performance.TIME_FPS),
			"process": Performance.get_monitor(Performance.TIME_PROCESS),
			"physics_process": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
			"navigation_process": Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS),
		},
		"memory": {
			"static": Performance.get_monitor(Performance.MEMORY_STATIC),
			"static_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
			"message_buffer_max": Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX),
		},
		"objects": {
			"count": Performance.get_monitor(Performance.OBJECT_COUNT),
			"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		},
		"rendering": {
			"total_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"total_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"total_draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"video_memory_used": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		},
		"physics_2d": {
			"active_objects": Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
			"collision_pairs": Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS),
			"island_count": Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT),
		},
		"physics_3d": {
			"active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
			"collision_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
			"island_count": Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT),
		},
		"navigation": {
			"active_maps": Performance.get_monitor(Performance.NAVIGATION_ACTIVE_MAPS),
			"region_count": Performance.get_monitor(Performance.NAVIGATION_REGION_COUNT),
			"agent_count": Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT),
			"link_count": Performance.get_monitor(Performance.NAVIGATION_LINK_COUNT),
			"polygon_count": Performance.get_monitor(Performance.NAVIGATION_POLYGON_COUNT),
			"edge_count": Performance.get_monitor(Performance.NAVIGATION_EDGE_COUNT),
			"edge_merge_count": Performance.get_monitor(Performance.NAVIGATION_EDGE_MERGE_COUNT),
			"edge_connection_count": Performance.get_monitor(Performance.NAVIGATION_EDGE_CONNECTION_COUNT),
			"edge_free_count": Performance.get_monitor(Performance.NAVIGATION_EDGE_FREE_COUNT),
		},
	}
	
	# Filter by category if specified
	if not category.is_empty() and data.has(category):
		return _success(cmd_id, {
			"category": category,
			"data": data[category]
		})
	
	return _success(cmd_id, data)


## Get orphan nodes (nodes without an owner, potential memory leak).
## [br][br]
## Returns the count and attempts to identify orphan nodes.
func cmd_get_orphan_nodes(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var orphan_count: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var total_nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	return _success(cmd_id, {
		"orphan_count": orphan_count,
		"total_nodes": total_nodes,
		"percentage": (float(orphan_count) / float(max(total_nodes, 1))) * 100.0,
		"note": "Orphan nodes are nodes without an owner. They may indicate memory leaks.",
		"recommendation": "Call node.queue_free() to properly clean up nodes."
	})


## Get detailed object statistics.
func cmd_get_object_stats(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var stats: Dictionary = {
		"total_objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
	}
	
	# Calculate derived stats
	var non_node_objects: int = stats["total_objects"] - stats["nodes"] - stats["resources"]
	stats["other_objects"] = max(0, non_node_objects)
	
	# Memory efficiency estimate
	var static_memory: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	if stats["total_objects"] > 0:
		stats["avg_bytes_per_object"] = static_memory / stats["total_objects"]
	else:
		stats["avg_bytes_per_object"] = 0
	
	return _success(cmd_id, stats)


## Print a stack trace for debugging.
func cmd_get_stack_info(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var stack: Array = get_stack()
	var stack_info: Array = []
	
	for frame in stack:
		stack_info.append({
			"function": frame.get("function", "unknown"),
			"source": frame.get("source", "unknown"),
			"line": frame.get("line", 0)
		})
	
	return _success(cmd_id, {
		"stack": stack_info,
		"depth": stack_info.size()
	})
