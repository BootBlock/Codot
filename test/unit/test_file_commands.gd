extends GutTest
## Unit tests for file operation commands.
##
## Tests the create_directory, delete_file, delete_directory,
## rename_file, copy_file, and get_file_info commands.


var _handler: Node = null
var _test_dir: String = "res://test_temp_files/"


func before_each() -> void:
	# Create a fresh command handler for each test
	var handler_script = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)
	
	# Clean up test directory if it exists
	if DirAccess.dir_exists_absolute(_test_dir):
		_recursive_delete(_test_dir)


func after_each() -> void:
	_handler = null
	
	# Clean up test directory after tests
	if DirAccess.dir_exists_absolute(_test_dir):
		_recursive_delete(_test_dir)


func _recursive_delete(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path = path.path_join(file_name)
				if dir.current_is_dir():
					_recursive_delete(full_path)
				else:
					dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		var parent = DirAccess.open(path.get_base_dir())
		if parent:
			parent.remove(path.get_file())


# =============================================================================
# Create Directory Tests
# =============================================================================

func test_create_directory_basic() -> void:
	var command = {
		"id": 1,
		"command": "create_directory",
		"params": {"path": _test_dir}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "create_directory should succeed")
	assert_true(response["result"]["created"], "Directory should be created")
	assert_false(response["result"]["already_exists"], "Should not already exist")
	assert_true(DirAccess.dir_exists_absolute(_test_dir), "Directory should exist on disk")


func test_create_directory_already_exists() -> void:
	# Create directory first
	DirAccess.make_dir_recursive_absolute(_test_dir)
	
	var command = {
		"id": 1,
		"command": "create_directory",
		"params": {"path": _test_dir}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed even if exists")
	assert_false(response["result"]["created"], "Should not create again")
	assert_true(response["result"]["already_exists"], "Should indicate already exists")


func test_create_directory_nested() -> void:
	var nested_path = _test_dir + "nested/deep/folder"
	var command = {
		"id": 1,
		"command": "create_directory",
		"params": {"path": nested_path}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "Nested directory creation should succeed")
	assert_true(DirAccess.dir_exists_absolute(nested_path), "Nested directory should exist")


func test_create_directory_missing_param() -> void:
	var command = {
		"id": 1,
		"command": "create_directory",
		"params": {}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without path")
	assert_eq(response["error"]["code"], "MISSING_PARAM")


# =============================================================================
# Delete File Tests
# =============================================================================

func test_delete_file_basic() -> void:
	# Create a test file first
	DirAccess.make_dir_recursive_absolute(_test_dir)
	var file_path = _test_dir + "test_file.txt"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string("test content")
	file.close()
	
	var command = {
		"id": 1,
		"command": "delete_file",
		"params": {"path": file_path}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "delete_file should succeed")
	assert_true(response["result"]["deleted"], "File should be deleted")
	assert_false(FileAccess.file_exists(file_path), "File should not exist on disk")


func test_delete_file_not_found() -> void:
	var command = {
		"id": 1,
		"command": "delete_file",
		"params": {"path": _test_dir + "nonexistent.txt"}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail for nonexistent file")
	assert_eq(response["error"]["code"], "FILE_NOT_FOUND")


# =============================================================================
# Copy File Tests
# =============================================================================

func test_copy_file_basic() -> void:
	# Create source file
	DirAccess.make_dir_recursive_absolute(_test_dir)
	var source_path = _test_dir + "source.txt"
	var dest_path = _test_dir + "copy.txt"
	
	var file = FileAccess.open(source_path, FileAccess.WRITE)
	file.store_string("source content")
	file.close()
	
	var command = {
		"id": 1,
		"command": "copy_file",
		"params": {"from_path": source_path, "to_path": dest_path}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "copy_file should succeed")
	assert_true(response["result"]["copied"], "File should be copied")
	assert_true(FileAccess.file_exists(source_path), "Source should still exist")
	assert_true(FileAccess.file_exists(dest_path), "Destination should exist")
	
	# Verify content
	var dest_file = FileAccess.open(dest_path, FileAccess.READ)
	assert_eq(dest_file.get_as_text(), "source content", "Content should match")
	dest_file.close()


func test_copy_file_dest_exists_no_overwrite() -> void:
	DirAccess.make_dir_recursive_absolute(_test_dir)
	var source_path = _test_dir + "source.txt"
	var dest_path = _test_dir + "dest.txt"
	
	# Create both files
	for p in [source_path, dest_path]:
		var f = FileAccess.open(p, FileAccess.WRITE)
		f.store_string("content")
		f.close()
	
	var command = {
		"id": 1,
		"command": "copy_file",
		"params": {"from_path": source_path, "to_path": dest_path, "overwrite": false}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without overwrite")
	assert_eq(response["error"]["code"], "FILE_EXISTS")


func test_copy_file_with_overwrite() -> void:
	DirAccess.make_dir_recursive_absolute(_test_dir)
	var source_path = _test_dir + "source.txt"
	var dest_path = _test_dir + "dest.txt"
	
	# Create source with specific content
	var f = FileAccess.open(source_path, FileAccess.WRITE)
	f.store_string("new content")
	f.close()
	
	# Create dest with different content
	f = FileAccess.open(dest_path, FileAccess.WRITE)
	f.store_string("old content")
	f.close()
	
	var command = {
		"id": 1,
		"command": "copy_file",
		"params": {"from_path": source_path, "to_path": dest_path, "overwrite": true}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "copy_file with overwrite should succeed")
	
	# Verify new content
	var dest_file = FileAccess.open(dest_path, FileAccess.READ)
	assert_eq(dest_file.get_as_text(), "new content", "Content should be overwritten")
	dest_file.close()


# =============================================================================
# Rename/Move File Tests
# =============================================================================

func test_rename_file_basic() -> void:
	DirAccess.make_dir_recursive_absolute(_test_dir)
	var old_path = _test_dir + "old_name.txt"
	var new_path = _test_dir + "new_name.txt"
	
	var file = FileAccess.open(old_path, FileAccess.WRITE)
	file.store_string("content")
	file.close()
	
	var command = {
		"id": 1,
		"command": "rename_file",
		"params": {"from_path": old_path, "to_path": new_path}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "rename_file should succeed")
	assert_true(response["result"]["renamed"], "File should be renamed")
	assert_eq(response["result"]["type"], "file", "Type should be file")
	assert_false(FileAccess.file_exists(old_path), "Old path should not exist")
	assert_true(FileAccess.file_exists(new_path), "New path should exist")


func test_rename_directory() -> void:
	var old_dir = _test_dir + "old_dir/"
	var new_dir = _test_dir + "new_dir/"
	DirAccess.make_dir_recursive_absolute(old_dir)
	
	var command = {
		"id": 1,
		"command": "rename_file",
		"params": {"from_path": old_dir.rstrip("/"), "to_path": new_dir.rstrip("/")}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "rename directory should succeed")
	assert_eq(response["result"]["type"], "directory", "Type should be directory")


# =============================================================================
# Get File Info Tests
# =============================================================================

func test_get_file_info_for_file() -> void:
	DirAccess.make_dir_recursive_absolute(_test_dir)
	var file_path = _test_dir + "info_test.gd"
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string("extends Node\n")
	file.close()
	
	var command = {
		"id": 1,
		"command": "get_file_info",
		"params": {"path": file_path}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "get_file_info should succeed")
	assert_eq(response["result"]["type"], "file", "Type should be file")
	assert_eq(response["result"]["extension"], "gd", "Extension should be gd")
	assert_eq(response["result"]["name"], "info_test.gd", "Name should match")
	assert_true(response["result"]["size"] > 0, "Size should be positive")


func test_get_file_info_for_directory() -> void:
	DirAccess.make_dir_recursive_absolute(_test_dir)
	
	var command = {
		"id": 1,
		"command": "get_file_info",
		"params": {"path": _test_dir.rstrip("/")}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "get_file_info should succeed for directory")
	assert_eq(response["result"]["type"], "directory", "Type should be directory")


func test_get_file_info_not_found() -> void:
	var command = {
		"id": 1,
		"command": "get_file_info",
		"params": {"path": _test_dir + "nonexistent.txt"}
	}
	var response = _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail for nonexistent path")
	assert_eq(response["error"]["code"], "NOT_FOUND")


# =============================================================================
# Delete Directory Tests
# =============================================================================

func test_delete_directory_empty() -> void:
	var dir_path = _test_dir + "empty_dir"
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	var command = {
		"id": 1,
		"command": "delete_directory",
		"params": {"path": dir_path}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "delete_directory should succeed for empty dir")
	assert_true(response["result"]["deleted"], "Directory should be deleted")


func test_delete_directory_recursive() -> void:
	var dir_path = _test_dir + "nonempty_dir"
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Create some files inside
	var file = FileAccess.open(dir_path + "/file1.txt", FileAccess.WRITE)
	file.store_string("content")
	file.close()
	
	file = FileAccess.open(dir_path + "/file2.txt", FileAccess.WRITE)
	file.store_string("content")
	file.close()
	
	var command = {
		"id": 1,
		"command": "delete_directory",
		"params": {"path": dir_path, "recursive": true}
	}
	var response = _handler.handle_command(command)
	
	assert_true(response["success"], "delete_directory recursive should succeed")
	assert_true(response["result"]["files_deleted"] >= 2, "Should have deleted files")
	assert_false(DirAccess.dir_exists_absolute(dir_path), "Directory should not exist")
