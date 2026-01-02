@tool
class_name CodotInputSimulator
extends Node
## Simulates input events for the running game.
## Supports keyboard, mouse, touch, and action-based input.

var _pending_inputs: Array[InputEvent] = []
var _is_game_running: bool = false


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	# Process pending inputs when game is running
	_flush_pending_inputs()


func simulate_action(action_name: String, pressed: bool, strength: float = 1.0) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = strength
	
	_queue_input(event)


func simulate_key(key_code: int, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key_code as Key
	event.pressed = pressed
	event.echo = echo
	
	_queue_input(event)


func simulate_key_with_modifiers(key_code: int, pressed: bool, ctrl: bool = false, 
		shift: bool = false, alt: bool = false, meta: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key_code as Key
	event.pressed = pressed
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.alt_pressed = alt
	event.meta_pressed = meta
	
	_queue_input(event)


func simulate_mouse_motion(position: Vector2, relative: Vector2 = Vector2.ZERO, 
		velocity: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.velocity = velocity
	
	_queue_input(event)


func simulate_mouse_button(button_index: int, pressed: bool, position: Vector2 = Vector2.ZERO,
		double_click: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index as MouseButton
	event.pressed = pressed
	event.position = position
	event.global_position = position
	event.double_click = double_click
	
	_queue_input(event)


func simulate_click(position: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	# Press
	simulate_mouse_button(button, true, position)
	# Release (queued to happen after press)
	simulate_mouse_button(button, false, position)


func simulate_double_click(position: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	simulate_mouse_button(button, true, position, true)
	simulate_mouse_button(button, false, position)


func simulate_drag(from: Vector2, to: Vector2, button: int = MOUSE_BUTTON_LEFT, 
		steps: int = 10) -> void:
	# Press at start position
	simulate_mouse_button(button, true, from)
	
	# Move in steps
	var delta := (to - from) / float(steps)
	var current := from
	
	for i in range(steps):
		current += delta
		simulate_mouse_motion(current, delta)
	
	# Release at end position
	simulate_mouse_button(button, false, to)


func simulate_touch(position: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	event.index = index
	
	_queue_input(event)


func simulate_touch_drag(position: Vector2, relative: Vector2, velocity: Vector2 = Vector2.ZERO,
		index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = position
	event.relative = relative
	event.velocity = velocity
	event.index = index
	
	_queue_input(event)


func simulate_joypad_button(button_index: int, pressed: bool, device: int = 0) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index as JoyButton
	event.pressed = pressed
	event.device = device
	
	_queue_input(event)


func simulate_joypad_motion(axis: int, axis_value: float, device: int = 0) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis as JoyAxis
	event.axis_value = axis_value
	event.device = device
	
	_queue_input(event)


func simulate_action_sequence(sequence: Array) -> void:
	## Execute a sequence of input actions.
	## Each entry should be: {"action": "name", "pressed": true/false}
	## Note: delays are not supported in @tool mode
	
	for entry in sequence:
		var action_name: String = entry.get("action", "")
		if action_name.is_empty():
			continue
		
		var pressed: bool = entry.get("pressed", true)
		var strength: float = entry.get("strength", 1.0)
		
		if entry.get("release", false):
			pressed = false
		
		simulate_action(action_name, pressed, strength)


func clear_pending_inputs() -> void:
	_pending_inputs.clear()


func set_game_running(running: bool) -> void:
	_is_game_running = running
	set_process(running)


func _queue_input(event: InputEvent) -> void:
	_pending_inputs.append(event)
	
	# If processing is enabled, inputs will be flushed next frame
	# Otherwise, try to parse immediately
	if not is_processing():
		_flush_pending_inputs()


func _flush_pending_inputs() -> void:
	for event in _pending_inputs:
		Input.parse_input_event(event)
	_pending_inputs.clear()
