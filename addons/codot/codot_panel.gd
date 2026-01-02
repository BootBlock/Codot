## Codot Prompt Management Panel
## [br][br]
## Manages multiple prompts that can be edited and sent to VS Code AI assistants.
## Features auto-save, archiving, export/import, and real-time status updates.
@tool
extends PanelContainer

## Preload project config for per-project pre/post prompts
const ProjectConfig = preload("res://addons/codot/codot_project_config.gd")

## Emitted when a prompt is sent to VS Code
signal prompt_sent(prompt_data: Dictionary)

## Emitted when connection status changes
signal connection_changed(connected: bool)

## Emitted when settings button is pressed
signal settings_requested

## Emitted when send to AI is requested (for external connection via main plugin)
signal send_to_ai_requested(title: String, body: String)

#region Constants
const SETTINGS_PREFIX := "plugin/codot/"
const SAVE_FILE_PATH := "user://codot_prompts.json"
const DEFAULT_VSCODE_PORT := 6851
const RECONNECT_INTERVAL := 5.0
const AUTO_SAVE_DELAY := 1.5
const SETTINGS_MESSAGE_DURATION := 20.0  # Duration to show settings navigation message
#endregion

#region Node References (set in _ready via unique names)
var _status_indicator: Label
var _new_prompt_button: Button
var _duplicate_button: Button
var _export_button: Button
var _import_button: Button
var _archived_toggle: Button
var _wrapper_button: Button
var _settings_button: Button
var _reconnect_button: Button
var _prompt_list: VBoxContainer
var _editor_section: VBoxContainer
var _prompt_title_edit: LineEdit
var _prompt_text_edit: TextEdit
var _send_button: Button
var _delete_button: Button
var _prompt_count_label: Label
var _auto_save_indicator: Label
#endregion

#region State Variables
var _websocket: WebSocketPeer
var _is_connected: bool = false
var _reconnect_timer: Timer
var _auto_save_timer: Timer

## Array of prompt dictionaries: {id, title, content, created_at, archived}
var _prompts: Array[Dictionary] = []

## Currently selected prompt ID (empty string if none)
var _selected_prompt_id: String = ""

## Whether showing archived prompts
var _showing_archived: bool = false

## Dirty flag for auto-save
var _is_dirty: bool = false

## Track if we're programmatically setting text (to avoid triggering auto-save)
var _updating_editor: bool = false

## Track connection attempts for debugging
var _connection_attempts: int = 0
var _last_connection_error: String = ""

## Track pending ack for send operation
var _waiting_for_ack: bool = false
var _pending_ack_prompt_id: String = ""
var _ack_received: bool = false
var _ack_error: String = ""

## Test mode flag - when true, uses in-memory storage instead of file persistence
var _test_mode: bool = false

## Context menu for prompt items
var _context_menu: PopupMenu = null
var _context_menu_prompt_id: String = ""
#endregion


func _ready() -> void:
	_cache_node_references()
	_setup_timers()
	_connect_signals()
	_setup_websocket()
	_load_prompts()
	_update_ui()
	_update_editor_enabled_state()


func _cache_node_references() -> void:
	_status_indicator = %StatusIndicator
	_new_prompt_button = %NewPromptButton
	_duplicate_button = %DuplicateButton
	_export_button = %ExportButton
	_import_button = %ImportButton
	_archived_toggle = %ArchivedToggle
	_wrapper_button = %WrapperButton
	_settings_button = %SettingsButton
	_reconnect_button = %ReconnectButton
	_prompt_list = %PromptList
	_editor_section = %EditorSection
	_prompt_title_edit = %PromptTitleEdit
	_prompt_text_edit = %PromptTextEdit
	_send_button = %SendButton
	_delete_button = %DeleteButton
	_prompt_count_label = %PromptCountLabel
	_auto_save_indicator = %AutoSaveIndicator


func _setup_timers() -> void:
	# Reconnect timer
	_reconnect_timer = Timer.new()
	_reconnect_timer.wait_time = _get_setting("reconnect_interval", RECONNECT_INTERVAL)
	_reconnect_timer.one_shot = false
	_reconnect_timer.timeout.connect(_on_reconnect_timer_timeout)
	add_child(_reconnect_timer)
	
	# Auto-save timer - use setting for wait time
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = _get_setting("auto_save_delay", AUTO_SAVE_DELAY)
	_auto_save_timer.one_shot = true
	_auto_save_timer.timeout.connect(_on_auto_save_timer_timeout)
	add_child(_auto_save_timer)
	
	# Context menu for prompt items
	_setup_context_menu()


## Create the right-click context menu for prompt items.
func _setup_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(_context_menu)


## Timer callback for reconnection attempts.
func _on_reconnect_timer_timeout() -> void:
	_try_connect()


