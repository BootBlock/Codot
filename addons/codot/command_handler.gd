@tool
extends Node
## Command handler for Codot AI agent integration.
##
## This class processes commands received from AI agents via WebSocket
## and executes corresponding actions in the Godot editor. It delegates
## to specialized command modules for organization and maintainability.
##
## @tutorial: https://github.com/your-repo/codot
## @version: 0.2.0
##
## =============================================================================
## ARCHITECTURE
## =============================================================================
##
## Commands are organized into modules under addons/codot/commands/:
##   - commands_status.gd     - Status, play, stop, debug output
##   - commands_scene_tree.gd - Scene tree inspection
##   - commands_file.gd       - File read/write/list operations
##   - commands_scene.gd      - Scene open/save/create
##   - commands_editor.gd     - Editor selection and settings
##   - commands_script.gd     - Script editing and errors
##   - commands_node.gd       - Node manipulation
##   - commands_input.gd      - Input simulation
##   - commands_gut.gd        - GUT testing framework
##   - commands_advanced.gd   - Signals, methods, groups
##   - commands_resource.gd   - Resources, animations, audio
##   - commands_debug.gd      - Performance, memory, advanced debug
##   - commands_plugin.gd     - Plugin management
##
## =============================================================================

## Reference to the EditorInterface for accessing editor functionality.
var editor_interface: EditorInterface = null:
	set(value):
		editor_interface = value
		_update_all_modules()

## Reference to the debugger plugin for capturing runtime errors.
var debugger_plugin: EditorDebuggerPlugin = null:
	set(value):
		debugger_plugin = value
		_update_all_modules()

# Command modules (loaded dynamically)
var _status: Object = null
var _scene_tree: Object = null
var _file: Object = null
var _scene: Object = null
var _editor: Object = null
var _script: Object = null
var _node: Object = null
var _input: Object = null
var _gut: Object = null
var _advanced: Object = null
var _resource: Object = null
var _debug: Object = null
var _plugin: Object = null


func _ready() -> void:
	_load_command_modules()


## Load all command modules.
func _load_command_modules() -> void:
	var base_path := "res://addons/codot/commands/"
	
	_status = _load_module(base_path + "commands_status.gd")
	_scene_tree = _load_module(base_path + "commands_scene_tree.gd")
	_file = _load_module(base_path + "commands_file.gd")
	_scene = _load_module(base_path + "commands_scene.gd")
	_editor = _load_module(base_path + "commands_editor.gd")
	_script = _load_module(base_path + "commands_script.gd")
	_node = _load_module(base_path + "commands_node.gd")
	_input = _load_module(base_path + "commands_input.gd")
	_gut = _load_module(base_path + "commands_gut.gd")
	_advanced = _load_module(base_path + "commands_advanced.gd")
	_resource = _load_module(base_path + "commands_resource.gd")
	_debug = _load_module(base_path + "commands_debug.gd")
	_plugin = _load_module(base_path + "commands_plugin.gd")


## Load a single command module and set up its references.
func _load_module(path: String) -> Object:
	if not FileAccess.file_exists(path):
		push_warning("[Codot] Module not found: " + path)
		return null
	
	var script := load(path) as GDScript
	if script == null:
		push_warning("[Codot] Failed to load module: " + path)
		return null
	
	var instance := script.new()
	if instance.has_method("setup"):
		instance.setup(editor_interface, debugger_plugin, get_tree())
	return instance


## Update references in all modules when editor_interface or debugger_plugin change.
func _update_all_modules() -> void:
	var modules := [_status, _scene_tree, _file, _scene, _editor, _script, 
					_node, _input, _gut, _advanced, _resource, _debug, _plugin]
	
	for module in modules:
		if module != null and module.has_method("setup"):
			module.setup(editor_interface, debugger_plugin, get_tree())


