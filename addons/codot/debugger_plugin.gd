@tool
extends EditorDebuggerPlugin
## Codot Debugger Plugin - Captures debug output from running games.
##
## This plugin hooks into Godot's debugger to capture real-time output
## including print statements, errors, warnings, and script errors.
## Data is stored in a circular buffer for retrieval by AI agents.
##
## @tutorial: https://docs.godotengine.org/en/stable/classes/class_editordebuggerplugin.html

## Maximum number of entries to keep in memory
const MAX_ENTRIES: int = 1000

## Enable verbose logging to help debug the debugger
const VERBOSE: bool = true

## Signal emitted when a new debug entry is captured
signal entry_captured(entry: Dictionary)

## Signal emitted when an error is captured (for immediate notification)
signal error_captured(entry: Dictionary)

## Circular buffer of captured debug entries
var _entries: Array[Dictionary] = []

## Counter for assigning unique IDs to entries
var _entry_id: int = 0

## Line number marker for "clear" functionality
var _skip_before_id: int = 0

## Session tracking
var _active_sessions: Array[int] = []

## List of all message types we've seen (for debugging)
var _seen_message_types: Dictionary = {}

## Track if we've received any messages from the game-side capture
var _game_capture_active: bool = false


func _has_capture(capture: String) -> bool:
	# Capture our custom "codot" prefix for game-side messages
	# AND capture standard debugger messages
	if VERBOSE:
		print("[Codot Debug] _has_capture called for: ", capture)
	if capture == "codot":
		return true
	# Also try to capture everything else to see what's available
	return true


func _capture(message: String, data: Array, session_id: int) -> bool:
	# Track all message types for debugging
	if not _seen_message_types.has(message):
		_seen_message_types[message] = 0
		if VERBOSE:
			print("[Codot Debug] New message type seen: ", message)
	_seen_message_types[message] += 1
	
	# Handle our custom game-side capture messages (prefixed with "codot:")
	if message.begins_with("codot:"):
		var msg_type := message.substr(6)  # Remove "codot:" prefix
		_handle_game_message(msg_type, data, session_id)
		return true
	
	match message:
		"output":
			_handle_output(data, session_id)
			return true
		"error":
			_handle_error(data, session_id)
			return true
		"debug_enter":
			_handle_debug_enter(data, session_id)
			return true
		"stack_dump":
			_handle_stack_dump(data, session_id)
			return true
		_:
			if VERBOSE:
				print("[Codot Debug] Unhandled message: ", message, " data: ", data)
	return false


func _handle_game_message(msg_type: String, data: Array, session_id: int) -> void:
	## Handle messages from the game-side CodotOutputCapture autoload
	if data.size() < 1:
		return
	
	var payload: Dictionary = data[0] if data[0] is Dictionary else {}
	
	match msg_type:
		"ready":
			_game_capture_active = true
			if VERBOSE:
				print("[Codot Debug] Game capture connected!")
			_add_entry({
				"type": "info",
				"message": "Game output capture initialized",
				"session_id": session_id,
				"source": "game",
			})
		
		"entry":
			# This is a captured log entry from the game
			var entry := {
				"type": payload.get("type", "info"),
				"message": payload.get("message", ""),
				"session_id": session_id,
				"source": "game",
			}
			if payload.has("file"):
				entry["file"] = payload["file"]
			if payload.has("line"):
				entry["line"] = payload["line"]
			if payload.has("function"):
				entry["function"] = payload["function"]
			if payload.has("stack_trace"):
				entry["stack_trace"] = payload["stack_trace"]
			
			if entry["type"] == "error" or entry["type"] == "script_error":
				error_captured.emit(entry)
			
			_add_entry(entry)
		
		"pong":
			if VERBOSE:
				print("[Codot Debug] Pong from game at ", payload.get("time", 0))
		
		"status":
			if VERBOSE:
				print("[Codot Debug] Game status: ", payload)
		
		"test_complete":
			if VERBOSE:
				print("[Codot Debug] Test complete: ", payload)
			_add_entry({
				"type": "info",
				"message": "Test completed: mode=" + str(payload.get("mode", "?")) + " tests=" + str(payload.get("tests_run", 0)),
				"session_id": session_id,
				"source": "game",
				"payload": payload,
			})
		
		"test_starting":
			if VERBOSE:
				print("[Codot Debug] Test starting: ", payload)
			_add_entry({
				"type": "info",
				"message": "Test starting: " + str(payload.get("mode", "?")),
				"session_id": session_id,
				"source": "game",
				"payload": payload,
			})
		
		_:
			# Unknown message from game - still log it
			if VERBOSE:
				print("[Codot Debug] Unknown game message: ", msg_type, " payload: ", payload)
			_add_entry({
				"type": "debug",
				"message": "Game message: " + msg_type,
				"session_id": session_id,
				"source": "game",
				"payload": payload,
			})


