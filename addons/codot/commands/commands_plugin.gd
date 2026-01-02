## Plugin Management Module
## Handles enabling, disabling, and listing editor plugins.
extends "command_base.gd"


## Enable an editor plugin by its name or folder name.
## [br][br]
## [param params]:
## - 'name' (String, required): Plugin name or folder name (e.g., "Codot", "gut")
func cmd_enable_plugin(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var plugin_name: String = params.get("name", "")
	if plugin_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'name' parameter")
	
	var plugin_path := _find_plugin_cfg(plugin_name)
	if plugin_path.is_empty():
		return _error(cmd_id, "PLUGIN_NOT_FOUND", "Plugin not found: " + plugin_name)
	
	if editor_interface.is_plugin_enabled(plugin_path):
		return _success(cmd_id, {
			"plugin": plugin_path,
			"enabled": true,
			"was_already_enabled": true,
		})
	
	editor_interface.set_plugin_enabled(plugin_path, true)
	
	return _success(cmd_id, {
		"plugin": plugin_path,
		"enabled": true,
		"was_already_enabled": false,
	})


## Disable an editor plugin by its name or folder name.
## [br][br]
## [param params]:
## - 'name' (String, required): Plugin name or folder name (e.g., "Codot", "gut")
func cmd_disable_plugin(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var plugin_name: String = params.get("name", "")
	if plugin_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'name' parameter")
	
	var plugin_path := _find_plugin_cfg(plugin_name)
	if plugin_path.is_empty():
		return _error(cmd_id, "PLUGIN_NOT_FOUND", "Plugin not found: " + plugin_name)
	
	if not editor_interface.is_plugin_enabled(plugin_path):
		return _success(cmd_id, {
			"plugin": plugin_path,
			"enabled": false,
			"was_already_disabled": true,
		})
	
	editor_interface.set_plugin_enabled(plugin_path, false)
	
	return _success(cmd_id, {
		"plugin": plugin_path,
		"enabled": false,
		"was_already_disabled": false,
	})


## List all available editor plugins and their enabled status.
func cmd_get_plugins(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var plugins: Array[Dictionary] = []
	var addons_dir := DirAccess.open("res://addons")
	
	if addons_dir != null:
		addons_dir.list_dir_begin()
		var folder_name := addons_dir.get_next()
		
		while folder_name != "":
			if addons_dir.current_is_dir() and not folder_name.begins_with("."):
				var plugin_cfg_path := "res://addons/" + folder_name + "/plugin.cfg"
				
				if FileAccess.file_exists(plugin_cfg_path):
					var cfg := ConfigFile.new()
					if cfg.load(plugin_cfg_path) == OK:
						var plugin_info := {
							"folder": folder_name,
							"path": plugin_cfg_path,
							"name": cfg.get_value("plugin", "name", folder_name),
							"description": cfg.get_value("plugin", "description", ""),
							"author": cfg.get_value("plugin", "author", ""),
							"version": cfg.get_value("plugin", "version", ""),
							"enabled": editor_interface.is_plugin_enabled(plugin_cfg_path),
						}
						plugins.append(plugin_info)
			
			folder_name = addons_dir.get_next()
		
		addons_dir.list_dir_end()
	
	return _success(cmd_id, {
		"plugins": plugins,
		"count": plugins.size(),
	})


## Reload the current project (restarts the editor).
## Note: This will close and reopen the project and disconnect the WebSocket.
func cmd_reload_project(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var project_path := ProjectSettings.globalize_path("res://")
	
	if editor_interface.has_method("restart_editor"):
		print("[Codot] Restarting editor...")
		call_deferred("_do_restart_editor", true)
		
		return _success(cmd_id, {
			"restarting": true,
			"project_path": project_path,
			"note": "Editor will restart momentarily. Connection will be lost.",
		})
	else:
		return _error(cmd_id, "NOT_SUPPORTED", "Editor restart not supported in this Godot version")


## Deferred restart to allow response to be sent first.
func _do_restart_editor(with_project: bool) -> void:
	await tree.create_timer(0.5).timeout
	editor_interface.restart_editor(with_project)


# =============================================================================
# Helper Functions
# =============================================================================

## Find a plugin.cfg path by plugin name or folder name.
func _find_plugin_cfg(name_or_folder: String) -> String:
	var lower_name := name_or_folder.to_lower()
	
	# First, try direct folder match
	var direct_path := "res://addons/" + name_or_folder + "/plugin.cfg"
	if FileAccess.file_exists(direct_path):
		return direct_path
	
	# Try lowercase folder match
	var lower_path := "res://addons/" + lower_name + "/plugin.cfg"
	if FileAccess.file_exists(lower_path):
		return lower_path
	
	# Search by plugin name in cfg files
	var addons_dir := DirAccess.open("res://addons")
	if addons_dir == null:
		return ""
	
	addons_dir.list_dir_begin()
	var folder_name := addons_dir.get_next()
	
	while folder_name != "":
		if addons_dir.current_is_dir() and not folder_name.begins_with("."):
			var plugin_cfg_path := "res://addons/" + folder_name + "/plugin.cfg"
			
			if FileAccess.file_exists(plugin_cfg_path):
				var cfg := ConfigFile.new()
				if cfg.load(plugin_cfg_path) == OK:
					var cfg_name: String = cfg.get_value("plugin", "name", "")
					if cfg_name.to_lower() == lower_name:
						addons_dir.list_dir_end()
						return plugin_cfg_path
		
		folder_name = addons_dir.get_next()
	
	addons_dir.list_dir_end()
	return ""
