## Node Manipulation Module
## Handles node creation, deletion, properties, and transformations.
extends "command_base.gd"


## Create a new node in the scene tree.
## [br][br]
## [param params]:
## - 'type' (String, required): Node class name (e.g., "Node2D", "Sprite2D").
## - 'name' (String, optional): Node name (auto-generated if empty).
## - 'parent' (String, default "."): Parent node path.
func cmd_create_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_type: String = params.get("type", "")
	var node_name: String = params.get("name", "")
	var parent_path: String = params.get("parent", ".")
	
	if node_type.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'type' parameter")
	
	var root = _get_scene_root()
	
	# Find parent node
	var parent: Node = root if parent_path == "." else root.get_node_or_null(parent_path)
	if parent == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Parent node not found: " + parent_path)
	
	# Create the node
	var new_node: Node = null
	if ClassDB.class_exists(node_type):
		new_node = ClassDB.instantiate(node_type)
	else:
		return _error(cmd_id, "INVALID_TYPE", "Unknown node type: " + node_type)
	
	if new_node == null:
		return _error(cmd_id, "CREATE_FAILED", "Failed to create node of type: " + node_type)
	
	# Set name if provided
	if not node_name.is_empty():
		new_node.name = node_name
	
	# Add to parent
	parent.add_child(new_node)
	new_node.owner = root
	
	return _success(cmd_id, {
		"created": true,
		"name": new_node.name,
		"type": node_type,
		"path": str(new_node.get_path())
	})


## Delete a node from the scene tree.
## [br][br]
## [param params]: Must contain 'path' (String) - node path to delete.
func cmd_delete_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = _get_scene_root()
	
	# Don't allow deleting the root node
	if node_path == "." or node_path == str(root.get_path()):
		return _error(cmd_id, "INVALID_OPERATION", "Cannot delete the root node")
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var deleted_name = node.name
	node.queue_free()
	
	return _success(cmd_id, {"deleted": true, "name": deleted_name})


## Set a property on a node.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'property' (String, required): Property name.
## - 'value' (Variant, required): Value to set.
func cmd_set_node_property(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var property: String = params.get("property", "")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if property.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'property' parameter")
	if not params.has("value"):
		return _error(cmd_id, "MISSING_PARAM", "Missing 'value' parameter")
	
	var value = params.get("value", null)  # null is valid after has() check
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	# Convert value if needed (e.g., dict to Vector2/Vector3)
	var converted_value = _convert_value(value, node, property)
	
	node.set(property, converted_value)
	
	return _success(cmd_id, {
		"set": true,
		"path": node_path,
		"property": property,
		"value": _value_to_json(node.get(property))
	})


## Rename a node.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'name' (String, required): New name for the node.
func cmd_rename_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var new_name: String = params.get("name", "")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if new_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'name' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var old_name = node.name
	node.name = new_name
	
	return _success(cmd_id, {
		"renamed": true,
		"old_name": old_name,
		"new_name": node.name,
		"new_path": str(node.get_path())
	})


## Move a node to a new parent.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'new_parent' (String, required): New parent node path.
func cmd_move_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var new_parent_path: String = params.get("new_parent", "")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if new_parent_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'new_parent' parameter")
	
	var root = _get_scene_root()
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var new_parent = root if new_parent_path == "." else root.get_node_or_null(new_parent_path)
	if new_parent == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "New parent not found: " + new_parent_path)
	
	# Don't allow moving root or to a child of itself
	if node == root:
		return _error(cmd_id, "INVALID_OPERATION", "Cannot move the root node")
	if new_parent.is_ancestor_of(node) or node == new_parent:
		return _error(cmd_id, "INVALID_OPERATION", "Cannot move node to itself or a descendant")
	
	node.reparent(new_parent)
	
	return _success(cmd_id, {
		"moved": true,
		"new_path": str(node.get_path())
	})


