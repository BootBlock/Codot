## Advanced Node Operations Module
## Handles signals, methods, groups, and introspection.
extends "command_base.gd"


# =============================================================================
# Signal Operations
# =============================================================================

## List all signals on a node.
## [br][br]
## [param params]: Must contain 'path' (String) - node path.
func cmd_list_node_signals(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var signals: Array = []
	for sig in node.get_signal_list():
		var signal_info = {
			"name": sig["name"],
			"args": []
		}
		for arg in sig["args"]:
			signal_info["args"].append({
				"name": arg["name"],
				"type": type_string(arg["type"])
			})
		signals.append(signal_info)
	
	return _success(cmd_id, {
		"path": node_path,
		"signals": signals,
		"count": signals.size()
	})


## Emit a signal on a node.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'signal' (String, required): Signal name to emit.
## - 'args' (Array, optional): Arguments to pass to signal handlers.
func cmd_emit_signal(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var signal_name: String = params.get("signal", "")
	var args: Array = params.get("args", [])
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if signal_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'signal' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node.has_signal(signal_name):
		return _error(cmd_id, "SIGNAL_NOT_FOUND", "Signal not found: " + signal_name)
	
	node.emit_signal(signal_name, args)
	
	return _success(cmd_id, {
		"emitted": true,
		"path": node_path,
		"signal": signal_name
	})


# =============================================================================
# Method Operations
# =============================================================================

## Call a method on a node.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'method' (String, required): Method name to call.
## - 'args' (Array, optional): Arguments to pass to the method.
func cmd_call_method(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var method_name: String = params.get("method", "")
	var args: Array = params.get("args", [])
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if method_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'method' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node.has_method(method_name):
		return _error(cmd_id, "METHOD_NOT_FOUND", "Method not found: " + method_name)
	
	var call_result = node.callv(method_name, args)
	
	return _success(cmd_id, {
		"called": true,
		"path": node_path,
		"method": method_name,
		"result": str(call_result) if call_result != null else null
	})


## List methods on a node.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'include_inherited' (bool, default false): Include inherited/engine methods.
func cmd_list_node_methods(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var include_inherited: bool = params.get("include_inherited", false)
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	var methods: Array = []
	for method in node.get_method_list():
		# Filter to script methods only if not including inherited
		if not include_inherited:
			var flags = method.get("flags", 0)
			if flags & 64 == 0:  # METHOD_FLAG_FROM_SCRIPT = 64
				continue
		
		var method_info = {
			"name": method["name"],
			"args": [],
			"return_type": type_string(method.get("return", {}).get("type", TYPE_NIL))
		}
		for arg in method.get("args", []):
			method_info["args"].append({
				"name": arg["name"],
				"type": type_string(arg["type"])
			})
		methods.append(method_info)
	
	return _success(cmd_id, {
		"path": node_path,
		"methods": methods,
		"count": methods.size()
	})


# =============================================================================
# Group Operations
# =============================================================================

## Get all nodes that belong to a specific group.
## [br][br]
## [param params]: Must contain 'group' (String) - group name.
func cmd_get_nodes_in_group(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var group_name: String = params.get("group", "")
	if group_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'group' parameter")
	
	var root = _get_scene_root()
	var nodes_in_group: Array = []
	_find_nodes_in_group(root, group_name, nodes_in_group)
	
	var paths: Array = []
	for node in nodes_in_group:
		paths.append(str(root.get_path_to(node)))
	
	return _success(cmd_id, {
		"group": group_name,
		"nodes": paths,
		"count": paths.size()
	})


## Add a node to a group.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'group' (String, required): Group name to add to.
## - 'persistent' (bool, default true): Whether group membership saves with scene.
func cmd_add_node_to_group(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var group_name: String = params.get("group", "")
	var persistent: bool = params.get("persistent", true)
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if group_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'group' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	node.add_to_group(group_name, persistent)
	
	return _success(cmd_id, {
		"added": true,
		"path": node_path,
		"group": group_name
	})


## Remove a node from a group.
## [br][br]
## [param params]:
## - 'path' (String, required): Node path.
## - 'group' (String, required): Group name to remove from.
func cmd_remove_node_from_group(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var group_name: String = params.get("group", "")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if group_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'group' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	node.remove_from_group(group_name)
	
	return _success(cmd_id, {
		"removed": true,
		"path": node_path,
		"group": group_name
	})


# =============================================================================
# Helper Functions
# =============================================================================

## Recursively find nodes in a group.
func _find_nodes_in_group(node: Node, group: String, results: Array) -> void:
	if node.is_in_group(group):
		results.append(node)
	for child in node.get_children():
		_find_nodes_in_group(child, group, results)