func _setup_session(session_id: int) -> void:
	_active_sessions.append(session_id)
	if VERBOSE:
		print("[Codot Debug] Session started: ", session_id)
	_add_entry({
		"type": "session_start",
		"message": "Debug session started",
		"session_id": session_id,
	})


func _breaked(session_id: int, can_debug: bool, reason: String, has_stackdump: bool) -> void:
	if VERBOSE:
		print("[Codot Debug] Breaked - reason: ", reason, " can_debug: ", can_debug)
	_add_entry({
		"type": "breakpoint",
		"message": "Execution paused: " + reason,
		"session_id": session_id,
		"can_debug": can_debug,
		"has_stackdump": has_stackdump,
	})


func _stopped(session_id: int) -> void:
	_active_sessions.erase(session_id)
	if VERBOSE:
		print("[Codot Debug] Session stopped: ", session_id)
		print("[Codot Debug] Message types seen: ", _seen_message_types)
	_add_entry({
		"type": "session_stop", 
		"message": "Debug session ended",
		"session_id": session_id,
	})


func _handle_output(data: Array, session_id: int) -> void:
	# Output data format: [message: String, type: int]
	# Type: 0 = normal/print, 1 = error, 2 = script error, 3 = warning
	if data.size() < 2:
		if VERBOSE:
			print("[Codot Debug] Output with insufficient data: ", data)
		return
	
	var message: String = str(data[0])
	var msg_type: int = int(data[1])
	
	if VERBOSE:
		print("[Codot Debug] Output - type: ", msg_type, " msg: ", message.substr(0, 50))
	
	var type_name: String = "print"
	match msg_type:
		0:
			type_name = "print"
		1:
			type_name = "error"
		2:
			type_name = "error"  # Script errors also come as type 2
		3:
			type_name = "warning"
		_:
			type_name = "info"
	
	var entry := {
		"type": type_name,
		"message": message.strip_edges(),
		"session_id": session_id,
		"raw_type": msg_type,
	}
	
	# Try to parse error details from the message
	if type_name == "error":
		var parsed := _parse_error_message(message)
		entry.merge(parsed)
		error_captured.emit(entry)
	
	_add_entry(entry)


func _handle_error(data: Array, session_id: int) -> void:
	# Error message format in Godot 4: 
	# [callstack: Array, error: String, error_descr: String, warning: bool]
	if VERBOSE:
		print("[Codot Debug] Error message received: ", data)
	
	if data.size() >= 4:
		var callstack: Array = data[0] if data[0] is Array else []
		var error_type: String = str(data[1])
		var error_desc: String = str(data[2])
		var is_warning: bool = bool(data[3]) if data.size() > 3 else false
		
		var full_message := error_type + ": " + error_desc
		
		var entry := {
			"type": "warning" if is_warning else "error",
			"message": full_message,
			"error_type": error_type,
			"error_description": error_desc,
			"session_id": session_id,
			"callstack": callstack,
		}
		
		# Parse file/line from callstack if available
		if callstack.size() > 0 and callstack[0] is Dictionary:
			var frame = callstack[0]
			if frame.has("file"):
				entry["file"] = frame["file"]
			if frame.has("line"):
				entry["line"] = frame["line"]
			if frame.has("function"):
				entry["function"] = frame["function"]
		
		if not is_warning:
			error_captured.emit(entry)
		
		_add_entry(entry)


func _handle_debug_enter(data: Array, session_id: int) -> void:
	# Called when debugger breaks (error or breakpoint)
	if VERBOSE:
		print("[Codot Debug] Debug enter: ", data)
	
	var reason: String = ""
	var can_continue: bool = true
	
	if data.size() >= 1:
		can_continue = bool(data[0])
	if data.size() >= 2:
		reason = str(data[1])
	
	_add_entry({
		"type": "break",
		"message": "Debugger entered: " + reason,
		"reason": reason,
		"can_continue": can_continue,
		"session_id": session_id,
	})


func _handle_stack_dump(data: Array, session_id: int) -> void:
	# Stack dump from debugger - extract error location
	if VERBOSE:
		print("[Codot Debug] Stack dump received, frames: ", data.size())
	
	if data.size() > 0:
		var frames: Array = []
		for frame_data in data:
			if frame_data is Dictionary:
				frames.append(frame_data)
		
		if frames.size() > 0:
			var top_frame = frames[0]
			_add_entry({
				"type": "stack_trace",
				"message": "Stack trace at " + str(top_frame.get("file", "?")) + ":" + str(top_frame.get("line", "?")),
				"frames": frames,
				"top_file": top_frame.get("file", ""),
				"top_line": top_frame.get("line", 0),
				"top_function": top_frame.get("function", ""),
				"session_id": session_id,
			})


