## Autoload Management Module
## Handles getting, adding, removing, and modifying autoload singletons.
extends "command_base.gd"


# =============================================================================
# Autoload Read Operations
# =============================================================================

## Get all autoload singletons defined in the project.
func cmd_get_autoloads(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var autoloads: Array[Dictionary] = []
	
	# Autoloads are stored in ProjectSettings with "autoload/" prefix
	var properties: Array[Dictionary] = ProjectSettings.get_property_list()
	
	for prop: Dictionary in properties:
		var prop_name: String = prop.get("name", "")
		if prop_name.begins_with("autoload/"):
			var autoload_name: String = prop_name.substr(9)  # Remove "autoload/" prefix
			var value: Variant = ProjectSettings.get_setting(prop_name)
			
			# Value format: "*path" for enabled, "path" for disabled
			# The asterisk indicates the autoload is a singleton
			var path: String = ""
			var is_singleton: bool = false
			
			if value is String:
				if value.begins_with("*"):
					is_singleton = true
					path = value.substr(1)
				else:
					path = value
			
			autoloads.append({
				"name": autoload_name,
				"path": path,
				"singleton": is_singleton,
				"enabled": true,  # If it's in ProjectSettings, it's enabled
			})
	
	return _success(cmd_id, {
		"autoloads": autoloads,
		"count": autoloads.size(),
	})


## Get information about a specific autoload.
## [br][br]
## [param params]:
## - 'name' (String, required): Name of the autoload singleton.
func cmd_get_autoload(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var autoload_name: String = params.get("name", "")
	
	if autoload_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'name' parameter")
	
	var setting_name: String = "autoload/" + autoload_name
	
	if not ProjectSettings.has_setting(setting_name):
		return _error(cmd_id, "AUTOLOAD_NOT_FOUND", "Autoload not found: " + autoload_name)
	
	var value: Variant = ProjectSettings.get_setting(setting_name)
	var path: String = ""
	var is_singleton: bool = false
	
	if value is String:
		if value.begins_with("*"):
			is_singleton = true
			path = value.substr(1)
		else:
			path = value
	
	# Check if the script/scene file exists
	var file_exists: bool = FileAccess.file_exists(path)
	
	return _success(cmd_id, {
		"name": autoload_name,
		"path": path,
		"singleton": is_singleton,
		"exists": true,
		"file_exists": file_exists,
	})


# =============================================================================
# Autoload Modify Operations
# =============================================================================

## Add a new autoload singleton to the project.
## [br][br]
## [param params]:
## - 'name' (String, required): Name of the autoload (will be accessible as /root/Name).
## - 'path' (String, required): Path to the script or scene (e.g., "res://scripts/game_manager.gd").
## - 'singleton' (bool, optional): Whether to create as singleton (accessible globally). Default: true.
func cmd_add_autoload(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var autoload_name: String = params.get("name", "")
	var script_path: String = params.get("path", "")
	var is_singleton: bool = params.get("singleton", true)
	
	if autoload_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'name' parameter")
	if script_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	# Validate name (must be valid identifier)
	if not autoload_name.is_valid_identifier():
		return _error(cmd_id, "INVALID_NAME", "Autoload name must be a valid identifier: " + autoload_name)
	
	# Check if file exists
	if not FileAccess.file_exists(script_path):
		return _error(cmd_id, "FILE_NOT_FOUND", "File not found: " + script_path)
	
	# Check if already exists
	var setting_name: String = "autoload/" + autoload_name
	if ProjectSettings.has_setting(setting_name):
		return _error(cmd_id, "AUTOLOAD_EXISTS", "Autoload already exists: " + autoload_name)
	
	# Add the autoload
	var value: String = ("*" if is_singleton else "") + script_path
	ProjectSettings.set_setting(setting_name, value)
	
	# Set the order (add to end)
	var order: int = _get_next_autoload_order()
	ProjectSettings.set_order(setting_name, order)
	
	var save_err: int = ProjectSettings.save()
	
	return _success(cmd_id, {
		"name": autoload_name,
		"path": script_path,
		"singleton": is_singleton,
		"added": true,
		"saved": save_err == OK,
		"note": "Restart the editor or reload the project to activate the autoload.",
	})


## Remove an autoload singleton from the project.
## [br][br]
## [param params]:
## - 'name' (String, required): Name of the autoload to remove.
func cmd_remove_autoload(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var autoload_name: String = params.get("name", "")
	
	if autoload_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'name' parameter")
	
	var setting_name: String = "autoload/" + autoload_name
	
	if not ProjectSettings.has_setting(setting_name):
		return _error(cmd_id, "AUTOLOAD_NOT_FOUND", "Autoload not found: " + autoload_name)
	
	# Remove the autoload
	ProjectSettings.set_setting(setting_name, null)
	
	var save_err: int = ProjectSettings.save()
	
	return _success(cmd_id, {
		"name": autoload_name,
		"removed": true,
		"saved": save_err == OK,
		"note": "Restart the editor or reload the project to apply the change.",
	})


## Rename an autoload singleton.
## [br][br]
## [param params]:
## - 'name' (String, required): Current name of the autoload.
## - 'new_name' (String, required): New name for the autoload.
func cmd_rename_autoload(cmd_id: Variant, params: Dictionary) -> Dictionary:
	# Support both 'name' and 'old_name' for the source autoload
	var autoload_name: String = params.get("old_name", params.get("name", ""))
	var new_name: String = params.get("new_name", "")
	
	if autoload_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'old_name' or 'name' parameter")
	if new_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'new_name' parameter")
	
	if not new_name.is_valid_identifier():
		return _error(cmd_id, "INVALID_NAME", "New autoload name must be a valid identifier: " + new_name)
	
	var old_setting: String = "autoload/" + autoload_name
	var new_setting: String = "autoload/" + new_name
	
	if not ProjectSettings.has_setting(old_setting):
		return _error(cmd_id, "AUTOLOAD_NOT_FOUND", "Autoload not found: " + autoload_name)
	
	if ProjectSettings.has_setting(new_setting):
		return _error(cmd_id, "AUTOLOAD_EXISTS", "Autoload already exists with name: " + new_name)
	
	# Get the old value and order
	var value: Variant = ProjectSettings.get_setting(old_setting)
	var order: int = ProjectSettings.get_order(old_setting)
	
	# Remove old, add new
	ProjectSettings.set_setting(old_setting, null)
	ProjectSettings.set_setting(new_setting, value)
	ProjectSettings.set_order(new_setting, order)
	
	var save_err: int = ProjectSettings.save()
	
	return _success(cmd_id, {
		"old_name": autoload_name,
		"new_name": new_name,
		"renamed": true,
		"saved": save_err == OK,
		"note": "Restart the editor or reload the project to apply the change.",
	})


## Change the path of an autoload singleton.
## [br][br]
## [param params]:
## - 'name' (String, required): Name of the autoload.
## - 'path' (String, required): New path to the script or scene.
func cmd_set_autoload_path(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var autoload_name: String = params.get("name", "")
	var new_path: String = params.get("path", "")
	
	if autoload_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'name' parameter")
	if new_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var setting_name: String = "autoload/" + autoload_name
	
	if not ProjectSettings.has_setting(setting_name):
		return _error(cmd_id, "AUTOLOAD_NOT_FOUND", "Autoload not found: " + autoload_name)
	
	if not FileAccess.file_exists(new_path):
		return _error(cmd_id, "FILE_NOT_FOUND", "File not found: " + new_path)
	
	# Get current value to preserve singleton flag
	var old_value: Variant = ProjectSettings.get_setting(setting_name)
	var is_singleton: bool = old_value is String and old_value.begins_with("*")
	
	var new_value: String = ("*" if is_singleton else "") + new_path
	ProjectSettings.set_setting(setting_name, new_value)
	
	var save_err: int = ProjectSettings.save()
	
	return _success(cmd_id, {
		"name": autoload_name,
		"path": new_path,
		"updated": true,
		"saved": save_err == OK,
		"note": "Restart the editor or reload the project to apply the change.",
	})


## Reorder autoloads (change loading order).
## [br][br]
## [param params]:
## - 'order' (Array, required): Array of autoload names in the desired order.
func cmd_reorder_autoloads(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var order_array: Array = params.get("order", [])
	
	if order_array.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'order' parameter (array of autoload names)")
	
	# Validate all names exist
	for name_entry: Variant in order_array:
		if name_entry is not String:
			return _error(cmd_id, "INVALID_PARAM", "Order array must contain strings")
		var autoload_name: String = name_entry as String
		var setting_name: String = "autoload/" + autoload_name
		if not ProjectSettings.has_setting(setting_name):
			return _error(cmd_id, "AUTOLOAD_NOT_FOUND", "Autoload not found: " + autoload_name)
	
	# Set order for each autoload
	var base_order: int = 100  # Start from a base order number
	for i: int in range(order_array.size()):
		var autoload_name: String = order_array[i]
		var setting_name: String = "autoload/" + autoload_name
		ProjectSettings.set_order(setting_name, base_order + i)
	
	var save_err: int = ProjectSettings.save()
	
	return _success(cmd_id, {
		"new_order": order_array,
		"reordered": true,
		"saved": save_err == OK,
		"note": "Restart the editor or reload the project to apply the change.",
	})


# =============================================================================
# Helper Functions
# =============================================================================

## Get the next available order number for autoloads.
func _get_next_autoload_order() -> int:
	var max_order: int = 100
	var properties: Array[Dictionary] = ProjectSettings.get_property_list()
	
	for prop: Dictionary in properties:
		var prop_name: String = prop.get("name", "")
		if prop_name.begins_with("autoload/"):
			var order: int = ProjectSettings.get_order(prop_name)
			if order > max_order:
				max_order = order
	
	return max_order + 1