## Main command routing function.
## [br][br]
## Routes incoming commands to their respective handler functions based
## on the command name. All commands follow a request/response pattern
## with JSON serialization.
## [br][br]
## [param command]: Dictionary containing:
## - id: Unique command identifier for matching responses
## - command: String name of the command to execute
## - params: Dictionary of command-specific parameters
## [br][br]
## Returns a response Dictionary with success/error status and results.
func handle_command(command: Dictionary) -> Dictionary:
	var cmd_id = command.get("id")
	var cmd_name: String = command.get("command", "")
	var params: Dictionary = command.get("params", {})
	
	if cmd_name.is_empty():
		return _error(cmd_id, "MISSING_COMMAND", "No command specified")
	
	match cmd_name:
		# =================================================================
		# Basic Commands
		# =================================================================
		"ping":
			return _success(cmd_id, {"pong": true, "timestamp": Time.get_unix_time_from_system()})
		
		# =================================================================
		# Status & Game Control (commands_status.gd)
		# =================================================================
		"get_status":
			return _status.cmd_get_status(cmd_id, params)
		"play", "play_main_scene":
			return _status.cmd_play_main_scene(cmd_id, params)
		"play_current", "play_current_scene":
			return _status.cmd_play_current_scene(cmd_id, params)
		"play_custom_scene":
			return _status.cmd_play_custom_scene(cmd_id, params)
		"stop", "stop_scene":
			return _status.cmd_stop_scene(cmd_id, params)
		"is_playing":
			return _status.cmd_is_playing(cmd_id, params)
		"get_debug_output":
			return _status.cmd_get_debug_output(cmd_id, params)
		"clear_debug_log":
			return _status.cmd_clear_debug_log(cmd_id, params)
		"get_debugger_status":
			return _status.cmd_get_debugger_status(cmd_id, params)
		"get_editor_log":
			return _status.cmd_get_editor_log(cmd_id, params)
		
		# =================================================================
		# Scene Tree Inspection (commands_scene_tree.gd)
		# =================================================================
		"get_scene_tree":
			return _scene_tree.cmd_get_scene_tree(cmd_id, params)
		"get_node_info":
			return _scene_tree.cmd_get_node_info(cmd_id, params)
		"get_node_properties":
			return _scene_tree.cmd_get_node_properties(cmd_id, params)
		
		# =================================================================
		# File Operations (commands_file.gd)
		# =================================================================
		"get_project_files":
			return _file.cmd_get_project_files(cmd_id, params)
		"read_file":
			return _file.cmd_read_file(cmd_id, params)
		"write_file":
			return _file.cmd_write_file(cmd_id, params)
		"file_exists":
			return _file.cmd_file_exists(cmd_id, params)
		"create_directory":
			return _file.cmd_create_directory(cmd_id, params)
		"delete_file":
			return _file.cmd_delete_file(cmd_id, params)
		"delete_directory":
			return _file.cmd_delete_directory(cmd_id, params)
		"rename_file":
			return _file.cmd_rename_file(cmd_id, params)
		"copy_file":
			return _file.cmd_copy_file(cmd_id, params)
		"get_file_info":
			return _file.cmd_get_file_info(cmd_id, params)
		
		# =================================================================
		# Scene Operations (commands_scene.gd)
		# =================================================================
		"open_scene":
			return await _scene.cmd_open_scene(cmd_id, params)
		"save_scene":
			return await _scene.cmd_save_scene(cmd_id, params)
		"save_all_scenes":
			return _scene.cmd_save_all_scenes(cmd_id, params)
		"get_open_scenes":
			return _scene.cmd_get_open_scenes(cmd_id, params)
		"create_scene":
			return _scene.cmd_create_scene(cmd_id, params)
		"new_inherited_scene":
			return _scene.cmd_new_inherited_scene(cmd_id, params)
		"duplicate_scene":
			return _scene.cmd_duplicate_scene(cmd_id, params)
		"get_scene_dependencies":
			return _scene.cmd_get_scene_dependencies(cmd_id, params)
		"reload_current_scene":
			return _scene.cmd_reload_current_scene(cmd_id, params)
		"close_scene":
			return _scene.cmd_close_scene(cmd_id, params)
		
		# =================================================================
		# Editor Operations (commands_editor.gd)
		# =================================================================
		"get_selected_nodes":
			return _editor.cmd_get_selected_nodes(cmd_id, params)
		"select_node":
			return _editor.cmd_select_node(cmd_id, params)
		"get_editor_settings":
			return _editor.cmd_get_editor_settings(cmd_id, params)
		"get_editor_state":
			return _editor.cmd_get_editor_state(cmd_id, params)
		"get_unsaved_changes":
			return _editor.cmd_get_unsaved_changes(cmd_id, params)
		"get_project_settings":
			return _editor.cmd_get_project_settings(cmd_id, params)
		"list_resources":
			return _editor.cmd_list_resources(cmd_id, params)
		"get_open_dialogs":
			return _editor.cmd_get_open_dialogs(cmd_id, params)
		"dismiss_dialog":
			return _editor.cmd_dismiss_dialog(cmd_id, params)
		"refresh_filesystem":
			return _editor.cmd_refresh_filesystem(cmd_id, params)
		"reimport_resource":
			return _editor.cmd_reimport_resource(cmd_id, params)
		"mark_modified":
			return _editor.cmd_mark_modified(cmd_id, params)
		"get_current_screen":
			return _editor.cmd_get_current_screen(cmd_id, params)
		"set_current_screen":
			return _editor.cmd_set_current_screen(cmd_id, params)
		
		# =================================================================
		# Script Operations (commands_script.gd)
		# =================================================================
		"get_script_errors":
			return _script.cmd_get_script_errors(cmd_id, params)
		"open_script":
			return _script.cmd_open_script(cmd_id, params)
		
		# =================================================================
		# Node Manipulation (commands_node.gd)
		# =================================================================
		"create_node":
			return _node.cmd_create_node(cmd_id, params)
		"delete_node":
			return _node.cmd_delete_node(cmd_id, params)
		"set_node_property":
			return _node.cmd_set_node_property(cmd_id, params)
		"rename_node":
			return _node.cmd_rename_node(cmd_id, params)
		"move_node":
			return _node.cmd_move_node(cmd_id, params)
		"duplicate_node":
			return _node.cmd_duplicate_node(cmd_id, params)
		
		# =================================================================
		# Input Simulation (commands_input.gd)
		# =================================================================
		"simulate_key":
			return _input.cmd_simulate_key(cmd_id, params)
		"simulate_mouse_button":
			return _input.cmd_simulate_mouse_button(cmd_id, params)
		"simulate_mouse_motion":
			return _input.cmd_simulate_mouse_motion(cmd_id, params)
		"simulate_action":
			return _input.cmd_simulate_action(cmd_id, params)
		"get_input_actions":
			return _input.cmd_get_input_actions(cmd_id, params)
		
		# =================================================================
		# GUT Testing (commands_gut.gd)
		# =================================================================
		"gut_check_installed":
			return _gut.cmd_gut_check_installed(cmd_id, params)
		"gut_run_all":
			return _gut.cmd_gut_run_all(cmd_id, params)
		"gut_run_script":
			return _gut.cmd_gut_run_script(cmd_id, params)
		"gut_run_test":
			return _gut.cmd_gut_run_test(cmd_id, params)
		"gut_get_results":
			return _gut.cmd_gut_get_results(cmd_id, params)
		"gut_list_tests":
			return _gut.cmd_gut_list_tests(cmd_id, params)
		"gut_create_test":
			return _gut.cmd_gut_create_test(cmd_id, params)
		
		# =================================================================
		# Advanced Node Operations (commands_advanced.gd)
		# =================================================================
		"list_node_signals":
			return _advanced.cmd_list_node_signals(cmd_id, params)
		"emit_signal":
			return _advanced.cmd_emit_signal(cmd_id, params)
		"call_method":
			return _advanced.cmd_call_method(cmd_id, params)
		"list_node_methods":
			return _advanced.cmd_list_node_methods(cmd_id, params)
		"get_nodes_in_group":
			return _advanced.cmd_get_nodes_in_group(cmd_id, params)
		"add_node_to_group":
			return _advanced.cmd_add_node_to_group(cmd_id, params)
		"remove_node_from_group":
			return _advanced.cmd_remove_node_from_group(cmd_id, params)
		
		# =================================================================
		# Resource, Animation, Audio (commands_resource.gd)
		# =================================================================
		"load_resource":
			return _resource.cmd_load_resource(cmd_id, params)
		"get_resource_info":
			return _resource.cmd_get_resource_info(cmd_id, params)
		"list_animations":
			return _resource.cmd_list_animations(cmd_id, params)
		"play_animation":
			return _resource.cmd_play_animation(cmd_id, params)
		"stop_animation":
			return _resource.cmd_stop_animation(cmd_id, params)
		"list_audio_buses":
			return _resource.cmd_list_audio_buses(cmd_id, params)
		"set_audio_bus_volume":
			return _resource.cmd_set_audio_bus_volume(cmd_id, params)
		"set_audio_bus_mute":
			return _resource.cmd_set_audio_bus_mute(cmd_id, params)
		"create_resource":
			return _resource.cmd_create_resource(cmd_id, params)
		"save_resource":
			return _resource.cmd_save_resource(cmd_id, params)
		"duplicate_resource":
			return _resource.cmd_duplicate_resource(cmd_id, params)
		"set_resource_properties":
			return _resource.cmd_set_resource_properties(cmd_id, params)
		"list_resource_types":
			return _resource.cmd_list_resource_types(cmd_id, params)
		
		# =================================================================
		# Debug & Performance (commands_debug.gd)
		# =================================================================
		"get_performance_info":
			return _debug.cmd_get_performance_info(cmd_id, params)
		"get_memory_info":
			return _debug.cmd_get_memory_info(cmd_id, params)
		"print_to_console":
			return _debug.cmd_print_to_console(cmd_id, params)
		"get_recent_errors":
			return _debug.cmd_get_recent_errors(cmd_id, params)
		"run_and_capture":
			return await _debug.cmd_run_and_capture(cmd_id, params)
		"wait_for_output":
			return await _debug.cmd_wait_for_output(cmd_id, params)
		"ping_game":
			return await _debug.cmd_ping_game(cmd_id, params)
		"get_game_state":
			return _debug.cmd_get_game_state(cmd_id, params)
		"take_screenshot":
			return await _debug.cmd_take_screenshot(cmd_id, params)
		"gut_run_and_wait":
			return await _debug.cmd_gut_run_and_wait(cmd_id, params)
		"gut_get_summary":
			return _debug.cmd_gut_get_summary(cmd_id, params)
		
		# =================================================================
		# Plugin Management (commands_plugin.gd)
		# =================================================================
		"enable_plugin":
			return _plugin.cmd_enable_plugin(cmd_id, params)
		"disable_plugin":
			return _plugin.cmd_disable_plugin(cmd_id, params)
		"get_plugins":
			return _plugin.cmd_get_plugins(cmd_id, params)
		"reload_project":
			return _plugin.cmd_reload_project(cmd_id, params)
		
		# =================================================================
		# Unknown Command
		# =================================================================
		_:
			return _error(cmd_id, "UNKNOWN_COMMAND", "Unknown command: " + cmd_name)


## Create a successful response dictionary.
func _success(cmd_id: Variant, result: Dictionary) -> Dictionary:
	return {"id": cmd_id, "success": true, "result": result}


## Create an error response dictionary.
func _error(cmd_id: Variant, code: String, message: String) -> Dictionary:
	return {"id": cmd_id, "success": false, "error": {"code": code, "message": message}}
