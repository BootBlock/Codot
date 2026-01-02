## Input Simulation Module
## Handles keyboard, mouse, and action input simulation.
extends "command_base.gd"


## Simulate a keyboard key press or release.
## [br][br]
## [param params]:
## - 'key' (String, required): Key name (e.g., "A", "SPACE", "ESCAPE").
## - 'pressed' (bool, default true): Whether key is pressed or released.
## - 'echo' (bool, default false): Whether this is a key repeat.
## - 'shift', 'ctrl', 'alt', 'meta' (bool): Modifier key states.
func cmd_simulate_key(cmd_id: Variant, params: Dictionary) -> Dictionary:
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


## Simulate a mouse button press or release.
## [br][br]
## [param params]:
## - 'button' (int, default 1): Mouse button index (1=left, 2=right, 3=middle).
## - 'pressed' (bool, default true): Whether button is pressed or released.
## - 'x', 'y' (float): Position of the mouse cursor.
## - 'double_click' (bool, default false): Whether this is a double-click.
func cmd_simulate_mouse_button(cmd_id: Variant, params: Dictionary) -> Dictionary:
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


## Simulate mouse movement.
## [br][br]
## [param params]:
## - 'x', 'y' (float): Absolute position of the mouse cursor.
## - 'relative_x', 'relative_y' (float): Relative movement.
## - 'button_mask' (int): Which buttons are held during movement.
func cmd_simulate_mouse_motion(cmd_id: Variant, params: Dictionary) -> Dictionary:
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


## Simulate an input action.
## [br][br]
## [param params]:
## - 'action' (String, required): Action name from InputMap.
## - 'pressed' (bool, default true): Whether action is pressed or released.
## - 'strength' (float, default 1.0): Action strength (0.0 to 1.0).
func cmd_simulate_action(cmd_id: Variant, params: Dictionary) -> Dictionary:
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


# =============================================================================
# Key Name Mapping
# =============================================================================

## Map key names to Godot key constants.
func _key_name_to_code(key_name: String) -> int:
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
