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


## Duplicate an existing scene to a new path.
## [br][br]
## [param params]:
## - 'source_path' (String, required): Source scene path.
## - 'dest_path' (String, required): Destination scene path.
## - 'open' (bool, default true): Open the duplicated scene in editor.
func cmd_duplicate_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var source_path: String = params.get("source_path", "")
	var dest_path: String = params.get("dest_path", "")
	var open_scene: bool = params.get("open", true)
	
	if source_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'source_path' parameter")
	if dest_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'dest_path' parameter")
	
	if not ResourceLoader.exists(source_path):
		return _error(cmd_id, "FILE_NOT_FOUND", "Source scene not found: " + source_path)
	
	# Load source scene
	var source_scene: PackedScene = load(source_path)
	if source_scene == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load source scene")
	
	# Ensure destination directory exists
	var dir_path = dest_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Save copy
	var result = ResourceSaver.save(source_scene, dest_path)
	if result != OK:
		return _error(cmd_id, "SAVE_FAILED", "Failed to save duplicate to: " + dest_path)
	
	# Open if requested
	if open_scene and editor_interface != null:
		editor_interface.open_scene_from_path(dest_path)
	
	return _success(cmd_id, {
		"duplicated": true,
		"source_path": source_path,
		"dest_path": dest_path,
		"opened": open_scene
	})