## Timer callback for auto-save.
func _on_auto_save_timer_timeout() -> void:
	_perform_auto_save()

func _connect_signals() -> void:
	_new_prompt_button.pressed.connect(_on_new_prompt_pressed)
	_duplicate_button.pressed.connect(_on_duplicate_pressed)
	_export_button.pressed.connect(_on_export_pressed)
	_import_button.pressed.connect(_on_import_pressed)
	_archived_toggle.toggled.connect(_on_archived_toggled)
	_wrapper_button.pressed.connect(_on_wrapper_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_reconnect_button.pressed.connect(_on_reconnect_pressed)
	_send_button.pressed.connect(_on_send_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_prompt_title_edit.text_changed.connect(_on_title_changed)
	_prompt_text_edit.text_changed.connect(_on_content_changed)


func _setup_websocket() -> void:
	_websocket = WebSocketPeer.new()
	_try_connect()
	_reconnect_timer.start()


func _try_connect() -> void:
	if _is_connected:
		return
	
	_connection_attempts += 1
	var port: int = _get_setting("vscode_port", DEFAULT_VSCODE_PORT)
	var url := "ws://127.0.0.1:%d" % port
	
	var err := _websocket.connect_to_url(url)
	if err != OK:
		_last_connection_error = "Connection failed: %s" % error_string(err)
		_update_status(false, _last_connection_error)


func _process(_delta: float) -> void:
	if not is_instance_valid(_websocket):
		return
	
	_websocket.poll()
	
	var state := _websocket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _is_connected:
				_connection_attempts = 0
				_last_connection_error = ""
				_update_status(true)
			_process_incoming_messages()
		WebSocketPeer.STATE_CLOSED:
			if _is_connected:
				_update_status(false, "Connection closed")
		WebSocketPeer.STATE_CLOSING:
			_update_status_text("● Closing...", Color(0.8, 0.6, 0.2, 0.6),
				"Connection is closing...")
		WebSocketPeer.STATE_CONNECTING:
			# Check if user wants to see connecting animation or just static disconnected
			if _get_setting("show_reconnecting_status", true):
				_update_status_text("● Connecting...", Color(0.8, 0.8, 0.2, 0.6), 
					"Attempting to connect to VS Code Codot Bridge\n" +
					"Port: %d\n" % _get_setting("vscode_port", DEFAULT_VSCODE_PORT) +
					"Attempt: #%d\n\n" % _connection_attempts +
					"Make sure:\n" +
					"1. VS Code is running\n" +
					"2. Codot Bridge extension is installed\n" +
					"3. Run 'Codot: Start Bridge Server' command")
			else:
				# Static disconnected status when show_reconnecting_status is false
				_update_status_text("● Disconnected", Color(0.5, 0.5, 0.5, 0.6), 
					"Auto-reconnecting in background...\n" +
					"Port: %d\n" % _get_setting("vscode_port", DEFAULT_VSCODE_PORT) +
					"Attempt: #%d" % _connection_attempts)


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
	var success: bool = data.get("success", false)
	
	# Handle ack messages when waiting for confirmation
	if _waiting_for_ack:
		if msg_type == "ack" or success == true:
			_ack_received = true
			_ack_error = ""
			return
		elif msg_type == "error" or data.get("success") == false:
			_ack_received = true
			_ack_error = data.get("message", data.get("error", "Unknown error"))
			return
		# Ignore "connected" messages while waiting
		elif msg_type == "connected":
			return
	
	match msg_type:
		"prompt_accepted":
			var prompt_id: String = data.get("prompt_id", "")
			if prompt_id and _get_setting("auto_archive_on_send", true):
				_archive_prompt(prompt_id)
			_show_auto_save_status("Sent ✓", Color(0.2, 0.8, 0.2))
		"prompt_rejected":
			push_warning("Codot: Prompt rejected by VS Code: %s" % data.get("reason", "unknown"))
			_show_auto_save_status("Rejected", Color(0.8, 0.2, 0.2))
		"status", "connected", "ack":
			pass  # Silently ignore status/connection messages outside of send


func _update_status(connected: bool, reason: String = "") -> void:
	_is_connected = connected
	
	if connected:
		_update_status_text("● Connected", Color(0.2, 0.8, 0.2, 0.6),
			"Connected to VS Code Copilot Bridge on port %d" % _get_setting("vscode_port", DEFAULT_VSCODE_PORT))
	else:
		var tooltip := "Not connected to VS Code Copilot Bridge"
		if reason:
			tooltip += "\n" + reason
		tooltip += "\nMake sure the Codot Bridge extension is running in VS Code"
		if _connection_attempts > 0:
			tooltip += "\nConnection attempts: %d" % _connection_attempts
		_update_status_text("● Disconnected", Color(0.8, 0.2, 0.2, 0.6), tooltip)
	
	_update_send_button_state()
	connection_changed.emit(connected)


func _update_status_text(text: String, color: Color, tooltip: String) -> void:
	if _status_indicator:
		_status_indicator.text = text
		_status_indicator.add_theme_color_override("font_color", color)
		_status_indicator.tooltip_text = tooltip


func _update_send_button_state() -> void:
	if _send_button:
		var has_content := _prompt_text_edit and _prompt_text_edit.text.strip_edges().length() > 0
		var has_selection := _selected_prompt_id != ""
		_send_button.disabled = not (has_content and has_selection)
		
		if not has_selection:
			_send_button.tooltip_text = "Select a prompt first"
		elif not has_content:
			_send_button.tooltip_text = "Prompt content is empty"
		elif not _is_connected:
			_send_button.tooltip_text = "Send prompt (not connected - will attempt connection)"
		else:
			_send_button.tooltip_text = "Send prompt to VS Code AI (Ctrl+Enter)"


func _update_editor_enabled_state() -> void:
	var has_selection := _selected_prompt_id != ""
	
	if _prompt_title_edit:
		_prompt_title_edit.editable = has_selection
		_prompt_title_edit.placeholder_text = "Prompt title..." if has_selection else "Select a prompt..."
	
	if _prompt_text_edit:
		_prompt_text_edit.editable = has_selection
		if not has_selection:
			_prompt_text_edit.placeholder_text = "Select a prompt to edit...\n\nTips:\n• Use '+ New' to create a prompt\n• Click a prompt in the list to select it\n• Changes are saved automatically"
		else:
			_prompt_text_edit.placeholder_text = "Enter your prompt here..."
	
	if _delete_button:
		_delete_button.disabled = not has_selection
	
	if _duplicate_button:
		_duplicate_button.disabled = not has_selection
	
	if _export_button:
		_export_button.disabled = not has_selection


#region Auto-Save System

func _on_title_changed(_new_text: String) -> void:
	if _updating_editor:
		return
	_mark_dirty()


func _on_content_changed() -> void:
	if _updating_editor:
		return
	_mark_dirty()
	_update_send_button_state()


func _mark_dirty() -> void:
	if _selected_prompt_id == "":
		return
	
	_is_dirty = true
	_show_auto_save_status("Unsaved...", Color(0.8, 0.8, 0.2))
	_auto_save_timer.start()


func _perform_auto_save() -> void:
	if not _is_dirty or _selected_prompt_id == "":
		return
	
	var title := _prompt_title_edit.text.strip_edges()
	var content := _prompt_text_edit.text
	
	# Store empty titles as-is (display uses placeholder)
	if update_prompt(_selected_prompt_id, title, content):
		_is_dirty = false
		_show_auto_save_status("Saved ✓", Color(0.5, 0.5, 0.5))
		# Clear the indicator after a moment
		await get_tree().create_timer(2.0).timeout
		if not _is_dirty:
			_show_auto_save_status("", Color(0.5, 0.5, 0.5))


func _show_auto_save_status(text: String, color: Color) -> void:
	if _auto_save_indicator:
		_auto_save_indicator.text = text
		_auto_save_indicator.add_theme_color_override("font_color", color)


func _save_if_dirty() -> void:
	if _is_dirty and _selected_prompt_id != "":
		_auto_save_timer.stop()
		_perform_auto_save()

#endregion


#region Prompt Management

func create_prompt(title: String = "", content: String = "") -> String:
	var prompt_id := _generate_id()
	var prompt := {
		"id": prompt_id,
		"title": title,  # Store empty titles as-is (UI displays placeholder)
		"content": content,
		"created_at": Time.get_datetime_string_from_system(),
		"archived": false
	}
	_prompts.append(prompt)
	_save_prompts()
	_refresh_prompt_list()
	_select_prompt(prompt_id)
	
	# Auto-focus title field and select all text
	_focus_title_field()
	
	return prompt_id


## Focus the title field and select all text for immediate editing
func _focus_title_field() -> void:
	if _prompt_title_edit:
		_prompt_title_edit.grab_focus()
		_prompt_title_edit.select_all()


func duplicate_prompt(prompt_id: String) -> String:
	var original := get_prompt(prompt_id)
	if original.is_empty():
		return ""
	
	return create_prompt(original.get("title", "Untitled") + " (copy)", original.get("content", ""))


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
				_update_editor_enabled_state()
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
				_update_editor_enabled_state()
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


#region Export/Import

func export_prompt(prompt_id: String, file_path: String) -> bool:
	var prompt := get_prompt(prompt_id)
	if prompt.is_empty():
		push_error("Codot: Cannot export - prompt not found")
		return false
	
	var export_data := {
		"codot_version": "1.0",
		"exported_at": Time.get_datetime_string_from_system(),
		"prompt": {
			"title": prompt.get("title", ""),
			"content": prompt.get("content", ""),
			"created_at": prompt.get("created_at", "")
		}
	}
	
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Codot: Failed to write export file: %s" % error_string(FileAccess.get_open_error()))
		return false
	
	var json_str := JSON.stringify(export_data, "\t")
	file.store_string(json_str)
	file.close()
	
	_show_auto_save_status("Exported ✓", Color(0.2, 0.8, 0.2))
	return true


func import_prompt(file_path: String) -> String:
	if not FileAccess.file_exists(file_path):
		push_error("Codot: Import file not found: %s" % file_path)
		_show_auto_save_status("Import failed", Color(0.8, 0.2, 0.2))
		return ""
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Codot: Failed to read import file: %s" % error_string(FileAccess.get_open_error()))
		_show_auto_save_status("Import failed", Color(0.8, 0.2, 0.2))
		return ""
	
	var json := JSON.new()
	var text := file.get_as_text()
	file.close()
	
	if json.parse(text) != OK:
		push_error("Codot: Failed to parse import file: %s" % json.get_error_message())
		_show_auto_save_status("Invalid file", Color(0.8, 0.2, 0.2))
		return ""
	
	var data = json.get_data()
	if not data is Dictionary:
		push_error("Codot: Invalid import file format")
		_show_auto_save_status("Invalid format", Color(0.8, 0.2, 0.2))
		return ""
	
	# Support both full export format and simple format
	var prompt_data: Dictionary
	if data.has("prompt"):
		prompt_data = data.prompt
	else:
		prompt_data = data
	
	var title: String = prompt_data.get("title", "Imported Prompt")
	var content: String = prompt_data.get("content", "")
	
	var prompt_id := create_prompt(title, content)
	_show_auto_save_status("Imported ✓", Color(0.2, 0.8, 0.2))
	return prompt_id

#endregion


func send_prompt(prompt_id: String) -> bool:
	var prompt := get_prompt(prompt_id)
	if prompt.is_empty():
		_show_auto_save_status("Prompt not found", Color(0.8, 0.2, 0.2))
		return false
	
	# Check WebSocket state
	if not is_instance_valid(_websocket):
		_show_auto_save_status("WebSocket invalid", Color(0.8, 0.2, 0.2))
		push_error("Codot: WebSocket instance is invalid")
		return false
	
	var ws_state := _websocket.get_ready_state()
	
	# If not connected, try to connect first
	if ws_state != WebSocketPeer.STATE_OPEN:
		_show_auto_save_status("Connecting...", Color(0.8, 0.8, 0.2))
		
		# Try to establish connection
		var port: int = _get_setting("vscode_port", DEFAULT_VSCODE_PORT)
		var url := "ws://127.0.0.1:%d" % port
		
		# Close existing connection attempt
		_websocket.close()
		
		var err := _websocket.connect_to_url(url)
		if err != OK:
			var error_msg := "Connection failed: %s\n\nMake sure:\n1. VS Code is running\n2. Codot Bridge extension is active\n3. Port %d is correct" % [error_string(err), port]
			push_warning("Codot: %s" % error_msg)
			_show_auto_save_status("Not connected", Color(0.8, 0.2, 0.2))
			return false
		
		# Wait for connection with timeout
		var timeout := 3.0
		var elapsed := 0.0
		while elapsed < timeout:
			_websocket.poll()
			if _websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
				_is_connected = true
				_update_status(true)
				break
			await get_tree().create_timer(0.1).timeout
			elapsed += 0.1
		
		if _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
			_show_auto_save_status("Connection timeout", Color(0.8, 0.2, 0.2))
			push_warning("Codot: Connection timed out after %.1fs" % timeout)
			return false
	
	# Now try to send
	# Build the final content with pre/post prompt wrappers if enabled
	var final_content: String = prompt.content
	if _get_setting("wrap_prompts_with_prefix_suffix", true):
		var pre_prompt: String = _get_setting("pre_prompt_message", "")
		var post_prompt: String = _get_setting("post_prompt_message", "")
		if pre_prompt or post_prompt:
			var parts: Array[String] = []
			if pre_prompt:
				parts.append(pre_prompt)
			parts.append(prompt.content)
			if post_prompt:
				parts.append(post_prompt)
			final_content = "\n\n".join(parts)
	
	# Build message - only include title if not empty
	var message := {
		"type": "prompt",
		"prompt_id": prompt.id,
		"content": final_content,
		"timestamp": Time.get_datetime_string_from_system()
	}
	var prompt_title: String = prompt.get("title", "")
	if not prompt_title.is_empty():
		message["title"] = prompt_title
	
	var json_str := JSON.stringify(message)
	
	# Set up ack tracking before sending
	_waiting_for_ack = true
	_pending_ack_prompt_id = prompt.id
	_ack_received = false
	_ack_error = ""
	
	var err := _websocket.send_text(json_str)
	
	if err != OK:
		_waiting_for_ack = false
		var error_msg := "Send failed: %s" % error_string(err)
		push_error("Codot: %s" % error_msg)
		_show_auto_save_status("Send failed", Color(0.8, 0.2, 0.2))
		return false
	
	_show_auto_save_status("Waiting for confirmation...", Color(0.8, 0.8, 0.2))
	
	# Wait for VS Code to acknowledge receipt (handled by _process/_handle_message)
	var ack_timeout := 5.0
	var ack_elapsed := 0.0
	
	while ack_elapsed < ack_timeout:
		# The _process() function will poll and _handle_message will set _ack_received
		if _ack_received:
			break
		
		# Check if connection was lost
		if _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
			_waiting_for_ack = false
			push_error("Codot: Connection lost while waiting for acknowledgment")
			_show_auto_save_status("Connection lost", Color(0.8, 0.2, 0.2))
			_is_connected = false
			_update_status(false)
			return false
		
		await get_tree().create_timer(0.1).timeout
		ack_elapsed += 0.1
	
	_waiting_for_ack = false
	
	if not _ack_received:
		push_warning("Codot: No acknowledgment received from VS Code (sent but unconfirmed)")
		_show_auto_save_status("Sent (unconfirmed)", Color(0.8, 0.6, 0.2))
		# Don't archive if we didn't get confirmation
		return false
	
	# Check if there was an error in the ack
	if _ack_error != "":
		push_error("Codot: VS Code rejected prompt: %s" % _ack_error)
		_show_auto_save_status("Rejected: %s" % _ack_error, Color(0.8, 0.2, 0.2))
		return false
	
	# Confirmed! Now safe to archive
	prompt_sent.emit(prompt)
	_show_auto_save_status("Sent ✓", Color(0.2, 0.8, 0.2))
	
	# Auto-archive only after confirmation
	if _get_setting("auto_archive_on_send", true):
		_archive_prompt(prompt_id)
	return true

#endregion


#region Persistence

func _load_prompts() -> void:
	_prompts.clear()
	
	# In test mode, don't load from file - start with empty prompts
	if _test_mode:
		return
	
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
	# In test mode, don't persist to disk
	if _test_mode:
		return
	
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
	_update_editor_enabled_state()


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
			empty_label.text = "[color=dimgray]No archived prompts.\n\nPrompts are archived after sending.[/color]"
		else:
			empty_label.text = "[color=dimgray]No prompts yet.[/color]\n\n[color=dimgray]Click[/color]  [color=gray]+ New[/color]  [color=dimgray]to create one.[/color]"
	
	# Create prompt items
	for prompt in prompts_to_show:
		var item := _create_prompt_item(prompt)
		_prompt_list.add_child(item)
	
	_update_prompt_count()


func _create_prompt_item(prompt: Dictionary) -> Control:
	var item := PanelContainer.new()
	item.set_meta("prompt_id", prompt.id)
	
	# Style based on selection
	var style := StyleBoxFlat.new()
	if prompt.id == _selected_prompt_id:
		style.bg_color = Color(0.25, 0.45, 0.65, 0.4)
		style.border_color = Color(0.4, 0.6, 0.8, 0.6)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 0.6)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	item.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	item.add_child(hbox)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var title_label := Label.new()
	var display_title: String = prompt.get("title", "")
	title_label.text = display_title if display_title else "Untitled Prompt"
	if display_title.is_empty():
		title_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	title_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title_label)
	
	var preview_length: int = _get_setting("prompt_preview_length", 80)
	var content_str: String = prompt.get("content", "")
	var preview: String = content_str.substr(0, preview_length).replace("\n", " ").strip_edges()
	if preview.length() < content_str.length():
		preview += "..."
	
	var preview_label := Label.new()
	preview_label.text = preview if preview else "(empty)"
	preview_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	preview_label.add_theme_font_size_override("font_size", 11)
	preview_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(preview_label)
	
	# Action button for archived items
	if _showing_archived:
		var restore_btn := Button.new()
		restore_btn.text = "↩"
		restore_btn.tooltip_text = "Restore this prompt to active prompts"
		restore_btn.pressed.connect(_on_restore_prompt.bind(prompt.id))
		hbox.add_child(restore_btn)
		
		var delete_btn := Button.new()
		delete_btn.text = "🗑"
		delete_btn.tooltip_text = "Permanently delete this archived prompt"
		delete_btn.pressed.connect(_on_delete_archived_prompt.bind(prompt.id))
		hbox.add_child(delete_btn)
	
	# Make the item clickable
	item.gui_input.connect(_on_prompt_item_input.bind(prompt.id))
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	return item


