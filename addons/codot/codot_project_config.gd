## Codot Project Config Manager
## [br][br]
## Manages per-project settings stored in .codot/config.json.
## Allows projects to override global EditorSettings for specific options
## like pre/post prompts.
@tool
class_name CodotProjectConfig
extends RefCounted

## Path to the project config file (relative to project root).
const CONFIG_FILE_PATH := "res://.codot/config.json"

## Settings that can be stored per-project.
## These override the corresponding EditorSettings when present.
const PROJECT_SETTINGS := [
	"pre_prompt_message",
	"post_prompt_message",
	"wrap_prompts_with_prefix_suffix",
]

## Cached config data.
static var _config_cache: Dictionary = {}
static var _cache_loaded: bool = false


## Load the project config from disk.
## Returns true if config was loaded successfully.
static func load_config() -> bool:
	_config_cache = {}
	_cache_loaded = true
	
	if not FileAccess.file_exists(CONFIG_FILE_PATH):
		return false
	
	var file := FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Codot: Failed to open project config: " + CONFIG_FILE_PATH)
		return false
	
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(content)
	if error != OK:
		push_warning("Codot: Failed to parse project config: " + json.get_error_message())
		return false
	
	if json.data is Dictionary:
		_config_cache = json.data
		return true
	
	return false


## Save the project config to disk.
## Returns true if config was saved successfully.
static func save_config() -> bool:
	# Ensure the .codot directory exists
	var dir_path := CONFIG_FILE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			push_error("Codot: Failed to create config directory: " + dir_path)
			return false
	
	var file := FileAccess.open(CONFIG_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Codot: Failed to save project config: " + CONFIG_FILE_PATH)
		return false
	
	var json_string := JSON.stringify(_config_cache, "\t")
	file.store_string(json_string)
	file.close()
	
	return true


## Check if a project config file exists.
static func config_exists() -> bool:
	return FileAccess.file_exists(CONFIG_FILE_PATH)


## Get a setting from the project config.
## Returns null if the setting is not present.
static func get_project_setting(key: String) -> Variant:
	if not _cache_loaded:
		load_config()
	
	if _config_cache.has(key):
		return _config_cache[key]
	
	return null


## Set a setting in the project config.
## Pass null to remove the setting.
static func set_project_setting(key: String, value: Variant) -> void:
	if not _cache_loaded:
		load_config()
	
	if value == null:
		_config_cache.erase(key)
	else:
		_config_cache[key] = value


## Check if a setting has a project-level override.
static func has_project_setting(key: String) -> bool:
	if not _cache_loaded:
		load_config()
	
	return _config_cache.has(key)


## Get a setting with project override support.
## Checks project config first, then falls back to editor settings.
static func get_setting_with_project_override(key: String, default_value: Variant = null) -> Variant:
	# Check if this setting supports project-level overrides
	if key in PROJECT_SETTINGS:
		var project_value := get_project_setting(key)
		if project_value != null:
			return project_value
	
	# Fall back to editor settings
	return CodotSettings.get_setting(key, default_value)


## Get all project-level settings.
static func get_all_project_settings() -> Dictionary:
	if not _cache_loaded:
		load_config()
	
	return _config_cache.duplicate()


## Clear the config cache (force reload on next access).
static func clear_cache() -> void:
	_config_cache = {}
	_cache_loaded = false


## Check if project config is being used (vs editor settings).
static func is_using_project_config(key: String) -> bool:
	if key not in PROJECT_SETTINGS:
		return false
	
	return has_project_setting(key)


## Copy a setting from editor settings to project config.
static func copy_from_editor_settings(key: String) -> void:
	if key not in PROJECT_SETTINGS:
		push_warning("Codot: Setting '" + key + "' cannot be stored in project config")
		return
	
	var value := CodotSettings.get_setting(key)
	set_project_setting(key, value)


## Remove a project-level setting (revert to editor settings).
static func revert_to_editor_settings(key: String) -> void:
	set_project_setting(key, null)


## Initialise the project config system.
## Called during plugin initialization.
static func initialise() -> void:
	load_config()


## Get a summary of project config status.
static func get_status() -> Dictionary:
	if not _cache_loaded:
		load_config()
	
	return {
		"exists": config_exists(),
		"path": CONFIG_FILE_PATH,
		"settings_count": _config_cache.size(),
		"settings": _config_cache.keys(),
	}