## Duplicate a node.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path to duplicate.
## - 'new_name' (String, optional): Name for the duplicate.
func cmd_duplicate_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var new_name: String = params.get("new_name", "")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = _get_scene_root()
	
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var duplicate = node.duplicate()
	
	# Generate a proper name for the duplicate
	if new_name.is_empty():
		new_name = _generate_unique_name(node.name, node.get_parent())
	duplicate.name = new_name
	
	node.get_parent().add_child(duplicate)
	duplicate.owner = root
	
	# Set ownership for all children recursively
	_set_owner_recursive(duplicate, root)
	
	return _success(cmd_id, {
		"duplicated": true,
		"original": node_path,
		"new_path": str(duplicate.get_path()),
		"new_name": duplicate.name
	})


# =============================================================================
# Helper Functions
# =============================================================================

## Convert a value based on property type.
func _convert_value(value: Variant, node: Node, property: String) -> Variant:
	# Handle resource path strings
	if value is String and value.begins_with("res://"):
		var loaded_resource = load(value)
		if loaded_resource != null:
			return loaded_resource
	
	# Handle inline resource creation via dictionary with "_type" key
	if value is Dictionary and value.has("_type"):
		return _create_resource_from_dict(value)
	
	# Get the expected type from the node's property
	var prop_list = node.get_property_list()
	for prop in prop_list:
		if prop["name"] == property:
			var prop_type = prop["type"]
			if prop_type == TYPE_VECTOR2 and value is Dictionary:
				return Vector2(value.get("x", 0), value.get("y", 0))
			elif prop_type == TYPE_VECTOR3 and value is Dictionary:
				return Vector3(value.get("x", 0), value.get("y", 0), value.get("z", 0))
			elif prop_type == TYPE_COLOR and value is Dictionary:
				return Color(value.get("r", 0), value.get("g", 0), value.get("b", 0), value.get("a", 1))
			elif prop_type == TYPE_OBJECT and value is String and value.begins_with("res://"):
				var res = load(value)
				if res != null:
					return res
			break
	return value


## Create a Resource from a dictionary specification.
func _create_resource_from_dict(spec: Dictionary) -> Resource:
	var type_name: String = spec.get("_type", "")
	if type_name.is_empty():
		return null
	
	var resource: Resource = null
	
	# Create the resource based on type
	match type_name:
		"ShaderMaterial":
			resource = ShaderMaterial.new()
		"ParticleProcessMaterial":
			resource = ParticleProcessMaterial.new()
		"StandardMaterial3D":
			resource = StandardMaterial3D.new()
		"CanvasItemMaterial":
			resource = CanvasItemMaterial.new()
		"Gradient":
			resource = Gradient.new()
		"GradientTexture1D":
			resource = GradientTexture1D.new()
		"GradientTexture2D":
			resource = GradientTexture2D.new()
		"Curve":
			resource = Curve.new()
		"CurveTexture":
			resource = CurveTexture.new()
		_:
			# Try to create via ClassDB
			if ClassDB.class_exists(type_name) and ClassDB.is_parent_class(type_name, "Resource"):
				resource = ClassDB.instantiate(type_name)
	
	if resource == null:
		return null
	
	# Set properties on the resource
	for key in spec.keys():
		if key == "_type":
			continue
		
		var prop_value = spec[key]
		
		# Recursively convert nested resources/values
		if prop_value is String and prop_value.begins_with("res://"):
			prop_value = load(prop_value)
		elif prop_value is Dictionary:
			if prop_value.has("_type"):
				prop_value = _create_resource_from_dict(prop_value)
			elif prop_value.has("x") and prop_value.has("y"):
				if prop_value.has("z"):
					prop_value = Vector3(prop_value.x, prop_value.y, prop_value.z)
				else:
					prop_value = Vector2(prop_value.x, prop_value.y)
			elif prop_value.has("r") and prop_value.has("g") and prop_value.has("b"):
				prop_value = Color(prop_value.r, prop_value.g, prop_value.b, prop_value.get("a", 1.0))
		
		if resource.has_method("set"):
			resource.set(key, prop_value)
	
	return resource


