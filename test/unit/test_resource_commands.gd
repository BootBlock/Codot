extends GutTest
## Unit tests for resource operation commands.
##
## Tests the create_resource, save_resource, duplicate_resource,
## set_resource_properties, and list_resource_types commands.


var _handler: Node = null
var _test_dir: String = "res://test_temp_resources/"


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
# List Resource Types Tests
# =============================================================================

func test_list_resource_types() -> void:
	var command = {
		"id": 1,
		"command": "list_resource_types",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "list_resource_types should succeed")
	assert_true(response["result"].has("types"), "Should include types array")
	assert_true(response["result"]["count"] > 0, "Should have available types")
	
	# Check some common types exist
	var types: Array = response["result"]["types"]
	assert_true("Resource" in types, "Should include Resource type")
	assert_true("Gradient" in types, "Should include Gradient type")


# =============================================================================
# Create Resource Tests
# =============================================================================

func test_create_resource_basic() -> void:
	var resource_path = _test_dir + "test_resource.tres"
	var command = {
		"id": 1,
		"command": "create_resource",
		"params": {
			"type": "Resource",
			"path": resource_path
		}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "create_resource should succeed")
	assert_true(response["result"]["created"], "Resource should be created")
	assert_eq(response["result"]["type"], "Resource", "Type should match")
	assert_true(ResourceLoader.exists(resource_path), "Resource should exist")


func test_create_resource_with_properties() -> void:
	var resource_path = _test_dir + "gradient.tres"
	var command = {
		"id": 1,
		"command": "create_resource",
		"params": {
			"type": "Gradient",
			"path": resource_path,
			"properties": {
				"interpolation_mode": 1  # Gradient.GRADIENT_INTERPOLATE_LINEAR
			}
		}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "create_resource with properties should succeed")
	assert_true(response["result"]["properties_set"].size() >= 0, "Should list set properties")


func test_create_resource_invalid_type() -> void:
	var command = {
		"id": 1,
		"command": "create_resource",
		"params": {
			"type": "NotARealType",
			"path": _test_dir + "fake.tres"
		}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail for invalid type")
	assert_eq(response["error"]["code"], "INVALID_TYPE")


func test_create_resource_non_resource_type() -> void:
	var command = {
		"id": 1,
		"command": "create_resource",
		"params": {
			"type": "Node2D",  # This is a Node, not a Resource
			"path": _test_dir + "node.tres"
		}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail for non-Resource type")
	assert_eq(response["error"]["code"], "INVALID_TYPE")


func test_create_resource_missing_params() -> void:
	var command = {
		"id": 1,
		"command": "create_resource",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without params")
	assert_eq(response["error"]["code"], "MISSING_PARAM")


# =============================================================================
# Save Resource Tests
# =============================================================================

func test_save_resource() -> void:
	# First create a resource
	var resource_path = _test_dir + "save_test.tres"
	var resource = Resource.new()
	ResourceSaver.save(resource, resource_path)
	
	var command = {
		"id": 1,
		"command": "save_resource",
		"params": {"path": resource_path}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "save_resource should succeed")
	assert_true(response["result"]["saved"], "Resource should be saved")
	assert_eq(response["result"]["path"], resource_path, "Path should match")


func test_save_resource_not_found() -> void:
	var command = {
		"id": 1,
		"command": "save_resource",
		"params": {"path": _test_dir + "nonexistent.tres"}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail for nonexistent resource")
	assert_eq(response["error"]["code"], "RESOURCE_NOT_FOUND")


# =============================================================================
# Duplicate Resource Tests
# =============================================================================

func test_duplicate_resource() -> void:
	# Create source resource
	var source_path = _test_dir + "source.tres"
	var dest_path = _test_dir + "duplicate.tres"
	
	var resource = Gradient.new()
	ResourceSaver.save(resource, source_path)
	
	var command = {
		"id": 1,
		"command": "duplicate_resource",
		"params": {
			"source_path": source_path,
			"dest_path": dest_path
		}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "duplicate_resource should succeed")
	assert_true(response["result"]["duplicated"], "Resource should be duplicated")
	assert_true(ResourceLoader.exists(dest_path), "Duplicate should exist")
	assert_true(ResourceLoader.exists(source_path), "Source should still exist")


func test_duplicate_resource_source_not_found() -> void:
	var command = {
		"id": 1,
		"command": "duplicate_resource",
		"params": {
			"source_path": _test_dir + "nonexistent.tres",
			"dest_path": _test_dir + "dest.tres"
		}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail for nonexistent source")
	assert_eq(response["error"]["code"], "RESOURCE_NOT_FOUND")


# =============================================================================
# Set Resource Properties Tests
# =============================================================================

func test_set_resource_properties() -> void:
	# Create a Gradient resource (has settable properties)
	var resource_path = _test_dir + "props_test.tres"
	var resource = Gradient.new()
	ResourceSaver.save(resource, resource_path)
	
	var command = {
		"id": 1,
		"command": "set_resource_properties",
		"params": {
			"path": resource_path,
			"properties": {
				"interpolation_mode": 2  # GRADIENT_INTERPOLATE_CONSTANT
			},
			"save": true
		}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "set_resource_properties should succeed")
	assert_true(response["result"]["saved"], "Should be saved")


func test_set_resource_properties_invalid_property() -> void:
	var resource_path = _test_dir + "props_test2.tres"
	var resource = Resource.new()
	ResourceSaver.save(resource, resource_path)
	
	var command = {
		"id": 1,
		"command": "set_resource_properties",
		"params": {
			"path": resource_path,
			"properties": {
				"nonexistent_property": 42
			}
		}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed even with invalid properties")
	assert_true("nonexistent_property" in response["result"]["properties_failed"],
		"Invalid property should be in failed list")


func test_set_resource_properties_not_found() -> void:
	var command = {
		"id": 1,
		"command": "set_resource_properties",
		"params": {
			"path": _test_dir + "nonexistent.tres",
			"properties": {"key": "value"}
		}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail for nonexistent resource")
	assert_eq(response["error"]["code"], "RESOURCE_NOT_FOUND")
