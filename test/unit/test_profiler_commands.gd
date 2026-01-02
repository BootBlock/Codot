extends GutTest
## Unit tests for scene diff and profiler commands.
##
## Tests scene comparison and performance monitoring.


var _handler: Node = null


func before_each() -> void:
	var handler_script = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)


func after_each() -> void:
	_handler = null


# =============================================================================
# Scene Diff Tests
# =============================================================================

func test_get_scene_diff_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "get_scene_diff",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	# Without editor, should fail
	assert_false(response["success"], "Should fail without editor")


# =============================================================================
# Profiler Data Tests
# =============================================================================

func test_get_profiler_data_returns_structure() -> void:
	var command = {
		"id": 1,
		"command": "get_profiler_data",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_has(response["result"], "time", "Should have time category")
	assert_has(response["result"], "memory", "Should have memory category")
	assert_has(response["result"], "objects", "Should have objects category")
	assert_has(response["result"], "rendering", "Should have rendering category")


func test_get_profiler_data_with_category_filter() -> void:
	var command = {
		"id": 1,
		"command": "get_profiler_data",
		"params": {"category": "memory"}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_eq(response["result"]["category"], "memory", "Should return memory category")
	assert_has(response["result"], "data", "Should have data field")


func test_get_profiler_data_time_category() -> void:
	var command = {
		"id": 1,
		"command": "get_profiler_data",
		"params": {"category": "time"}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_has(response["result"]["data"], "fps", "Should have fps")
	assert_has(response["result"]["data"], "process", "Should have process time")


# =============================================================================
# Orphan Nodes Tests
# =============================================================================

func test_get_orphan_nodes_returns_structure() -> void:
	var command = {
		"id": 1,
		"command": "get_orphan_nodes",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_has(response["result"], "orphan_count", "Should have orphan_count")
	assert_has(response["result"], "total_nodes", "Should have total_nodes")
	assert_has(response["result"], "percentage", "Should have percentage")
	assert_has(response["result"], "note", "Should have note")
	assert_has(response["result"], "recommendation", "Should have recommendation")


# =============================================================================
# Object Stats Tests
# =============================================================================

func test_get_object_stats_returns_structure() -> void:
	var command = {
		"id": 1,
		"command": "get_object_stats",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_has(response["result"], "total_objects", "Should have total_objects")
	assert_has(response["result"], "resources", "Should have resources")
	assert_has(response["result"], "nodes", "Should have nodes")
	assert_has(response["result"], "orphan_nodes", "Should have orphan_nodes")


func test_get_object_stats_calculates_derived_stats() -> void:
	var command = {
		"id": 1,
		"command": "get_object_stats",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_has(response["result"], "other_objects", "Should have other_objects")
	assert_has(response["result"], "avg_bytes_per_object", "Should have avg_bytes_per_object")


# =============================================================================
# Stack Info Tests
# =============================================================================

func test_get_stack_info_returns_structure() -> void:
	var command = {
		"id": 1,
		"command": "get_stack_info",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_has(response["result"], "stack", "Should have stack")
	assert_has(response["result"], "depth", "Should have depth")
	assert_true(response["result"]["stack"] is Array, "Stack should be array")


# =============================================================================
# Editor Theme/Layout Tests
# =============================================================================

func test_get_editor_theme_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "get_editor_theme",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	# Without editor, should fail
	assert_false(response["success"], "Should fail without editor")


func test_get_editor_layout_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "get_editor_layout",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	# Without editor, should fail
	assert_false(response["success"], "Should fail without editor")


func test_get_editor_viewport_info_requires_editor() -> void:
	var command = {
		"id": 1,
		"command": "get_editor_viewport_info",
		"params": {"viewport": "2d"}
	}
	var response = await _handler.handle_command(command)
	
	# Without editor, should fail
	assert_false(response["success"], "Should fail without editor")
