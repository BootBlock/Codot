## Codot Settings Manager
## [br][br]
## Manages Codot plugin settings in Godot's Editor Settings.
## Settings are stored under "plugin/codot/" prefix.
@tool
class_name CodotSettings
extends RefCounted

const SETTINGS_PREFIX := "plugin/codot/"

## Setting definitions with metadata
const SETTING_DEFINITIONS := {
	"enable_prompt_panel": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Enable the Codot prompt management panel in the editor dock."
	},
	"enable_websocket_server": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Enable the MCP WebSocket server for AI agent connections."
	},
	"enable_debug_capture": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Enable capturing debug output from running games."
	},
	"mcp_server_port": {
		"default": 6850,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1024,65535",
		"description": "Port for the MCP WebSocket server (AI agents connect here)."
	},
	"vscode_port": {
		"default": 6851,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1024,65535",
		"description": "Port to connect to VS Code Codot Bridge extension."
	},
	"auto_archive_on_send": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Automatically archive prompts after successfully sending to VS Code."
	},
	"max_debug_entries": {
		"default": 1000,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "100,10000",
		"description": "Maximum number of debug entries to keep in the buffer."
	},
	"auto_reconnect": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Automatically attempt to reconnect to VS Code when connection is lost."
	},
	"reconnect_interval": {
		"default": 5.0,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1.0,60.0,0.5",
		"description": "Seconds between reconnection attempts."
	},
	"show_connection_status": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Show connection status indicator in the Codot panel."
	}
}


## Register all Codot settings with the editor.
## Call this once during plugin initialization.
static func register_settings() -> void:
	if not Engine.is_editor_hint():
		return
	
	var settings := EditorInterface.get_editor_settings()
	
	for key: String in SETTING_DEFINITIONS:
		var def: Dictionary = SETTING_DEFINITIONS[key]
		var full_key: String = SETTINGS_PREFIX + key
		
		# Add setting if it doesn't exist
		if not settings.has_setting(full_key):
			settings.set_setting(full_key, def.default)
		
		# Set initial value from default (preserves existing values)
		settings.set_initial_value(full_key, def.default, false)
		
		# Add property info for the editor UI
		var property_info := {
			"name": full_key,
			"type": def.type,
			"hint": def.hint,
			"hint_string": def.hint_string
		}
		settings.add_property_info(property_info)


## Get a setting value with fallback to default.
static func get_setting(key: String, default_value: Variant = null) -> Variant:
	if not Engine.is_editor_hint():
		# Return default from definitions if available
		if default_value == null and SETTING_DEFINITIONS.has(key):
			return SETTING_DEFINITIONS[key].default
		return default_value
	
	var settings := EditorInterface.get_editor_settings()
	var full_key := SETTINGS_PREFIX + key
	
	if settings.has_setting(full_key):
		return settings.get_setting(full_key)
	
	# Fall back to definition default
	if SETTING_DEFINITIONS.has(key):
		return SETTING_DEFINITIONS[key].default
	
	return default_value


## Set a setting value.
static func set_setting(key: String, value: Variant) -> void:
	if not Engine.is_editor_hint():
		return
	
	var settings := EditorInterface.get_editor_settings()
	var full_key := SETTINGS_PREFIX + key
	settings.set_setting(full_key, value)


## Check if a feature is enabled based on settings.
static func is_feature_enabled(feature: String) -> bool:
	match feature:
		"prompt_panel":
			return get_setting("enable_prompt_panel", true)
		"websocket_server":
			return get_setting("enable_websocket_server", true)
		"debug_capture":
			return get_setting("enable_debug_capture", true)
		_:
			return true


## Get all current settings as a dictionary.
static func get_all_settings() -> Dictionary:
	var result := {}
	for key in SETTING_DEFINITIONS:
		result[key] = get_setting(key)
	return result


## Reset a setting to its default value.
static func reset_setting(key: String) -> void:
	if SETTING_DEFINITIONS.has(key):
		set_setting(key, SETTING_DEFINITIONS[key].default)


## Reset all settings to defaults.
static func reset_all_settings() -> void:
	for key in SETTING_DEFINITIONS:
		reset_setting(key)
