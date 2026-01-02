extends Node2D

func _ready() -> void:
	print("=== TEST OUTPUT START ===")
	
	# Regular print
	print("This is a regular print statement")
	
	# Print rich (for Output panel)
	print_rich("[color=green]This is print_rich[/color]")
	
	# Push error (soft error)
	push_error("TEST_SOFT_ERROR: This is a push_error call")
	
	# Push warning
	push_warning("TEST_WARNING: This is a push_warning call")
	
	# printerr (stderr)
	printerr("This is printerr (stderr)")
	
	print("=== TEST OUTPUT END ===")
	
	# Wait a bit then quit
	await get_tree().create_timer(2.0).timeout
	print("Quitting after timer...")
