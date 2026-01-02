extends Node
## Test script for error capture functionality.
##
## This script generates various types of errors to test if they
## are properly captured by the Codot debug system.

@export var test_mode: String = "soft"  # "soft", "hard", or "all"

var _tests_run: int = 0


func _ready() -> void:
	print("[Test] Error capture test starting...")
	print("[Test] Mode: ", test_mode)
	
	# Give the debugger a moment to initialize
	await get_tree().create_timer(0.5).timeout
	
	match test_mode:
		"soft":
			_test_soft_errors()
		"hard":
			_test_hard_errors()
		"all":
			_test_soft_errors()
			await get_tree().create_timer(1.0).timeout
			_test_hard_errors()


func _test_soft_errors() -> void:
	## Test soft errors that don't halt execution
	print("[Test] === Testing Soft Errors ===")
	
	# Get the autoload for explicit capture
	var capture = get_node_or_null("/root/CodotOutputCapture")
	print("[Test] CodotOutputCapture autoload found: ", capture != null)
	
	if capture == null:
		# Try alternative paths
		capture = get_tree().root.get_node_or_null("CodotOutputCapture")
		print("[Test] Trying root.CodotOutputCapture: ", capture != null)
	
	# Debug: List root children
	print("[Test] Root children: ", get_tree().root.get_children().map(func(n): return n.name))
	
	# Test 1: push_error (standard Godot)
	push_error("TEST: This is a soft error via push_error()")
	_tests_run += 1
	print("[Test] push_error() called")
	
	# Also send via our capture system
	if capture:
		print("[Test] Sending explicit error via capture...")
		capture.capture_error("TEST: Explicit error via CodotOutputCapture")
	else:
		print("[Test] WARNING: No capture autoload - sending directly via EngineDebugger")
		if EngineDebugger.is_active():
			EngineDebugger.send_message("codot:entry", [{
				"id": 1,
				"type": "error",
				"message": "TEST: Direct error without autoload",
				"timestamp": Time.get_unix_time_from_system(),
			}])
	
	# Test 2: push_warning (standard Godot)
	push_warning("TEST: This is a warning via push_warning()")
	_tests_run += 1
	print("[Test] push_warning() called")
	
	# Also send via our capture system
	if capture:
		capture.capture_warning("TEST: Explicit warning via CodotOutputCapture")
	
	# Test 3: printerr (prints to stderr)
	printerr("TEST: This is stderr output via printerr()")
	_tests_run += 1
	print("[Test] printerr() called")
	
	# Test 4: Print (standard)
	print("[Test] This is a regular print() statement")
	if capture:
		capture.capture_print("TEST: Explicit print via CodotOutputCapture")
	
	print("[Test] Soft error tests complete. Tests run: ", _tests_run)
	
	# Signal to editor that tests are done
	if EngineDebugger.is_active():
		EngineDebugger.send_message("codot:test_complete", [{
			"mode": "soft",
			"tests_run": _tests_run,
			"capture_available": capture != null,
		}])


func _test_hard_errors() -> void:
	## Test hard errors that halt execution
	print("[Test] === Testing Hard Errors ===")
	print("[Test] This will cause a null reference error...")
	
	var capture = get_node_or_null("/root/CodotOutputCapture")
	
	# Signal before the error
	if EngineDebugger.is_active():
		EngineDebugger.send_message("codot:test_starting", [{
			"mode": "hard",
			"next_test": "null_reference",
		}])
	
	await get_tree().create_timer(0.5).timeout
	
	# Try to capture the error ourselves first
	if capture:
		capture.capture_error("About to trigger null reference error", get_script().resource_path, 91)
	
	# This will cause a hard error (null reference)
	var nonexistent: Node = null
	var _name = nonexistent.name  # This will error!
	
	# This line should never be reached
	print("[Test] ERROR: This line should not have been reached!")
