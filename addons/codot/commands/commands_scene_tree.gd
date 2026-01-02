@tool
extends "command_base.gd"
## Scene tree inspection commands for Codot.
##
## Provides commands for:
## - Getting scene tree structure
## - Getting node info
## - Getting node properties


## Get the scene tree structure as a nested dictionary.
## [br][br]
## [param params]:
## - 'max_depth' (int, optional): Maximum depth to traverse (default 10).
## - 'include_visibility' (bool, optional): Include visibility state (default false).
## - 'include_scripts' (bool, optional): Include script paths (default true).
## - 'filter_type' (String, optional): Only include nodes of this type.
## - 'filter_name' (String, optional): Only include nodes matching this name pattern.
func cmd_get_scene_tree(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var err = _require_editor(cmd_id)
	if not err.is_empty():
		return err
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _success(cmd_id, {"tree": null, "message": "No scene open"})
	
	var options: Dictionary = {
		"max_depth": params.get("max_depth", 10),
		"include_visibility": params.get("include_visibility", false),
		"include_scripts": params.get("include_scripts", true),
		"filter_type": params.get("filter_type", ""),
		"filter_name": params.get("filter_name", ""),
	}
	
	var tree_data: Dictionary = _node_to_dict(root, 0, options)
	return _success(cmd_id, {"tree": tree_data})


## Convert a node and its children to a dictionary representation.
func _node_to_dict(node: Node, depth: int, options: Dictionary) -> Dictionary:
	var data: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}
	
	# Include script path if requested
	if options.include_scripts:
		var script = node.get_script()
		if script != null:
			data["script"] = script.resource_path
	
	# Include visibility state if requested
	if options.include_visibility:
		if node is CanvasItem:
			data["visible"] = node.visible
			data["modulate_alpha"] = node.modulate.a
		elif node is Node3D:
			data["visible"] = node.visible
	
	# Process children
	if depth < options.max_depth:
		var children: Array = []
		for child in node.get_children():
			# Apply filters
			if not options.filter_type.is_empty():
				if not child.is_class(options.filter_type):
					continue
			if not options.filter_name.is_empty():
				if not child.name.matchn("*" + options.filter_name + "*"):
					continue
			
			children.append(_node_to_dict(child, depth + 1, options))
		if children.size() > 0:
			data["children"] = children
	
	return data


## Get detailed information about a specific node.
func cmd_get_node_info(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var err = _require_editor(cmd_id)
	if not err.is_empty():
		return err
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var info: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"owner": str(node.owner.get_path()) if node.owner else null,
		"child_count": node.get_child_count(),
	}
	
	var script = node.get_script()
	if script != null:
		info["script"] = script.resource_path
	
	# Add type-specific info
	if node is Node2D:
		info["position"] = {"x": node.position.x, "y": node.position.y}
		info["rotation"] = node.rotation
		info["scale"] = {"x": node.scale.x, "y": node.scale.y}
	elif node is Node3D:
		info["position"] = {"x": node.position.x, "y": node.position.y, "z": node.position.z}
		info["rotation"] = {"x": node.rotation.x, "y": node.rotation.y, "z": node.rotation.z}
		info["scale"] = {"x": node.scale.x, "y": node.scale.y, "z": node.scale.z}
	elif node is Control:
		info["position"] = {"x": node.position.x, "y": node.position.y}
		info["size"] = {"x": node.size.x, "y": node.size.y}
	
	return _success(cmd_id, info)


## Get all editable properties of a node.
func cmd_get_node_properties(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var err = _require_editor(cmd_id)
	if not err.is_empty():
		return err
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene open")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var properties: Dictionary = {}
	var prop_list = node.get_property_list()
	
	for prop in prop_list:
		var prop_name: String = prop["name"]
		if prop_name.begins_with("_"):
			continue
		if prop["usage"] & PROPERTY_USAGE_EDITOR:
			var value = node.get(prop_name)
			properties[prop_name] = _value_to_json(value)
	
	return _success(cmd_id, {"path": node_path, "properties": properties})


## Convert a Godot Variant value to JSON-compatible format.
func _value_to_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_RECT2:
			return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
		TYPE_OBJECT:
			if value == null:
				return null
			if value is Resource:
				return value.resource_path if not value.resource_path.is_empty() else str(value)
			return str(value)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var arr: Array = []
			for item in value:
				arr.append(_value_to_json(item))
			return arr
		TYPE_DICTIONARY:
			var dict: Dictionary = {}
			for key in value.keys():
				dict[str(key)] = _value_to_json(value[key])
			return dict
		_:
			return value
