extends GutTest
## Unit tests for security safeguards.
##
## Tests the file access restriction, file size limits,
## and path validation features.


var _handler: Node = null
var _test_dir: String = "res://test_temp_safeguards/"


func before_each() -> void:
	# Create a fresh command handler for each test
	var handler_script: GDScript = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)
	
	# Create test directory
	if not DirAccess.dir_exists_absolute(_test_dir):
		DirAccess.make_dir_recursive_absolute(_test_dir)


func after_each() -> void:
	_handler = null
	
	# Clean up test directory after tests
	if DirAccess.dir_exists_absolute(_test_dir):
		_recursive_delete(_test_dir)


func _recursive_delete(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path: String = path.path_join(file_name)
				if dir.current_is_dir():
					_recursive_delete(full_path)
				else:
					dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		var parent: DirAccess = DirAccess.open(path.get_base_dir())
		if parent != null:
			parent.remove(path.get_file())


# =============================================================================
# Path Validation Tests
# =============================================================================

func test_res_path_allowed() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "file_exists",
		"params": {"path": "res://project.godot"}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "res:// paths should be allowed")


func test_user_path_allowed() -> void:
	var command: Dictionary = {
		"id": 1,
		"command": "file_exists",
		"params": {"path": "user://"}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "user:// paths should be allowed")


