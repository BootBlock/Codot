extends GutTest
## Integration tests for the Codot plugin.
##
## These tests verify the complete flow from command receipt
## to response generation, testing real editor operations
## where possible.


var _handler: Node = null


func before_each() -> void:
	var handler_script = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)


func after_each() -> void:
	_handler = null


# =============================================================================
# File Operations Tests (without editor)
# =============================================================================

func test_file_exists_returns_correct_status() -> void:
	# Test with a file that definitely exists
	var command = {
		"id": 1,
		"command": "file_exists",
		"params": {"path": "res://project.godot"}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "file_exists should succeed")
	assert_true(response["result"]["exists"], "project.godot should exist")


func test_file_exists_nonexistent_file() -> void:
	var command = {
		"id": 1,
		"command": "file_exists",
		"params": {"path": "res://this_file_definitely_does_not_exist.xyz"}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "file_exists should succeed")
	assert_false(response["result"]["exists"], "Non-existent file should return false")


func test_read_file_success() -> void:
	# Read project.godot which should always exist
	var command = {
		"id": 1,
		"command": "read_file",
		"params": {"path": "res://project.godot"}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "read_file should succeed")
	assert_true(response["result"]["content"].length() > 0, 
		"project.godot should have content")


func test_read_file_nonexistent() -> void:
	var command = {
		"id": 1,
		"command": "read_file",
		"params": {"path": "res://nonexistent_file.txt"}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Reading non-existent file should fail")
	assert_eq(response["error"]["code"], "FILE_NOT_FOUND")


# =============================================================================
# Project Settings Tests
# =============================================================================

func test_get_project_settings_specific_key() -> void:
	var command = {
		"id": 1,
		"command": "get_project_settings",
		"params": {"key": "application/config/name"}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "get_project_settings should succeed")


# =============================================================================
# GUT Integration Tests (meta!)
# =============================================================================

func test_gut_check_installed() -> void:
	var command = {"id": 1, "command": "gut_check_installed", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "gut_check_installed should succeed")
	assert_true(response["result"].has("installed"), "Should indicate if GUT is installed")


func test_gut_list_tests_empty_directory() -> void:
	var command = {
		"id": 1,
		"command": "gut_list_tests",
		"params": {"dirs": ["res://nonexistent_test_dir/"]}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "gut_list_tests should succeed even with empty dir")
	assert_eq(response["result"]["count"], 0, "Should find 0 tests in non-existent dir")


# =============================================================================
# Resource Operations Tests
# =============================================================================

func test_load_resource_missing_path() -> void:
	var command = {
		"id": 1,
		"command": "load_resource",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "load_resource without path should fail")
	assert_eq(response["error"]["code"], "MISSING_PARAM")


func test_load_resource_nonexistent() -> void:
	var command = {
		"id": 1,
		"command": "load_resource",
		"params": {"path": "res://nonexistent_resource.tres"}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Loading non-existent resource should fail")
	assert_eq(response["error"]["code"], "RESOURCE_NOT_FOUND")


# =============================================================================
# Input Simulation Tests
# =============================================================================

func test_simulate_key_missing_param() -> void:
	var command = {
		"id": 1,
		"command": "simulate_key",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "simulate_key without key should fail")
	assert_eq(response["error"]["code"], "MISSING_PARAM")


func test_simulate_key_valid() -> void:
	var command = {
		"id": 1,
		"command": "simulate_key",
		"params": {"key": "W", "pressed": true}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "simulate_key with valid key should succeed")
	assert_true(response["result"]["simulated"], "Should confirm key was simulated")


func test_simulate_key_invalid() -> void:
	var command = {
		"id": 1,
		"command": "simulate_key",
		"params": {"key": "INVALID_KEY_NAME"}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "simulate_key with invalid key should fail")
	assert_eq(response["error"]["code"], "INVALID_KEY")


func test_simulate_action_missing_param() -> void:
	var command = {
		"id": 1,
		"command": "simulate_action",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "simulate_action without action should fail")


func test_simulate_action_invalid() -> void:
	var command = {
		"id": 1,
		"command": "simulate_action",
		"params": {"action": "nonexistent_action_12345"}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "simulate_action with invalid action should fail")
	assert_eq(response["error"]["code"], "INVALID_ACTION")


# =============================================================================
# Error Handling Edge Cases
# =============================================================================

func test_command_with_numeric_id() -> void:
	var command = {"id": 12345, "command": "ping", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_eq(response["id"], 12345, "Numeric ID should be preserved")


func test_command_with_string_id() -> void:
	var command = {"id": "uuid-abc-123", "command": "ping", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_eq(response["id"], "uuid-abc-123", "String ID should be preserved")


func test_command_with_empty_params() -> void:
	var command = {"id": 1, "command": "ping"}  # No params key at all
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "Command without params should use empty dict")
