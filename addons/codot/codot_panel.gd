## Codot Prompt Management Panel
## [br][br]
## Manages multiple prompts that can be edited and sent to VS Code AI assistants.
## Prompts can be saved, archived after sending, and restored from archive.
@tool
extends PanelContainer

## Emitted when a prompt is sent to VS Code
signal prompt_sent(prompt_data: Dictionary)

## Emitted when connection status changes
signal connection_changed(connected: bool)

#region Constants
const SETTINGS_PREFIX := "plugin/codot/"
const SAVE_FILE_PATH := "user://codot_prompts.json"
const DEFAULT_VSCODE_PORT := 6851
const RECONNECT_INTERVAL := 5.0
#endregion

#region Node References (set in _ready via unique names)
var _status_indicator: Label
var _new_prompt_button: Button
var _archive_toggle: Button
var _settings_button: Button
var _reconnect_button: Button
var _prompt_list: VBoxContainer
var _editor_section: VBoxContainer
var _prompt_title_edit: LineEdit
var _prompt_text_edit: TextEdit
var _save_button: Button
var _send_button: Button
var _delete_button: Button
var _prompt_count_label: Label
#endregion

#region State Variables
var _websocket: WebSocketPeer
var _is_connected: bool = false
var _reconnect_timer: Timer

## Array of prompt dictionaries: {id, title, content, created_at, archived}
var _prompts: Array[Dictionary] = []

## Currently selected prompt ID (empty string if none)
var _selected_prompt_id: String = ""

## Whether showing archived prompts
var _showing_archived: bool = false
#endregion


func _ready() -> void:
	_cache_node_references()
	_connect_signals()
	_setup_websocket()
	_load_prompts()
	_update_ui()


func _cache_node_references() -> void:
	_status_indicator = %StatusIndicator
	_new_prompt_button = %NewPromptButton
	_archive_toggle = %ArchiveToggle
	_settings_button = %SettingsButton
	_reconnect_button = %ReconnectButton
	_prompt_list = %PromptList
	_editor_section = %EditorSection
	_prompt_title_edit = %PromptTitleEdit
	_prompt_text_edit = %PromptTextEdit
	_save_button = %SaveButton
	_send_button = %SendButton
	_delete_button = %DeleteButton
	_prompt_count_label = %PromptCountLabel