## Get the dependencies of a scene (resources it uses).
## [br][br]
## [param params]:
## - 'path' (String, required): Scene path to analyze.
## - 'recursive' (bool, default false): Include transitive dependencies.
func cmd_get_scene_dependencies(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var recursive: bool = params.get("recursive", false)
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not ResourceLoader.exists(path):
		return _error(cmd_id, "FILE_NOT_FOUND", "Resource not found: " + path)
	
	var dependencies: Array = []
	var processed: Dictionary = {}
	
	_collect_dependencies(path, dependencies, processed, recursive)
	
	# Categorize dependencies
	var scripts: Array = []
	var textures: Array = []
	var scenes: Array = []
	var shaders: Array = []
	var other: Array = []
	
	for dep in dependencies:
		if dep.ends_with(".gd") or dep.ends_with(".cs"):
			scripts.append(dep)
		elif dep.ends_with(".png") or dep.ends_with(".jpg") or dep.ends_with(".svg") or dep.ends_with(".webp"):
			textures.append(dep)
		elif dep.ends_with(".tscn") or dep.ends_with(".scn"):
			scenes.append(dep)
		elif dep.ends_with(".gdshader") or dep.ends_with(".shader"):
			shaders.append(dep)
		else:
			other.append(dep)
	
	return _success(cmd_id, {
		"path": path,
		"dependencies": dependencies,
		"count": dependencies.size(),
		"by_type": {
			"scripts": scripts,
			"textures": textures,
			"scenes": scenes,
			"shaders": shaders,
			"other": other
		}
	})


## Helper: Collect dependencies from a resource.
func _collect_dependencies(path: String, out_deps: Array, processed: Dictionary, recursive: bool) -> void:
	if processed.has(path):
		return
	processed[path] = true
	
	var deps := ResourceLoader.get_dependencies(path)
	for dep in deps:
		# Dependencies are formatted as "type::path"
		var parts := dep.split("::")
		var dep_path := parts[parts.size() - 1] if parts.size() > 1 else dep
		
		if dep_path not in out_deps:
			out_deps.append(dep_path)
		
		if recursive:
			_collect_dependencies(dep_path, out_deps, processed, recursive)


## Reload the currently edited scene from disk.
func cmd_reload_current_scene(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var err = _require_editor(cmd_id)
	if not err.is_empty():
		return err
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene is currently open")
	
	var scene_path: String = root.scene_file_path
	if scene_path.is_empty():
		return _error(cmd_id, "UNSAVED_SCENE", "Scene has never been saved")
	
	# Close and reopen the scene
	# Note: The reload_current_scene method was introduced in newer Godot versions
	editor_interface.reload_scene_from_path(scene_path)
	
	return _success(cmd_id, {
		"reloaded": true,
		"path": scene_path
	})


## Close a specific scene in the editor.
## [br][br]
## [param params]:
## - 'path' (String): Scene path to close. If empty, closes current scene.
## - 'save' (bool, default true): Save before closing.
func cmd_close_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var err = _require_editor(cmd_id)
	if not err.is_empty():
		return err
	
	var path: String = params.get("path", "")
	var save: bool = params.get("save", true)
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene is currently open")
	
	var scene_path: String = root.scene_file_path if path.is_empty() else path
	
	if save and not scene_path.is_empty():
		editor_interface.save_scene()
	
	# Close the scene by setting an empty edited scene root
	# or by using internal editor methods
	# Note: There's no direct "close_scene" API, we use workarounds
	var open_scenes = Array(editor_interface.get_open_scenes())
	
	if scene_path in open_scenes:
		# Open a different scene or create empty state
		if open_scenes.size() > 1:
			for s in open_scenes:
				if s != scene_path:
					editor_interface.open_scene_from_path(s)
					break
	
	return _success(cmd_id, {
		"closed": true,
		"path": scene_path,
		"saved": save
	})


## Compare current scene state to the saved version on disk.
## [br][br]
## [param params]:
## - 'path' (String, optional): Scene path to compare. Uses current scene if empty.
## - 'include_properties' (bool, default true): Include property changes.
func cmd_get_scene_diff(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var path: String = params.get("path", "")
	var include_properties: bool = params.get("include_properties", true)
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene is currently open")
	
	var scene_path: String = path if not path.is_empty() else root.scene_file_path
	
	if scene_path.is_empty():
		return _success(cmd_id, {
			"has_changes": true,
			"is_new": true,
			"changes": [],
			"note": "Scene has never been saved"
		})
	
	if not FileAccess.file_exists(scene_path):
		return _success(cmd_id, {
			"has_changes": true,
			"is_new": true,
			"changes": [],
			"note": "Scene file does not exist on disk"
		})
	
	# Load the saved version
	var saved_scene := load(scene_path) as PackedScene
	if saved_scene == null:
		return _error(cmd_id, "LOAD_ERROR", "Could not load saved scene: " + scene_path)
	
	var saved_root := saved_scene.instantiate()
	if saved_root == null:
		return _error(cmd_id, "INSTANTIATE_ERROR", "Could not instantiate saved scene")
	
	var changes: Array = []
	
	# Compare nodes recursively
	_compare_nodes(root, saved_root, "", changes, include_properties)
	
	# Check for nodes in current that aren't in saved (added)
	_find_added_nodes(root, saved_root, "", changes)
	
	# Check for nodes in saved that aren't in current (removed)
	_find_removed_nodes(root, saved_root, "", changes)
	
	# Clean up
	saved_root.queue_free()
	
	return _success(cmd_id, {
		"path": scene_path,
		"has_changes": changes.size() > 0,
		"is_new": false,
		"changes": changes,
		"change_count": changes.size()
	})


## Helper: Compare two nodes and their properties.
func _compare_nodes(current: Node, saved: Node, path: String, changes: Array, include_props: bool) -> void:
	if current == null or saved == null:
		return
	
	var current_path := path + "/" + current.name if not path.is_empty() else current.name
	
	# Check if type changed
	if current.get_class() != saved.get_class():
		changes.append({
			"type": "type_changed",
			"path": current_path,
			"old_type": saved.get_class(),
			"new_type": current.get_class()
		})
		return
	
	# Compare properties if requested
	if include_props:
		for prop in current.get_property_list():
			if prop["usage"] & PROPERTY_USAGE_STORAGE:
				var prop_name: String = prop["name"]
				# Skip internal properties
				if prop_name.begins_with("_") or prop_name in ["script", "owner"]:
					continue
				
				var current_val = current.get(prop_name)
				var saved_val = saved.get(prop_name)
				
				if not _values_equal(current_val, saved_val):
					changes.append({
						"type": "property_changed",
						"path": current_path,
						"property": prop_name,
						"old_value": _safe_string(saved_val),
						"new_value": _safe_string(current_val)
					})
	
	# Compare children with same name
	for i in range(current.get_child_count()):
		var current_child := current.get_child(i)
		var saved_child := saved.get_node_or_null(NodePath(current_child.name))
		if saved_child != null:
			_compare_nodes(current_child, saved_child, current_path, changes, include_props)


## Helper: Find nodes that were added.
func _find_added_nodes(current: Node, saved: Node, path: String, changes: Array) -> void:
	var current_path := path + "/" + current.name if not path.is_empty() else current.name
	
	for i in range(current.get_child_count()):
		var current_child := current.get_child(i)
		var saved_child := saved.get_node_or_null(NodePath(current_child.name)) if saved else null
		
		if saved_child == null:
			changes.append({
				"type": "node_added",
				"path": current_path + "/" + current_child.name,
				"node_type": current_child.get_class()
			})
		else:
			_find_added_nodes(current_child, saved_child, current_path, changes)


## Helper: Find nodes that were removed.
func _find_removed_nodes(current: Node, saved: Node, path: String, changes: Array) -> void:
	if saved == null:
		return
	
	var current_path := path + "/" + saved.name if not path.is_empty() else saved.name
	
	for i in range(saved.get_child_count()):
		var saved_child := saved.get_child(i)
		var current_child := current.get_node_or_null(NodePath(saved_child.name)) if current else null
		
		if current_child == null:
			changes.append({
				"type": "node_removed",
				"path": current_path + "/" + saved_child.name,
				"node_type": saved_child.get_class()
			})
		else:
			_find_removed_nodes(current_child, saved_child, current_path, changes)


## Helper: Check if two values are equal.
func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	
	match typeof(a):
		TYPE_OBJECT:
			if a is Resource and b is Resource:
				return a.resource_path == b.resource_path
			return a == b
		TYPE_ARRAY:
			if a.size() != b.size():
				return false
			for i in range(a.size()):
				if not _values_equal(a[i], b[i]):
					return false
			return true
		TYPE_DICTIONARY:
			if a.size() != b.size():
				return false
			for key in a:
				if not b.has(key) or not _values_equal(a[key], b[key]):
					return false
			return true
		_:
			return a == b


## Helper: Convert value to safe string representation.
func _safe_string(value: Variant) -> String:
	match typeof(value):
		TYPE_OBJECT:
			if value is Resource:
				return value.resource_path if value.resource_path else "(embedded)"
			return value.get_class() if value else "null"
		TYPE_VECTOR2:
			return "Vector2(%s, %s)" % [value.x, value.y]
		TYPE_VECTOR3:
			return "Vector3(%s, %s, %s)" % [value.x, value.y, value.z]
		TYPE_COLOR:
			return "Color(%s, %s, %s, %s)" % [value.r, value.g, value.b, value.a]
		TYPE_NIL:
			return "null"
		_:
			return str(value)
