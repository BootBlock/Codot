## Codot Settings Manager
## [br][br]
## Manages Codot plugin settings in Godot's Editor Settings.
## Settings are stored under "plugin/codot/" prefix.
## Includes live-update callbacks for real-time setting changes.
@tool
class_name CodotSettings
extends RefCounted

const SETTINGS_PREFIX := "plugin/codot/"

## Setting definitions with metadata organized by category
const SETTING_DEFINITIONS := {
	# ===================
	# General Settings
	# ===================
	"enable_debug_logging": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Show [Codot] messages in Godot's Output panel. Disable to reduce console noise. Restart required for full effect."
	},
	
	# ===================
	# Prompt Panel Settings  
	# ===================
	"enable_prompt_panel": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Enable the Codot prompt management panel in the editor dock. Allows you to create, edit, and send prompts to VS Code AI assistants. Requires plugin reload to take effect."
	},
	"auto_archive_on_send": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Automatically move prompts to the archive after successfully sending them to VS Code. Keeps your active prompt list clean and focused on work in progress."
	},
	"auto_save_delay": {
		"default": 1.5,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0.5,10.0,0.5",
		"description": "Seconds to wait after you stop typing before auto-saving the prompt. Lower values save more frequently, higher values reduce disk writes."
	},
	"prompt_preview_length": {
		"default": 80,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "20,200",
		"description": "Maximum number of characters to show in the prompt preview in the list view. Longer values show more context but take more space."
	},
	
	# ===================
	# MCP Server Settings
	# ===================
	"enable_websocket_server": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Enable the MCP (Model Context Protocol) WebSocket server. AI agents like Claude connect to this server to control Godot. Disable if you only need the prompt panel."
	},
	"mcp_server_port": {
		"default": 6850,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1024,65535",
		"description": "Port number for the MCP WebSocket server. AI agents connect to ws://localhost:<port>. Change if the default port conflicts with other services. Requires server restart."
	},
	"mcp_connection_timeout": {
		"default": 30.0,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "5.0,120.0,1.0",
		"description": "Timeout in seconds for MCP commands. Long-running operations like running tests may need higher values. Commands that exceed this timeout will fail."
	},
	
	# ===================
	# VS Code Connection Settings
	# ===================
	"vscode_port": {
		"default": 6851,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1024,65535",
		"description": "Port number to connect to the VS Code Codot Bridge extension. The Codot panel sends prompts to VS Code on this port. Must match the port configured in VS Code."
	},
	"auto_reconnect": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Automatically attempt to reconnect to VS Code when the connection is lost. Useful when restarting VS Code or the Codot Bridge extension."
	},
	"reconnect_interval": {
		"default": 5.0,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1.0,60.0,0.5",
		"description": "Seconds between automatic reconnection attempts when disconnected from VS Code. Lower values reconnect faster but use more resources."
	},
	
	# ===================
	# Debug Capture Settings
	# ===================
	"enable_debug_capture": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Enable capturing debug output (errors, warnings, print statements) from running games. Required for commands like godot_get_debug_output. Requires plugin reload."
	},
	"max_debug_entries": {
		"default": 1000,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "100,10000,100",
		"description": "Maximum number of debug entries to keep in the capture buffer. Older entries are discarded when the limit is reached. Higher values use more memory."
	},
	"capture_print_statements": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Include print() statements in debug capture. Disable to only capture errors and warnings, reducing noise in debug output."
	},
	
	# ===================
	# Advanced Settings
	# ===================
	"show_connection_status": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Show the connection status indicator (● Connected/Disconnected) in the Codot panel header. Disable for a cleaner interface if you don't need visual feedback."
	},
	"confirm_prompt_delete": {
		"default": false,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Show a confirmation dialog before deleting prompts. Enable if you frequently accidentally delete prompts."
	},
	"keyboard_shortcuts_enabled": {
		"default": true,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"description": "Enable keyboard shortcuts in the Codot panel (Ctrl+Enter to send, Ctrl+N for new prompt). Disable if shortcuts conflict with other plugins."
	},
	"clear_archive_after_days": {
		"default": 0,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,365",
		"description": "Automatically delete archived prompts older than this many days. Set to 0 to keep archived prompts forever. Helps manage storage for long-term use."
	},
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
		"debug_logging":
			return get_setting("enable_debug_logging", true)
		"keyboard_shortcuts":
			return get_setting("keyboard_shortcuts_enabled", true)
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


## Get the description for a setting (for tooltips/help)
static func get_setting_description(key: String) -> String:
	if SETTING_DEFINITIONS.has(key):
		return SETTING_DEFINITIONS[key].get("description", "")
	return ""
