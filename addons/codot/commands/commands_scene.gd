@tool
extends "command_base.gd"
## Scene operation commands for Codot.
##
## Provides commands for:
## - Opening scenes
## - Saving scenes
## - Creating scenes
## - Getting open scenes


## Open a scene file in the editor.
func cmd_open_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not FileAccess.file_exists(path) and not path.begins_with("res://"):
		path = "res://" + path
	
	if not FileAccess.file_exists(path.replace("res://", "")) and not ResourceLoader.exists(path):
		return _error(cmd_id, "FILE_NOT_FOUND", "Scene file not found: " + path)
	
	var err = _require_editor(cmd_id)
	if not err.is_empty():
		return err
	
	editor_interface.open_scene_from_path(path)
	
	# Verify the scene was opened
	await tree.process_frame
	var opened_scenes = Array(editor_interface.get_open_scenes())
	var was_opened = path in opened_scenes
	
	return _success(cmd_id, {
		"opened": was_opened,
		"path": path,
		"open_scenes": opened_scenes
	})


## Save the currently edited scene.
func cmd_save_scene(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var err = _require_editor(cmd_id)
	if not err.is_empty():
		return err
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene is currently open")
	
	var scene_path: String = root.scene_file_path
	if scene_path.is_empty():
		return _error(cmd_id, "UNSAVED_SCENE", "Scene has never been saved. Use create_scene with a path first.")
	
	var mod_time_before: int = 0
	if FileAccess.file_exists(scene_path.replace("res://", "")):
		mod_time_before = FileAccess.get_modified_time(scene_path)
	
	var error: int = editor_interface.save_scene()
	
	if error != OK:
		return _error(cmd_id, "SAVE_FAILED", "Failed to save scene. Error code: " + str(error))
	
	await tree.process_frame
	var mod_time_after: int = 0
	if FileAccess.file_exists(scene_path.replace("res://", "")):
		mod_time_after = FileAccess.get_modified_time(scene_path)
	
	var file_was_updated: bool = mod_time_after > mod_time_before or mod_time_before == 0
	
	return _success(cmd_id, {
		"saved": error == OK,
		"path": scene_path,
		"file_updated": file_was_updated,
		"error_code": error
	})


## Save all open scenes in the editor.
func cmd_save_all_scenes(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var err = _require_editor(cmd_id)
	if not err.is_empty():
		return err
	
	var open_scenes = Array(editor_interface.get_open_scenes())
	if open_scenes.is_empty():
		return _error(cmd_id, "NO_SCENES", "No scenes are currently open")
	
	editor_interface.save_all_scenes()
	
	return _success(cmd_id, {
		"saved": true,
		"scene_count": open_scenes.size(),
		"scenes": open_scenes
	})


## Get list of all currently open scenes.
func cmd_get_open_scenes(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var scenes: Array = []
	if editor_interface != null:
		scenes = Array(editor_interface.get_open_scenes())
	return _success(cmd_id, {"scenes": scenes, "count": scenes.size()})


## Create a new scene with a root node.
func cmd_create_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var root_type: String = params.get("root_type", "Node2D")
	var root_name: String = params.get("root_name", "Root")
	var path: String = params.get("path", "")
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter for scene file")
	
	# Create root node
	var root_node: Node = null
	match root_type:
		"Node":
			root_node = Node.new()
		"Node2D":
			root_node = Node2D.new()
		"Node3D":
			root_node = Node3D.new()
		"Control":
			root_node = Control.new()
		"CanvasLayer":
			root_node = CanvasLayer.new()
		"CharacterBody2D":
			root_node = CharacterBody2D.new()
		"CharacterBody3D":
			root_node = CharacterBody3D.new()
		"RigidBody2D":
			root_node = RigidBody2D.new()
		"RigidBody3D":
			root_node = RigidBody3D.new()
		"Area2D":
			root_node = Area2D.new()
		"Area3D":
			root_node = Area3D.new()
		_:
			# Try to create by class name
			if ClassDB.class_exists(root_type) and ClassDB.is_parent_class(root_type, "Node"):
				root_node = ClassDB.instantiate(root_type)
			else:
				return _error(cmd_id, "INVALID_TYPE", "Unknown or non-Node type: " + root_type)
	
	if root_node == null:
		return _error(cmd_id, "CREATE_FAILED", "Failed to create node of type: " + root_type)
	
	root_node.name = root_name
	
	# Create and save scene
	var scene = PackedScene.new()
	var result = scene.pack(root_node)
	root_node.queue_free()
	
	if result != OK:
		return _error(cmd_id, "PACK_FAILED", "Failed to pack scene")
	
	# Ensure directory exists
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	result = ResourceSaver.save(scene, path)
	if result != OK:
		return _error(cmd_id, "SAVE_FAILED", "Failed to save scene to: " + path)
	
	# Open the new scene in editor
	if editor_interface != null:
		editor_interface.open_scene_from_path(path)
	
	return _success(cmd_id, {
		"created": true,
		"path": path,
		"root_type": root_type,
		"root_name": root_name
	})


## Create a new scene that inherits from an existing scene.
func cmd_new_inherited_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var base_scene_path: String = params.get("base_scene", "")
	var new_scene_path: String = params.get("path", "")
	
	if base_scene_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'base_scene' parameter")
	if new_scene_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not ResourceLoader.exists(base_scene_path):
		return _error(cmd_id, "FILE_NOT_FOUND", "Base scene not found: " + base_scene_path)
	
	# Load and instantiate base scene
	var base_scene: PackedScene = load(base_scene_path)
	if base_scene == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load base scene")
	
	var instance = base_scene.instantiate()
	instance.set_scene_inherited_state(base_scene.get_state())
	
	# Create new packed scene
	var new_scene = PackedScene.new()
	var result = new_scene.pack(instance)
	instance.queue_free()
	
	if result != OK:
		return _error(cmd_id, "PACK_FAILED", "Failed to pack inherited scene")
	
	# Ensure directory exists
	var dir_path = new_scene_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	result = ResourceSaver.save(new_scene, new_scene_path)
	if result != OK:
		return _error(cmd_id, "SAVE_FAILED", "Failed to save scene to: " + new_scene_path)
	
	# Open the new scene
	if editor_interface != null:
		editor_interface.open_scene_from_path(new_scene_path)
	
	return _success(cmd_id, {
		"created": true,
		"path": new_scene_path,
		"base_scene": base_scene_path
	})
