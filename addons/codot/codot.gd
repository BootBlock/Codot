@tool
## Main Codot editor plugin.
## Provides a WebSocket-based bridge for AI agents to control the Godot editor.
extends EditorPlugin

const CodotSettingsClass = preload("res://addons/codot/codot_settings.gd")
const DebuggerPluginClass = preload("res://addons/codot/debugger_plugin.gd")

var _server: Node
var _handler: Node
var _debugger_plugin: EditorDebuggerPlugin
var _dock: Control
var _settings: CodotSettingsClass
var _editor_settings: EditorSettings


## Initializes the plugin, starts WebSocket server, and adds the dock panel.
func _enter_tree() -> void:
	# Initialize settings first (so logging knows if it's enabled)
	_settings = CodotSettingsClass.new()
	_editor_settings = EditorInterface.get_editor_settings()
	
	# Connect to settings changes for live updates
	if _editor_settings:
		_editor_settings.settings_changed.connect(_on_settings_changed)
	
	_log("Initializing Codot plugin...")
	
	# Initialize the debugger plugin for capturing game output
	_debugger_plugin = DebuggerPluginClass.new()
	add_debugger_plugin(_debugger_plugin)
	_log("Debugger plugin registered")
	
	# Create and configure WebSocket server
	_server = preload("res://addons/codot/websocket_server.gd").new()
	add_child(_server)
	
	# Create command handler and inject dependencies
	_handler = preload("res://addons/codot/command_handler.gd").new()
	_handler.set_editor_interface(EditorInterface)
	_handler.set_editor_plugin(self)
	_handler.set_debugger_plugin(_debugger_plugin)
	add_child(_handler)
	
	# Connect WebSocket events
	_server.client_connected.connect(_on_client_connected)
	_server.client_disconnected.connect(_on_client_disconnected)
	_server.command_received.connect(_on_command_received)
	
	# Start the server
	var port := _settings.get_setting("websocket_port")
	_server.start(port)
	_log("WebSocket server started on port %d" % port)
	
	# Add the Codot dock panel
	_add_dock_panel()
	
	_log("Codot plugin v%s initialized" % get_plugin_version())


## Cleans up the plugin when disabled.
func _exit_tree() -> void:
	_log("Shutting down Codot plugin...")
	
	# Disconnect from settings changes
	if _editor_settings and _editor_settings.settings_changed.is_connected(_on_settings_changed):
		_editor_settings.settings_changed.disconnect(_on_settings_changed)
	
	# Remove dock panel
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	
	# Stop and remove WebSocket server
	if _server:
		_server.stop()
		_server.queue_free()
		_server = null
	
	# Remove command handler
	if _handler:
		_handler.queue_free()
		_handler = null
	
	# Remove debugger plugin
	if _debugger_plugin:
		remove_debugger_plugin(_debugger_plugin)
		_debugger_plugin = null
	
	_log("Codot plugin shutdown complete")


## Adds the Codot dock panel to the editor.
func _add_dock_panel() -> void:
	var dock_scene = preload("res://addons/codot/codot_panel.tscn")
	_dock = dock_scene.instantiate()
	
	# Connect panel signals
	_dock.settings_requested.connect(_on_settings_requested)
	_dock.send_to_ai_requested.connect(_on_send_to_ai_requested)
	
	# Inject dependencies into the dock
	if _dock.has_method("set_websocket_server"):
		_dock.set_websocket_server(_server)
	
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_log("Codot panel added to dock")


## Handles settings button click from the panel.
func _on_settings_requested() -> void:
	_log("Opening Codot settings...")
	# Open Editor Settings and try to focus on Codot section
	EditorInterface.get_command_palette().open_command_palette()
	# The user can type "Codot" to find the settings
	# Unfortunately there's no direct API to navigate to a specific settings section


