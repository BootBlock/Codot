#!/usr/bin/env python3
"""
Test script to verify error capture is working.

This script:
1. Connects to Godot via MCP
2. Sets up the test scene
3. Runs the game
4. Waits for errors
5. Reports what was captured

IMPORTANT: You may need to reload the Codot plugin in Godot after code changes:
- Project > Project Settings > Plugins
- Disable "Codot", then enable it again
- Or restart Godot

"""

import asyncio
import json
import sys
from websockets import connect


async def send_command(ws, command: str, params: dict = None) -> dict:
    """Send a command and wait for response."""
    msg = {"command": command}
    if params:
        msg["params"] = params
    await ws.send(json.dumps(msg))
    response = await ws.recv()
    return json.loads(response)


async def main():
    print("=" * 60)
    print("  Codot Error Capture Test")
    print("=" * 60)
    print()
    
    try:
        async with connect("ws://127.0.0.1:6850") as ws:
            # Step 1: Ping to verify connection
            print("1. Connecting to Godot...")
            result = await send_command(ws, "ping")
            if not result.get("success"):
                print(f"   ERROR: {result}")
                return
            print("   ✓ Connected!")
            
            # Step 2: Get initial debugger status
            print("\n2. Checking debugger status...")
            result = await send_command(ws, "get_debugger_status")
            if result.get("success"):
                status = result.get("result", {})
                print(f"   Sessions: {status.get('session_count', status.get('active_sessions', 'N/A'))}")
                print(f"   Message types seen: {list(status.get('message_types_seen', {}).keys())}")
                game_active = status.get('game_capture_active', 'Not reported')
                print(f"   Game capture active: {game_active}")
                
                if game_active == 'Not reported':
                    print("\n   ⚠️  WARNING: game_capture_active not in status.")
                    print("      This may mean the plugin needs to be reloaded.")
                    print("      Go to: Project > Project Settings > Plugins")
                    print("      Disable 'Codot' and re-enable it.\n")
            else:
                print(f"   WARNING: {result}")
            
            # Step 3: Reset debug log (don't skip any entries)
            print("\n3. Resetting debug log marker...")
            # We need to pass a special flag or just note we want all entries
            result = await send_command(ws, "clear_debug_log")
            since_id = result.get("result", {}).get("since_id", 0)
            print(f"   Marker set at ID: {since_id}")
            
            # Step 4: Open the test scene
            print("\n4. Opening test scene...")
            result = await send_command(ws, "open_scene", {
                "path": "res://test_error_capture.tscn"
            })
            if result.get("success"):
                print("   ✓ Scene opened!")
            else:
                print(f"   ⚠️  {result.get('error', {}).get('message', 'Unknown error')}")
            
            # Step 5: Play the current scene (not the main scene)
            print("\n5. Playing current scene...")
            result = await send_command(ws, "play_current")
            if not result.get("success"):
                # Try regular play if play_current fails
                print("   play_current failed, trying play...")
                result = await send_command(ws, "play")
            if not result.get("success"):
                print(f"   ERROR: {result}")
                return
            print("   ✓ Game started!")
            
            # Step 6: Wait for errors to be generated
            print("\n6. Waiting 3 seconds for test script to run...")
            await asyncio.sleep(3.0)
            
            # Step 7: Check debugger status again
            print("\n7. Checking debugger status after run...")
            result = await send_command(ws, "get_debugger_status")
            if result.get("success"):
                status = result.get("result", {})
                msg_types = status.get('message_types_seen', {})
                print(f"   Message types: {msg_types}")
                print(f"   Game capture active: {status.get('game_capture_active', 'N/A')}")
                print(f"   Total entries: {status.get('total_entries', 'N/A')}")
                
                # Check for expected message types
                if "codot:ready" in msg_types:
                    print("   ✓ codot:ready received - autoload is working!")
                if "codot:entry" in msg_types:
                    print("   ✓ codot:entry received - capture messages coming through!")
                if "codot:test_complete" in msg_types:
                    print("   ✓ codot:test_complete received - test finished!")
            
            # Step 8: Get debug output - use -1 to try to get all entries
            print("\n8. Getting debug output...")
            # First without the marker
            result = await send_command(ws, "get_debug_output", {
                "lines": 50
            })
            if result.get("success"):
                output = result.get("result", {})
                entries = output.get("entries", [])
                print(f"   Source: {output.get('source', 'N/A')}")
                print(f"   Total entries returned: {len(entries)}")
                print(f"   Errors: {output.get('error_count', 0)}")
                print(f"   Warnings: {output.get('warning_count', 0)}")
                
                if entries:
                    print("\n   --- Captured Entries ---")
                    for entry in entries[:15]:  # Show first 15
                        entry_type = entry.get("type", "?")
                        source = entry.get("source", "dbg")
                        msg = entry.get("message", "")[:60]
                        eid = entry.get("id", "?")
                        print(f"   [{eid}] {entry_type:8} ({source:4}) {msg}")
                    if len(entries) > 15:
                        print(f"   ... and {len(entries) - 15} more entries")
                else:
                    print("\n   ⚠️  No entries captured.")
                    print("      This could mean:")
                    print("      - Plugin needs reloading (see step 2 warning)")
                    print("      - The game-side capture isn't hooked up")
            else:
                print(f"   ERROR: {result}")
            
            # Step 9: Stop the game
            print("\n9. Stopping game...")
            result = await send_command(ws, "stop")
            if result.get("success"):
                print("   ✓ Game stopped!")
            
            # Step 10: Final summary
            print("\n" + "=" * 60)
            print("  Test Complete")
            print("=" * 60)
            
            result = await send_command(ws, "get_debugger_status")
            if result.get("success"):
                status = result.get("result", {})
                msg_types = status.get('message_types_seen', {})
                
                print(f"\n  Message types seen: {list(msg_types.keys())}")
                print(f"  Total entries: {status.get('total_entries', 'N/A')}")
                
                # Analysis
                print("\n  Analysis:")
                if "codot:ready" in msg_types:
                    print("  ✓ Game-side autoload (CodotOutputCapture) is working")
                else:
                    print("  ✗ Game-side autoload not detected")
                    print("    → Check that CodotOutputCapture is in project autoloads")
                
                if "codot:entry" in msg_types:
                    print("  ✓ Error/warning capture is working")
                else:
                    print("  ✗ No captured entries received")
                    print("    → Plugin may need reload, or capture not hooked up")
            
    except ConnectionRefusedError:
        print("ERROR: Could not connect to Godot on port 6850")
        print("Make sure Godot is running with the Codot plugin enabled.")
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
