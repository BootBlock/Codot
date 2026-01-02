extends GutTest
## Unit tests for scene tree inspection commands.
##
## Tests the get_scene_tree improvements including visibility state,
## script paths, and filtering capabilities.


var _handler: Node = null


func before_each() -> void:
	# Create a fresh command handler for each test
	var handler_script = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)


func after_each() -> void:
	_handler = null


# =============================================================================
# Scene Tree Command Tests
# =============================================================================

func test_get_scene_tree_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "get_scene_tree",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	# Without editor, should fail or return empty tree
	if response["success"]:
		assert_true(response["result"]["tree"] == null, "Should have null tree without editor")
	else:
		assert_eq(response["error"]["code"], "NO_EDITOR", "Should return NO_EDITOR")


func test_get_scene_tree_max_depth_param() -> void:
	var command = {
		"id": 1,
		"command": "get_scene_tree",
		"params": {"max_depth": 2}
	}
	var response = await _handler.handle_command(command)
	
	# Just verify the command is processed without error
	assert_true(response.has("success"), "Response should have success field")


func test_get_scene_tree_include_visibility_param() -> void:
	var command = {
		"id": 1,
		"command": "get_scene_tree",
		"params": {"include_visibility": true}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response.has("success"), "Response should have success field")


func test_get_scene_tree_include_scripts_param() -> void:
	var command = {
		"id": 1,
		"command": "get_scene_tree",
		"params": {"include_scripts": false}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response.has("success"), "Response should have success field")


func test_get_scene_tree_filter_type_param() -> void:
	var command = {
		"id": 1,
		"command": "get_scene_tree",
		"params": {"filter_type": "Sprite2D"}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response.has("success"), "Response should have success field")


func test_get_scene_tree_filter_name_param() -> void:
	var command = {
		"id": 1,
		"command": "get_scene_tree",
		"params": {"filter_name": "Player"}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response.has("success"), "Response should have success field")


func test_get_scene_tree_all_options() -> void:
	var command = {
		"id": 1,
		"command": "get_scene_tree",
		"params": {
			"max_depth": 5,
			"include_visibility": true,
			"include_scripts": true,
			"filter_type": "",
			"filter_name": ""
		}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response.has("success"), "Response should have success field")


# =============================================================================
# Node Info Tests
# =============================================================================

func test_get_node_info_requires_path() -> void:
	var command = {
		"id": 1,
		"command": "get_node_info",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path")


func test_get_node_properties_requires_path() -> void:
	var command = {
		"id": 1,
		"command": "get_node_properties",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path")