## Handles Send to AI button click from the panel.
func _on_send_to_ai_requested(prompt_title: String, prompt_body: String) -> void:
	_log("Sending prompt to AI: %s" % prompt_title)
	
	# Check if VS Code extension WebSocket server is running
	var vscode_port := _settings.get_setting("vscode_port")
	
	# Create a WebSocket client to send the prompt
	var ws := WebSocketPeer.new()
	var url := "ws://127.0.0.1:%d" % vscode_port
	
	var error := ws.connect_to_url(url)
	if error != OK:
		push_warning("[Codot] Could not connect to VS Code extension on port %d. Is the Codot Bridge extension running?" % vscode_port)
		if _dock and _dock.has_method("show_send_error"):
			_dock.show_send_error("Could not connect to VS Code extension on port %d.\nMake sure the Codot Bridge extension is installed and running." % vscode_port)
		return
	
	# We need to poll the connection in a deferred way
	# For now, queue this as a background operation
	_send_prompt_async(ws, prompt_title, prompt_body)


## Sends the prompt asynchronously to the VS Code extension.
func _send_prompt_async(ws: WebSocketPeer, title: String, body: String) -> void:
	# Simple async polling for WebSocket connection
	var timeout := 5.0
	var elapsed := 0.0
	
	while elapsed < timeout:
		ws.poll()
		var state := ws.get_ready_state()
		
		if state == WebSocketPeer.STATE_OPEN:
			# Connected! Send the prompt
			var message := JSON.stringify({
				"type": "prompt",
				"title": title,
				"body": body
			})
			ws.send_text(message)
			_log("Prompt sent to VS Code extension")
			
			if _dock and _dock.has_method("show_send_success"):
				_dock.show_send_success()
			
			ws.close()
			return
		elif state == WebSocketPeer.STATE_CLOSED or state == WebSocketPeer.STATE_CLOSING:
			break
		
		# Wait a bit and try again
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	# Failed to connect
	push_warning("[Codot] Timed out connecting to VS Code extension")
	if _dock and _dock.has_method("show_send_error"):
		_dock.show_send_error("Connection timed out. Make sure the Codot Bridge extension is running in VS Code.")


## Called when editor settings change.
func _on_settings_changed() -> void:
	# Notify dock panel about settings changes
	if _dock and _dock.has_method("on_settings_changed"):
		_dock.on_settings_changed()
	
	# Update WebSocket port if changed (would require restart though)
	# For now, just log that settings changed
	if _settings.is_feature_enabled("debug_logging"):
		print("[Codot] Settings updated")


## Handles a new WebSocket client connection.
func _on_client_connected(client_id: int) -> void:
	_log("Client connected: %d" % client_id)
	_update_dock_status()


## Handles a WebSocket client disconnection.
func _on_client_disconnected(client_id: int) -> void:
	_log("Client disconnected: %d" % client_id)
	_update_dock_status()


## Handles an incoming command from a WebSocket client.
func _on_command_received(client_id: int, command: Dictionary) -> void:
	var cmd_name: String = command.get("command", "unknown")
	_log("Received command: %s" % cmd_name)
	
	var response = await _handler.handle_command(command)
	_server.send_response(client_id, response)


## Updates the dock panel status display.
func _update_dock_status() -> void:
	if not _dock:
		return
	
	if _dock.has_method("update_connection_status"):
		var connected: bool = _server.get_client_count() > 0 if _server else false
		var client_count: int = _server.get_client_count() if _server else 0
		var port: int = _settings.get_setting("websocket_port") if _settings else 6850
		_dock.update_connection_status(connected, client_count, port)


## Returns the current plugin version.
func get_plugin_version() -> String:
	var config := ConfigFile.new()
	if config.load("res://addons/codot/plugin.cfg") == OK:
		return config.get_value("plugin", "version", "unknown")
	return "unknown"


## Returns the debugger plugin instance.
func get_debugger_plugin() -> EditorDebuggerPlugin:
	return _debugger_plugin


## Logs a message if debug logging is enabled.
func _log(message: String) -> void:
	if _settings and _settings.is_feature_enabled("debug_logging"):
		print("[Codot] %s" % message)
	elif not _settings:
		# During initialization, always log
		print("[Codot] %s" % message)
