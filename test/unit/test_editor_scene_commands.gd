extends GutTest
## Unit tests for editor operation commands.
##
## Tests refresh_filesystem, reimport_resource, mark_modified,
## get_current_screen, and set_current_screen commands.
## Also tests scene commands like duplicate_scene, get_scene_dependencies.


var _handler: Node = null
var _test_dir: String = "res://test_temp_editor/"


func before_each() -> void:
	var handler_script = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)
	
	# Clean up test directory
	if DirAccess.dir_exists_absolute(_test_dir):
		_recursive_delete(_test_dir)
	DirAccess.make_dir_recursive_absolute(_test_dir)


func after_each() -> void:
	_handler = null
	
	if DirAccess.dir_exists_absolute(_test_dir):
		_recursive_delete(_test_dir)


func _recursive_delete(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path = path.path_join(file_name)
				if dir.current_is_dir():
					_recursive_delete(full_path)
				else:
					dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		var parent = DirAccess.open(path.get_base_dir())
		if parent:
			parent.remove(path.get_file())


# =============================================================================
# Editor Screen Tests (basic - no editor required)
# =============================================================================

func test_get_current_screen_no_editor() -> void:
	# Without EditorInterface, this should return an error
	var command = {
		"id": 1,
		"command": "get_current_screen",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	# Without editor, should fail
	assert_false(response["success"], "Should fail without editor interface")
	assert_eq(response["error"]["code"], "NO_EDITOR")


func test_set_current_screen_no_editor() -> void:
	var command = {
		"id": 1,
		"command": "set_current_screen",
		"params": {"screen": "Script"}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor interface")
	assert_eq(response["error"]["code"], "NO_EDITOR")


func test_set_current_screen_invalid_screen() -> void:
	# This will fail with NO_EDITOR first, but let's make sure the
	# schema validation would catch invalid screens
	var command = {
		"id": 1,
		"command": "set_current_screen",
		"params": {"screen": "InvalidScreen"}
	}
	var response = _handler.handle_command(command)
	
	# Will fail with NO_EDITOR since we don't have editor
	assert_false(response["success"])


func test_set_current_screen_missing_param() -> void:
	var command = {
		"id": 1,
		"command": "set_current_screen",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	# Will fail - either NO_EDITOR or MISSING_PARAM
	assert_false(response["success"])


# =============================================================================
# Refresh Filesystem Tests
# =============================================================================

func test_refresh_filesystem_no_editor() -> void:
	var command = {
		"id": 1,
		"command": "refresh_filesystem",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	# Without editor, should fail
	assert_false(response["success"], "Should fail without editor interface")
	assert_eq(response["error"]["code"], "NO_EDITOR")


# =============================================================================
# Reimport Resource Tests
# =============================================================================

func test_reimport_resource_no_editor() -> void:
	var command = {
		"id": 1,
		"command": "reimport_resource",
		"params": {"path": "res://icon.svg"}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor interface")
	assert_eq(response["error"]["code"], "NO_EDITOR")


func test_reimport_resource_missing_param() -> void:
	var command = {
		"id": 1,
		"command": "reimport_resource",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	# Will fail - either NO_EDITOR or MISSING_PARAM
	assert_false(response["success"])


# =============================================================================
# Scene Dependencies Tests
# =============================================================================

func test_get_scene_dependencies() -> void:
	# Test with a known scene file that exists
	var command = {
		"id": 1,
		"command": "get_scene_dependencies",
		"params": {"path": "res://test_scene.tscn"}
	}
	var response = _handler.handle_command(command)
	
	# Should succeed if test_scene.tscn exists
	if ResourceLoader.exists("res://test_scene.tscn"):
		assert_true(response["success"], "get_scene_dependencies should succeed")
		assert_true(response["result"].has("dependencies"), "Should include dependencies")
		assert_true(response["result"].has("count"), "Should include count")
		assert_true(response["result"].has("by_type"), "Should categorize by type")
	else:
		# If the scene doesn't exist, it should fail appropriately
		assert_false(response["success"])


func test_get_scene_dependencies_not_found() -> void:
	var command = {
		"id": 1,
		"command": "get_scene_dependencies",
		"params": {"path": "res://nonexistent_scene_12345.tscn"}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail for nonexistent scene")
	assert_eq(response["error"]["code"], "FILE_NOT_FOUND")


func test_get_scene_dependencies_missing_param() -> void:
	var command = {
		"id": 1,
		"command": "get_scene_dependencies",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path")
	assert_eq(response["error"]["code"], "MISSING_PARAM")


# =============================================================================
# Duplicate Scene Tests
# =============================================================================

func test_duplicate_scene() -> void:
	# This requires a source scene to exist
	var source_path = "res://test_scene.tscn"
	var dest_path = _test_dir + "duplicated_scene.tscn"
	
	if not ResourceLoader.exists(source_path):
		pass_test("Skipping - no source scene available")
		return
	
	var command = {
		"id": 1,
		"command": "duplicate_scene",
		"params": {
			"source_path": source_path,
			"dest_path": dest_path,
			"open": false  # Don't open - we don't have editor
		}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "duplicate_scene should succeed")
	assert_true(response["result"]["duplicated"], "Scene should be duplicated")
	assert_true(ResourceLoader.exists(dest_path), "Duplicated scene should exist")


func test_duplicate_scene_source_not_found() -> void:
	var command = {
		"id": 1,
		"command": "duplicate_scene",
		"params": {
			"source_path": "res://nonexistent_scene.tscn",
			"dest_path": _test_dir + "dest.tscn"
		}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail for nonexistent source")
	assert_eq(response["error"]["code"], "FILE_NOT_FOUND")


func test_duplicate_scene_missing_params() -> void:
	var command = {
		"id": 1,
		"command": "duplicate_scene",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without params")
	assert_eq(response["error"]["code"], "MISSING_PARAM")


# =============================================================================
# Reload/Close Scene Tests (require editor)
# =============================================================================

func test_reload_current_scene_no_editor() -> void:
	var command = {
		"id": 1,
		"command": "reload_current_scene",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")
	assert_eq(response["error"]["code"], "NO_EDITOR")


func test_close_scene_no_editor() -> void:
	var command = {
		"id": 1,
		"command": "close_scene",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor")
	assert_eq(response["error"]["code"], "NO_EDITOR")
