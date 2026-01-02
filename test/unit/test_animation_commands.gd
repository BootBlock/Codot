extends GutTest
## Unit tests for animation commands.
##
## Tests animation creation, tracks, and keyframes.


var _handler: Node = null


func before_each() -> void:
	var handler_script = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)


func after_each() -> void:
	_handler = null


# =============================================================================
# Animation Creation Tests
# =============================================================================

func test_create_animation_requires_editor_or_param() -> void:
	# In headless mode, we get NO_EDITOR. With editor, we'd get MISSING_PARAM
	var command = {
		"id": 1,
		"command": "create_animation",
		"params": {"name": "test_anim"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor or path")
	# Either NO_EDITOR (headless) or MISSING_PARAM (with editor) is acceptable
	assert_true(response["error"]["code"] in ["NO_EDITOR", "MISSING_PARAM"], "Should return NO_EDITOR or MISSING_PARAM")


func test_create_animation_requires_name() -> void:
	# In headless mode, we get NO_EDITOR before param validation
	var command = {
		"id": 1,
		"command": "create_animation",
		"params": {"path": "AnimationPlayer"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor or name")
	assert_true(response["error"]["code"] in ["NO_EDITOR", "MISSING_PARAM"], "Should return NO_EDITOR or MISSING_PARAM")


func test_create_animation_requires_scene() -> void:
	var command = {
		"id": 1,
		"command": "create_animation",
		"params": {"path": "AnimationPlayer", "name": "test_anim"}
	}
	var response = await _handler.handle_command(command)
	
	# Should fail without editor/scene
	assert_false(response["success"], "Should fail without scene")


# =============================================================================
# Animation Track Tests
# =============================================================================

func test_add_animation_track_requires_editor_or_params() -> void:
	# In headless mode, we get NO_EDITOR before param validation
	var command = {
		"id": 1,
		"command": "add_animation_track",
		"params": {"animation": "idle", "track_type": "value", "track_path": "Sprite:modulate"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor or path")
	assert_true(response["error"]["code"] in ["NO_EDITOR", "MISSING_PARAM"], "Should return NO_EDITOR or MISSING_PARAM")


func test_add_animation_track_requires_animation_or_editor() -> void:
	# In headless mode, we get NO_EDITOR before param validation
	var command = {
		"id": 1,
		"command": "add_animation_track",
		"params": {"path": "AnimationPlayer", "track_type": "value", "track_path": "Sprite:modulate"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor or animation")
	assert_true(response["error"]["code"] in ["NO_EDITOR", "MISSING_PARAM"], "Should return NO_EDITOR or MISSING_PARAM")


func test_add_animation_track_requires_track_path_or_editor() -> void:
	# In headless mode, we get NO_EDITOR before param validation
	var command = {
		"id": 1,
		"command": "add_animation_track",
		"params": {"path": "AnimationPlayer", "animation": "idle", "track_type": "value"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without editor or track_path")
	assert_true(response["error"]["code"] in ["NO_EDITOR", "MISSING_PARAM"], "Should return NO_EDITOR or MISSING_PARAM")


# =============================================================================
# Animation Keyframe Tests
# =============================================================================

func test_add_animation_keyframe_requires_path() -> void:
	var command = {
		"id": 1,
		"command": "add_animation_keyframe",
		"params": {"animation": "idle", "track_index": 0, "time": 0.0, "value": 1.0}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path")


func test_add_animation_keyframe_requires_animation() -> void:
	var command = {
		"id": 1,
		"command": "add_animation_keyframe",
		"params": {"path": "AnimationPlayer", "track_index": 0, "time": 0.0, "value": 1.0}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without animation")


func test_add_animation_keyframe_requires_track_index() -> void:
	var command = {
		"id": 1,
		"command": "add_animation_keyframe",
		"params": {"path": "AnimationPlayer", "animation": "idle", "time": 0.0, "value": 1.0}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without track_index")


func test_add_animation_keyframe_requires_value() -> void:
	var command = {
		"id": 1,
		"command": "add_animation_keyframe",
		"params": {"path": "AnimationPlayer", "animation": "idle", "track_index": 0, "time": 0.0}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without value")


# =============================================================================
# Preview Animation Tests
# =============================================================================

func test_preview_animation_requires_path() -> void:
	var command = {
		"id": 1,
		"command": "preview_animation",
		"params": {"animation": "idle"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path")


func test_preview_animation_requires_animation() -> void:
	var command = {
		"id": 1,
		"command": "preview_animation",
		"params": {"path": "AnimationPlayer"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without animation")