func _select_prompt(prompt_id: String) -> void:
	# Save current prompt if dirty before switching
	_save_if_dirty()
	
	_selected_prompt_id = prompt_id
	var prompt := get_prompt(prompt_id)
	
	if prompt.is_empty():
		_clear_editor()
		_update_editor_enabled_state()
		return
	
	# Prevent auto-save triggering when we programmatically set text
	_updating_editor = true
	
	if _prompt_title_edit:
		_prompt_title_edit.text = prompt.get("title", "")
	if _prompt_text_edit:
		_prompt_text_edit.text = prompt.get("content", "")
	
	_updating_editor = false
	_is_dirty = false
	
	_refresh_prompt_list()
	_update_send_button_state()
	_update_editor_enabled_state()
	_show_auto_save_status("", Color(0.5, 0.5, 0.5))


func _clear_editor() -> void:
	_updating_editor = true
	if _prompt_title_edit:
		_prompt_title_edit.text = ""
	if _prompt_text_edit:
		_prompt_text_edit.text = ""
	_updating_editor = false
	_is_dirty = false
	_update_send_button_state()
	_show_auto_save_status("", Color(0.5, 0.5, 0.5))


func _update_prompt_count() -> void:
	if not _prompt_count_label:
		return
	
	var active := get_active_prompts().size()
	var archived := get_archived_prompts().size()
	
	if _showing_archived:
		_prompt_count_label.text = "%d archived" % archived
	else:
		var text := "%d prompt%s" % [active, "" if active == 1 else "s"]
		if archived > 0:
			text += " • %d archived" % archived
		_prompt_count_label.text = text

