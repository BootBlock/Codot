extends Node
## Runtime output capture - runs in the running game (NOT the editor).
##
## This autoload script captures runtime output (print, errors, warnings)
## and sends them back to the editor via Godot's EngineDebugger.
## The editor-side EditorDebuggerPlugin receives these messages.
##
## USAGE: Automatically added as autoload by the Codot plugin when the game runs.

## Entry counter
var _entry_id: int = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		# Don't run in editor
		queue_free()
		return
	
	# Register our custom message capture with the debugger
	if EngineDebugger.is_active():
		EngineDebugger.register_message_capture("codot", _on_editor_message)
		
		# Send initialization message
		_send_to_editor("ready", {
			"timestamp": Time.get_unix_time_from_system(),
		})
		print("[Codot] Output capture active - connected to editor debugger")
	else:
		print("[Codot] Debugger not active - output capture disabled")


func _on_editor_message(message: String, data: Array) -> bool:
	## Handle messages from the editor
	match message:
		"ping":
			_send_to_editor("pong", {"time": Time.get_unix_time_from_system()})
			return true
		"get_status":
			_send_to_editor("status", {
				"entry_id": _entry_id,
				"scene": get_tree().current_scene.name if get_tree().current_scene else "",
				"fps": Engine.get_frames_per_second(),
			})
			return true
		"screenshot":
			if data.size() > 0 and data[0] is Dictionary:
				_take_screenshot(data[0].get("path", "user://screenshot.png"))
			return true
	return false


## Take a screenshot of the current viewport and save it
func _take_screenshot(path: String) -> void:
	await get_tree().process_frame  # Wait for render
	
	var viewport := get_viewport()
	if viewport == null:
		_send_to_editor("screenshot_result", {"success": false, "error": "No viewport"})
		return
	
	var image := viewport.get_texture().get_image()
	if image == null:
		_send_to_editor("screenshot_result", {"success": false, "error": "Failed to get image"})
		return
	
	var error := image.save_png(path)
	if error != OK:
		_send_to_editor("screenshot_result", {"success": false, "error": "Save failed: " + str(error)})
		return
	
	_send_to_editor("screenshot_result", {"success": true, "path": path})


## Capture a print message and send to editor
func capture_print(message: String) -> void:
	_send_entry("print", message)


## Capture an error and send to editor
func capture_error(message: String, file: String = "", line: int = 0, function_name: String = "") -> void:
	_send_entry("error", message, file, line, function_name)


## Capture a warning and send to editor  
func capture_warning(message: String, file: String = "", line: int = 0, function_name: String = "") -> void:
	_send_entry("warning", message, file, line, function_name)


## Capture a script error (usually fatal)
func capture_script_error(message: String, file: String = "", line: int = 0, function_name: String = "", stack_trace: Array = []) -> void:
	_send_entry("script_error", message, file, line, function_name, stack_trace)


func _send_entry(type: String, message: String, file: String = "", line: int = 0, function_name: String = "", stack_trace: Array = []) -> void:
	_entry_id += 1
	var entry := {
		"id": _entry_id,
		"type": type,
		"message": message,
		"timestamp": Time.get_unix_time_from_system(),
	}
	if not file.is_empty():
		entry["file"] = file
	if line > 0:
		entry["line"] = line
	if not function_name.is_empty():
		entry["function"] = function_name
	if not stack_trace.is_empty():
		entry["stack_trace"] = stack_trace
	
	_send_to_editor("entry", entry)


func _send_to_editor(msg_type: String, data: Dictionary) -> void:
	## Send a message to the editor's debugger plugin
	if EngineDebugger.is_active():
		EngineDebugger.send_message("codot:" + msg_type, [data])
