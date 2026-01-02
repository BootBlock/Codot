@tool
extends Control
## AI Chat Dock - Send prompts to VS Code's AI assistant.
##
## This dock panel allows users to type prompts that are sent to the
## AI assistant running in VS Code (e.g., GitHub Copilot, Claude).

signal prompt_submitted(prompt: String)

const VSCODE_PORT: int = 6851  # Different port from main Codot server

var _websocket: WebSocketPeer = null
var _is_connected: bool = false
var _reconnect_timer: Timer = null
var _status_label: Label = null
var _prompt_input: TextEdit = null
var _send_button: Button = null
var _history: Array[String] = []
var _history_index: int = -1


func _ready() -> void:
	_build_ui()
	_setup_websocket()
	set_process(true)


func _process(_delta: float) -> void:
	if _websocket == null:
		return
	
	_websocket.poll()
	
	var state := _websocket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _is_connected:
				_is_connected = true
				_on_connected()
			_process_messages()
		WebSocketPeer.STATE_CONNECTING:
			pass
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			if _is_connected:
				_is_connected = false
				_on_disconnected()


func _build_ui() -> void:
	# Main vertical container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	
	# Header with status
	var header := HBoxContainer.new()
	vbox.add_child(header)
	
	var title := Label.new()
	title.text = "AI Assistant"
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)
	
	header.add_child(HSeparator.new())
	
	_status_label = Label.new()
	_status_label.text = "● Disconnected"
	_status_label.add_theme_color_override("font_color", Color.RED)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_status_label)
	
	# Prompt input area
	var prompt_label := Label.new()
	prompt_label.text = "Enter your prompt:"
	vbox.add_child(prompt_label)
	
	_prompt_input = TextEdit.new()
	_prompt_input.placeholder_text = "e.g., Create a new scene with GPUParticles2D..."
	_prompt_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prompt_input.custom_minimum_size = Vector2(0, 100)
	_prompt_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(_prompt_input)
	
	# Button row
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	vbox.add_child(button_row)
	
	_send_button = Button.new()
	_send_button.text = "Send to AI"
	_send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_send_button.pressed.connect(_on_send_pressed)
	_send_button.disabled = true
	button_row.add_child(_send_button)
	
	var clear_button := Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(_on_clear_pressed)
	button_row.add_child(clear_button)
	
	var reconnect_button := Button.new()
	reconnect_button.text = "Reconnect"
	reconnect_button.pressed.connect(_connect_to_vscode)
	button_row.add_child(reconnect_button)
	
	# Tips
	var tips := Label.new()
	tips.text = "Tip: Press Ctrl+Enter to send. Use ↑/↓ for history."
	tips.add_theme_font_size_override("font_size", 11)
	tips.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(tips)


func _setup_websocket() -> void:
	_reconnect_timer = Timer.new()
	_reconnect_timer.wait_time = 3.0
	_reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(_connect_to_vscode)
	add_child(_reconnect_timer)
	
	_connect_to_vscode()


func _connect_to_vscode() -> void:
	if _websocket != null:
		_websocket.close()
	
	_websocket = WebSocketPeer.new()
	var error := _websocket.connect_to_url("ws://127.0.0.1:%d" % VSCODE_PORT)
	
	if error != OK:
		_update_status(false)
		_schedule_reconnect()


func _schedule_reconnect() -> void:
	if _reconnect_timer and _reconnect_timer.is_stopped():
		_reconnect_timer.start()


func _on_connected() -> void:
	_update_status(true)
	print("[Codot] Connected to VS Code AI bridge")


func _on_disconnected() -> void:
	_update_status(false)
	print("[Codot] Disconnected from VS Code AI bridge")
	_schedule_reconnect()


func _update_status(connected: bool) -> void:
	if _status_label:
		if connected:
			_status_label.text = "● Connected"
			_status_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			_status_label.text = "● Disconnected"
			_status_label.add_theme_color_override("font_color", Color.RED)
	
	if _send_button:
		_send_button.disabled = not connected


func _process_messages() -> void:
	while _websocket.get_available_packet_count() > 0:
		var packet := _websocket.get_packet()
		var text := packet.get_string_from_utf8()
		var json := JSON.new()
		if json.parse(text) == OK:
			_handle_response(json.data)


func _handle_response(response: Dictionary) -> void:
	var msg_type: String = response.get("type", "")
	match msg_type:
		"ack":
			print("[Codot] Prompt acknowledged by VS Code")
		"error":
			push_error("[Codot] VS Code error: %s" % response.get("message", "Unknown"))


func _on_send_pressed() -> void:
	var prompt := _prompt_input.text.strip_edges()
	if prompt.is_empty():
		return
	
	_send_prompt(prompt)


func _send_prompt(prompt: String) -> void:
	if not _is_connected or _websocket == null:
		push_warning("[Codot] Not connected to VS Code")
		return
	
	# Add to history
	if _history.is_empty() or _history[-1] != prompt:
		_history.append(prompt)
		_history_index = _history.size()
	
	# Send to VS Code
	var message := {
		"type": "prompt",
		"prompt": prompt,
		"context": {
			"current_scene": _get_current_scene(),
			"selected_nodes": _get_selected_nodes(),
		},
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var json_string := JSON.stringify(message)
	_websocket.send_text(json_string)
	
	prompt_submitted.emit(prompt)
	
	# Clear input
	_prompt_input.text = ""
	
	print("[Codot] Sent prompt to VS Code: %s" % prompt.substr(0, 50))


func _get_current_scene() -> String:
	var editor := EditorInterface
	if editor:
		var root := EditorInterface.get_edited_scene_root()
		if root:
			return root.scene_file_path
	return ""


func _get_selected_nodes() -> Array:
	var result: Array = []
	var editor := EditorInterface
	if editor:
		var selection := EditorInterface.get_selection()
		for node in selection.get_selected_nodes():
			result.append(str(node.get_path()))
	return result


func _on_clear_pressed() -> void:
	_prompt_input.text = ""


func _input(event: InputEvent) -> void:
	if not _prompt_input or not _prompt_input.has_focus():
		return
	
	if event is InputEventKey and event.pressed:
		# Ctrl+Enter to send
		if event.keycode == KEY_ENTER and event.ctrl_pressed:
			_on_send_pressed()
			get_viewport().set_input_as_handled()
		# Up arrow for history
		elif event.keycode == KEY_UP and _history.size() > 0:
			_history_index = max(0, _history_index - 1)
			_prompt_input.text = _history[_history_index]
			get_viewport().set_input_as_handled()
		# Down arrow for history
		elif event.keycode == KEY_DOWN and _history.size() > 0:
			_history_index = min(_history.size() - 1, _history_index + 1)
			_prompt_input.text = _history[_history_index]
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _websocket:
		_websocket.close()
