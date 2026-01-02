extends GutTest
## Unit tests for InputMap commands.
##
## Tests the get_input_actions, add_input_action, remove_input_action,
## add_input_event_key, and related commands.


var _handler: Node = null
var _test_action: String = "test_action_gut"
var _test_action_2: String = "test_action_gut_2"


func before_each() -> void:
	# Create a fresh command handler for each test
	var handler_script: GDScript = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)
	
	# Clean up test actions if they exist
	_cleanup_test_actions()


func after_each() -> void:
	_handler = null
	
	# Clean up test actions after tests
	_cleanup_test_actions()


func _cleanup_test_actions() -> void:
	if InputMap.has_action(_test_action):
		InputMap.erase_action(_test_action)
	if InputMap.has_action(_test_action_2):
		InputMap.erase_action(_test_action_2)
	
	# Also remove from ProjectSettings if present
	if ProjectSettings.has_setting("input/" + _test_action):
		ProjectSettings.set_setting("input/" + _test_action, null)
	if ProjectSettings.has_setting("input/" + _test_action_2):
		ProjectSettings.set_setting("input/" + _test_action_2, null)


# =============================================================================
# Get Input Actions Tests
# =============================================================================

func test_get_input_actions_basic() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "get_input_actions",
		"params": {}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "get_input_actions should succeed")
	assert_true(response["result"].has("actions"), "Should have actions key")
	assert_true(response["result"]["actions"] is Array, "Actions should be an array")
	assert_gt(response["result"]["count"], 0, "Should have at least one action")


func test_get_input_actions_include_builtins() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "get_input_actions",
		"params": {"include_builtins": true}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "get_input_actions should succeed")
	
	# Check that builtin actions are included
	var action_names: Array = []
	for action: Dictionary in response["result"]["actions"]:
		action_names.append(action["name"])
	
	assert_true("ui_accept" in action_names, "Should include ui_accept builtin")


func test_get_input_actions_exclude_builtins() -> void:
	# Add a custom action first
	InputMap.add_action(_test_action)
	
	var command: Dictionary = {
		"id": 1,
		"command": "get_input_actions",
		"params": {"include_builtins": false}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "get_input_actions should succeed")
	
	# Check that builtin ui_ actions are excluded
	var action_names: Array = []
	for action: Dictionary in response["result"]["actions"]:
		action_names.append(action["name"])
	
	assert_false("ui_accept" in action_names, "Should not include ui_accept builtin")


# =============================================================================
# Get Input Action (Single) Tests
# =============================================================================

func test_get_input_action_exists() -> void:
	# Add a test action with a key event
	InputMap.add_action(_test_action)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = KEY_W
	InputMap.action_add_event(_test_action, key_event)
	
	var command: Dictionary = {
		"id": 1,
		"command": "get_input_action",
		"params": {"action": _test_action}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "get_input_action should succeed")
	assert_eq(response["result"]["action"], _test_action, "Should return correct action name")
	assert_true(response["result"]["exists"], "Action should exist")
	assert_true(response["result"]["events"] is Array, "Events should be an array")
	assert_eq(response["result"]["events"].size(), 1, "Should have one event")


func test_get_input_action_not_found() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "get_input_action",
		"params": {"action": "nonexistent_action_12345"}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "get_input_action should fail for nonexistent action")
	assert_eq(response["error"]["code"], "ACTION_NOT_FOUND", "Should have correct error code")


func test_get_input_action_missing_param() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "get_input_action",
		"params": {}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "get_input_action should fail without action param")
	assert_eq(response["error"]["code"], "MISSING_PARAM", "Should have MISSING_PARAM error")


# =============================================================================
# Add Input Action Tests
# =============================================================================

func test_add_input_action_basic() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "add_input_action",
		"params": {"action": _test_action}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "add_input_action should succeed")
	assert_eq(response["result"]["action"], _test_action, "Should return action name")
	assert_true(response["result"]["added"], "Should indicate action was added")
	assert_true(InputMap.has_action(_test_action), "Action should exist in InputMap")


func test_add_input_action_with_deadzone() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "add_input_action",
		"params": {"action": _test_action, "deadzone": 0.3}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "add_input_action should succeed")
	assert_almost_eq(response["result"]["deadzone"], 0.3, 0.001, "Deadzone should be set")


func test_add_input_action_already_exists() -> void:
	# Add action first
	InputMap.add_action(_test_action)
	
	var command: Dictionary = {
		"id": 1,
		"command": "add_input_action",
		"params": {"action": _test_action}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "add_input_action should fail if action exists")
	assert_eq(response["error"]["code"], "ACTION_EXISTS", "Should have correct error code")


# =============================================================================
# Remove Input Action Tests
# =============================================================================