#endregion


#region Signal Handlers

func _on_new_prompt_pressed() -> void:
	_save_if_dirty()
	if _showing_archived:
		_archived_toggle.button_pressed = false
		_showing_archived = false
	create_prompt()


func _on_duplicate_pressed() -> void:
	if _selected_prompt_id == "":
		return
	_save_if_dirty()
	duplicate_prompt(_selected_prompt_id)


func _on_export_pressed() -> void:
	if _selected_prompt_id == "":
		return
	
	_save_if_dirty()
	
	# Get prompt for default filename
	var prompt := get_prompt(_selected_prompt_id)
	var title_str: String = prompt.get("title", "prompt")
	var default_name: String = title_str.to_snake_case() + ".json"
	
	# Create file dialog
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.json", "JSON Files")
	dialog.current_file = default_name
	dialog.title = "Export Prompt"
	
	dialog.file_selected.connect(func(path: String):
		export_prompt(_selected_prompt_id, path)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	
	add_child(dialog)
	dialog.popup_centered_ratio(0.5)


func _on_import_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.json", "JSON Files")
	dialog.title = "Import Prompt"
	
	dialog.file_selected.connect(func(path: String):
		import_prompt(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	
	add_child(dialog)
	dialog.popup_centered_ratio(0.5)


func _on_archived_toggled(pressed: bool) -> void:
	_save_if_dirty()
	_showing_archived = pressed
	_selected_prompt_id = ""
	_clear_editor()
	_update_editor_enabled_state()
	_refresh_prompt_list()


func _on_settings_pressed() -> void:
	settings_requested.emit()
	if Engine.is_editor_hint():
		# Show notification: settings now visible in Inspector, plus path to full dialog
		_show_auto_save_status("Settings shown in Inspector | Full: Editor → Editor Settings → Plugin → Codot", Color(0.5, 0.7, 0.9))
		await get_tree().create_timer(SETTINGS_MESSAGE_DURATION).timeout
		if not _is_dirty:
			_show_auto_save_status("", Color(0.5, 0.5, 0.5))


func _on_wrapper_pressed() -> void:
	_show_wrapper_dialog()


## Show dialog for editing pre/post prompt wrappers
func _show_wrapper_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Edit Prompt Wrappers"
	dialog.size = Vector2(500, 520)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.custom_minimum_size = Vector2(480, 470)
	dialog.add_child(main_vbox)
	
	# Enable/Disable toggle
	var enable_hbox := HBoxContainer.new()
	main_vbox.add_child(enable_hbox)
	
	var enable_check := CheckBox.new()
	enable_check.text = "Enable prompt wrappers"
	enable_check.button_pressed = _get_setting("wrap_prompts_with_prefix_suffix", true)
	enable_hbox.add_child(enable_check)
	
	var enable_spacer := Control.new()
	enable_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enable_hbox.add_child(enable_spacer)
	
	# Project vs Global toggle
	var scope_hbox := HBoxContainer.new()
	main_vbox.add_child(scope_hbox)
	
	var scope_check := CheckBox.new()
	scope_check.text = "Store in project config (for this project only)"
	scope_check.button_pressed = ProjectConfig.is_using_project_config("pre_prompt_message")
	scope_check.tooltip_text = "When enabled, these settings are stored in .codot/config.json\nand only apply to this project. When disabled, settings\nare stored in global Editor Settings."
	scope_hbox.add_child(scope_check)
	
	main_vbox.add_child(HSeparator.new())
	
	# Pre-prompt section
	var pre_label := Label.new()
	pre_label.text = "Pre-Prompt (added before every prompt):"
	main_vbox.add_child(pre_label)
	
	var pre_edit := TextEdit.new()
	pre_edit.custom_minimum_size = Vector2(0, 120)
	pre_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pre_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	pre_edit.placeholder_text = "Enter text to add before every prompt...\n\nExample:\nYou are working on a Godot 4.x game project. Follow the coding conventions in AGENTS.md."
	pre_edit.text = _get_setting("pre_prompt_message", "")
	main_vbox.add_child(pre_edit)
	
	# Post-prompt section
	var post_label := Label.new()
	post_label.text = "Post-Prompt (added after every prompt):"
	main_vbox.add_child(post_label)
	
	var post_edit := TextEdit.new()
	post_edit.custom_minimum_size = Vector2(0, 120)
	post_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	post_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	post_edit.placeholder_text = "Enter text to add after every prompt...\n\nExample:\nRemember to create GUT tests for any new functionality."
	post_edit.text = _get_setting("post_prompt_message", "")
	main_vbox.add_child(post_edit)
	
	# Help text
	var help_label := Label.new()
	help_label.text = "These wrappers will be added to all prompts when sent to VS Code."
	help_label.add_theme_font_size_override("font_size", 11)
	help_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	main_vbox.add_child(help_label)
	
	# Handle dialog confirmation
	dialog.confirmed.connect(func():
		# Always save enable toggle to editor settings (global preference)
		CodotSettings.set_setting("wrap_prompts_with_prefix_suffix", enable_check.button_pressed)
		
		if scope_check.button_pressed:
			# Save to project config
			ProjectConfig.set_project_setting("pre_prompt_message", pre_edit.text)
			ProjectConfig.set_project_setting("post_prompt_message", post_edit.text)
			ProjectConfig.set_project_setting("wrap_prompts_with_prefix_suffix", enable_check.button_pressed)
			ProjectConfig.save_config()
			_show_auto_save_status("Wrappers saved to project ✓", Color(0.2, 0.8, 0.2))
		else:
			# Clear any project settings and save to editor settings
			if ProjectConfig.has_project_setting("pre_prompt_message"):
				ProjectConfig.revert_to_editor_settings("pre_prompt_message")
				ProjectConfig.revert_to_editor_settings("post_prompt_message")
				ProjectConfig.revert_to_editor_settings("wrap_prompts_with_prefix_suffix")
				ProjectConfig.save_config()
			CodotSettings.set_setting("pre_prompt_message", pre_edit.text)
			CodotSettings.set_setting("post_prompt_message", post_edit.text)
			_show_auto_save_status("Wrappers saved globally ✓", Color(0.2, 0.8, 0.2))
		dialog.queue_free()
	)
	
	dialog.canceled.connect(dialog.queue_free)
	
	add_child(dialog)
	dialog.popup_centered()


func _on_reconnect_pressed() -> void:
	_websocket.close()
	_is_connected = false
	_connection_attempts = 0
	_update_status(false, "Reconnecting...")
	_try_connect()


func _on_send_pressed() -> void:
	if _selected_prompt_id == "":
		return
	
	# Save before sending
	_save_if_dirty()
	send_prompt(_selected_prompt_id)


func _on_delete_pressed() -> void:
	if _selected_prompt_id == "":
		return
	_is_dirty = false  # Don't save, we're deleting
	delete_prompt(_selected_prompt_id)


func _on_prompt_item_input(event: InputEvent, prompt_id: String) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_prompt(prompt_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_show_prompt_context_menu(prompt_id, event.global_position)


## Show the context menu for a prompt item.
func _show_prompt_context_menu(prompt_id: String, position: Vector2) -> void:
	if not _context_menu:
		return
	
	_context_menu_prompt_id = prompt_id
	_context_menu.clear()
	
	var prompt := get_prompt(prompt_id)
	if prompt.is_empty():
		return
	
	# Copy options
	_context_menu.add_item("Copy Title", 0)
	_context_menu.add_item("Copy Content", 1)
	_context_menu.add_item("Copy Title + Content", 2)
	_context_menu.add_separator()
	
	# Action options based on whether archived or not
	if _showing_archived:
		_context_menu.add_item("Restore to Active", 10)
		_context_menu.add_separator()
		_context_menu.add_item("Delete Permanently", 11)
	else:
		_context_menu.add_item("Duplicate", 20)
		_context_menu.add_item("Export...", 21)
		_context_menu.add_separator()
		_context_menu.add_item("Delete", 22)
	
	_context_menu.position = Vector2i(position)
	_context_menu.popup()


## Handle context menu item selection.
func _on_context_menu_id_pressed(id: int) -> void:
	var prompt := get_prompt(_context_menu_prompt_id)
	if prompt.is_empty():
		return
	
	match id:
		0:  # Copy Title
			var title: String = prompt.get("title", "")
			DisplayServer.clipboard_set(title)
			_show_auto_save_status("Title copied", Color(0.4, 0.7, 0.4))
		1:  # Copy Content
			var content: String = prompt.get("content", "")
			DisplayServer.clipboard_set(content)
			_show_auto_save_status("Content copied", Color(0.4, 0.7, 0.4))
		2:  # Copy Title + Content
			var title: String = prompt.get("title", "")
			var content: String = prompt.get("content", "")
			var combined := ""
			if title:
				combined = "# " + title + "\n\n"
			combined += content
			DisplayServer.clipboard_set(combined)
			_show_auto_save_status("Copied to clipboard", Color(0.4, 0.7, 0.4))
		10:  # Restore to Active
			restore_prompt(_context_menu_prompt_id)
		11:  # Delete Permanently
			delete_prompt(_context_menu_prompt_id)
			_show_auto_save_status("Deleted", Color(0.8, 0.4, 0.2))
		20:  # Duplicate
			duplicate_prompt(_context_menu_prompt_id)
		21:  # Export
			_on_export_pressed()
		22:  # Delete
			delete_prompt(_context_menu_prompt_id)
	
	_context_menu_prompt_id = ""


func _on_restore_prompt(prompt_id: String) -> void:
	restore_prompt(prompt_id)


func _on_delete_archived_prompt(prompt_id: String) -> void:
	# Permanently delete an archived prompt
	delete_prompt(prompt_id)
	_show_auto_save_status("Deleted", Color(0.8, 0.4, 0.2))


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	
	# Check if keyboard shortcuts are enabled
	if not _get_setting("keyboard_shortcuts_enabled", true):
		return
	
	if event is InputEventKey and event.pressed:
		# Ctrl+Enter to send
		if event.keycode == KEY_ENTER and event.ctrl_pressed:
			if _selected_prompt_id != "":
				_on_send_pressed()
				get_viewport().set_input_as_handled()
		# Ctrl+N to create new prompt
		elif event.keycode == KEY_N and event.ctrl_pressed:
			_on_new_prompt_pressed()
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
	
	# Check project config first for supported settings
	if ProjectConfig.is_using_project_config(key):
		var project_value: Variant = ProjectConfig.get_project_setting(key)
		if project_value != null:
			return project_value
	
	var settings := EditorInterface.get_editor_settings()
	var full_key := SETTINGS_PREFIX + key
	
	if settings.has_setting(full_key):
		return settings.get_setting(full_key)
	return default_value

#endregion


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE:
			_save_if_dirty()


func _exit_tree() -> void:
	_save_if_dirty()
	if _websocket:
		_websocket.close()
	if _reconnect_timer:
		_reconnect_timer.stop()
	if _auto_save_timer:
		_auto_save_timer.stop()


#region External Interface (Called by codot.gd)

## Called by the main plugin to inject the WebSocket server reference.
func set_websocket_server(_server: Node) -> void:
	# We manage our own WebSocket for VS Code communication
	# The server passed here is for MCP, not VS Code
	pass


## Called by the main plugin when settings change.
func on_settings_changed() -> void:
	# Update auto-save delay from settings
	var new_delay: float = _get_setting("auto_save_delay", AUTO_SAVE_DELAY)
	if _auto_save_timer:
		_auto_save_timer.wait_time = new_delay


## Called by the main plugin to update connection status display.
func update_connection_status(connected: bool, client_count: int, port: int) -> void:
	# This is for MCP server status, not VS Code
	# We could display this somewhere in the panel if desired
	pass


## Called when a send operation fails.
func show_send_error(message: String) -> void:
	_show_auto_save_status("Send failed", Color(0.8, 0.2, 0.2))
	push_warning("Codot: %s" % message)


## Called when a send operation succeeds.
func show_send_success() -> void:
	_show_auto_save_status("Sent ✓", Color(0.2, 0.8, 0.2))
	# Auto-archive after successful send
	if _selected_prompt_id != "" and _get_setting("auto_archive_on_send", true):
		_archive_prompt(_selected_prompt_id)


## Get connection diagnostics for debugging
func get_connection_diagnostics() -> Dictionary:
	return {
		"is_connected": _is_connected,
		"connection_attempts": _connection_attempts,
		"last_error": _last_connection_error,
		"websocket_valid": is_instance_valid(_websocket),
		"websocket_state": _websocket.get_ready_state() if is_instance_valid(_websocket) else -1,
		"vscode_port": _get_setting("vscode_port", DEFAULT_VSCODE_PORT)
	}

#endregion
