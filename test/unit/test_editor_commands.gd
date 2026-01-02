extends GutTest
## Unit tests for additional editor commands.
##
## Tests get_recent_files and other editor commands.


var _handler: Node = null


func before_each() -> void:
	# Create a fresh command handler for each test
	var handler_script = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)


func after_each() -> void:
	_handler = null


# =============================================================================
# Get Recent Files Tests
# =============================================================================

func test_get_recent_files_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "get_recent_files",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")
	assert_eq(response["error"]["code"], "NO_EDITOR", "Should return NO_EDITOR")


func test_get_recent_files_with_max_count() -> void:
	var command = {
		"id": 1,
		"command": "get_recent_files",
		"params": {"max_count": 5}
	}
	var response = await _handler.handle_command(command)
	
	# Without editor, should fail
	assert_false(response["success"], "Should fail without editor")


func test_get_recent_files_with_filter() -> void:
	var command = {
		"id": 1,
		"command": "get_recent_files",
		"params": {"filter": "tscn"}
	}
	var response = await _handler.handle_command(command)
	
	# Without editor, should fail
	assert_false(response["success"], "Should fail without editor")


# =============================================================================
# Make Node Local Tests
# =============================================================================

func test_make_node_local_requires_path() -> void:
	var command = {
		"id": 1,
		"command": "make_node_local",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path")


func test_make_node_local_requires_scene() -> void:
	var command = {
		"id": 1,
		"command": "make_node_local",
		"params": {"path": "."}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without scene")
	assert_true(
		response["error"]["code"] == "NO_EDITOR" or response["error"]["code"] == "NO_SCENE",
		"Should return appropriate error"
	)


# =============================================================================
# Get Node Hierarchy Info Tests
# =============================================================================

func test_get_node_hierarchy_info_requires_path() -> void:
	var command = {
		"id": 1,
		"command": "get_node_hierarchy_info",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path")


func test_get_node_hierarchy_info_requires_scene() -> void:
	var command = {
		"id": 1,
		"command": "get_node_hierarchy_info",
		"params": {"path": "."}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without scene")


# =============================================================================
# Undo/Redo Tests
# =============================================================================

func test_undo_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "undo",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")


func test_redo_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "redo",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")


func test_get_undo_redo_status_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "get_undo_redo_status",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")
