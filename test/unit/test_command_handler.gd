extends GutTest
## Unit tests for the Codot command handler.
##
## These tests verify that the command handler correctly processes
## various commands and returns appropriate responses.


var _handler: Node = null


func before_each() -> void:
	# Create a fresh command handler for each test
	var handler_script = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)


func after_each() -> void:
	_handler = null


# =============================================================================
# Response Format Tests
# =============================================================================

func test_success_response_format() -> void:
	# Test that successful responses have correct format
	var command = {"id": "test-123", "command": "ping", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_true(response.has("id"), "Response should have 'id' field")
	assert_true(response.has("success"), "Response should have 'success' field")
	assert_eq(response["id"], "test-123", "Response ID should match command ID")
	assert_true(response["success"], "Ping should succeed")
	assert_true(response.has("result"), "Successful response should have 'result' field")


func test_error_response_format() -> void:
	# Test that error responses have correct format
	var command = {"id": "test-456", "command": "nonexistent_command", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_true(response.has("id"), "Response should have 'id' field")
	assert_true(response.has("success"), "Response should have 'success' field")
	assert_false(response["success"], "Unknown command should fail")
	assert_true(response.has("error"), "Failed response should have 'error' field")
	assert_true(response["error"].has("code"), "Error should have 'code' field")
	assert_true(response["error"].has("message"), "Error should have 'message' field")


func test_missing_command_error() -> void:
	# Test handling of missing command name
	var command = {"id": "test-789", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Missing command should fail")
	assert_eq(response["error"]["code"], "MISSING_COMMAND")


# =============================================================================
# Ping Command Tests
# =============================================================================

func test_ping_returns_pong() -> void:
	var command = {"id": 1, "command": "ping", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "Ping should succeed")
	assert_true(response["result"]["pong"], "Ping should return pong: true")
	assert_true(response["result"].has("timestamp"), "Ping should include timestamp")


func test_ping_timestamp_is_reasonable() -> void:
	var before = Time.get_unix_time_from_system()
	var command = {"id": 1, "command": "ping", "params": {}}
	var response = _handler.handle_command(command)
	var after = Time.get_unix_time_from_system()
	
	var timestamp = response["result"]["timestamp"]
	assert_true(timestamp >= before and timestamp <= after,
		"Timestamp should be between test start and end")


# =============================================================================
# Status Command Tests
# =============================================================================

func test_get_status_returns_version_info() -> void:
	var command = {"id": 1, "command": "get_status", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "get_status should succeed")
	assert_true(response["result"].has("godot_version"), "Should include Godot version")
	assert_true(response["result"].has("plugin_version"), "Should include plugin version")
	assert_true(response["result"].has("is_playing"), "Should include playing state")


func test_get_status_plugin_version() -> void:
	var command = {"id": 1, "command": "get_status", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_eq(response["result"]["plugin_version"], "0.1.0",
		"Plugin version should be 0.1.0")


# =============================================================================
# Performance Commands Tests
# =============================================================================

func test_get_performance_info() -> void:
	var command = {"id": 1, "command": "get_performance_info", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "get_performance_info should succeed")
	assert_true(response["result"].has("fps"), "Should include FPS")
	assert_true(response["result"].has("object_count"), "Should include object count")
	assert_true(response["result"].has("memory_static"), "Should include memory info")


func test_get_memory_info() -> void:
	var command = {"id": 1, "command": "get_memory_info", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "get_memory_info should succeed")
	assert_true(response["result"].has("static_memory"), "Should include static memory")
	assert_true(response["result"].has("node_count"), "Should include node count")


# =============================================================================
# Console Commands Tests
# =============================================================================

func test_print_to_console_info() -> void:
	var command = {
		"id": 1,
		"command": "print_to_console",
		"params": {"message": "Test message", "level": "info"}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "print_to_console should succeed")
	assert_true(response["result"]["printed"], "Should confirm message was printed")


func test_print_to_console_warning() -> void:
	var command = {
		"id": 1,
		"command": "print_to_console",
		"params": {"message": "Test warning", "level": "warning"}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "print_to_console warning should succeed")


# =============================================================================
# Input Actions Tests
# =============================================================================

func test_get_input_actions() -> void:
	var command = {"id": 1, "command": "get_input_actions", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "get_input_actions should succeed")
	assert_true(response["result"].has("actions"), "Should include actions array")
	assert_true(response["result"].has("count"), "Should include count")
	
	# Should at least have built-in UI actions
	assert_true(response["result"]["count"] > 0, "Should have at least some input actions")


# =============================================================================
# Audio Bus Tests
# =============================================================================

func test_list_audio_buses() -> void:
	var command = {"id": 1, "command": "list_audio_buses", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "list_audio_buses should succeed")
	assert_true(response["result"].has("buses"), "Should include buses array")
	assert_true(response["result"]["count"] >= 1, "Should have at least Master bus")
	
	# Check Master bus exists
	var has_master = false
	for bus in response["result"]["buses"]:
		if bus["name"] == "Master":
			has_master = true
			break
	assert_true(has_master, "Should have Master audio bus")


# =============================================================================
# Command Validation Tests
# =============================================================================

func test_unknown_command_returns_error() -> void:
	var command = {"id": 1, "command": "definitely_not_a_real_command", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Unknown command should fail")
	assert_eq(response["error"]["code"], "UNKNOWN_COMMAND")


func test_empty_command_name_returns_error() -> void:
	var command = {"id": 1, "command": "", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Empty command should fail")
	assert_eq(response["error"]["code"], "MISSING_COMMAND")


func test_null_id_preserved_in_response() -> void:
	var command = {"id": null, "command": "ping", "params": {}}
	var response = _handler.handle_command(command)
	
	assert_eq(response["id"], null, "Null ID should be preserved in response")