## Generate a unique node name based on siblings.
func _generate_unique_name(base_name: String, parent: Node) -> String:
	var regex = RegEx.new()
	regex.compile("^(.+?)(\\d+)$")
	var result = regex.search(base_name)
	
	var name_part: String
	var start_num: int
	
	if result:
		name_part = result.get_string(1)
		start_num = int(result.get_string(2)) + 1
	else:
		name_part = base_name
		start_num = 2
	
	# Find a unique name
	var candidate = name_part + str(start_num)
	while parent.has_node(candidate):
		start_num += 1
		candidate = name_part + str(start_num)
	
	return candidate


## Set owner recursively for node hierarchy.
func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)


## Convert a value to JSON-safe representation.
func _value_to_json(value: Variant) -> Variant:
	if value == null:
		return null
	elif value is Vector2:
		return {"x": value.x, "y": value.y}
	elif value is Vector2i:
		return {"x": value.x, "y": value.y}
	elif value is Vector3:
		return {"x": value.x, "y": value.y, "z": value.z}
	elif value is Vector3i:
		return {"x": value.x, "y": value.y, "z": value.z}
	elif value is Color:
		return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
	elif value is Rect2:
		return {"position": {"x": value.position.x, "y": value.position.y}, "size": {"x": value.size.x, "y": value.size.y}}
	elif value is Transform2D:
		return {"x": {"x": value.x.x, "y": value.x.y}, "y": {"x": value.y.x, "y": value.y.y}, "origin": {"x": value.origin.x, "y": value.origin.y}}
	elif value is Transform3D:
		return {"basis": str(value.basis), "origin": {"x": value.origin.x, "y": value.origin.y, "z": value.origin.z}}
	elif value is Basis:
		return str(value)
	elif value is NodePath:
		return str(value)
	elif value is Resource:
		return {"_type": value.get_class(), "_path": value.resource_path if value.resource_path else "(embedded)"}
	elif value is Node:
		return {"_node": str(value.get_path())}
	elif value is Array:
		var arr: Array = []
		for item in value:
			arr.append(_value_to_json(item))
		return arr
	elif value is Dictionary:
		var dict: Dictionary = {}
		for key in value:
			dict[str(key)] = _value_to_json(value[key])
		return dict
	elif value is bool or value is int or value is float or value is String:
		return value
	else:
		return str(value)


## Instantiate a scene as a child of a node.
## [br][br]
## [param params]:
## - 'scene' (String, required): Path to the scene file to instantiate.
## - 'parent' (String, optional): Parent node path (default ".").
## - 'name' (String, optional): Name for the instantiated node.
func cmd_instantiate_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var scene_path: String = params.get("scene", "")
	var parent_path: String = params.get("parent", ".")
	var node_name: String = params.get("name", "")
	
	if scene_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'scene' parameter")
	
	# Load the scene
	if not ResourceLoader.exists(scene_path):
		return _error(cmd_id, "SCENE_NOT_FOUND", "Scene file not found: " + scene_path)
	
	var packed_scene: PackedScene = load(scene_path)
	if packed_scene == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load scene: " + scene_path)
	
	# Get root and parent
	var root = _get_scene_root()
	var parent: Node = root if parent_path == "." else root.get_node_or_null(parent_path)
	if parent == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Parent node not found: " + parent_path)
	
	# Instantiate the scene
	var instance: Node = packed_scene.instantiate()
	if instance == null:
		return _error(cmd_id, "INSTANTIATE_FAILED", "Failed to instantiate scene: " + scene_path)
	
	# Set name if provided
	if not node_name.is_empty():
		instance.name = node_name
	
	# Add to parent
	parent.add_child(instance)
	instance.owner = root
	
	# Set owner for all descendants so they're saved with the scene
	_set_owner_recursive(instance, root)
	
	return _success(cmd_id, {
		"instantiated": true,
		"scene": scene_path,
		"name": instance.name,
		"path": str(instance.get_path())
	})


