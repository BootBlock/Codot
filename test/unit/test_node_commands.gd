extends GutTest
## Unit tests for node manipulation commands.
##
## Tests the instantiate_scene, get_node_script, attach_script, and 
## detach_script commands.


var _handler: Node = null
var _test_script_path: String = "res://test_temp_script.gd"
var _test_scene_path: String = "res://test_temp_scene.tscn"


func before_each() -> void:
	# Create a fresh command handler for each test
	var handler_script = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)
	
	# Create a test script file
	var file = FileAccess.open(_test_script_path, FileAccess.WRITE)
	if file:
		file.store_string("extends Node\n\nfunc _ready():\n\tpass\n")
		file.close()
	
	# Create a test scene file
	_create_test_scene()


func after_each() -> void:
	_handler = null
	
	# Clean up test files
	if FileAccess.file_exists(_test_script_path):
		DirAccess.remove_absolute(_test_script_path)
	if FileAccess.file_exists(_test_scene_path):
		DirAccess.remove_absolute(_test_scene_path)


func _create_test_scene() -> void:
	# Create a simple test scene programmatically
	var scene = PackedScene.new()
	var root = Node2D.new()
	root.name = "TestRoot"
	scene.pack(root)
	ResourceSaver.save(scene, _test_scene_path)
	root.free()


# =============================================================================
# Get Node Script Tests (without editor)
# =============================================================================

func test_get_node_script_missing_path() -> void:
	var command = {
		"id": 1,
		"command": "get_node_script",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	# Without editor, should get NO_EDITOR or MISSING_PARAM error
	assert_false(response["success"], "Should fail without proper params")


func test_get_node_script_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "get_node_script",
		"params": {"path": "."}
	}
	var response = await _handler.handle_command(command)
	
	# Without editor_interface set, should get NO_EDITOR or NO_SCENE error
	assert_false(response["success"], "Should fail without editor")
	assert_true(
		response["error"]["code"] == "NO_EDITOR" or response["error"]["code"] == "NO_SCENE",
		"Should return appropriate error"
	)


# =============================================================================
# Attach Script Tests (without editor)
# =============================================================================

func test_attach_script_missing_path() -> void:
	var command = {
		"id": 1,
		"command": "attach_script",
		"params": {"script": _test_script_path}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path param")


func test_attach_script_missing_script() -> void:
	var command = {
		"id": 1,
		"command": "attach_script",
		"params": {"path": "."}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without script param")


func test_attach_script_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "attach_script",
		"params": {"path": ".", "script": _test_script_path}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")
	assert_true(
		response["error"]["code"] == "NO_EDITOR" or response["error"]["code"] == "NO_SCENE",
		"Should return appropriate error"
	)


# =============================================================================
# Detach Script Tests (without editor)
# =============================================================================

func test_detach_script_missing_path() -> void:
	var command = {
		"id": 1,
		"command": "detach_script",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path param")


func test_detach_script_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "detach_script",
		"params": {"path": "."}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")
	assert_true(
		response["error"]["code"] == "NO_EDITOR" or response["error"]["code"] == "NO_SCENE",
		"Should return appropriate error"
	)


# =============================================================================
# Instantiate Scene Tests (without editor)
# =============================================================================

func test_instantiate_scene_missing_scene() -> void:
	var command = {
		"id": 1,
		"command": "instantiate_scene",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without scene param")


func test_instantiate_scene_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "instantiate_scene",
		"params": {"scene": _test_scene_path}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")
	assert_true(
		response["error"]["code"] == "NO_EDITOR" or response["error"]["code"] == "NO_SCENE",
		"Should return appropriate error"
	)


func test_instantiate_scene_scene_not_found() -> void:
	# Set up the handler with a mock editor interface
	# This is tricky to test without full editor - we test parameter validation
	var command = {
		"id": 1,
		"command": "instantiate_scene",
		"params": {"scene": "res://nonexistent_scene.tscn"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail with nonexistent scene")
