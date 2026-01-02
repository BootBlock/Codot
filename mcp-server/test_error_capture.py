"""Test script to verify error capture capabilities."""
import asyncio
import time
from codot.godot_client import GodotClient


SOFT_ERROR_SCRIPT = '''extends Node2D
## Test script with a soft error (push_error) that doesn't halt execution

var counter: int = 0

func _ready() -> void:
	print("Test scene started - soft error test")
	# This will log an error but not halt execution
	push_error("This is a SOFT ERROR - execution continues")
	push_warning("This is a WARNING - just for testing")
	print("Execution continued after soft error!")

func _process(delta: float) -> void:
	counter += 1
	if counter == 60:  # After ~1 second
		print("Still running after 60 frames!")
	if counter == 120:
		push_error("Another soft error at frame 120")
'''

HARD_ERROR_SCRIPT = '''extends Node2D
## Test script with a hard error that halts execution

func _ready() -> void:
	print("Test scene started - hard error test")
	# This will cause a runtime error and halt
	var node: Node = null
	node.get_name()  # Null reference error!
	print("This line should never execute")
'''

SCENE_TEMPLATE = '''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://test_error_script.gd" id="1_script"]

[node name="TestErrorScene" type="Node2D"]
script = ExtResource("1_script")
'''


async def get_log_line_count(client: GodotClient) -> int:
    """Get current line count of log file to use as marker."""
    result = await client.send_command("get_editor_log", {"lines": 1})
    if result.get("success"):
        return result.get("result", {}).get("total_lines", 0)
    return 0


async def test_soft_error(client: GodotClient):
    """Test capturing soft errors (push_error)."""
    print("\n" + "="*60)
    print("TEST 1: SOFT ERROR (push_error)")
    print("="*60)
    
    # Write the soft error script
    print("\n1. Writing soft error test script...")
    await client.send_command("write_file", {
        "path": "res://test_error_script.gd",
        "content": SOFT_ERROR_SCRIPT
    })
    
    # Write the test scene
    await client.send_command("write_file", {
        "path": "res://test_error_scene.tscn",
        "content": SCENE_TEMPLATE
    })
    
    # Get current log position
    print("2. Marking log position...")
    start_line = await get_log_line_count(client)
    print(f"   Start line: {start_line}")
    
    # Open and run the scene
    print("3. Opening and running test scene...")
    await client.send_command("open_scene", {"path": "res://test_error_scene.tscn"})
    await client.send_command("play_current", {})
    
    # Wait for script to run
    print("4. Waiting 3 seconds for script to execute...")
    await asyncio.sleep(3)
    
    # Get editor log entries since our start line
    print("5. Checking editor log...")
    result = await client.send_command("get_editor_log", {
        "lines": 50,
        "filter": "all",
        "tail": True
    })
    
    errors_found = []
    warnings_found = []
    
    if result.get("success"):
        data = result.get("result", {})
        
        # Filter entries after our start line
        new_entries = [e for e in data.get("entries", []) if e.get("line", 0) >= start_line]
        new_errors = [e for e in data.get("errors", []) if e.get("line", 0) >= start_line]
        new_warnings = [e for e in data.get("warnings", []) if e.get("line", 0) >= start_line]
        
        print(f"\n   New entries since start: {len(new_entries)}")
        print(f"   New errors: {len(new_errors)}")
        print(f"   New warnings: {len(new_warnings)}")
        
        print("\n   --- New Log Entries ---")
        for entry in new_entries:
            etype = entry.get("type", "?")
            text = entry.get("text", "")[:80]
            marker = "❌" if etype == "error" else ("⚠" if etype == "warning" else "")
            print(f"   {marker} [{etype}] {text}")
        
        errors_found = new_errors
        warnings_found = new_warnings
    else:
        print(f"   Failed: {result}")
    
    # Stop the game
    print("\n6. Stopping game...")
    await client.send_command("stop", {})
    await asyncio.sleep(0.5)
    
    soft_error_captured = any("SOFT ERROR" in e.get("text", "") for e in errors_found)
    warning_captured = len(warnings_found) > 0 or any("WARNING" in e.get("text", "") for e in result.get("result", {}).get("entries", []) if e.get("line", 0) >= start_line)
    
    print(f"\n   Soft error captured: {'✓ YES' if soft_error_captured else '✗ NO'}")
    print(f"   Warning captured: {'✓ YES' if warning_captured else '✗ NO'}")
    
    return soft_error_captured


