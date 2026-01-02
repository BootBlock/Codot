"""Test different methods of capturing runtime output."""
import asyncio
from codot.godot_client import GodotClient


# Script that prints to various outputs
TEST_SCRIPT = '''extends Node2D

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
'''

SCENE = '''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://test_output.gd" id="1"]
[node name="TestOutput" type="Node2D"]
script = ExtResource("1")
'''


async def main():
    client = GodotClient()
    await client.connect()
    print("Connected!")
    
    # Create test files
    print("\n1. Creating test script and scene...")
    await client.send_command("write_file", {"path": "res://test_output.gd", "content": TEST_SCRIPT})
    await client.send_command("write_file", {"path": "res://test_output.tscn", "content": SCENE})
    
    # Get initial log state
    print("\n2. Getting initial log state...")
    log_before = await client.send_command("get_editor_log", {"lines": 5, "tail": True})
    lines_before = log_before.get("result", {}).get("total_lines", 0)
    print(f"   Lines before: {lines_before}")
    
    # Run the scene
    print("\n3. Running test scene...")
    await client.send_command("open_scene", {"path": "res://test_output.tscn"})
    await client.send_command("play_current", {})
    
    # Poll for output every second
    print("\n4. Polling for output...")
    for i in range(5):
        await asyncio.sleep(1)
        
        # Check status
        status = await client.send_command("get_status", {})
        is_playing = status.get("result", {}).get("is_playing", False)
        
        # Check log
        log_now = await client.send_command("get_editor_log", {"lines": 20, "tail": True})
        lines_now = log_now.get("result", {}).get("total_lines", 0)
        
        # Check debugger
        dbg_status = await client.send_command("get_debugger_status", {})
        dbg_entries = dbg_status.get("result", {}).get("total_entries", 0)
        msg_types = dbg_status.get("result", {}).get("message_types_seen", {})
        
        print(f"   [{i+1}s] playing={is_playing}, log_lines={lines_now}, dbg_entries={dbg_entries}, msg_types={msg_types}")
        
        if not is_playing:
            print("   Game stopped!")
            break
    
    # Final check
    print("\n5. Final state check...")
    
    log_after = await client.send_command("get_editor_log", {"lines": 30, "tail": True})
    if log_after.get("success"):
        data = log_after.get("result", {})
        print(f"   Log lines: {data.get('total_lines')}")
        print(f"   Errors: {data.get('error_count')}")
        
        # Show entries that contain our test markers
        entries = data.get("entries", [])
        print("\n   --- Entries containing 'TEST' ---")
        for e in entries:
            text = e.get("text", "")
            if "TEST" in text or "test_output" in text.lower():
                print(f"   {e}")
    
    # Check debugger status
    dbg_final = await client.send_command("get_debugger_status", {})
    if dbg_final.get("success"):
        data = dbg_final.get("result", {})
        print(f"\n   Debugger entries: {data.get('total_entries')}")
        print(f"   Message types seen: {data.get('message_types_seen')}")
    
    # Stop game if still running
    await client.send_command("stop", {})
    
    await client.disconnect()
    print("\nDone!")


if __name__ == "__main__":
    asyncio.run(main())