func _parse_error_message(message: String) -> Dictionary:
	var result: Dictionary = {}
	
	# Common error format: "res://path/file.gd:123 - Error message"
	var regex := RegEx.new()
	regex.compile("(res://[^:]+):(\\d+)")
	var match := regex.search(message)
	
	if match:
		result["file"] = match.get_string(1)
		result["line"] = int(match.get_string(2))
	
	# Check for common error patterns
	if message.contains("Invalid call") or message.contains("Nonexistent function"):
		result["error_type"] = "method_error"
	elif message.contains("Invalid operands") or message.contains("Cannot convert"):
		result["error_type"] = "type_error"
	elif message.contains("Identifier not found") or message.contains("not declared"):
		result["error_type"] = "reference_error"
	elif message.contains("Parse Error") or message.contains("Unexpected"):
		result["error_type"] = "syntax_error"
	
	return result


func _add_entry(entry: Dictionary) -> void:
	_entry_id += 1
	entry["id"] = _entry_id
	entry["timestamp"] = Time.get_unix_time_from_system()
	
	_entries.append(entry)
	
	# Trim old entries if we exceed the limit
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	
	entry_captured.emit(entry)


## Get all captured entries, optionally filtered.
## [br][br]
## [param filter]: "all", "error", "warning", or "info"
## [param since_id]: Only return entries with ID greater than this
## [param max_count]: Maximum entries to return
func get_entries(filter: String = "all", since_id: int = 0, max_count: int = 100) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var actual_since := max(since_id, _skip_before_id)
	
	for entry in _entries:
		if entry.id <= actual_since:
			continue
		
		if filter != "all":
			if filter == "error" and entry.type != "error":
				continue
			if filter == "warning" and entry.type != "warning":
				continue
			if filter == "info" and entry.type != "info":
				continue
		
		result.append(entry)
		
		if result.size() >= max_count:
			break
	
	return result


## Get summary of captured entries.
func get_summary() -> Dictionary:
	var error_count := 0
	var warning_count := 0
	var info_count := 0
	
	for entry in _entries:
		if entry.id <= _skip_before_id:
			continue
		match entry.type:
			"error":
				error_count += 1
			"warning":
				warning_count += 1
			"info":
				info_count += 1
	
	return {
		"total_entries": _entries.size(),
		"error_count": error_count,
		"warning_count": warning_count,
		"info_count": info_count,
		"last_id": _entry_id,
		"skip_before_id": _skip_before_id,
		"active_sessions": _active_sessions.size(),
	}


## Mark current position - entries before this will be skipped in queries.
func mark_position() -> int:
	_skip_before_id = _entry_id
	return _skip_before_id


## Clear the skip marker to see all entries again.
func reset_position() -> void:
	_skip_before_id = 0


## Get only errors since the last mark.
func get_errors_since_mark() -> Array[Dictionary]:
	return get_entries("error", _skip_before_id, 100)


## Get only warnings since the last mark.
func get_warnings_since_mark() -> Array[Dictionary]:
	return get_entries("warning", _skip_before_id, 100)


## Check if there are any new errors since the mark.
func has_new_errors() -> bool:
	for entry in _entries:
		if entry.id > _skip_before_id and entry.type == "error":
			return true
	return false


## Get diagnostics about the debugger plugin itself.
## Useful for troubleshooting why messages aren't being captured.
func get_diagnostics() -> Dictionary:
	return {
		"active_sessions": _active_sessions.duplicate(),
		"session_count": _active_sessions.size(),
		"message_types_seen": _seen_message_types.duplicate(),
		"game_capture_active": _game_capture_active,
		"total_entries": _entries.size(),
		"entry_id": _entry_id,
		"skip_before_id": _skip_before_id,
		"max_entries": MAX_ENTRIES,
		"verbose": VERBOSE,
	}


## Send an input simulation command to the running game.
## This uses the debugger protocol to cross the process boundary.
## [br][br]
## [param input_params]: Dictionary with input event parameters
## Returns: true if message was sent (game may or may not be running)
func send_input_to_game(input_params: Dictionary) -> bool:
	if _active_sessions.is_empty():
		if VERBOSE:
			print("[Codot Debug] No active sessions - cannot send input to game")
		return false
	
	# Send to all active debug sessions (usually just one)
	for session_id in _active_sessions:
		var session := get_session(session_id)
		if session:
			session.send_message("codot:simulate_input", [input_params])
			if VERBOSE:
				print("[Codot Debug] Sent input to game session ", session_id, ": ", input_params)
	
	return true


## Send a ping to the game to check if the output capture is active.
## [br][br]
## Returns: true if message was sent
func ping_game() -> bool:
	if _active_sessions.is_empty():
		return false
	
	for session_id in _active_sessions:
		var session := get_session(session_id)
		if session:
			session.send_message("codot:ping", [{}])
	
	return true


## Send a screenshot request to the game.
## [br][br]
## [param path]: Path to save the screenshot
## Returns: true if message was sent
func request_screenshot(path: String) -> bool:
	if _active_sessions.is_empty():
		return false
	
	for session_id in _active_sessions:
		var session := get_session(session_id)
		if session:
			session.send_message("codot:screenshot", [{"path": path}])
	
	return true