func _connect_signals() -> void:
	_new_prompt_button.pressed.connect(_on_new_prompt_pressed)
	_archive_toggle.toggled.connect(_on_archive_toggled)
	_settings_button.pressed.connect(_on_settings_pressed)
	_reconnect_button.pressed.connect(_on_reconnect_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_send_button.pressed.connect(_on_send_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_prompt_title_edit.text_changed.connect(_on_editor_changed)
	_prompt_text_edit.text_changed.connect(_on_editor_changed)


func _setup_websocket() -> void:
	_websocket = WebSocketPeer.new()
	
	_reconnect_timer = Timer.new()
	_reconnect_timer.wait_time = RECONNECT_INTERVAL
	_reconnect_timer.one_shot = false
	_reconnect_timer.timeout.connect(_try_connect)
	add_child(_reconnect_timer)
	
	_try_connect()
	_reconnect_timer.start()


func _try_connect() -> void:
	if _is_connected:
		return
	
	var port := _get_setting("vscode_port", DEFAULT_VSCODE_PORT)
	var url := "ws://127.0.0.1:%d" % port
	
	var err := _websocket.connect_to_url(url)
	if err != OK:
		_update_status(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(_websocket):
		return
	
	_websocket.poll()
	
	var state := _websocket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _is_connected:
				_update_status(true)
			_process_incoming_messages()
		WebSocketPeer.STATE_CLOSED:
			if _is_connected:
				_update_status(false)
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CONNECTING:
			pass


func _process_incoming_messages() -> void:
	while _websocket.get_available_packet_count() > 0:
		var packet := _websocket.get_packet()
		var text := packet.get_string_from_utf8()
		_handle_message(text)


func _handle_message(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	
	var data: Dictionary = json.get_data()
	var msg_type: String = data.get("type", "")
	
	match msg_type:
		"prompt_accepted":
			# VS Code acknowledged the prompt - archive it
			var prompt_id: String = data.get("prompt_id", "")
			if prompt_id and _get_setting("auto_archive_on_send", true):
				_archive_prompt(prompt_id)
		"prompt_rejected":
			# VS Code rejected the prompt
			push_warning("Codot: Prompt rejected by VS Code: %s" % data.get("reason", "unknown"))
		"status":
			# Status update from VS Code
			pass


func _update_status(connected: bool) -> void:
	_is_connected = connected
	
	if _status_indicator:
		if connected:
			_status_indicator.text = "● Connected"
			_status_indicator.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		else:
			_status_indicator.text = "● Disconnected"
			_status_indicator.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	
	_update_send_button_state()
	connection_changed.emit(connected)


func _update_send_button_state() -> void:
	if _send_button:
		var has_content := _prompt_text_edit and _prompt_text_edit.text.strip_edges().length() > 0
		_send_button.disabled = not (_is_connected and has_content and _selected_prompt_id != "")


#region Prompt Management

func create_prompt(title: String = "", content: String = "") -> String:
	var prompt_id := _generate_id()
	var prompt := {
		"id": prompt_id,
		"title": title if title else "Untitled Prompt",
		"content": content,
		"created_at": Time.get_datetime_string_from_system(),
		"archived": false
	}
	_prompts.append(prompt)
	_save_prompts()
	_refresh_prompt_list()
	_select_prompt(prompt_id)
	return prompt_id


func update_prompt(prompt_id: String, title: String, content: String) -> bool:
	for i in range(_prompts.size()):
		if _prompts[i].id == prompt_id:
			_prompts[i].title = title
			_prompts[i].content = content
			_save_prompts()
			_refresh_prompt_list()
			return true
	return false


func delete_prompt(prompt_id: String) -> bool:
	for i in range(_prompts.size()):
		if _prompts[i].id == prompt_id:
			_prompts.remove_at(i)
			_save_prompts()
			if _selected_prompt_id == prompt_id:
				_selected_prompt_id = ""
				_clear_editor()
			_refresh_prompt_list()
			return true
	return false


func _archive_prompt(prompt_id: String) -> bool:
	for i in range(_prompts.size()):
		if _prompts[i].id == prompt_id:
			_prompts[i].archived = true
			_prompts[i].archived_at = Time.get_datetime_string_from_system()
			_save_prompts()
			if _selected_prompt_id == prompt_id and not _showing_archived:
				_selected_prompt_id = ""
				_clear_editor()
			_refresh_prompt_list()
			return true
	return false


func restore_prompt(prompt_id: String) -> bool:
	for i in range(_prompts.size()):
		if _prompts[i].id == prompt_id:
			_prompts[i].archived = false
			_prompts[i].erase("archived_at")
			_save_prompts()
			_refresh_prompt_list()
			return true
	return false


func get_prompt(prompt_id: String) -> Dictionary:
	for prompt in _prompts:
		if prompt.id == prompt_id:
			return prompt
	return {}


func get_active_prompts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for prompt in _prompts:
		if not prompt.get("archived", false):
			result.append(prompt)
	return result


func get_archived_prompts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for prompt in _prompts:
		if prompt.get("archived", false):
			result.append(prompt)
	return result


func send_prompt(prompt_id: String) -> bool:
	var prompt := get_prompt(prompt_id)
	if prompt.is_empty():
		return false
	
	if not _is_connected:
		push_warning("Codot: Cannot send prompt - not connected to VS Code")
		return false
	
	var message := {
		"type": "prompt",
		"prompt_id": prompt.id,
		"title": prompt.title,
		"content": prompt.content,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	var json_str := JSON.stringify(message)
	var err := _websocket.send_text(json_str)
	
	if err == OK:
		prompt_sent.emit(prompt)
		# Auto-archive if setting enabled
		if _get_setting("auto_archive_on_send", true):
			_archive_prompt(prompt_id)
		return true
	else:
		push_error("Codot: Failed to send prompt: %s" % error_string(err))
		return false

#endregion


#region Persistence

func _load_prompts() -> void:
	_prompts.clear()
	
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return
	
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Codot: Failed to open prompts file: %s" % error_string(FileAccess.get_open_error()))
		return
	
	var json := JSON.new()
	var text := file.get_as_text()
	file.close()
	
	if json.parse(text) != OK:
		push_error("Codot: Failed to parse prompts file: %s" % json.get_error_message())
		return
	
	var data = json.get_data()
	if data is Array:
		for item in data:
			if item is Dictionary:
				_prompts.append(item)


func _save_prompts() -> void:
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Codot: Failed to save prompts: %s" % error_string(FileAccess.get_open_error()))
		return
	
	var json_str := JSON.stringify(_prompts, "\t")
	file.store_string(json_str)
	file.close()

#endregion


#region UI Updates

func _update_ui() -> void:
	_refresh_prompt_list()
	_update_prompt_count()
	_update_send_button_state()


func _refresh_prompt_list() -> void:
	if not _prompt_list:
		return
	
	# Clear existing prompt items (except the EmptyLabel which is first child)
	for i in range(_prompt_list.get_child_count() - 1, 0, -1):
		_prompt_list.get_child(i).queue_free()
	
	var prompts_to_show := get_archived_prompts() if _showing_archived else get_active_prompts()
	
	# Show/hide empty label
	var empty_label := _prompt_list.get_child(0)
	if empty_label:
		empty_label.visible = prompts_to_show.is_empty()
		if _showing_archived:
			empty_label.text = "No archived prompts."
		else:
			empty_label.text = "No prompts yet. Click '+ New' to create one."
	
	# Create prompt items
	for prompt in prompts_to_show:
		var item := _create_prompt_item(prompt)
		_prompt_list.add_child(item)
	
	_update_prompt_count()


func _create_prompt_item(prompt: Dictionary) -> Control:
	var item := PanelContainer.new()
	item.set_meta("prompt_id", prompt.id)
	
	# Style based on selection
	if prompt.id == _selected_prompt_id:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.4, 0.6, 0.3)
		style.set_corner_radius_all(4)
		item.add_theme_stylebox_override("panel", style)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
		style.set_corner_radius_all(4)
		item.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	item.add_child(hbox)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var title_label := Label.new()
	title_label.text = prompt.get("title", "Untitled")
	title_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title_label)
	
	var content_str: String = prompt.get("content", "")
	var preview: String = content_str.substr(0, 60).replace("\n", " ")
	if preview.length() < content_str.length():
		preview += "..."
	
	var preview_label := Label.new()
	preview_label.text = preview if preview else "(empty)"
	preview_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	preview_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(preview_label)
	
	# Action button for archived items
	if _showing_archived:
		var restore_btn := Button.new()
		restore_btn.text = "↩"
		restore_btn.tooltip_text = "Restore this prompt"
		restore_btn.pressed.connect(_on_restore_prompt.bind(prompt.id))
		hbox.add_child(restore_btn)
	
	# Make the item clickable
	item.gui_input.connect(_on_prompt_item_input.bind(prompt.id))
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	return item


func _select_prompt(prompt_id: String) -> void:
	_selected_prompt_id = prompt_id
	var prompt := get_prompt(prompt_id)
	
	if prompt.is_empty():
		_clear_editor()
		return
	
	if _prompt_title_edit:
		_prompt_title_edit.text = prompt.get("title", "")
	if _prompt_text_edit:
		_prompt_text_edit.text = prompt.get("content", "")
	
	_refresh_prompt_list()
	_update_send_button_state()


func _clear_editor() -> void:
	if _prompt_title_edit:
		_prompt_title_edit.text = ""
	if _prompt_text_edit:
		_prompt_text_edit.text = ""
	_update_send_button_state()


func _update_prompt_count() -> void:
	if not _prompt_count_label:
		return
	
	var active := get_active_prompts().size()
	var archived := get_archived_prompts().size()
	
	if _showing_archived:
		_prompt_count_label.text = "%d archived" % archived
	else:
		_prompt_count_label.text = "%d prompt%s" % [active, "" if active == 1 else "s"]

#endregion


#region Signal Handlers

func _on_new_prompt_pressed() -> void:
	if _showing_archived:
		_archive_toggle.button_pressed = false
		_showing_archived = false
	create_prompt()


func _on_archive_toggled(pressed: bool) -> void:
	_showing_archived = pressed
	_selected_prompt_id = ""
	_clear_editor()
	_refresh_prompt_list()


func _on_settings_pressed() -> void:
	# Open Editor Settings to the Codot section
	if Engine.is_editor_hint():
		var editor := EditorInterface.get_editor_settings()
		EditorInterface.get_command_palette().open_command_palette()


func _on_reconnect_pressed() -> void:
	_websocket.close()
	_is_connected = false
	_update_status(false)
	_try_connect()


func _on_save_pressed() -> void:
	if _selected_prompt_id == "":
		return
	
	var title := _prompt_title_edit.text.strip_edges()
	var content := _prompt_text_edit.text
	
	if title.is_empty():
		title = "Untitled Prompt"
	
	update_prompt(_selected_prompt_id, title, content)


func _on_send_pressed() -> void:
	if _selected_prompt_id == "":
		return
	
	# Save before sending
	_on_save_pressed()
	send_prompt(_selected_prompt_id)


func _on_delete_pressed() -> void:
	if _selected_prompt_id == "":
		return
	delete_prompt(_selected_prompt_id)


func _on_editor_changed(_arg = null) -> void:
	_update_send_button_state()


func _on_prompt_item_input(event: InputEvent, prompt_id: String) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_prompt(prompt_id)


func _on_restore_prompt(prompt_id: String) -> void:
	restore_prompt(prompt_id)


func _input(event: InputEvent) -> void:
	# Handle Ctrl+Enter to send
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER and event.ctrl_pressed:
			if _selected_prompt_id != "" and _is_connected:
				_on_send_pressed()
				get_viewport().set_input_as_handled()

#endregion


#region Utility Functions

func _generate_id() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var result := ""
	for i in range(12):
		result += chars[randi() % chars.length()]
	return result


func _get_setting(key: String, default_value: Variant) -> Variant:
	if not Engine.is_editor_hint():
		return default_value
	
	var settings := EditorInterface.get_editor_settings()
	var full_key := SETTINGS_PREFIX + key
	
	if settings.has_setting(full_key):
		return settings.get_setting(full_key)
	return default_value

#endregion


func _exit_tree() -> void:
	if _websocket:
		_websocket.close()
	if _reconnect_timer:
		_reconnect_timer.stop()
