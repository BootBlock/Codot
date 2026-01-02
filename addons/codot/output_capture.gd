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
		"simulate_input":
			if data.size() > 0 and data[0] is Dictionary:
				_handle_simulate_input(data[0])
			return true
	return false


## Handle input simulation commands from the editor.
## This runs in the GAME process, so Input.parse_input_event() works correctly.
func _handle_simulate_input(params: Dictionary) -> void:
	var input_type: String = params.get("type", "")
	var event: InputEvent = null
	
	match input_type:
		"action":
			var action_event := InputEventAction.new()
			action_event.action = params.get("action", "")
			action_event.pressed = params.get("pressed", true)
			action_event.strength = params.get("strength", 1.0)
			event = action_event
		
		"key":
			var key_event := InputEventKey.new()
			key_event.keycode = params.get("keycode", 0) as Key
			key_event.pressed = params.get("pressed", true)
			key_event.echo = params.get("echo", false)
			key_event.ctrl_pressed = params.get("ctrl", false)
			key_event.shift_pressed = params.get("shift", false)
			key_event.alt_pressed = params.get("alt", false)
			key_event.meta_pressed = params.get("meta", false)
			event = key_event
		
		"mouse_button":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = params.get("button", 1) as MouseButton
			mouse_event.pressed = params.get("pressed", true)
			mouse_event.position = Vector2(params.get("x", 0), params.get("y", 0))
			mouse_event.global_position = mouse_event.position
			mouse_event.double_click = params.get("double_click", false)
			event = mouse_event
		
		"mouse_motion":
			var motion_event := InputEventMouseMotion.new()
			motion_event.position = Vector2(params.get("x", 0), params.get("y", 0))
			motion_event.global_position = motion_event.position
			motion_event.relative = Vector2(params.get("rel_x", 0), params.get("rel_y", 0))
			motion_event.velocity = Vector2(params.get("vel_x", 0), params.get("vel_y", 0))
			event = motion_event
		
		"joypad_button":
			var joy_event := InputEventJoypadButton.new()
			joy_event.button_index = params.get("button", 0) as JoyButton
			joy_event.pressed = params.get("pressed", true)
			joy_event.device = params.get("device", 0)
			event = joy_event
		
		"joypad_motion":
			var joy_motion := InputEventJoypadMotion.new()
			joy_motion.axis = params.get("axis", 0) as JoyAxis
			joy_motion.axis_value = params.get("value", 0.0)
			joy_motion.device = params.get("device", 0)
			event = joy_motion
	
	if event:
		Input.parse_input_event(event)
		_send_to_editor("input_result", {
			"success": true,
			"type": input_type,
		})
	else:
		_send_to_editor("input_result", {
			"success": false,
			"error": "Unknown input type: " + input_type,
		})


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
