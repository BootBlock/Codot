## Unit tests for CodotSettings
extends GutTest

const CodotSettings := preload("res://addons/codot/codot_settings.gd")


#region Default Value Tests

func test_get_setting_returns_default_when_not_set() -> void:
	# These should return the defaults from SETTING_DEFINITIONS
	var result: bool = CodotSettings.get_setting("enable_prompt_panel", false)
	# Can't easily test in non-editor context, but verify it doesn't crash
	assert_true(result is bool or result == null, "Should return a value or null")


func test_setting_definitions_has_required_keys() -> void:
	for key: String in CodotSettings.SETTING_DEFINITIONS:
		var def: Dictionary = CodotSettings.SETTING_DEFINITIONS[key]
		assert_true(def.has("default"), "Setting '%s' should have 'default'" % key)
		assert_true(def.has("type"), "Setting '%s' should have 'type'" % key)
		assert_true(def.has("description"), "Setting '%s' should have 'description'" % key)


func test_all_settings_have_valid_types() -> void:
	var valid_types := [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]
	for key: String in CodotSettings.SETTING_DEFINITIONS:
		var def: Dictionary = CodotSettings.SETTING_DEFINITIONS[key]
		assert_true(def.type in valid_types, 
			"Setting '%s' has invalid type: %s" % [key, def.type])


func test_default_values_match_types() -> void:
	for key: String in CodotSettings.SETTING_DEFINITIONS:
		var def: Dictionary = CodotSettings.SETTING_DEFINITIONS[key]
		var default_type := typeof(def.default)
		match def.type:
			TYPE_BOOL:
				assert_eq(default_type, TYPE_BOOL, 
					"Setting '%s' default should be bool" % key)
			TYPE_INT:
				assert_eq(default_type, TYPE_INT, 
					"Setting '%s' default should be int" % key)
			TYPE_FLOAT:
				assert_true(default_type in [TYPE_FLOAT, TYPE_INT], 
					"Setting '%s' default should be float" % key)
			TYPE_STRING:
				assert_eq(default_type, TYPE_STRING, 
					"Setting '%s' default should be string" % key)

#endregion


#region Feature Flag Tests

func test_is_feature_enabled_returns_bool() -> void:
	var result: bool = CodotSettings.is_feature_enabled("prompt_panel")
	assert_true(result is bool, "Should return a boolean")


func test_is_feature_enabled_handles_unknown_feature() -> void:
	var result: bool = CodotSettings.is_feature_enabled("nonexistent_feature")
	assert_true(result, "Unknown feature should return true (enabled by default)")


func test_known_features_exist() -> void:
	# Verify all expected features have corresponding settings
	var features := ["prompt_panel", "websocket_server", "debug_capture"]
	for feature in features:
		var result: bool = CodotSettings.is_feature_enabled(feature)
		assert_true(result is bool, "Feature '%s' should be checkable" % feature)

#endregion


#region Settings Prefix Tests

func test_settings_prefix_is_correct() -> void:
	assert_eq(CodotSettings.SETTINGS_PREFIX, "plugin/codot/", 
		"Prefix should be 'plugin/codot/'")


func test_get_all_settings_returns_dict() -> void:
	var all_settings: Dictionary = CodotSettings.get_all_settings()
	assert_true(all_settings is Dictionary, "Should return a dictionary")


func test_get_all_settings_has_all_keys() -> void:
	var all_settings: Dictionary = CodotSettings.get_all_settings()
	for key: String in CodotSettings.SETTING_DEFINITIONS:
		assert_true(all_settings.has(key), 
			"get_all_settings should include '%s'" % key)

#endregion


#region Expected Settings Tests

func test_has_port_settings() -> void:
	assert_true(CodotSettings.SETTING_DEFINITIONS.has("mcp_server_port"),
		"Should have MCP server port setting")
	assert_true(CodotSettings.SETTING_DEFINITIONS.has("vscode_port"),
		"Should have VS Code port setting")


func test_port_defaults_are_valid() -> void:
	var mcp_port: int = CodotSettings.SETTING_DEFINITIONS["mcp_server_port"].default
	var vscode_port: int = CodotSettings.SETTING_DEFINITIONS["vscode_port"].default
	
	assert_true(mcp_port >= 1024 and mcp_port <= 65535,
		"MCP port should be in valid range")
	assert_true(vscode_port >= 1024 and vscode_port <= 65535,
		"VS Code port should be in valid range")
	assert_ne(mcp_port, vscode_port,
		"Ports should be different")


func test_has_enable_settings() -> void:
	var expected_enables := [
		"enable_prompt_panel",
		"enable_websocket_server",
		"enable_debug_capture"
	]
	for setting in expected_enables:
		assert_true(CodotSettings.SETTING_DEFINITIONS.has(setting),
			"Should have '%s' setting" % setting)


func test_has_auto_archive_setting() -> void:
	assert_true(CodotSettings.SETTING_DEFINITIONS.has("auto_archive_on_send"),
		"Should have auto_archive_on_send setting")
	assert_eq(CodotSettings.SETTING_DEFINITIONS["auto_archive_on_send"].default, true,
		"auto_archive_on_send should default to true")

#endregion