func test_remove_input_action_basic() -> void:
	# Add action first
	InputMap.add_action(_test_action)
	
	var command: Dictionary = {
		"id": 1,
		"command": "remove_input_action",
		"params": {"action": _test_action}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "remove_input_action should succeed")
	assert_true(response["result"]["removed"], "Should indicate action was removed")
	assert_false(InputMap.has_action(_test_action), "Action should not exist in InputMap")


func test_remove_input_action_not_found() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "remove_input_action",
		"params": {"action": "nonexistent_action_12345"}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "remove_input_action should fail for nonexistent action")
	assert_eq(response["error"]["code"], "ACTION_NOT_FOUND", "Should have correct error code")


# =============================================================================
# Add Input Event Key Tests
# =============================================================================

func test_add_input_event_key_basic() -> void:
	# Add action first
	InputMap.add_action(_test_action)
	
	var command: Dictionary = {
		"id": 1,
		"command": "add_input_event_key",
		"params": {"action": _test_action, "key": "W"}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "add_input_event_key should succeed")
	assert_true(response["result"]["added"], "Should indicate event was added")
	assert_eq(response["result"]["key"], "W", "Should return key name")
	
	# Verify event was added
	var events: Array = InputMap.action_get_events(_test_action)
	assert_eq(events.size(), 1, "Should have one event")


func test_add_input_event_key_with_modifiers() -> void:
	# Add action first
	InputMap.add_action(_test_action)
	
	var command: Dictionary = {
		"id": 1,
		"command": "add_input_event_key",
		"params": {"action": _test_action, "key": "S", "shift": true, "ctrl": true}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "add_input_event_key should succeed")
	assert_true(response["result"]["modifiers"]["shift"], "Should have shift modifier")
	assert_true(response["result"]["modifiers"]["ctrl"], "Should have ctrl modifier")


func test_add_input_event_key_invalid_key() -> void:
	# Add action first
	InputMap.add_action(_test_action)
	
	var command: Dictionary = {
		"id": 1,
		"command": "add_input_event_key",
		"params": {"action": _test_action, "key": "INVALID_KEY_NAME"}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "add_input_event_key should fail for invalid key")
	assert_eq(response["error"]["code"], "INVALID_KEY", "Should have correct error code")


func test_add_input_event_key_action_not_found() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "add_input_event_key",
		"params": {"action": "nonexistent_action_12345", "key": "W"}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "add_input_event_key should fail for nonexistent action")
	assert_eq(response["error"]["code"], "ACTION_NOT_FOUND", "Should have correct error code")


# =============================================================================
# Add Input Event Mouse Tests
# =============================================================================

func test_add_input_event_mouse_basic() -> void:
	# Add action first
	InputMap.add_action(_test_action)
	
	var command: Dictionary = {
		"id": 1,
		"command": "add_input_event_mouse",
		"params": {"action": _test_action, "button": 1}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "add_input_event_mouse should succeed")
	assert_true(response["result"]["added"], "Should indicate event was added")
	assert_eq(response["result"]["button"], 1, "Should return button index")


# =============================================================================
# Add Input Event Joypad Button Tests
# =============================================================================

func test_add_input_event_joypad_button_basic() -> void:
	# Add action first
	InputMap.add_action(_test_action)
	
	var command: Dictionary = {
		"id": 1,
		"command": "add_input_event_joypad_button",
		"params": {"action": _test_action, "button": 0}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "add_input_event_joypad_button should succeed")
	assert_true(response["result"]["added"], "Should indicate event was added")


# =============================================================================
# Add Input Event Joypad Axis Tests
# =============================================================================

func test_add_input_event_joypad_axis_basic() -> void:
	# Add action first
	InputMap.add_action(_test_action)
	
	var command: Dictionary = {
		"id": 1,
		"command": "add_input_event_joypad_axis",
		"params": {"action": _test_action, "axis": 0, "axis_value": 1.0}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "add_input_event_joypad_axis should succeed")
	assert_true(response["result"]["added"], "Should indicate event was added")


# =============================================================================
# Clear Input Action Events Tests
# =============================================================================

func test_clear_input_action_events_basic() -> void:
	# Add action with events
	InputMap.add_action(_test_action)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = KEY_W
	InputMap.action_add_event(_test_action, key_event)
	
	var command: Dictionary = {
		"id": 1,
		"command": "clear_input_action_events",
		"params": {"action": _test_action}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "clear_input_action_events should succeed")
	assert_gt(response["result"]["events_cleared"], 0, "Should have cleared events")
	
	# Verify events were cleared
	var events: Array = InputMap.action_get_events(_test_action)
	assert_eq(events.size(), 0, "Should have no events")


func test_clear_input_action_events_not_found() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "clear_input_action_events",
		"params": {"action": "nonexistent_action_12345"}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "clear_input_action_events should fail for nonexistent action")
	assert_eq(response["error"]["code"], "ACTION_NOT_FOUND", "Should have correct error code")
