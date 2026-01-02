"""Test all available commands in Codot."""

import asyncio
import json
from codot.godot_client import GodotClient


async def test_all():
    client = GodotClient()
    
    if not await client.connect():
        print("Failed to connect to Godot!")
        return
    
    print("=" * 60)
    print("Testing all Codot commands")
    print("=" * 60)
    
    # Basic commands
    commands = [
        ("ping", {}),
        ("get_status", {}),
        ("is_playing", {}),
    ]
    
    # Scene tree commands
    commands += [
        ("get_scene_tree", {"max_depth": 3}),
        ("get_open_scenes", {}),
        ("get_selected_nodes", {}),
    ]
    
    # File operations
    commands += [
        ("get_project_files", {"path": "res://", "extension": ".gd"}),
        ("file_exists", {"path": "res://project.godot"}),
        ("read_file", {"path": "res://project.godot"}),
    ]
    
    # Project info
    commands += [
        ("get_project_settings", {}),
        ("list_resources", {"type": "scripts"}),
        ("list_resources", {"type": "scenes"}),
    ]
    
    for cmd, params in commands:
        print(f"\n{'='*60}")
        print(f">>> {cmd}({json.dumps(params) if params else ''})")
        print("-" * 60)
        result = await client.send_command(cmd, params)
        
        # Pretty print, but truncate long content
        result_str = json.dumps(result, indent=2)
        if len(result_str) > 1000:
            result_str = result_str[:1000] + "\n... (truncated)"
        print(result_str)
        await asyncio.sleep(0.1)
    
    # Test play/stop
    print(f"\n{'='*60}")
    print(">>> Testing play/stop cycle...")
    print("-" * 60)
    
    # Play
    result = await client.send_command("play", {})
    print(f"play: {json.dumps(result)}")
    
    await asyncio.sleep(2)
    
    # Check if playing
    result = await client.send_command("is_playing", {})
    print(f"is_playing: {json.dumps(result)}")
    
    # Stop
    result = await client.send_command("stop", {})
    print(f"stop: {json.dumps(result)}")
    
    await asyncio.sleep(0.5)
    
    # Confirm stopped
    result = await client.send_command("is_playing", {})
    print(f"is_playing: {json.dumps(result)}")
    
    await client.disconnect()
    print("\n" + "=" * 60)
    print("Tests complete!")


if __name__ == "__main__":
    asyncio.run(test_all())