func test_absolute_path_in_project_allowed() -> void:
	# Get absolute path to project.godot
	var project_path: String = ProjectSettings.globalize_path("res://project.godot")
	
	var command: Dictionary = {
		"id": 1,
		"command": "file_exists",
		"params": {"path": project_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	# This should succeed because the path is within the project
	assert_true(response["success"], "Absolute paths within project should be allowed")


func test_path_outside_project_blocked() -> void:
	# Enable file access restriction
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var original_value: bool = settings.get_setting("plugin/codot/restrict_file_access_to_project")
	settings.set_setting("plugin/codot/restrict_file_access_to_project", true)
	
	# Try to access a path outside the project (Windows root or Unix root)
	var outside_path: String = "C:\\Windows\\System32\\notepad.exe" if OS.get_name() == "Windows" else "/etc/passwd"
	
	var command: Dictionary = {
		"id": 1,
		"command": "file_exists",
		"params": {"path": outside_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	# Restore original setting
	settings.set_setting("plugin/codot/restrict_file_access_to_project", original_value)
	
	# Should fail with PATH_OUTSIDE_PROJECT error
	assert_false(response["success"], "Paths outside project should be blocked")
	assert_eq(response["error"]["code"], "PATH_OUTSIDE_PROJECT", "Should have correct error code")


func test_path_restriction_disabled() -> void:
	# Disable file access restriction
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var original_value: bool = settings.get_setting("plugin/codot/restrict_file_access_to_project")
	settings.set_setting("plugin/codot/restrict_file_access_to_project", false)
	
	# Try to access a path outside the project
	var outside_path: String = "C:\\" if OS.get_name() == "Windows" else "/"
	
	var command: Dictionary = {
		"id": 1,
		"command": "file_exists",
		"params": {"path": outside_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	# Restore original setting
	settings.set_setting("plugin/codot/restrict_file_access_to_project", original_value)
	
	# Should succeed because restriction is disabled
	assert_true(response["success"], "Paths should be allowed when restriction is disabled")


# =============================================================================
# File Size Limit Tests
# =============================================================================

func test_read_file_within_size_limit() -> void:
	# Create a small test file
	var test_file: String = _test_dir.path_join("small_file.txt")
	var content: String = "This is a small test file."
	var file: FileAccess = FileAccess.open(test_file, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()
	
	var command: Dictionary = {
		"id": 1,
		"command": "read_file",
		"params": {"path": test_file}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "Reading small files should succeed")


func test_write_content_within_size_limit() -> void:
	var test_file: String = _test_dir.path_join("write_test.txt")
	var content: String = "This is a small test content."
	
	var command: Dictionary = {
		"id": 1,
		"command": "write_file",
		"params": {"path": test_file, "content": content}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	assert_true(response["success"], "Writing small content should succeed")


func test_write_content_exceeds_size_limit() -> void:
	# Set a very small max file size for testing
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var original_value: int = settings.get_setting("plugin/codot/max_file_size_kb")
	settings.set_setting("plugin/codot/max_file_size_kb", 1)  # 1 KB limit
	
	# Create content larger than 1 KB
	var large_content: String = ""
	for i: int in range(2000):  # 2000 characters > 1 KB
		large_content += "x"
	
	var test_file: String = _test_dir.path_join("large_write_test.txt")
	var command: Dictionary = {
		"id": 1,
		"command": "write_file",
		"params": {"path": test_file, "content": large_content}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	# Restore original setting
	settings.set_setting("plugin/codot/max_file_size_kb", original_value)
	
	assert_false(response["success"], "Writing large content should fail")
	assert_eq(response["error"]["code"], "CONTENT_TOO_LARGE", "Should have correct error code")


# =============================================================================
# Copy and Rename Path Validation Tests
# =============================================================================

func test_copy_file_validates_both_paths() -> void:
	# Enable file access restriction
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var original_value: bool = settings.get_setting("plugin/codot/restrict_file_access_to_project")
	settings.set_setting("plugin/codot/restrict_file_access_to_project", true)
	
	# Create a test file
	var test_file: String = _test_dir.path_join("source.txt")
	var file: FileAccess = FileAccess.open(test_file, FileAccess.WRITE)
	if file != null:
		file.store_string("test content")
		file.close()
	
	# Try to copy to outside the project
	var outside_path: String = "C:\\temp\\dest.txt" if OS.get_name() == "Windows" else "/tmp/dest.txt"
	
	var command: Dictionary = {
		"id": 1,
		"command": "copy_file",
		"params": {"from_path": test_file, "to_path": outside_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	# Restore original setting
	settings.set_setting("plugin/codot/restrict_file_access_to_project", original_value)
	
	assert_false(response["success"], "Copying to outside project should fail")
	assert_eq(response["error"]["code"], "PATH_OUTSIDE_PROJECT", "Should have correct error code")


func test_rename_file_validates_both_paths() -> void:
	# Enable file access restriction
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var original_value: bool = settings.get_setting("plugin/codot/restrict_file_access_to_project")
	settings.set_setting("plugin/codot/restrict_file_access_to_project", true)
	
	# Create a test file
	var test_file: String = _test_dir.path_join("rename_source.txt")
	var file: FileAccess = FileAccess.open(test_file, FileAccess.WRITE)
	if file != null:
		file.store_string("test content")
		file.close()
	
	# Try to rename to outside the project
	var outside_path: String = "C:\\temp\\renamed.txt" if OS.get_name() == "Windows" else "/tmp/renamed.txt"
	
	var command: Dictionary = {
		"id": 1,
		"command": "rename_file",
		"params": {"from_path": test_file, "to_path": outside_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	# Restore original setting
	settings.set_setting("plugin/codot/restrict_file_access_to_project", original_value)
	
	assert_false(response["success"], "Renaming to outside project should fail")
	assert_eq(response["error"]["code"], "PATH_OUTSIDE_PROJECT", "Should have correct error code")


# =============================================================================
# Directory Operations Path Validation Tests
# =============================================================================

func test_create_directory_validates_path() -> void:
	# Enable file access restriction
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var original_value: bool = settings.get_setting("plugin/codot/restrict_file_access_to_project")
	settings.set_setting("plugin/codot/restrict_file_access_to_project", true)
	
	# Try to create directory outside the project
	var outside_path: String = "C:\\temp\\test_dir" if OS.get_name() == "Windows" else "/tmp/test_dir"
	
	var command: Dictionary = {
		"id": 1,
		"command": "create_directory",
		"params": {"path": outside_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	# Restore original setting
	settings.set_setting("plugin/codot/restrict_file_access_to_project", original_value)
	
	assert_false(response["success"], "Creating directory outside project should fail")
	assert_eq(response["error"]["code"], "PATH_OUTSIDE_PROJECT", "Should have correct error code")


func test_delete_directory_validates_path() -> void:
	# Enable file access restriction
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var original_value: bool = settings.get_setting("plugin/codot/restrict_file_access_to_project")
	settings.set_setting("plugin/codot/restrict_file_access_to_project", true)
	
	# Try to delete directory outside the project
	var outside_path: String = "C:\\temp" if OS.get_name() == "Windows" else "/tmp"
	
	var command: Dictionary = {
		"id": 1,
		"command": "delete_directory",
		"params": {"path": outside_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	# Restore original setting
	settings.set_setting("plugin/codot/restrict_file_access_to_project", original_value)
	
	assert_false(response["success"], "Deleting directory outside project should fail")
	assert_eq(response["error"]["code"], "PATH_OUTSIDE_PROJECT", "Should have correct error code")


func test_get_project_files_validates_path() -> void:
	# Enable file access restriction
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var original_value: bool = settings.get_setting("plugin/codot/restrict_file_access_to_project")
	settings.set_setting("plugin/codot/restrict_file_access_to_project", true)
	
	# Try to list files outside the project
	var outside_path: String = "C:\\" if OS.get_name() == "Windows" else "/"
	
	var command: Dictionary = {
		"id": 1,
		"command": "get_project_files",
		"params": {"path": outside_path}
	}
	var response: Dictionary = await _handler.handle_command(command)
	
	# Restore original setting
	settings.set_setting("plugin/codot/restrict_file_access_to_project", original_value)
	
	assert_false(response["success"], "Listing files outside project should fail")
	assert_eq(response["error"]["code"], "PATH_OUTSIDE_PROJECT", "Should have correct error code")