## Get the script attached to a node.
## [br][br]
## [param params]: Must contain 'path' (String) - node path.
func cmd_get_node_script(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = _get_scene_root()
	var node: Node = root if node_path == "." else root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var script = node.get_script()
	if script == null:
		return _success(cmd_id, {
			"node": node_path,
			"has_script": false,
			"script_path": "",
			"script_class": ""
		})
	
	var script_path: String = script.resource_path if script.resource_path else "(embedded)"
	var script_class: String = script.get_class() if script is Script else "unknown"
	
	return _success(cmd_id, {
		"node": node_path,
		"has_script": true,
		"script_path": script_path,
		"script_class": script_class
	})


## Attach a script to a node.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'script' (String, required): Script file path.
func cmd_attach_script(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var script_path: String = params.get("script", "")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if script_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'script' parameter")
	
	var root = _get_scene_root()
	var node: Node = root if node_path == "." else root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	# Load the script
	if not ResourceLoader.exists(script_path):
		return _error(cmd_id, "SCRIPT_NOT_FOUND", "Script file not found: " + script_path)
	
	var script = load(script_path)
	if script == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load script: " + script_path)
	
	if not script is Script:
		return _error(cmd_id, "INVALID_TYPE", "Resource is not a script: " + script_path)
	
	# Attach the script
	node.set_script(script)
	
	return _success(cmd_id, {
		"attached": true,
		"node": node_path,
		"script": script_path
	})


## Detach (remove) the script from a node.
## [br][br]
## [param params]: Must contain 'path' (String) - node path.
func cmd_detach_script(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = _get_scene_root()
	var node: Node = root if node_path == "." else root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var had_script: bool = node.get_script() != null
	node.set_script(null)
	
	return _success(cmd_id, {
		"detached": had_script,
		"node": node_path
	})


## Make an inherited scene node local.
## [br][br]
## This breaks the inheritance link for a node that came from an inherited scene,
## making all its properties editable locally.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path to make local.
func cmd_make_node_local(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = _get_scene_root()
	var node: Node = root if node_path == "." else root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	# Check if this is the root node (can't make root local)
	if node == root:
		return _error(cmd_id, "INVALID_OPERATION", "Cannot make root node local")
	
	# Check if node is from an inherited scene
	var scene_file_path: String = node.scene_file_path
	if scene_file_path.is_empty():
		# Not an instanced scene node - already local
		return _success(cmd_id, {
			"made_local": false,
			"node": node_path,
			"reason": "Node is not from an instanced scene"
		})
	
	# Clear the scene_file_path to make it local
	# This effectively "unlinks" the node from its original scene
	node.scene_file_path = ""
	
	# Also ensure owner is set to current scene root
	node.owner = root
	
	return _success(cmd_id, {
		"made_local": true,
		"node": node_path,
		"original_scene": scene_file_path
	})


## Get node hierarchy information including scene instance status.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
func cmd_get_node_hierarchy_info(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = _get_scene_root()
	var node: Node = root if node_path == "." else root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var hierarchy: Array = []
	var current: Node = node
	
	while current != null:
		var info: Dictionary = {
			"name": current.name,
			"type": current.get_class(),
			"path": str(current.get_path()),
			"is_scene_instance": not current.scene_file_path.is_empty(),
		}
		if not current.scene_file_path.is_empty():
			info["scene_file"] = current.scene_file_path
		if current.owner != null:
			info["owner"] = str(current.owner.get_path())
		
		hierarchy.append(info)
		current = current.get_parent()
	
	return _success(cmd_id, {
		"node": node_path,
		"hierarchy": hierarchy,
		"depth": hierarchy.size()
	})
