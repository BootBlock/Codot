@tool
class_name CodotCommandBase
extends RefCounted
## Base class for Codot command modules.
##
## Provides common utilities and references for command implementations.
## All command modules should extend this class.
##
## @version: 0.1.0

## Reference to the EditorInterface for accessing editor functionality.
var editor_interface: EditorInterface = null

## Reference to the debugger plugin for capturing runtime errors.
var debugger_plugin: EditorDebuggerPlugin = null

## Reference to the main tree for async operations.
var tree: SceneTree = null


## Initialize the command module with required references.
func setup(p_editor_interface: EditorInterface, p_debugger_plugin: EditorDebuggerPlugin, p_tree: SceneTree) -> void:
	editor_interface = p_editor_interface
	debugger_plugin = p_debugger_plugin
	tree = p_tree


# =============================================================================
# RESPONSE HELPERS
# =============================================================================

## Create a successful response dictionary.
## [br][br]
## [param cmd_id]: The command ID for response matching.
## [param result]: Dictionary containing the result data.
func _success(cmd_id: Variant, result: Dictionary) -> Dictionary:
	return {"id": cmd_id, "success": true, "result": result}


## Create an error response dictionary.
## [br][br]
## [param cmd_id]: The command ID for response matching.
## [param code]: Error code string (e.g., "MISSING_PARAM", "NO_EDITOR").
## [param message]: Human-readable error description.
func _error(cmd_id: Variant, code: String, message: String) -> Dictionary:
	return {"id": cmd_id, "success": false, "error": {"code": code, "message": message}}


# =============================================================================
# COMMON UTILITIES
# =============================================================================

## Get a node by path from the current edited scene.
## Returns null if not found.
func _get_node_by_path(path: String) -> Node:
	if editor_interface == null:
		return null
	
	var root = editor_interface.get_edited_scene_root()
	if root == null:
		return null
	
	if path == "." or path.is_empty():
		return root
	
	return root.get_node_or_null(NodePath(path))


## Check if editor interface is available, return error dict if not.
## Returns empty dict if available.
func _require_editor(cmd_id: Variant) -> Dictionary:
	if editor_interface == null:
		return _error(cmd_id, "NO_EDITOR", "Editor interface not available")
	return {}


## Check if a scene is open, return error dict if not.
## Returns empty dict if scene is available.
func _require_scene(cmd_id: Variant) -> Dictionary:
	var err = _require_editor(cmd_id)
	if not err.is_empty():
		return err
	
	if editor_interface.get_edited_scene_root() == null:
		return _error(cmd_id, "NO_SCENE", "No scene is currently open")
	return {}


## Get the current edited scene root, with error checking.
## Returns [node, error_dict] where error_dict is empty on success.
func _get_scene_root_checked(cmd_id: Variant) -> Array:
	var err = _require_scene(cmd_id)
	if not err.is_empty():
		return [null, err]
	return [editor_interface.get_edited_scene_root(), {}]


## Get the current edited scene root (assumes _require_scene already called).
## Use this after calling _require_scene() for cleaner code.
func _get_scene_root() -> Node:
	if editor_interface == null:
		return null
	return editor_interface.get_edited_scene_root()


## Parse a value from string to the appropriate GDScript type.
## Used for setting node properties from JSON values.
func _parse_value(value: Variant, type_hint: String = "") -> Variant:
	if value is String:
		var s: String = value
		
		# Try to detect type from string content
		if s.begins_with("Vector2("):
			var inner = s.substr(8, s.length() - 9)
			var parts = inner.split(",")
			if parts.size() == 2:
				return Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges()))
		elif s.begins_with("Vector3("):
			var inner = s.substr(8, s.length() - 9)
			var parts = inner.split(",")
			if parts.size() == 3:
				return Vector3(float(parts[0].strip_edges()), float(parts[1].strip_edges()), float(parts[2].strip_edges()))
		elif s.begins_with("Color("):
			var inner = s.substr(6, s.length() - 7)
			var parts = inner.split(",")
			if parts.size() >= 3:
				var r = float(parts[0].strip_edges())
				var g = float(parts[1].strip_edges())
				var b = float(parts[2].strip_edges())
				var a = float(parts[3].strip_edges()) if parts.size() > 3 else 1.0
				return Color(r, g, b, a)
		elif s.begins_with("res://") or s.begins_with("user://"):
			# Resource path - try to load it
			if ResourceLoader.exists(s):
				return load(s)
			return s
		elif s == "true":
			return true
		elif s == "false":
			return false
		elif s.is_valid_float():
			return float(s)
		elif s.is_valid_int():
			return int(s)
	
	return value


