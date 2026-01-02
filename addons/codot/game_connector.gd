class_name CodotGameConnector
extends Node
## This script runs inside the game (not the editor) to enable communication
## with the Codot plugin. It should be added as an autoload.
##
## This allows real-time access to the running game's scene tree, variables,
## and enables input simulation within the game context.

signal connected_to_editor
signal disconnected_from_editor
signal command_received(command: Dictionary)

const DEFAULT_PORT := 6850
const SETTINGS_PORT := "codot/network/port"

var _websocket: WebSocketPeer
var _is_connected: bool = false
var _reconnect_timer: Timer


func _ready() -> void:
	# Don't run in editor
	if Engine.is_editor_hint():
		queue_free()
		return
	
	_setup_reconnect_timer()
	_connect_to_editor()
	
	# Register ourselves for easy access
	Engine.register_singleton("CodotGame", self)


func _exit_tree() -> void:
	if Engine.has_singleton("CodotGame"):
		Engine.unregister_singleton("CodotGame")
	_disconnect_from_editor()


func _process(_delta: float) -> void:
	if not _websocket:
		return
	
	_websocket.poll()
	
	var state := _websocket.get_ready_state()
	
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _is_connected:
				_is_connected = true
				_on_connected()
			
			while _websocket.get_available_packet_count() > 0:
				var packet := _websocket.get_packet()
				_handle_packet(packet)
		
		WebSocketPeer.STATE_CLOSED:
			if _is_connected:
				_is_connected = false
				_on_disconnected()
				_schedule_reconnect()


func _setup_reconnect_timer() -> void:
	_reconnect_timer = Timer.new()
	_reconnect_timer.wait_time = 2.0
	_reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(_connect_to_editor)
	add_child(_reconnect_timer)


func _connect_to_editor() -> void:
	if _websocket:
		_websocket = null
	
	_websocket = WebSocketPeer.new()
	var port: int = ProjectSettings.get_setting(SETTINGS_PORT, DEFAULT_PORT)
	var error := _websocket.connect_to_url("ws://127.0.0.1:%d" % port)
	
	if error != OK:
		print("[Codot] Failed to connect to editor: ", error)
		_schedule_reconnect()


func _disconnect_from_editor() -> void:
	if _websocket:
		_websocket.close()
		_websocket = null
	_is_connected = false


func _schedule_reconnect() -> void:
	if not _reconnect_timer.is_stopped():
		return
	_reconnect_timer.start()


func _on_connected() -> void:
	print("[Codot] Connected to editor")
	connected_to_editor.emit()
	
	# Send initial game state
	send_message({
		"type": "game_connected",
		"data": {
			"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
			"timestamp": Time.get_unix_time_from_system()
		}
	})


func _on_disconnected() -> void:
	print("[Codot] Disconnected from editor")
	disconnected_from_editor.emit()


func _handle_packet(packet: PackedByteArray) -> void:
	var text := packet.get_string_from_utf8()
	var json := JSON.new()
	
	if json.parse(text) != OK:
		push_error("[Codot] Invalid JSON received: %s" % json.get_error_message())
		return
	
	var message: Dictionary = json.data
	if not message is Dictionary:
		return
	
	var msg_type: String = message.get("type", "")
	var command: Dictionary = message.get("command", {})
	
	if msg_type == "command" and not command.is_empty():
		var response := _handle_command(command)
		send_message({
			"type": "response",
			"id": command.get("id"),
			"data": response
		})
	
	command_received.emit(message)


func _handle_command(command: Dictionary) -> Dictionary:
	var cmd_name: String = command.get("command", "")
	var params: Dictionary = command.get("params", {})
	
	match cmd_name:
		"get_scene_tree":
			return _cmd_get_scene_tree(params)
		"get_node_info":
			return _cmd_get_node_info(params)
		"call_method":
			return _cmd_call_method(params)
		"get_variable":
			return _cmd_get_variable(params)
		"set_variable":
			return _cmd_set_variable(params)
		"simulate_action":
			return _cmd_simulate_action(params)
		_:
			return {"error": {"code": "UNKNOWN_COMMAND", "message": "Unknown command: %s" % cmd_name}}


func send_message(message: Dictionary) -> void:
	if not _websocket or _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	
	var json_string := JSON.stringify(message)
	_websocket.send_text(json_string)


func send_log(level: String, message: String, source: String = "") -> void:
	send_message({
		"type": "log",
		"data": {
			"level": level,
			"message": message,
			"source": source,
			"timestamp": Time.get_unix_time_from_system()
		}
	})


func send_error(message: String, stack_trace: Array = []) -> void:
	send_message({
		"type": "error",
		"data": {
			"message": message,
			"stack_trace": stack_trace,
			"timestamp": Time.get_unix_time_from_system()
		}
	})


# ============================================================================
# COMMAND HANDLERS
# ============================================================================

func _cmd_get_scene_tree(params: Dictionary) -> Dictionary:
	var max_depth: int = params.get("max_depth", 10)
	var root := get_tree().current_scene
	
	if not root:
		return {"error": {"code": "NO_SCENE", "message": "No scene currently running"}}
	
	return {
		"success": true,
		"tree": _serialize_node(root, max_depth)
	}


