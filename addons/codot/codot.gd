@tool
extends EditorPlugin
## Codot - AI Agent integration for Godot.
##
## This EditorPlugin enables AI agents to control and interact with the
## Godot editor through the Model Context Protocol (MCP). It starts a
## WebSocket server that accepts commands from AI agents and executes
## them in the editor context.
##
## Features:
## - Scene tree inspection and manipulation
## - File read/write operations
## - Game playback control
## - Node creation and property editing
## - GUT test framework integration
## - Input simulation during runtime
##
## @tutorial: https://github.com/your-repo/codot
## @version: 0.1.0

## Default port for the WebSocket server.
const DEFAULT_PORT: int = 6850

## Autoload name for the runtime output capture
const OUTPUT_CAPTURE_AUTOLOAD: String = "CodotOutputCapture"

## WebSocket server instance.
var _server: Node = null

## Command handler instance.
var _handler: Node = null

## Debugger plugin for capturing runtime errors.
var _debugger_plugin: EditorDebuggerPlugin = null

## Whether we've added the output capture autoload
var _output_capture_added: bool = false

## AI Chat dock for sending prompts to VS Code
var _ai_chat_dock: Control = null


## Called when the plugin enters the scene tree.
## Initializes the WebSocket server and command handler.
func _enter_tree() -> void:
	print("[Codot] Loading plugin...")
	_initialize()
	_setup_output_capture_autoload()
	_setup_ai_chat_dock()


## Called when the plugin exits the scene tree.
## Cleans up server and handler resources.
func _exit_tree() -> void:
	_cleanup()
	_remove_output_capture_autoload()
	_remove_ai_chat_dock()
	print("[Codot] Plugin unloaded")


## Initialize the plugin components.
## Creates and configures the WebSocket server and command handler.
func _initialize() -> void:
	# Load and create debugger plugin first
	var debugger_script = load("res://addons/codot/debugger_plugin.gd")
	if debugger_script != null:
		_debugger_plugin = debugger_script.new()
		add_debugger_plugin(_debugger_plugin)
		print("[Codot] Debugger plugin registered")
	else:
		push_warning("[Codot] Could not load debugger_plugin.gd - debug capture disabled")
	
	# Load and create WebSocket server
	var ws_script = load("res://addons/codot/websocket_server.gd")
	if ws_script == null:
		push_error("[Codot] Failed to load websocket_server.gd")
		return
	
	_server = ws_script.new()
	add_child(_server)
	
	# Load and create command handler
	var handler_script = load("res://addons/codot/command_handler.gd")
	if handler_script == null:
		push_error("[Codot] Failed to load command_handler.gd")
		return
	
	_handler = handler_script.new()
	_handler.editor_interface = get_editor_interface()
	_handler.debugger_plugin = _debugger_plugin  # Pass debugger reference
	add_child(_handler)
	
	# Connect signals
	if _server.has_signal("command_received"):
		_server.command_received.connect(_on_command_received)
	
	# Start server
	var err: int = _server.start(DEFAULT_PORT)
	if err == OK:
		print("[Codot] Server started on port ", DEFAULT_PORT)
	else:
		push_error("[Codot] Failed to start server: ", err)


func _cleanup() -> void:
	if _debugger_plugin != null:
		remove_debugger_plugin(_debugger_plugin)
		_debugger_plugin = null
	if _handler != null:
		_handler.queue_free()
		_handler = null
	if _server != null:
		_server.stop()
		_server.queue_free()
		_server = null


func _on_command_received(client_id: int, command: Dictionary) -> void:
	if _handler == null or _server == null:
		return
	var response = await _handler.handle_command(command)
	if response is Dictionary:
		_server.send_response(client_id, response)
	else:
		# Should not happen, but just in case
		_server.send_response(client_id, {"id": command.get("id"), "success": false, "error": {"code": "INTERNAL_ERROR", "message": "Invalid response type"}})


## Setup the output capture autoload so it runs in the game.
## This allows the running game to send debug messages back to the editor.
func _setup_output_capture_autoload() -> void:
	# Check if it already exists
	if ProjectSettings.has_setting("autoload/" + OUTPUT_CAPTURE_AUTOLOAD):
		_output_capture_added = false  # We didn't add it, don't remove it
		print("[Codot] Output capture autoload already configured")
		return
	
	# Add the autoload
	var script_path := "res://addons/codot/output_capture.gd"
	if not FileAccess.file_exists(script_path.replace("res://", "")):
		# Check if it exists using the resource path
		if not ResourceLoader.exists(script_path):
			push_warning("[Codot] Output capture script not found at: ", script_path)
			return
	
	ProjectSettings.set_setting("autoload/" + OUTPUT_CAPTURE_AUTOLOAD, script_path)
	ProjectSettings.save()
	_output_capture_added = true
	print("[Codot] Output capture autoload configured: ", script_path)


## Remove the output capture autoload if we added it.
func _remove_output_capture_autoload() -> void:
	if not _output_capture_added:
		return
	
	if ProjectSettings.has_setting("autoload/" + OUTPUT_CAPTURE_AUTOLOAD):
		ProjectSettings.set_setting("autoload/" + OUTPUT_CAPTURE_AUTOLOAD, null)
		ProjectSettings.save()
		print("[Codot] Output capture autoload removed")


## Setup the AI Chat dock panel.
func _setup_ai_chat_dock() -> void:
	var dock_script = load("res://addons/codot/ai_chat_dock.gd")
	if dock_script == null:
		push_warning("[Codot] Could not load ai_chat_dock.gd")
		return
	
	_ai_chat_dock = dock_script.new()
	_ai_chat_dock.name = "AI Chat"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _ai_chat_dock)
	print("[Codot] AI Chat dock added")


## Remove the AI Chat dock panel.
func _remove_ai_chat_dock() -> void:
	if _ai_chat_dock != null:
		remove_control_from_docks(_ai_chat_dock)
		_ai_chat_dock.queue_free()
		_ai_chat_dock = null
		print("[Codot] AI Chat dock removed")
