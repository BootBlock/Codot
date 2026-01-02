## Editor Operations Module
## Handles editor selection, settings, state queries, and dialog detection.
extends "command_base.gd"


## Detect if any modal dialog is currently open in the editor.
## [br][br]
## Returns dialog information if one is open, or indicates no dialog.
## Use this before running commands that might fail due to open dialogs.
func cmd_get_open_dialogs(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var dialogs: Array = []
	var has_blocking_dialog: bool = false
	
	# Get the editor's base control (root of all UI)
	var base_control: Control = editor_interface.get_base_control()
	if base_control == null:
		return _success(cmd_id, {
			"has_dialog": false,
			"has_blocking_dialog": false,
			"dialogs": [],
			"note": "Could not access editor base control"
		})
	
	# Recursively find all visible popup/dialog windows
	_find_open_dialogs(base_control, dialogs)
	
	# Also check for popup windows at the Window level
	var editor_windows = base_control.get_tree().root.get_children()
	for child in editor_windows:
		if child is Window and child.visible:
			if child is AcceptDialog or child is ConfirmationDialog or child is FileDialog:
				var dialog_info = _get_dialog_info(child)
				dialogs.append(dialog_info)
				if child.exclusive:
					has_blocking_dialog = true
	
	return _success(cmd_id, {
		"has_dialog": dialogs.size() > 0,
		"has_blocking_dialog": has_blocking_dialog,
		"dialogs": dialogs,
		"dialog_count": dialogs.size()
	})


## Helper: Recursively find open dialogs/popups in the control tree.
func _find_open_dialogs(node: Node, dialogs: Array) -> void:
	if node is Window and node.visible:
		if node is AcceptDialog or node is Popup:
			var dialog_info = _get_dialog_info(node)
			if not _dialog_in_list(dialog_info, dialogs):
				dialogs.append(dialog_info)
	
	for child in node.get_children():
		_find_open_dialogs(child, dialogs)


## Helper: Extract dialog information.
func _get_dialog_info(dialog: Window) -> Dictionary:
	var info: Dictionary = {
		"type": dialog.get_class(),
		"title": dialog.title if dialog.title else "(untitled)",
		"visible": dialog.visible,
		"exclusive": dialog.exclusive if "exclusive" in dialog else false,
		"name": dialog.name,
	}
	
	# Try to get dialog text for AcceptDialog types
	if dialog is AcceptDialog:
		info["text"] = dialog.dialog_text
		info["ok_button_text"] = dialog.ok_button_text
	
	return info


## Helper: Check if dialog is already in list (avoid duplicates).
func _dialog_in_list(dialog_info: Dictionary, dialogs: Array) -> bool:
	for d in dialogs:
		if d["name"] == dialog_info["name"] and d["type"] == dialog_info["type"]:
			return true
	return false


## Dismiss/close an open dialog by clicking OK or Cancel.
## [br][br]
## [param params]:
## - 'action' (String, default "ok"): "ok" to confirm, "cancel" to dismiss.
## - 'dialog_name' (String, optional): Specific dialog name to close.
func cmd_dismiss_dialog(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var action: String = params.get("action", "ok")
	var dialog_name: String = params.get("dialog_name", "")
	
	var base_control: Control = editor_interface.get_base_control()
	if base_control == null:
		return _error(cmd_id, "NO_BASE_CONTROL", "Could not access editor base control")
	
	# Find the dialog
	var found_dialog: AcceptDialog = null
	var windows = base_control.get_tree().root.get_children()
	
	for child in windows:
		if child is AcceptDialog and child.visible:
			if dialog_name.is_empty() or child.name == dialog_name:
				found_dialog = child
				break
	
	if found_dialog == null:
		# Also search within the control tree
		found_dialog = _find_first_open_dialog(base_control, dialog_name)
	
	if found_dialog == null:
		return _error(cmd_id, "NO_DIALOG", "No open dialog found to dismiss")
	
	var dialog_title = found_dialog.title
	
	match action:
		"ok", "confirm", "accept":
			if found_dialog.has_method("_ok_pressed"):
				found_dialog._ok_pressed()
			found_dialog.hide()
		"cancel", "dismiss", "close":
			if found_dialog is ConfirmationDialog and found_dialog.has_method("_cancel_pressed"):
				found_dialog._cancel_pressed()
			found_dialog.hide()
		_:
			return _error(cmd_id, "INVALID_ACTION", "Action must be 'ok' or 'cancel'")
	
	return _success(cmd_id, {
		"dismissed": true,
		"action": action,
		"dialog_title": dialog_title
	})


## Helper: Find first open AcceptDialog in control tree.
func _find_first_open_dialog(node: Node, name_filter: String = "") -> AcceptDialog:
	if node is AcceptDialog and node.visible:
		if name_filter.is_empty() or node.name == name_filter:
			return node
	
	for child in node.get_children():
		var found = _find_first_open_dialog(child, name_filter)
		if found != null:
			return found
	
	return null


## Get the currently selected nodes in the editor.
func cmd_get_selected_nodes(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var selection = editor_interface.get_selection()
	var selected: Array = []
	
	for node in selection.get_selected_nodes():
		selected.append({
			"name": node.name,
			"type": node.get_class(),
			"path": str(node.get_path())
		})
	
	return _success(cmd_id, {"selected": selected, "count": selected.size()})


## Select a node in the editor by path.
## [br][br]
## [param params]: Must contain 'path' (String) - node path to select.
func cmd_select_node(cmd_id: Variant, params: Dictionary) -> Dictionary:
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
	
	var selection = editor_interface.get_selection()
	selection.clear()
	selection.add_node(node)
	
	return _success(cmd_id, {"selected": node_path})


## Get current editor settings.
## [br][br]
## Returns theme preset and font size settings.
func cmd_get_editor_settings(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var settings = editor_interface.get_editor_settings()
	var data: Dictionary = {
		"theme": settings.get_setting("interface/theme/preset"),
		"font_size": settings.get_setting("interface/editor/main_font_size"),
	}
	return _success(cmd_id, data)


## Get comprehensive editor state.
## [br][br]
## Returns information about open scenes, modified files, current selection, etc.
func cmd_get_editor_state(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var state: Dictionary = {
		"is_playing": editor_interface.is_playing_scene(),
		"open_scenes": Array(editor_interface.get_open_scenes()),
		"current_scene": "",
		"current_scene_modified": false,
		"selected_nodes": [],
		"has_unsaved_changes": false,
		"modified_scenes": [],
	}
	
	# Get current scene info
	var root = editor_interface.get_edited_scene_root()
	if root != null:
		state["current_scene"] = root.scene_file_path
		# Check if scene has unsaved changes
		if root.scene_file_path.is_empty():
			state["current_scene_modified"] = true
			state["has_unsaved_changes"] = true
	
	# Get selected nodes
	var selection = editor_interface.get_selection()
	for node in selection.get_selected_nodes():
		state["selected_nodes"].append({
			"name": node.name,
			"type": node.get_class(),
			"path": str(root.get_path_to(node)) if root else str(node.get_path())
		})
	
	return _success(cmd_id, state)


## Check for unsaved changes in open scenes.
## [br][br]
## Returns list of scenes that may have unsaved modifications.
func cmd_get_unsaved_changes(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var data: Dictionary = {
		"has_unsaved": false,
		"unsaved_scenes": [],
		"current_scene_path": "",
		"current_scene_is_new": false,
	}
	
	var root = editor_interface.get_edited_scene_root()
	if root != null:
		data["current_scene_path"] = root.scene_file_path
		if root.scene_file_path.is_empty():
			data["current_scene_is_new"] = true
			data["has_unsaved"] = true
			data["unsaved_scenes"].append("(new unsaved scene)")
	
	return _success(cmd_id, data)


## Get project settings values.
## [br][br]
## [param params]: Optional 'keys' (Array) - specific settings to retrieve.
## If empty, returns common settings (name, description, version, main_scene, icon).
func cmd_get_project_settings(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var keys: Array = params.get("keys", [])
	
	var data: Dictionary = {}
	
	if keys.is_empty():
		# Return common project settings
		data = {
			"name": ProjectSettings.get_setting("application/config/name", ""),
			"description": ProjectSettings.get_setting("application/config/description", ""),
			"version": ProjectSettings.get_setting("application/config/version", ""),
			"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
			"icon": ProjectSettings.get_setting("application/config/icon", ""),
		}
	else:
		for key in keys:
			data[key] = ProjectSettings.get_setting(key, null)
	
	return _success(cmd_id, data)


## List resources of a specific type in the project.
## [br][br]
## [param params]:
## - 'type' (String): Resource type (scene, script, texture, audio, shader, resource).
## - 'path' (String, default "res://"): Directory to search.
func cmd_list_resources(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var resource_type: String = params.get("type", "")
	var path: String = params.get("path", "res://")
	
	var extensions: Array = []
	match resource_type:
		"scene", "scenes":
			extensions = [".tscn", ".scn"]
		"script", "scripts":
			extensions = [".gd", ".cs"]
		"texture", "textures", "image", "images":
			extensions = [".png", ".jpg", ".jpeg", ".webp", ".svg"]
		"audio", "sound", "sounds":
			extensions = [".ogg", ".wav", ".mp3"]
		"shader", "shaders":
			extensions = [".gdshader", ".shader"]
		"resource", "resources":
			extensions = [".tres", ".res"]
		_:
			extensions = []  # All files
	
	var files: Array = []
	
	for ext in extensions if extensions.size() > 0 else [""]:
		var ext_files: Array = []
		_scan_directory(path, ext, true, ext_files)
		files.append_array(ext_files)
	
	return _success(cmd_id, {"resources": files, "type": resource_type, "count": files.size()})


## Refresh the editor's FileSystem dock to detect new/modified files.
## [br][br]
## Use this after creating or modifying files externally to make the editor aware.
func cmd_refresh_filesystem(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var filesystem := editor_interface.get_resource_filesystem()
	if filesystem == null:
		return _error(cmd_id, "NO_FILESYSTEM", "Cannot access editor filesystem")
	
	# Scan the filesystem
	filesystem.scan()
	
	return _success(cmd_id, {
		"refreshed": true,
		"scanning": filesystem.is_scanning()
	})


## Reimport a specific resource file.
## [br][br]
## [param params]:
## - 'path' (String, required): Resource path to reimport.
func cmd_reimport_resource(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not FileAccess.file_exists(path):
		return _error(cmd_id, "FILE_NOT_FOUND", "File not found: " + path)
	
	var filesystem := editor_interface.get_resource_filesystem()
	if filesystem == null:
		return _error(cmd_id, "NO_FILESYSTEM", "Cannot access editor filesystem")
	
	# Update the file in the filesystem
	filesystem.update_file(path)
	
	return _success(cmd_id, {
		"reimported": true,
		"path": path
	})


## Mark a resource as unsaved/modified.
## [br][br]
## [param params]:
## - 'path' (String, required): Resource path to mark as modified.
func cmd_mark_modified(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not ResourceLoader.exists(path):
		return _error(cmd_id, "RESOURCE_NOT_FOUND", "Resource not found: " + path)
	
	editor_interface.mark_scene_as_unsaved()
	
	return _success(cmd_id, {"marked": true, "path": path})


## Get current editor screen/view (2D, 3D, Script, AssetLib).
func cmd_get_current_screen(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var main_screen := editor_interface.get_editor_main_screen()
	var screen_name := ""
	
	# Determine current screen from focused control
	var focused := editor_interface.get_base_control().get_viewport().gui_get_focus_owner()
	if focused != null:
		var parent := focused.get_parent()
		while parent != null:
			if parent.name == "ScriptEditor":
				screen_name = "Script"
				break
			elif parent.name == "Node3DEditor":
				screen_name = "3D"
				break
			elif parent.name == "CanvasItemEditor":
				screen_name = "2D"
				break
			elif parent.name == "EditorAssetLibrary":
				screen_name = "AssetLib"
				break
			parent = parent.get_parent()
	
	return _success(cmd_id, {
		"screen": screen_name if screen_name else "Unknown",
		"main_screen_available": main_screen != null
	})


## Switch to a specific editor screen (2D, 3D, Script, AssetLib).
## [br][br]
## [param params]:
## - 'screen' (String, required): Screen name to switch to.
func cmd_set_current_screen(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var screen: String = params.get("screen", "")
	if screen.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'screen' parameter (2D, 3D, Script, AssetLib)")
	
	var valid_screens := ["2D", "3D", "Script", "AssetLib"]
	if screen not in valid_screens:
		return _error(cmd_id, "INVALID_SCREEN", "Invalid screen. Valid: " + str(valid_screens))
	
	editor_interface.set_main_screen_editor(screen)
	
	return _success(cmd_id, {"screen": screen, "switched": true})


# =============================================================================
# Project Config Commands
# =============================================================================

## Get project config status and settings.
## [br][br]
## Returns information about the project-level config file.
func cmd_get_project_config(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	const ProjectConfig = preload("res://addons/codot/codot_project_config.gd")
	
	return _success(cmd_id, {
		"exists": ProjectConfig.config_exists(),
		"path": ProjectConfig.CONFIG_FILE_PATH,
		"settings": ProjectConfig.get_all_project_settings(),
		"supported_settings": ProjectConfig.PROJECT_SETTINGS,
	})


## Set a project config setting.
## [br][br]
## [param params]:
## - 'key' (String, required): Setting key to set.
## - 'value' (Variant, required): Value to set. Pass null to remove.
func cmd_set_project_config(cmd_id: Variant, params: Dictionary) -> Dictionary:
	const ProjectConfig = preload("res://addons/codot/codot_project_config.gd")
	
	var key: String = params.get("key", "")
	if key.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'key' parameter")
	
	if key not in ProjectConfig.PROJECT_SETTINGS:
		return _error(cmd_id, "INVALID_KEY", "Key not supported for project config. Supported: " + str(ProjectConfig.PROJECT_SETTINGS))
	
	# value can be null (to clear/remove the setting)
	var value: Variant = params.get("value", null)
	ProjectConfig.set_project_setting(key, value)
	var saved: bool = ProjectConfig.save_config()
	
	return _success(cmd_id, {
		"key": key,
		"value": value,
		"saved": saved,
	})