func _cmd_get_node_info(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("path", "")
	
	if node_path.is_empty():
		return {"error": {"code": "MISSING_PARAM", "message": "path is required"}}
	
	var root := get_tree().current_scene
	if not root:
		return {"error": {"code": "NO_SCENE", "message": "No scene currently running"}}
	
	var node := root.get_node_or_null(node_path)
	if not node:
		return {"error": {"code": "NODE_NOT_FOUND", "message": "Node not found: %s" % node_path}}
	
	return {
		"success": true,
		"node": _serialize_node_detailed(node)
	}


func _cmd_call_method(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("path", "")
	var method_name: String = params.get("method", "")
	var args: Array = params.get("args", [])
	
	if node_path.is_empty() or method_name.is_empty():
		return {"error": {"code": "MISSING_PARAM", "message": "path and method are required"}}
	
	var root := get_tree().current_scene
	if not root:
		return {"error": {"code": "NO_SCENE", "message": "No scene currently running"}}
	
	var node := root.get_node_or_null(node_path)
	if not node:
		return {"error": {"code": "NODE_NOT_FOUND", "message": "Node not found: %s" % node_path}}
	
	if not node.has_method(method_name):
		return {"error": {"code": "METHOD_NOT_FOUND", "message": "Method not found: %s" % method_name}}
	
	var result = node.callv(method_name, args)
	var result_str: Variant = null
	if result != null:
		result_str = str(result)
	
	return {
		"success": true,
		"result": result_str
	}


func _cmd_get_variable(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("path", "")
	var variable_name: String = params.get("variable", "")
	
	if node_path.is_empty() or variable_name.is_empty():
		return {"error": {"code": "MISSING_PARAM", "message": "path and variable are required"}}
	
	var root := get_tree().current_scene
	if not root:
		return {"error": {"code": "NO_SCENE", "message": "No scene currently running"}}
	
	var node := root.get_node_or_null(node_path)
	if not node:
		return {"error": {"code": "NODE_NOT_FOUND", "message": "Node not found: %s" % node_path}}
	
	if not variable_name in node:
		return {"error": {"code": "VARIABLE_NOT_FOUND", "message": "Variable not found: %s" % variable_name}}
	
	var value = node.get(variable_name)
	
	return {
		"success": true,
		"value": _serialize_value(value)
	}


func _cmd_set_variable(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("path", "")
	var variable_name: String = params.get("variable", "")
	
	if node_path.is_empty() or variable_name.is_empty():
		return {"error": {"code": "MISSING_PARAM", "message": "path, variable, and value are required"}}
	if not params.has("value"):
		return {"error": {"code": "MISSING_PARAM", "message": "path, variable, and value are required"}}
	
	var value = params.get("value", null)  # null is valid after has() check
	
	var root := get_tree().current_scene
	if not root:
		return {"error": {"code": "NO_SCENE", "message": "No scene currently running"}}
	
	var node := root.get_node_or_null(node_path)
	if not node:
		return {"error": {"code": "NODE_NOT_FOUND", "message": "Node not found: %s" % node_path}}
	
	node.set(variable_name, value)
	
	return {
		"success": true
	}


func _cmd_simulate_action(params: Dictionary) -> Dictionary:
	var action_name: String = params.get("action", "")
	var pressed: bool = params.get("pressed", true)
	var strength: float = params.get("strength", 1.0)
	
	if action_name.is_empty():
		return {"error": {"code": "MISSING_PARAM", "message": "action is required"}}
	
	if not InputMap.has_action(action_name):
		return {"error": {"code": "INVALID_ACTION", "message": "Unknown action: %s" % action_name}}
	
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = strength
	Input.parse_input_event(event)
	
	return {
		"success": true,
		"action": action_name,
		"pressed": pressed
	}


# ============================================================================
# SERIALIZATION HELPERS
# ============================================================================

func _serialize_node(node: Node, max_depth: int, current_depth: int = 0) -> Dictionary:
	var data := {
		"name": node.name,
		"class": node.get_class(),
		"path": str(node.get_path())
	}
	
	if current_depth < max_depth and node.get_child_count() > 0:
		var children: Array = []
		for child in node.get_children():
			children.append(_serialize_node(child, max_depth, current_depth + 1))
		data["children"] = children
	
	return data


func _serialize_node_detailed(node: Node) -> Dictionary:
	var data := {
		"name": node.name,
		"class": node.get_class(),
		"path": str(node.get_path()),
		"visible": node.is_visible() if node is CanvasItem or node is Node3D else true,
		"process_mode": node.process_mode,
		"script": node.get_script().resource_path if node.get_script() else null,
		"groups": node.get_groups(),
		"properties": {}
	}
	
	# Get interesting properties based on node type
	if node is Node2D:
		data["position"] = {"x": node.position.x, "y": node.position.y}
		data["rotation"] = node.rotation
		data["scale"] = {"x": node.scale.x, "y": node.scale.y}
	elif node is Node3D:
		data["position"] = {"x": node.position.x, "y": node.position.y, "z": node.position.z}
		data["rotation"] = {"x": node.rotation.x, "y": node.rotation.y, "z": node.rotation.z}
		data["scale"] = {"x": node.scale.x, "y": node.scale.y, "z": node.scale.z}
	
	# Get script variables
	if node.get_script():
		for prop in node.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var value = node.get(prop.name)
				data.properties[prop.name] = _serialize_value(value)
	
	return data


func _serialize_value(value: Variant) -> Variant:
	if value == null:
		return null
	elif value is bool or value is int or value is float or value is String:
		return value
	elif value is Vector2:
		return {"_type": "Vector2", "x": value.x, "y": value.y}
	elif value is Vector3:
		return {"_type": "Vector3", "x": value.x, "y": value.y, "z": value.z}
	elif value is Color:
		return {"_type": "Color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
	elif value is Array:
		var arr := []
		for item in value:
			arr.append(_serialize_value(item))
		return arr
	elif value is Dictionary:
		var dict := {}
		for key in value:
			dict[str(key)] = _serialize_value(value[key])
		return dict
	elif value is Node:
		return {"_type": "Node", "path": str(value.get_path())}
	elif value is Resource:
		return {"_type": "Resource", "path": value.resource_path}
	else:
		return str(value)