## Recursively scan a directory for files.
func _scan_directory(path: String, extension: String, recursive: bool, files: Array) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var full_path = path.path_join(file_name)
		
		if dir.current_is_dir():
			if recursive:
				_scan_directory(full_path, extension, recursive, files)
		else:
			if extension.is_empty() or file_name.ends_with(extension):
				files.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


## Build a tree structure from a node, recursively.
func _build_tree(node: Node, depth: int, max_depth: int) -> Dictionary:
	var result: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"children": []
	}
	
	if depth < max_depth:
		for child in node.get_children():
			result["children"].append(_build_tree(child, depth + 1, max_depth))
	
	return result


# =============================================================================
# PATH VALIDATION HELPERS (Security Safeguards)
# =============================================================================

## Validate that a path is within the project directory.
## [br][br]
## [param path]: The path to validate (res://, user://, or absolute).
## [param cmd_id]: The command ID for error response.
## [returns]: Empty dictionary if valid, error dictionary if invalid.
func _validate_path_in_project(path: String, cmd_id: Variant) -> Dictionary:
	# Check if file access restriction is enabled
	if not _is_file_access_restricted():
		return {}  # No restriction
	
	# Allow res:// paths (always within project)
	if path.begins_with("res://"):
		return {}
	
	# Allow user:// paths (Godot user data directory)
	if path.begins_with("user://"):
		return {}
	
	# For absolute paths, check if they're within the project directory
	var project_path: String = ProjectSettings.globalize_path("res://")
	var absolute_path: String = path
	
	# Normalise paths for comparison
	project_path = project_path.replace("\\", "/").to_lower()
	absolute_path = absolute_path.replace("\\", "/").to_lower()
	
	if not absolute_path.begins_with(project_path):
		return _error(cmd_id, "PATH_OUTSIDE_PROJECT", 
			"File access restricted to project directory. Path '%s' is outside project root." % path)
	
	return {}


## Check if file access restriction is enabled in settings.
func _is_file_access_restricted() -> bool:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return true  # Default to restricted if settings unavailable
	return settings.get_setting("plugin/codot/restrict_file_access_to_project")


## Check if system commands are allowed.
func _are_system_commands_allowed() -> bool:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return false  # Default to not allowed if settings unavailable
	return settings.get_setting("plugin/codot/allow_system_commands")


## Get the maximum file size allowed for operations (in bytes).
func _get_max_file_size() -> int:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return 1024 * 1024  # Default 1MB
	var max_kb: int = settings.get_setting("plugin/codot/max_file_size_kb")
	return max_kb * 1024


## Validate file size before read/write operations.
## [br][br]
## [param path]: The file path to check.
## [param cmd_id]: The command ID for error response.
## [returns]: Empty dictionary if valid, error dictionary if file too large.
func _validate_file_size(path: String, cmd_id: Variant) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}  # Let other code handle file not found
	
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}  # Let other code handle access errors
	
	var file_size: int = file.get_length()
	file.close()
	
	var max_size: int = _get_max_file_size()
	if file_size > max_size:
		return _error(cmd_id, "FILE_TOO_LARGE",
			"File size (%d bytes) exceeds maximum allowed size (%d bytes)." % [file_size, max_size])
	
	return {}
