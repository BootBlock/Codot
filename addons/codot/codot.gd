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
## - Prompt management panel for AI workflows
##
## @tutorial: https://github.com/your-repo/codot
## @version: 0.2.0

const CodotSettingsClass := preload("res://addons/codot/codot_settings.gd")

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

## Codot prompt management panel
var _codot_panel: Control = null


## Called when the plugin enters the scene tree.
## Initializes the WebSocket server, command handler, and UI.
func _enter_tree() -> void:
	print("[Codot] Loading plugin...")
	CodotSettingsClass.register_settings()
	_initialize()
	_setup_output_capture_autoload()
	_setup_codot_panel()
	_add_menu_items()


## Called when the plugin exits the scene tree.
## Cleans up server and handler resources.
func _exit_tree() -> void:
	_remove_menu_items()
	_cleanup()
	_remove_output_capture_autoload()
	_remove_codot_panel()
	print("[Codot] Plugin unloaded")


## Initialize the plugin components.
## Creates and configures the WebSocket server and command handler.
func _initialize() -> void:
	# Load and create debugger plugin first (if enabled)
	if CodotSettingsClass.is_feature_enabled("debug_capture"):
		var debugger_script := load("res://addons/codot/debugger_plugin.gd")
		if debugger_script != null:
			_debugger_plugin = debugger_script.new()
			add_debugger_plugin(_debugger_plugin)
			print("[Codot] Debugger plugin registered")
		else:
			push_warning("[Codot] Could not load debugger_plugin.gd - debug capture disabled")
	else:
		print("[Codot] Debug capture disabled in settings")
	
	# Skip WebSocket server if disabled
	if not CodotSettingsClass.is_feature_enabled("websocket_server"):
		print("[Codot] WebSocket server disabled in settings")
		return
	
	# Load and create WebSocket server
	var ws_script := load("res://addons/codot/websocket_server.gd")
	if ws_script == null:
		push_error("[Codot] Failed to load websocket_server.gd")
		return
	
	_server = ws_script.new()
	add_child(_server)
	
	# Load and create command handler
	var handler_script := load("res://addons/codot/command_handler.gd")
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
	
	# Start server with configured port
	var port: int = CodotSettingsClass.get_setting("mcp_server_port", DEFAULT_PORT)
	var err: int = _server.start(port)
	if err == OK:
		print("[Codot] Server started on port ", port)
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


## Setup the Codot prompt management panel.
func _setup_codot_panel() -> void:
	if not CodotSettingsClass.is_feature_enabled("prompt_panel"):
		print("[Codot] Prompt panel disabled in settings")
		return
	
	var panel_scene := load("res://addons/codot/codot_panel.tscn")
	if panel_scene == null:
		push_warning("[Codot] Could not load codot_panel.tscn")
		return
	
	_codot_panel = panel_scene.instantiate()
	_codot_panel.name = "Codot"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _codot_panel)
	print("[Codot] Codot panel added")


## Remove the Codot panel.
func _remove_codot_panel() -> void:
	if _codot_panel != null:
		remove_control_from_docks(_codot_panel)
		_codot_panel.queue_free()
		_codot_panel = null
		print("[Codot] Codot panel removed")


## Add items to the editor's Debug menu.
func _add_menu_items() -> void:
	add_tool_menu_item("Codot: Open Settings", _on_open_settings_menu)
	add_tool_menu_item("Codot: Reconnect to VS Code", _on_reconnect_menu)
	add_tool_menu_item("Codot: Restart MCP Server", _on_restart_server_menu)


## Remove items from the editor's Debug menu.
func _remove_menu_items() -> void:
	remove_tool_menu_item("Codot: Open Settings")
	remove_tool_menu_item("Codot: Reconnect to VS Code")
	remove_tool_menu_item("Codot: Restart MCP Server")


## Menu callback: Open Codot settings.
func _on_open_settings_menu() -> void:
	# Open editor settings and try to focus on plugin settings
	EditorInterface.get_editor_settings()
	# Note: There's no direct API to scroll to a specific setting section
	print("[Codot] Settings are in: Editor > Editor Settings > Plugin > Codot")


## Menu callback: Reconnect to VS Code.
func _on_reconnect_menu() -> void:
	if _codot_panel and _codot_panel.has_method("_on_reconnect_pressed"):
		_codot_panel._on_reconnect_pressed()
		print("[Codot] Reconnecting to VS Code...")


## Menu callback: Restart the MCP server.
func _on_restart_server_menu() -> void:
	if _server != null:
		_server.stop()
		var port: int = CodotSettingsClass.get_setting("mcp_server_port", DEFAULT_PORT)
		var err: int = _server.start(port)
		if err == OK:
			print("[Codot] MCP Server restarted on port ", port)
		else:
			push_error("[Codot] Failed to restart server: ", err)
