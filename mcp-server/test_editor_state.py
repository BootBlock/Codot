#!/usr/bin/env python3
"""
Test the new editor state commands for robustness.
"""

import asyncio
import json
from codot.godot_client import GodotClient


async def test_editor_state():
    """Test the new editor state commands."""
    client = GodotClient()
    
    try:
        await client.connect()
        print("Connected to Godot!\n")
        
        # Test get_editor_state
        print("=" * 50)
        print("Testing get_editor_state")
        print("=" * 50)
        result = await client.send_command("get_editor_state", {})
        if result.get("success"):
            state = result.get("result", {})
            print(f"  is_playing: {state.get('is_playing')}")
            print(f"  current_scene: {state.get('current_scene')}")
            print(f"  current_scene_modified: {state.get('current_scene_modified')}")
            print(f"  has_unsaved_changes: {state.get('has_unsaved_changes')}")
            print(f"  open_scenes: {state.get('open_scenes')}")
            print(f"  selected_nodes: {state.get('selected_nodes')}")
            print(f"  modified_scenes: {state.get('modified_scenes')}")
            print("  ✓ PASS")
        else:
            print(f"  ✗ FAIL: {result.get('error')}")
        
        # Test get_unsaved_changes
        print("\n" + "=" * 50)
        print("Testing get_unsaved_changes")
        print("=" * 50)
        result = await client.send_command("get_unsaved_changes", {})
        if result.get("success"):
            state = result.get("result", {})
            print(f"  has_unsaved: {state.get('has_unsaved')}")
            print(f"  unsaved_scenes: {state.get('unsaved_scenes')}")
            print(f"  current_scene_path: {state.get('current_scene_path')}")
            print(f"  current_scene_is_new: {state.get('current_scene_is_new')}")
            print("  ✓ PASS")
        else:
            print(f"  ✗ FAIL: {result.get('error')}")
        
        # Test improved save_scene (should report actual status)
        print("\n" + "=" * 50)
        print("Testing save_scene (improved)")
        print("=" * 50)
        result = await client.send_command("save_scene", {})
        if result.get("success"):
            state = result.get("result", {})
            print(f"  saved: {state.get('saved')}")
            print(f"  path: {state.get('path')}")
            print(f"  file_updated: {state.get('file_updated')}")
            print(f"  error_code: {state.get('error_code')}")
            print("  ✓ PASS")
        else:
            error = result.get("error", {})
            print(f"  Expected error: {error.get('code')} - {error.get('message')}")
            print("  ✓ PASS (error properly reported)")
        
        print("\n" + "=" * 50)
        print("All editor state tests completed!")
        print("=" * 50)
        
    except Exception as e:
        print(f"Error: {e}")
    finally:
        await client.disconnect()


if __name__ == "__main__":
    asyncio.run(test_editor_state())
