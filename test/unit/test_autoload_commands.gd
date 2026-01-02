extends GutTest
## Unit tests for Autoload commands.
##
## Tests the get_autoloads, add_autoload, remove_autoload,
## rename_autoload, and related commands.


var _handler: Node = null
var _test_autoload: String = "TestAutoloadGUT"
var _test_autoload_2: String = "TestAutoloadGUT2"
var _test_script_path: String = "res://test_temp_autoload.gd"


func before_each() -> void:
	# Create a fresh command handler for each test
	var handler_script: GDScript = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)
	
	# Create a test script for autoload testing
	_create_test_script()
	
	# Clean up test autoloads if they exist
	_cleanup_test_autoloads()


func after_each() -> void:
	_handler = null
	
	# Clean up test autoloads after tests
	_cleanup_test_autoloads()
	
	# Remove test script
	if FileAccess.file_exists(_test_script_path):
		var dir: DirAccess = DirAccess.open("res://")
		if dir != null:
			dir.remove(_test_script_path.get_file())


func _create_test_script() -> void:
	var content: String = """extends Node
## Test autoload script for GUT tests.

func _ready() -> void:
	pass
"""
	var file: FileAccess = FileAccess.open(_test_script_path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()


func _cleanup_test_autoloads() -> void:
	# Remove from ProjectSettings
	if ProjectSettings.has_setting("autoload/" + _test_autoload):
		ProjectSettings.set_setting("autoload/" + _test_autoload, null)
	if ProjectSettings.has_setting("autoload/" + _test_autoload_2):
		ProjectSettings.set_setting("autoload/" + _test_autoload_2, null)


# =============================================================================
# Get Autoloads Tests
# =============================================================================

func test_get_autoloads_basic() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "get_autoloads",
		"params": {}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "get_autoloads should succeed")
	assert_true(response["result"].has("autoloads"), "Should have autoloads key")
	assert_true(response["result"]["autoloads"] is Array, "Autoloads should be an array")


func test_get_autoloads_with_existing() -> void:
	# Add a test autoload
	ProjectSettings.set_setting("autoload/" + _test_autoload, "*" + _test_script_path)
	
	var command: Dictionary = {
		"id": 1,
		"command": "get_autoloads",
		"params": {}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "get_autoloads should succeed")
	
	# Check that our test autoload is in the list
	var found: bool = false
	for autoload: Dictionary in response["result"]["autoloads"]:
		if autoload["name"] == _test_autoload:
			found = true
			break
	
	assert_true(found, "Test autoload should be in the list")


# =============================================================================
# Get Autoload (Single) Tests
# =============================================================================

func test_get_autoload_exists() -> void:
	# Add a test autoload
	ProjectSettings.set_setting("autoload/" + _test_autoload, "*" + _test_script_path)
	
	var command: Dictionary = {
		"id": 1,
		"command": "get_autoload",
		"params": {"name": _test_autoload}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "get_autoload should succeed")
	assert_eq(response["result"]["name"], _test_autoload, "Should return correct name")
	assert_true(response["result"]["exists"], "Autoload should exist")
	assert_true(response["result"]["path"].ends_with(".gd"), "Should have script path")


func test_get_autoload_not_found() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "get_autoload",
		"params": {"name": "NonexistentAutoload12345"}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "get_autoload should fail for nonexistent autoload")
	assert_eq(response["error"]["code"], "AUTOLOAD_NOT_FOUND", "Should have correct error code")


func test_get_autoload_missing_param() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "get_autoload",
		"params": {}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "get_autoload should fail without name param")
	assert_eq(response["error"]["code"], "MISSING_PARAM", "Should have MISSING_PARAM error")


# =============================================================================
# Add Autoload Tests
# =============================================================================

func test_add_autoload_basic() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "add_autoload",
		"params": {"name": _test_autoload, "path": _test_script_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "add_autoload should succeed")
	assert_eq(response["result"]["name"], _test_autoload, "Should return autoload name")
	assert_true(response["result"]["added"], "Should indicate autoload was added")
	assert_true(ProjectSettings.has_setting("autoload/" + _test_autoload), "Autoload should exist in ProjectSettings")


func test_add_autoload_already_exists() -> void:
	# Add autoload first
	ProjectSettings.set_setting("autoload/" + _test_autoload, "*" + _test_script_path)
	
	var command: Dictionary = {
		"id": 1,
		"command": "add_autoload",
		"params": {"name": _test_autoload, "path": _test_script_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "add_autoload should fail if autoload exists")
	assert_eq(response["error"]["code"], "AUTOLOAD_EXISTS", "Should have correct error code")


func test_add_autoload_file_not_found() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "add_autoload",
		"params": {"name": _test_autoload, "path": "res://nonexistent_script.gd"}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "add_autoload should fail if file does not exist")
	assert_eq(response["error"]["code"], "FILE_NOT_FOUND", "Should have correct error code")