async def test_hard_error(client: GodotClient):
    """Test capturing hard errors (runtime crash)."""
    print("\n" + "="*60)
    print("TEST 2: HARD ERROR (null reference)")
    print("="*60)
    
    # Write the hard error script
    print("\n1. Writing hard error test script...")
    await client.send_command("write_file", {
        "path": "res://test_error_script.gd",
        "content": HARD_ERROR_SCRIPT
    })
    
    # Get current log position
    print("2. Marking log position...")
    start_line = await get_log_line_count(client)
    print(f"   Start line: {start_line}")
    
    # Run the scene (should crash)
    print("3. Running test scene (expecting crash)...")
    await client.send_command("open_scene", {"path": "res://test_error_scene.tscn"})
    await client.send_command("play_current", {})
    
    # Wait a moment
    print("4. Waiting 2 seconds...")
    await asyncio.sleep(2)
    
    # Check if still playing
    status = await client.send_command("get_status", {})
    is_playing = status.get("result", {}).get("is_playing", False)
    print(f"   Is still playing: {is_playing}")
    
    # Get editor log
    print("5. Checking editor log...")
    result = await client.send_command("get_editor_log", {
        "lines": 50,
        "filter": "all",
        "tail": True
    })
    
    hard_error_captured = False
    
    if result.get("success"):
        data = result.get("result", {})
        
        # Filter entries after our start line
        new_entries = [e for e in data.get("entries", []) if e.get("line", 0) >= start_line]
        new_errors = [e for e in data.get("errors", []) if e.get("line", 0) >= start_line]
        
        print(f"\n   New entries: {len(new_entries)}")
        print(f"   New errors: {len(new_errors)}")
        
        print("\n   --- New Log Entries ---")
        for entry in new_entries:
            etype = entry.get("type", "?")
            text = entry.get("text", "")[:100]
            marker = "❌" if etype == "error" else ("⚠" if etype == "warning" else "")
            print(f"   {marker} [{etype}] {text}")
        
        # Check if we captured the null reference error
        hard_error_captured = any("null" in e.get("text", "").lower() or "get_name" in e.get("text", "") for e in new_entries)
        
    else:
        print(f"   Failed: {result}")
    
    # Stop if still running
    await client.send_command("stop", {})
    
    print(f"\n   Hard error captured: {'✓ YES' if hard_error_captured else '✗ NO'}")
    
    return hard_error_captured


async def main():
    client = GodotClient()
    await client.connect()
    
    if not client.is_connected:
        print("Failed to connect to Godot!")
        return
    
    print("Connected to Godot!")
    
    # Test soft errors
    soft_captured = await test_soft_error(client)
    
    # Small delay between tests
    await asyncio.sleep(1)
    
    # Test hard errors
    hard_captured = await test_hard_error(client)
    
    # Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print(f"  Soft errors captured: {'✓ YES' if soft_captured else '✗ NO'}")
    print(f"  Hard errors captured: {'✓ YES' if hard_captured else '✗ NO'}")
    
    if soft_captured and hard_captured:
        print("\n  ✓ All error types can be captured via editor log!")
    else:
        print("\n  ⚠ Some errors were not captured.")
    
    # Cleanup
    print("\nCleaning up test files...")
    await client.send_command("write_file", {
        "path": "res://test_error_script.gd",
        "content": "# Cleaned up"
    })
    
    await client.disconnect()
    print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
