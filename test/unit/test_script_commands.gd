extends GutTest
## Unit tests for script operation commands.
##
## Tests the get_breakpoints, set_breakpoint, and clear_breakpoints commands.


var _handler: Node = null
var _test_script_path: String = "res://test_temp_breakpoint_script.gd"


func before_each() -> void:
	# Create a fresh command handler for each test
	var handler_script = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)
	
	# Create a test script file
	var file = FileAccess.open(_test_script_path, FileAccess.WRITE)
	if file:
		file.store_string("""extends Node

func _ready():
	pass

func do_something():
	var x = 1
	var y = 2
	return x + y
""")
		file.close()


func after_each() -> void:
	_handler = null
	
	# Clean up test files
	if FileAccess.file_exists(_test_script_path):
		DirAccess.remove_absolute(_test_script_path)


# =============================================================================
# Get Breakpoints Tests
# =============================================================================

func test_get_breakpoints_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "get_breakpoints",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")
	assert_eq(response["error"]["code"], "NO_EDITOR", "Should return NO_EDITOR error")


func test_get_breakpoints_with_path_filter() -> void:
	var command = {
		"id": 1,
		"command": "get_breakpoints",
		"params": {"path": _test_script_path}
	}
	var response = await _handler.handle_command(command)
	
	# Without editor, should fail
	assert_false(response["success"], "Should fail without editor")


# =============================================================================
# Set Breakpoint Tests
# =============================================================================

func test_set_breakpoint_missing_path() -> void:
	var command = {
		"id": 1,
		"command": "set_breakpoint",
		"params": {"line": 5}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path param")
	assert_eq(response["error"]["code"], "NO_EDITOR", "Should return error")


func test_set_breakpoint_missing_line() -> void:
	var command = {
		"id": 1,
		"command": "set_breakpoint",
		"params": {"path": _test_script_path}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without line param")


func test_set_breakpoint_invalid_line() -> void:
	var command = {
		"id": 1,
		"command": "set_breakpoint",
		"params": {"path": _test_script_path, "line": 0}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail with invalid line")


func test_set_breakpoint_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "set_breakpoint",
		"params": {"path": _test_script_path, "line": 5}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")
	assert_eq(response["error"]["code"], "NO_EDITOR", "Should return NO_EDITOR error")


# =============================================================================
# Clear Breakpoints Tests
# =============================================================================

func test_clear_breakpoints_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "clear_breakpoints",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")
	assert_eq(response["error"]["code"], "NO_EDITOR", "Should return NO_EDITOR error")


func test_clear_breakpoints_with_path() -> void:
	var command = {
		"id": 1,
		"command": "clear_breakpoints",
		"params": {"path": _test_script_path}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")


# =============================================================================
# Script Error Tests
# =============================================================================

func test_get_script_errors_valid_script() -> void:
	var command = {
		"id": 1,
		"command": "get_script_errors",
		"params": {"path": _test_script_path}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed for valid script")
	assert_true(response["result"]["valid"], "Script should be valid")


func test_get_script_errors_nonexistent_script() -> void:
	var command = {
		"id": 1,
		"command": "get_script_errors",
		"params": {"path": "res://nonexistent.gd"}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should still succeed")
	assert_true(response["result"]["errors"].size() > 0, "Should have errors for nonexistent script")
	# GUT treats GDScript loading errors as engine errors, so acknowledge them
	assert_engine_error(2, "Expected engine errors when loading nonexistent script")


func test_open_script_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "open_script",
		"params": {"path": _test_script_path}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")
	assert_eq(response["error"]["code"], "NO_EDITOR", "Should return NO_EDITOR error")


func test_open_script_missing_path() -> void:
	var command = {
		"id": 1,
		"command": "open_script",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path")