# =============================================================================
# Remove Autoload Tests
# =============================================================================

func test_remove_autoload_basic() -> void:
	# Add autoload first
	ProjectSettings.set_setting("autoload/" + _test_autoload, "*" + _test_script_path)
	
	var command: Dictionary = {
		"id": 1,
		"command": "remove_autoload",
		"params": {"name": _test_autoload}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "remove_autoload should succeed")
	assert_true(response["result"]["removed"], "Should indicate autoload was removed")
	assert_false(ProjectSettings.has_setting("autoload/" + _test_autoload), "Autoload should not exist in ProjectSettings")


func test_remove_autoload_not_found() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "remove_autoload",
		"params": {"name": "NonexistentAutoload12345"}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "remove_autoload should fail for nonexistent autoload")
	assert_eq(response["error"]["code"], "AUTOLOAD_NOT_FOUND", "Should have correct error code")


# =============================================================================
# Rename Autoload Tests
# =============================================================================

func test_rename_autoload_basic() -> void:
	# Add autoload first
	ProjectSettings.set_setting("autoload/" + _test_autoload, "*" + _test_script_path)
	
	var command: Dictionary = {
		"id": 1,
		"command": "rename_autoload",
		"params": {"old_name": _test_autoload, "new_name": _test_autoload_2}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "rename_autoload should succeed")
	assert_true(response["result"]["renamed"], "Should indicate autoload was renamed")
	assert_false(ProjectSettings.has_setting("autoload/" + _test_autoload), "Old autoload should not exist")
	assert_true(ProjectSettings.has_setting("autoload/" + _test_autoload_2), "New autoload should exist")


func test_rename_autoload_not_found() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "rename_autoload",
		"params": {"old_name": "NonexistentAutoload12345", "new_name": _test_autoload}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "rename_autoload should fail for nonexistent autoload")
	assert_eq(response["error"]["code"], "AUTOLOAD_NOT_FOUND", "Should have correct error code")


func test_rename_autoload_new_name_exists() -> void:
	# Add both autoloads
	ProjectSettings.set_setting("autoload/" + _test_autoload, "*" + _test_script_path)
	ProjectSettings.set_setting("autoload/" + _test_autoload_2, "*" + _test_script_path)
	
	var command: Dictionary = {
		"id": 1,
		"command": "rename_autoload",
		"params": {"old_name": _test_autoload, "new_name": _test_autoload_2}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "rename_autoload should fail if new name exists")
	assert_eq(response["error"]["code"], "AUTOLOAD_EXISTS", "Should have correct error code")


# =============================================================================
# Set Autoload Path Tests
# =============================================================================

func test_set_autoload_path_basic() -> void:
	# Add autoload first
	ProjectSettings.set_setting("autoload/" + _test_autoload, "*" + _test_script_path)
	
	# Create another test script
	var new_path: String = "res://test_temp_autoload_2.gd"
	var file: FileAccess = FileAccess.open(new_path, FileAccess.WRITE)
	if file != null:
		file.store_string("extends Node\n")
		file.close()
	
	var command: Dictionary = {
		"id": 1,
		"command": "set_autoload_path",
		"params": {"name": _test_autoload, "path": new_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "set_autoload_path should succeed")
	assert_true(response["result"]["updated"], "Should indicate path was updated")
	
	# Clean up
	var dir: DirAccess = DirAccess.open("res://")
	if dir != null:
		dir.remove(new_path.get_file())


func test_set_autoload_path_not_found() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "set_autoload_path",
		"params": {"name": "NonexistentAutoload12345", "path": _test_script_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "set_autoload_path should fail for nonexistent autoload")
	assert_eq(response["error"]["code"], "AUTOLOAD_NOT_FOUND", "Should have correct error code")


# =============================================================================
# Reorder Autoloads Tests
# =============================================================================

func test_reorder_autoloads_basic() -> void:
	# Add two autoloads
	ProjectSettings.set_setting("autoload/" + _test_autoload, "*" + _test_script_path)
	ProjectSettings.set_setting("autoload/" + _test_autoload_2, "*" + _test_script_path)
	
	var command: Dictionary = {
		"id": 1,
		"command": "reorder_autoloads",
		"params": {"order": [_test_autoload_2, _test_autoload]}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "reorder_autoloads should succeed")
	assert_true(response["result"]["reordered"], "Should indicate autoloads were reordered")
	assert_eq(response["result"]["new_order"].size(), 2, "Should have two autoloads in order")


func test_reorder_autoloads_invalid_name() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "reorder_autoloads",
		"params": {"order": ["NonexistentAutoload12345"]}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_false(response["success"], "reorder_autoloads should fail for nonexistent autoload")
	assert_eq(response["error"]["code"], "AUTOLOAD_NOT_FOUND", "Should have correct error code")
