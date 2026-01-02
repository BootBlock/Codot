@tool
extends "command_base.gd"
## Batch and compound commands for Codot.
##
## Provides commands that perform multiple operations in a single call:
## - batch_commands: Execute multiple commands in sequence
## - bulk_set_properties: Set multiple properties on nodes at once
## - create_complete_scene: Create a full scene with nodes and scripts


## Reference to command handler for executing sub-commands
var _command_handler: Object = null


## Initialize with command handler reference
func set_command_handler(handler: Object) -> void:
	_command_handler = handler


## Execute multiple commands in sequence.
## [br][br]
## [param params]:
## - 'commands' (Array, required): Array of command objects, each with {command, params}.
## - 'stop_on_error' (bool, default true): Stop execution if a command fails.
## - 'return_all_results' (bool, default false): Return results from all commands.
func cmd_batch_commands(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var commands: Array = params.get("commands", [])
	if commands.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'commands' array")
	
	var stop_on_error: bool = params.get("stop_on_error", true)
	var return_all_results: bool = params.get("return_all_results", false)
	
	if _command_handler == null:
		return _error(cmd_id, "NO_HANDLER", "Command handler not available")
	
	var results: Array = []
	var executed := 0
	var failed := 0
	var last_result: Dictionary = {}
	
	for i in range(commands.size()):
		var cmd: Dictionary = commands[i]
		var cmd_name: String = cmd.get("command", "")
		var cmd_params: Dictionary = cmd.get("params", {})
		
		if cmd_name.is_empty():
			if stop_on_error:
				return _error(cmd_id, "INVALID_COMMAND", "Command at index %d missing 'command' name" % i)
			results.append({"index": i, "success": false, "error": "Missing command name"})
			failed += 1
			continue
		
		# Build the command request
		var request := {
			"id": "%s_%d" % [str(cmd_id), i],
			"command": cmd_name,
			"params": cmd_params
		}
		
		# Execute through command handler
		var result: Dictionary = await _command_handler.handle_command(request)
		executed += 1
		
		if return_all_results:
			results.append({
				"index": i,
				"command": cmd_name,
				"success": result.get("success", false),
				"result": result.get("result", {}),
				"error": result.get("error", {})
			})
		
		if not result.get("success", false):
			failed += 1
			last_result = result
			if stop_on_error:
				return _error(cmd_id, "BATCH_FAILED", 
					"Command '%s' at index %d failed: %s" % [
						cmd_name, i, result.get("error", {}).get("message", "Unknown error")
					])
		else:
			last_result = result
	
	var response := {
		"executed": executed,
		"failed": failed,
		"success": failed == 0
	}
	
	if return_all_results:
		response["results"] = results
	else:
		response["last_result"] = last_result.get("result", {})
	
	return _success(cmd_id, response)


## Set multiple properties on one or more nodes.
## [br][br]
## [param params]:
## - 'operations' (Array, required): Array of {node_path, property, value} or {node_path, properties: {prop: value}}.
## - 'stop_on_error' (bool, default false): Stop if a property set fails.
func cmd_bulk_set_properties(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var operations: Array = params.get("operations", [])
	if operations.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'operations' array")
	
	var stop_on_error: bool = params.get("stop_on_error", false)
	
	var result := _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var root := _get_scene_root()
	if root == null:
		return _error(cmd_id, "NO_SCENE", "No scene root available")
	
	var set_count := 0
	var errors: Array = []
	
	for op in operations:
		var node_path: String = op.get("node_path", "")
		if node_path.is_empty():
			if stop_on_error:
				return _error(cmd_id, "INVALID_OP", "Operation missing 'node_path'")
			errors.append({"error": "Missing node_path"})
			continue
		
		var node := root.get_node_or_null(node_path)
		if node == null:
			if stop_on_error:
				return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
			errors.append({"node_path": node_path, "error": "Node not found"})
			continue
		
		# Handle single property or multiple properties
		var properties: Dictionary = {}
		if op.has("properties"):
			properties = op.get("properties", {})
		elif op.has("property") and op.has("value"):
			properties[op.get("property")] = op.get("value")
		else:
			if stop_on_error:
				return _error(cmd_id, "INVALID_OP", "Operation needs 'properties' dict or 'property'/'value' pair")
			errors.append({"node_path": node_path, "error": "Invalid property specification"})
			continue
		
		# Set each property
		for prop: String in properties:
			var value: Variant = properties[prop]
			
			# Convert value if needed
			var converted_value := _convert_property_value(node, prop, value)
			
			if node.get(prop) != null or prop in node:
				node.set(prop, converted_value)
				set_count += 1
			else:
				if stop_on_error:
					return _error(cmd_id, "INVALID_PROPERTY", "Property '%s' not found on %s" % [prop, node_path])
				errors.append({"node_path": node_path, "property": prop, "error": "Property not found"})
	
	return _success(cmd_id, {
		"set_count": set_count,
		"error_count": errors.size(),
		"errors": errors if errors.size() > 0 else []
	})


## Create a complete scene with nodes and optionally scripts.
## [br][br]
## [param params]:
## - 'scene_path' (String, required): Path to save the scene.
## - 'root_type' (String, default "Node2D"): Type of the root node.
## - 'root_name' (String, default from path): Name of the root node.
## - 'nodes' (Array, optional): Array of node definitions to create.
##   Each node: {type, name, parent (relative path), properties: {}}
## - 'save' (bool, default true): Save the scene after creation.
func cmd_create_complete_scene(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var scene_path: String = params.get("scene_path", "")
	if scene_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'scene_path' parameter")
	
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"
	
	var root_type: String = params.get("root_type", "Node2D")
	var root_name: String = params.get("root_name", scene_path.get_file().get_basename().to_pascal_case())
	var nodes_def: Array = params.get("nodes", [])
	var should_save: bool = params.get("save", true)
	
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "EditorInterface not available")
	
	# Create root node
	var root_class := ClassDB.class_exists(root_type)
	if not root_class:
		return _error(cmd_id, "INVALID_TYPE", "Unknown node type: " + root_type)
	
	var root: Node = ClassDB.instantiate(root_type) as Node
	if root == null:
		return _error(cmd_id, "CREATE_FAILED", "Failed to instantiate root node: " + root_type)
	
	root.name = root_name
	
	var created_nodes := [root_name]
	var errors: Array = []
	
	# Create child nodes
	for node_def in nodes_def:
		var node_type: String = node_def.get("type", "Node")
		var node_name: String = node_def.get("name", "")
		var parent_path: String = node_def.get("parent", ".")
		var properties: Dictionary = node_def.get("properties", {})
		
		if node_name.is_empty():
			errors.append({"error": "Node definition missing 'name'"})
			continue
		
		if not ClassDB.class_exists(node_type):
			errors.append({"name": node_name, "error": "Unknown type: " + node_type})
			continue
		
		var node: Node = ClassDB.instantiate(node_type) as Node
		if node == null:
			errors.append({"name": node_name, "error": "Failed to instantiate"})
			continue
		
		node.name = node_name
		
		# Set properties
		for prop: String in properties:
			var value: Variant = properties[prop]
			var converted := _convert_property_value(node, prop, value)
			if prop in node or node.get(prop) != null:
				node.set(prop, converted)
		
		# Find parent and add
		var parent_node: Node = root
		if parent_path != "." and parent_path != "":
			parent_node = root.get_node_or_null(parent_path)
			if parent_node == null:
				# Try adding to root if parent not found
				parent_node = root
				errors.append({"name": node_name, "warning": "Parent '%s' not found, added to root" % parent_path})
		
		parent_node.add_child(node)
		node.owner = root
		created_nodes.append(node_name)
	
	# Pack the scene
	var packed_scene := PackedScene.new()
	var pack_result := packed_scene.pack(root)
	
	if pack_result != OK:
		root.queue_free()
		return _error(cmd_id, "PACK_FAILED", "Failed to pack scene: " + error_string(pack_result))
	
	# Save the scene
	if should_save:
		# Ensure directory exists
		var dir_path := scene_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
		
		var save_result := ResourceSaver.save(packed_scene, scene_path)
		if save_result != OK:
			root.queue_free()
			return _error(cmd_id, "SAVE_FAILED", "Failed to save scene: " + error_string(save_result))
		
		# Refresh filesystem
		editor_interface.get_resource_filesystem().scan()
	
	root.queue_free()
	
	return _success(cmd_id, {
		"scene_path": scene_path,
		"root_type": root_type,
		"root_name": root_name,
		"nodes_created": created_nodes,
		"node_count": created_nodes.size(),
		"saved": should_save,
		"errors": errors if errors.size() > 0 else []
	})


## Create a scene with a script attached to the root node.
## [br][br]
## [param params]:
## - 'scene_path' (String, required): Path to save the scene.
## - 'script_content' (String, required): GDScript content for the script.
## - 'root_type' (String, default "Node2D"): Type of the root node.
## - 'root_name' (String, optional): Name of the root node.
func cmd_create_scene_with_script(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var scene_path: String = params.get("scene_path", "")
	if scene_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'scene_path' parameter")
	
	var script_content: String = params.get("script_content", "")
	if script_content.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'script_content' parameter")
	
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"
	
	var script_path := scene_path.replace(".tscn", ".gd")
	var root_type: String = params.get("root_type", "Node2D")
	var root_name: String = params.get("root_name", scene_path.get_file().get_basename().to_pascal_case())
	
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "EditorInterface not available")
	
	# Create and save the script first
	var script := GDScript.new()
	script.source_code = script_content
	
	# Ensure directory exists
	var dir_path := script_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	var script_save := ResourceSaver.save(script, script_path)
	if script_save != OK:
		return _error(cmd_id, "SCRIPT_SAVE_FAILED", "Failed to save script: " + error_string(script_save))
	
	# Create root node
	if not ClassDB.class_exists(root_type):
		return _error(cmd_id, "INVALID_TYPE", "Unknown node type: " + root_type)
	
	var root: Node = ClassDB.instantiate(root_type) as Node
	if root == null:
		return _error(cmd_id, "CREATE_FAILED", "Failed to instantiate root node: " + root_type)
	
	root.name = root_name
	
	# Load and attach the script
	var loaded_script := load(script_path) as Script
	if loaded_script:
		root.set_script(loaded_script)
	
	# Pack and save the scene
	var packed_scene := PackedScene.new()
	var pack_result := packed_scene.pack(root)
	
	if pack_result != OK:
		root.queue_free()
		return _error(cmd_id, "PACK_FAILED", "Failed to pack scene: " + error_string(pack_result))
	
	var save_result := ResourceSaver.save(packed_scene, scene_path)
	if save_result != OK:
		root.queue_free()
		return _error(cmd_id, "SAVE_FAILED", "Failed to save scene: " + error_string(save_result))
	
	# Refresh filesystem
	editor_interface.get_resource_filesystem().scan()
	
	root.queue_free()
	
	return _success(cmd_id, {
		"scene_path": scene_path,
		"script_path": script_path,
		"root_type": root_type,
		"root_name": root_name
	})


#region Helper Functions

## Convert a value to the appropriate type for a property
func _convert_property_value(node: Node, property: String, value: Variant) -> Variant:
	# Get property info to determine expected type
	var prop_list := node.get_property_list()
	for prop in prop_list:
		if prop.name == property:
			var prop_type: int = prop.type
			
			match prop_type:
				TYPE_VECTOR2:
					if value is Array and value.size() >= 2:
						return Vector2(value[0], value[1])
					elif value is Dictionary:
						return Vector2(value.get("x", 0), value.get("y", 0))
				TYPE_VECTOR3:
					if value is Array and value.size() >= 3:
						return Vector3(value[0], value[1], value[2])
					elif value is Dictionary:
						return Vector3(value.get("x", 0), value.get("y", 0), value.get("z", 0))
				TYPE_COLOR:
					if value is Array and value.size() >= 3:
						var a: float = value[3] if value.size() > 3 else 1.0
						return Color(value[0], value[1], value[2], a)
					elif value is Dictionary:
						return Color(value.get("r", 0), value.get("g", 0), value.get("b", 0), value.get("a", 1))
					elif value is String:
						return Color.from_string(value, Color.WHITE)
				TYPE_RECT2:
					if value is Array and value.size() >= 4:
						return Rect2(value[0], value[1], value[2], value[3])
					elif value is Dictionary:
						return Rect2(value.get("x", 0), value.get("y", 0), value.get("w", 0), value.get("h", 0))
				TYPE_TRANSFORM2D:
					if value is Dictionary:
						var origin := Vector2(value.get("origin_x", 0), value.get("origin_y", 0))
						var rotation: float = value.get("rotation", 0)
						var scale := Vector2(value.get("scale_x", 1), value.get("scale_y", 1))
						return Transform2D(rotation, scale, 0, origin)
			break
	
	return value

#endregion
