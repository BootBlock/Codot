## GUT Testing Framework Module
## Handles GUT test discovery, execution, and result parsing.
extends "command_base.gd"

## Stores GUT process ID for async operations.
var _gut_process: int = -1

## Stores GUT console output.
var _gut_output: String = ""


## Check if GUT testing framework is installed.
## [br][br]
## Returns installation status and version if available.
func cmd_gut_check_installed(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var gut_path = "res://addons/gut/gut.gd"
	var installed = FileAccess.file_exists(gut_path)
	
	var version = ""
	if installed:
		var cfg_path = "res://addons/gut/plugin.cfg"
		if FileAccess.file_exists(cfg_path):
			var cfg = ConfigFile.new()
			if cfg.load(cfg_path) == OK:
				version = cfg.get_value("plugin", "version", "unknown")
	
	return _success(cmd_id, {
		"installed": installed,
		"version": version,
		"gut_path": gut_path
	})


## Run all GUT tests in specified directories.
## [br][br]
## [param params]:
## - 'dirs' (Array, default ["res://test/unit/"]): Test directories.
## - 'log_level' (int, default 1): GUT log verbosity level.
## - 'include_subdirs' (bool, default true): Include subdirectories.
## - 'output_file' (String): JUnit XML output file path.
func cmd_gut_run_all(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var gut_check = cmd_gut_check_installed(cmd_id, {})
	if not gut_check["result"]["installed"]:
		return _error(cmd_id, "GUT_NOT_INSTALLED", "GUT testing framework is not installed")
	
	var test_dirs: Array = params.get("dirs", ["res://test/unit/"])
	var log_level: int = params.get("log_level", 1)
	var include_subdirs: bool = params.get("include_subdirs", true)
	var output_file: String = params.get("output_file", "user://gut_results.xml")
	
	var args: Array = [
		"-d", "-s", "addons/gut/gut_cmdln.gd",
		"-gexit",
		"-glog=" + str(log_level),
		"-gjunit_xml_file=" + output_file
	]
	
	for dir in test_dirs:
		args.append("-gdir=" + str(dir))
	
	if include_subdirs:
		args.append("-ginclude_subdirs")
	
	var godot_path = OS.get_executable_path()
	var output: Array = []
	var exit_code = OS.execute(godot_path, args, output, true)
	
	return _success(cmd_id, {
		"started": true,
		"exit_code": exit_code,
		"output": "\n".join(output),
		"results_file": output_file,
		"message": "Tests completed. Use gut_get_results to parse the XML results."
	})


## Run all tests in a specific test script.
## [br][br]
## [param params]:
## - 'script' (String, required): Path to test script.
## - 'log_level' (int, default 1): GUT log verbosity level.
## - 'output_file' (String): JUnit XML output file path.
func cmd_gut_run_script(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var gut_check = cmd_gut_check_installed(cmd_id, {})
	if not gut_check["result"]["installed"]:
		return _error(cmd_id, "GUT_NOT_INSTALLED", "GUT testing framework is not installed")
	
	var script: String = params.get("script", "")
	if script.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'script' parameter")
	
	var log_level: int = params.get("log_level", 1)
	var output_file: String = params.get("output_file", "user://gut_results.xml")
	
	var args: Array = [
		"-d", "-s", "addons/gut/gut_cmdln.gd",
		"-gexit",
		"-glog=" + str(log_level),
		"-gtest=" + script,
		"-gjunit_xml_file=" + output_file
	]
	
	var godot_path = OS.get_executable_path()
	var output: Array = []
	var exit_code = OS.execute(godot_path, args, output, true)
	
	return _success(cmd_id, {
		"started": true,
		"script": script,
		"exit_code": exit_code,
		"output": "\n".join(output),
		"results_file": output_file
	})


## Run a specific test function within a test script.
## [br][br]
## [param params]:
## - 'script' (String, required): Path to test script.
## - 'test_name' (String, required): Name of test function to run.
## - 'log_level' (int, default 1): GUT log verbosity level.
## - 'output_file' (String): JUnit XML output file path.
func cmd_gut_run_test(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var gut_check = cmd_gut_check_installed(cmd_id, {})
	if not gut_check["result"]["installed"]:
		return _error(cmd_id, "GUT_NOT_INSTALLED", "GUT testing framework is not installed")
	
	var script: String = params.get("script", "")
	var test_name: String = params.get("test_name", "")
	
	if script.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'script' parameter")
	if test_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'test_name' parameter")
	
	var log_level: int = params.get("log_level", 1)
	var output_file: String = params.get("output_file", "user://gut_results.xml")
	
	var args: Array = [
		"-d", "-s", "addons/gut/gut_cmdln.gd",
		"-gexit",
		"-glog=" + str(log_level),
		"-gtest=" + script,
		"-gunit_test_name=" + test_name,
		"-gjunit_xml_file=" + output_file
	]
	
	var godot_path = OS.get_executable_path()
	var output: Array = []
	var exit_code = OS.execute(godot_path, args, output, true)
	
	return _success(cmd_id, {
		"started": true,
		"script": script,
		"test_name": test_name,
		"exit_code": exit_code,
		"output": "\n".join(output),
		"results_file": output_file
	})


## Get and parse GUT test results from JUnit XML file.
## [br][br]
## [param params]:
## - 'file' (String, default "user://gut_results.xml"): Results file path.
func cmd_gut_get_results(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var results_file: String = params.get("file", "user://gut_results.xml")
	
	if not FileAccess.file_exists(results_file):
		return _error(cmd_id, "FILE_NOT_FOUND", "Results file not found: " + results_file)
	
	var file = FileAccess.open(results_file, FileAccess.READ)
	if file == null:
		return _error(cmd_id, "READ_ERROR", "Failed to read results file")
	
	var xml_content = file.get_as_text()
	file.close()
	
	var results = _parse_junit_xml(xml_content)
	
	return _success(cmd_id, results)


## List test files and their test functions.
## [br][br]
## [param params]:
## - 'dirs' (Array, default ["res://test/"]): Directories to search.
## - 'prefix' (String, default "test_"): Test file prefix.
## - 'suffix' (String, default ".gd"): Test file suffix.
func cmd_gut_list_tests(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var test_dirs: Array = params.get("dirs", ["res://test/"])
	var prefix: String = params.get("prefix", "test_")
	var suffix: String = params.get("suffix", ".gd")
	
	var test_files: Array = []
	
	for dir in test_dirs:
		_find_test_files(dir, prefix, suffix, test_files)
	
	var tests: Array = []
	for file_path in test_files:
		var test_info = _parse_test_file(file_path)
		if test_info != null:
			tests.append(test_info)
	
	return _success(cmd_id, {
		"test_files": test_files,
		"tests": tests,
		"count": tests.size()
	})


## Create a new test file.
## [br][br]
## [param params]:
## - 'path' (String, required): Path for the new test file.
## - 'name' (String, optional): Initial test function name.
## - 'class_to_test' (String, optional): Path to class being tested.
func cmd_gut_create_test(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var file_path: String = params.get("path", "")
	var test_name: String = params.get("name", "")
	var class_to_test: String = params.get("class_to_test", "")
	
	if file_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not file_path.ends_with(".gd"):
		file_path += ".gd"
	
	# Ensure it follows naming convention
	var file_name = file_path.get_file()
	if not file_name.begins_with("test_"):
		var dir_part = file_path.get_base_dir()
		file_path = dir_part.path_join("test_" + file_name)
	
	# Create test file content
	var content = "extends GutTest\n\n"
	
	if not class_to_test.is_empty():
		content += "# Testing: " + class_to_test + "\n"
		content += "var _class_script = load(\"" + class_to_test + "\")\n\n"
	
	content += "func before_each():\n"
	content += "\t# Setup before each test\n"
	content += "\tpass\n\n"
	
	content += "func after_each():\n"
	content += "\t# Cleanup after each test\n"
	content += "\tpass\n\n"
	
	if not test_name.is_empty():
		var func_name = test_name
		if not func_name.begins_with("test_"):
			func_name = "test_" + func_name
		content += "func " + func_name + "():\n"
		content += "\t# TODO: Implement test\n"
		content += "\tpending(\"Not yet implemented\")\n"
	else:
		content += "func test_example():\n"
		content += "\t# Example test\n"
		content += "\tassert_true(true, \"This test passes\")\n"
	
	# Ensure directory exists
	var dir_path = file_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Write the file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return _error(cmd_id, "WRITE_ERROR", "Failed to create test file: " + str(FileAccess.get_open_error()))
	
	file.store_string(content)
	file.close()
	
	return _success(cmd_id, {
		"created": true,
		"path": file_path,
		"content": content
	})


# =============================================================================
# Helper Functions
# =============================================================================

## Parse JUnit XML format into a dictionary.
func _parse_junit_xml(xml_content: String) -> Dictionary:
	var parser = XMLParser.new()
	var error = parser.open_buffer(xml_content.to_utf8_buffer())
	
	if error != OK:
		return {"error": "Failed to parse XML", "raw": xml_content}
	
	var results = {
		"total_tests": 0,
		"total_failures": 0,
		"total_skipped": 0,
		"test_suites": []
	}
	
	var current_suite: Dictionary = {}
	var current_test: Dictionary = {}
	var in_failure = false
	var failure_text = ""
	
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node_name = parser.get_node_name()
				
				if node_name == "testsuites":
					for i in range(parser.get_attribute_count()):
						var attr_name = parser.get_attribute_name(i)
						if attr_name == "tests":
							results["total_tests"] = int(parser.get_attribute_value(i))
						elif attr_name == "failures":
							results["total_failures"] = int(parser.get_attribute_value(i))
				
				elif node_name == "testsuite":
					current_suite = {
						"name": "",
						"tests": 0,
						"failures": 0,
						"skipped": 0,
						"testcases": []
					}
					for i in range(parser.get_attribute_count()):
						var attr_name = parser.get_attribute_name(i)
						var attr_value = parser.get_attribute_value(i)
						if attr_name == "name":
							current_suite["name"] = attr_value
						elif attr_name == "tests":
							current_suite["tests"] = int(attr_value)
						elif attr_name == "failures":
							current_suite["failures"] = int(attr_value)
						elif attr_name == "skipped":
							current_suite["skipped"] = int(attr_value)
				
				elif node_name == "testcase":
					current_test = {
						"name": "",
						"status": "pass",
						"assertions": 0,
						"failure_message": ""
					}
					for i in range(parser.get_attribute_count()):
						var attr_name = parser.get_attribute_name(i)
						var attr_value = parser.get_attribute_value(i)
						if attr_name == "name":
							current_test["name"] = attr_value
						elif attr_name == "status":
							current_test["status"] = attr_value
						elif attr_name == "assertions":
							current_test["assertions"] = int(attr_value)
				
				elif node_name == "failure":
					in_failure = true
					failure_text = ""
				
				elif node_name == "skipped":
					current_test["status"] = "pending"
			
			XMLParser.NODE_TEXT:
				if in_failure:
					failure_text += parser.get_node_data()
			
			XMLParser.NODE_ELEMENT_END:
				var node_name = parser.get_node_name()
				
				if node_name == "testsuite":
					results["test_suites"].append(current_suite)
					results["total_skipped"] += current_suite["skipped"]
				
				elif node_name == "testcase":
					current_suite["testcases"].append(current_test)
				
				elif node_name == "failure":
					in_failure = false
					current_test["failure_message"] = failure_text.strip_edges()
	
	return results


## Recursively find test files.
func _find_test_files(dir_path: String, prefix: String, suffix: String, results: Array) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_find_test_files(dir_path.path_join(file_name), prefix, suffix, results)
		else:
			if file_name.begins_with(prefix) and file_name.ends_with(suffix):
				results.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	
	dir.list_dir_end()


## Parse a test file to find test functions.
func _parse_test_file(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	
	var content = file.get_as_text()
	file.close()
	
	var test_functions: Array = []
	var lines = content.split("\n")
	
	for line in lines:
		var stripped = line.strip_edges()
		if stripped.begins_with("func test_"):
			var paren_pos = stripped.find("(")
			if paren_pos > 0:
				var func_name = stripped.substr(5, paren_pos - 5)
				test_functions.append(func_name)
	
	return {
		"file": file_path,
		"test_count": test_functions.size(),
		"tests": test_functions
	}
