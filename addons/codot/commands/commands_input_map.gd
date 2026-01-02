## InputMap Management Module
## Handles getting, adding, removing, and modifying input actions.
extends "command_base.gd"


# =============================================================================
# InputMap Read Operations
# =============================================================================

## Get all input actions defined in the project.
## [br][br]
## [param params]:
## - 'include_builtin' (bool, optional): Include built-in Godot actions (ui_*, etc.). Default: false.
func cmd_get_input_actions(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var include_builtin: bool = params.get("include_builtin", false)
	
	var actions: Array[Dictionary] = []
	var action_list: Array[StringName] = InputMap.get_actions()
	
	for action_name: StringName in action_list:
		var name_str: String = String(action_name)
		
		# Skip built-in actions unless explicitly requested
		if not include_builtin and name_str.begins_with("ui_"):
			continue
		
		var action_info: Dictionary = {
			"name": name_str,
			"deadzone": InputMap.action_get_deadzone(action_name),
			"events": _get_action_events(action_name),
		}
		actions.append(action_info)
	
	return _success(cmd_id, {
		"actions": actions,
		"count": actions.size(),
		"include_builtin": include_builtin,
	})


## Get detailed information about a specific input action.
## [br][br]
## [param params]:
## - 'action' (String, required): Name of the input action.
func cmd_get_input_action(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action", "")
	
	if action_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'action' parameter")
	
	if not InputMap.has_action(action_name):
		return _error(cmd_id, "ACTION_NOT_FOUND", "Input action not found: " + action_name)
	
	return _success(cmd_id, {
		"name": action_name,
		"deadzone": InputMap.action_get_deadzone(action_name),
		"events": _get_action_events(action_name),
		"exists": true,
	})


# =============================================================================
# InputMap Modify Operations (require ProjectSettings save)
# =============================================================================

## Add a new input action to the project.
## [br][br]
## [param params]:
## - 'action' (String, required): Name of the input action to add.
## - 'deadzone' (float, optional): Action deadzone. Default: 0.5.
func cmd_add_input_action(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action", "")
	var deadzone: float = params.get("deadzone", 0.5)
	
	if action_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'action' parameter")
	
	if InputMap.has_action(action_name):
		return _error(cmd_id, "ACTION_EXISTS", "Input action already exists: " + action_name)
	
	# Add to InputMap (runtime)
	InputMap.add_action(action_name, deadzone)
	
	# Persist to ProjectSettings
	var input_settings: Dictionary = {}
	if ProjectSettings.has_setting("input/" + action_name):
		input_settings = ProjectSettings.get_setting("input/" + action_name)
	else:
		input_settings = {
			"deadzone": deadzone,
			"events": [],
		}
	
	ProjectSettings.set_setting("input/" + action_name, input_settings)
	var save_err: int = ProjectSettings.save()
	
	return _success(cmd_id, {
		"action": action_name,
		"added": true,
		"deadzone": deadzone,
		"saved": save_err == OK,
	})


## Remove an input action from the project.
## [br][br]
## [param params]:
## - 'action' (String, required): Name of the input action to remove.
func cmd_remove_input_action(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action", "")
	
	if action_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'action' parameter")
	
	if not InputMap.has_action(action_name):
		return _error(cmd_id, "ACTION_NOT_FOUND", "Input action not found: " + action_name)
	
	# Prevent removing built-in actions
	if action_name.begins_with("ui_"):
		return _error(cmd_id, "BUILTIN_ACTION", "Cannot remove built-in action: " + action_name)
	
	# Remove from InputMap (runtime)
	InputMap.erase_action(action_name)
	
	# Remove from ProjectSettings
	if ProjectSettings.has_setting("input/" + action_name):
		ProjectSettings.set_setting("input/" + action_name, null)
	
	var save_err: int = ProjectSettings.save()
	
	return _success(cmd_id, {
		"action": action_name,
		"removed": true,
		"saved": save_err == OK,
	})


## Add a key event to an input action.
## [br][br]
## [param params]:
## - 'action' (String, required): Name of the input action.
## - 'key' (String, required): Key name (e.g., "W", "Space", "Escape").
## - 'ctrl' (bool, optional): Require Ctrl modifier. Default: false.
## - 'alt' (bool, optional): Require Alt modifier. Default: false.
## - 'shift' (bool, optional): Require Shift modifier. Default: false.
## - 'meta' (bool, optional): Require Meta/Cmd modifier. Default: false.
func cmd_add_input_event_key(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action", "")
	var key_name: String = params.get("key", "")
	var ctrl: bool = params.get("ctrl", false)
	var alt: bool = params.get("alt", false)
	var shift: bool = params.get("shift", false)
	var meta: bool = params.get("meta", false)
	
	if action_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'action' parameter")
	if key_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'key' parameter")
	
	if not InputMap.has_action(action_name):
		return _error(cmd_id, "ACTION_NOT_FOUND", "Input action not found: " + action_name)
	
	# Parse key name to keycode
	var keycode: Key = OS.find_keycode_from_string(key_name)
	if keycode == KEY_NONE:
		return _error(cmd_id, "INVALID_KEY", "Invalid key name: " + key_name + ". Use names like 'W', 'Space', 'Escape', etc.")
	
	# Create key event
	var event := InputEventKey.new()
	event.keycode = keycode
	event.ctrl_pressed = ctrl
	event.alt_pressed = alt
	event.shift_pressed = shift
	event.meta_pressed = meta
	
	# Add to InputMap (runtime)
	InputMap.action_add_event(action_name, event)
	
	# Persist to ProjectSettings
	_save_action_to_project_settings(action_name)
	
	return _success(cmd_id, {
		"action": action_name,
		"key": key_name,
		"added": true,
		"modifiers": {
			"ctrl": ctrl,
			"alt": alt,
			"shift": shift,
			"meta": meta,
		},
	})


## Add a mouse button event to an input action.
## [br][br]
## [param params]:
## - 'action' (String, required): Name of the input action.
## - 'button' (String, required): Button name ("left", "right", "middle", "wheel_up", "wheel_down").
func cmd_add_input_event_mouse(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action", "")
	var button_name: String = params.get("button", "").to_lower()
	
	if action_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'action' parameter")
	if button_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'button' parameter")
	
	if not InputMap.has_action(action_name):
		return _error(cmd_id, "ACTION_NOT_FOUND", "Input action not found: " + action_name)
	
	# Map button name to enum
	var button_index: MouseButton
	match button_name:
		"left":
			button_index = MOUSE_BUTTON_LEFT
		"right":
			button_index = MOUSE_BUTTON_RIGHT
		"middle":
			button_index = MOUSE_BUTTON_MIDDLE
		"wheel_up":
			button_index = MOUSE_BUTTON_WHEEL_UP
		"wheel_down":
			button_index = MOUSE_BUTTON_WHEEL_DOWN
		_:
			return _error(cmd_id, "INVALID_BUTTON", "Invalid button name: " + button_name + ". Use: left, right, middle, wheel_up, wheel_down")
	
	# Create mouse button event
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	
	# Add to InputMap (runtime)
	InputMap.action_add_event(action_name, event)
	
	# Persist to ProjectSettings
	_save_action_to_project_settings(action_name)
	
	return _success(cmd_id, {
		"action": action_name,
		"button": button_name,
		"added": true,
	})


## Add a joypad button event to an input action.
## [br][br]
## [param params]:
## - 'action' (String, required): Name of the input action.
## - 'button' (int, required): Joypad button index (0-15 for standard gamepads).
func cmd_add_input_event_joypad_button(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action", "")
	var button_index: int = params.get("button", -1)
	
	if action_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'action' parameter")
	if button_index < 0:
		return _error(cmd_id, "MISSING_PARAM", "Missing or invalid 'button' parameter")
	
	if not InputMap.has_action(action_name):
		return _error(cmd_id, "ACTION_NOT_FOUND", "Input action not found: " + action_name)
	
	# Create joypad button event
	var event := InputEventJoypadButton.new()
	event.button_index = button_index as JoyButton
	
	# Add to InputMap (runtime)
	InputMap.action_add_event(action_name, event)
	
	# Persist to ProjectSettings
	_save_action_to_project_settings(action_name)
	
	return _success(cmd_id, {
		"action": action_name,
		"button": button_index,
		"added": true,
	})


## Add a joypad axis event to an input action.
## [br][br]
## [param params]:
## - 'action' (String, required): Name of the input action.
## - 'axis' (int, required): Joypad axis index (0=left stick X, 1=left stick Y, 2=right stick X, 3=right stick Y, 4=left trigger, 5=right trigger).
## - 'axis_value' (float, required): Axis direction and threshold (-1.0 to 1.0).
func cmd_add_input_event_joypad_axis(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action", "")
	var axis_index: int = params.get("axis", -1)
	var axis_value: float = params.get("axis_value", 0.0)
	
	if action_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'action' parameter")
	if axis_index < 0:
		return _error(cmd_id, "MISSING_PARAM", "Missing or invalid 'axis' parameter")
	
	if not InputMap.has_action(action_name):
		return _error(cmd_id, "ACTION_NOT_FOUND", "Input action not found: " + action_name)
	
	# Create joypad axis event
	var event := InputEventJoypadMotion.new()
	event.axis = axis_index as JoyAxis
	event.axis_value = axis_value
	
	# Add to InputMap (runtime)
	InputMap.action_add_event(action_name, event)
	
	# Persist to ProjectSettings
	_save_action_to_project_settings(action_name)
	
	return _success(cmd_id, {
		"action": action_name,
		"axis": axis_index,
		"axis_value": axis_value,
		"added": true,
	})


## Clear all events from an input action.
## [br][br]
## [param params]:
## - 'action' (String, required): Name of the input action.
func cmd_clear_input_action_events(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action", "")
	
	if action_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'action' parameter")
	
	if not InputMap.has_action(action_name):
		return _error(cmd_id, "ACTION_NOT_FOUND", "Input action not found: " + action_name)
	
	# Get event count before clearing
	var event_count: int = InputMap.action_get_events(action_name).size()
	
	# Clear all events (runtime)
	InputMap.action_erase_events(action_name)
	
	# Persist to ProjectSettings
	_save_action_to_project_settings(action_name)
	
	return _success(cmd_id, {
		"action": action_name,
		"cleared": true,
		"events_removed": event_count,
	})


# =============================================================================
# Helper Functions
# =============================================================================

## Get all events for an action as a serialisable array.
func _get_action_events(action_name: StringName) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var action_events: Array[InputEvent] = InputMap.action_get_events(action_name)
	
	for event: InputEvent in action_events:
		var event_info: Dictionary = {"type": event.get_class()}
		
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			event_info["key"] = OS.get_keycode_string(key_event.keycode)
			event_info["physical_key"] = OS.get_keycode_string(key_event.physical_keycode)
			event_info["ctrl"] = key_event.ctrl_pressed
			event_info["alt"] = key_event.alt_pressed
			event_info["shift"] = key_event.shift_pressed
			event_info["meta"] = key_event.meta_pressed
		elif event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			event_info["button"] = _mouse_button_name(mouse_event.button_index)
			event_info["button_index"] = int(mouse_event.button_index)
		elif event is InputEventJoypadButton:
			var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
			event_info["button_index"] = int(joy_event.button_index)
		elif event is InputEventJoypadMotion:
			var joy_motion: InputEventJoypadMotion = event as InputEventJoypadMotion
			event_info["axis"] = int(joy_motion.axis)
			event_info["axis_value"] = joy_motion.axis_value
		
		events.append(event_info)
	
	return events


## Convert mouse button index to readable name.
func _mouse_button_name(button: MouseButton) -> String:
	match button:
		MOUSE_BUTTON_LEFT:
			return "left"
		MOUSE_BUTTON_RIGHT:
			return "right"
		MOUSE_BUTTON_MIDDLE:
			return "middle"
		MOUSE_BUTTON_WHEEL_UP:
			return "wheel_up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "wheel_down"
		_:
			return "button_" + str(int(button))


## Save an action's current state to ProjectSettings.
func _save_action_to_project_settings(action_name: String) -> int:
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	var deadzone: float = InputMap.action_get_deadzone(action_name)
	
	var input_setting: Dictionary = {
		"deadzone": deadzone,
		"events": events,
	}
	
	ProjectSettings.set_setting("input/" + action_name, input_setting)
	return ProjectSettings.save()
