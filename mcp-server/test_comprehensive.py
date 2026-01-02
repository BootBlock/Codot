#!/usr/bin/env python3
"""
Comprehensive MCP Server Automation Tests

This script tests the MCP server functionality by:
1. Creating scenes with various node types (GPUParticles2D, Sprite2D, etc.)
2. Testing quick-find commands
3. Testing batch/compound commands
4. Testing file operations
5. Verifying scene manipulation works correctly

Run with: python test_comprehensive.py
"""

import asyncio
import sys
import json
from pathlib import Path

# Add the codot package to path
sys.path.insert(0, str(Path(__file__).parent))

from codot.godot_client import GodotClient


async def test_connection(client: GodotClient) -> bool:
    """Test basic connectivity."""
    print("\n" + "=" * 60)
    print("TEST: Basic Connection")
    print("=" * 60)
    
    result = await client.send_command("ping", {})
    if result.get("success"):
        print("✓ Ping successful")
        return True
    else:
        print(f"✗ Ping failed: {result}")
        return False


async def test_quick_find_commands(client: GodotClient) -> bool:
    """Test the new quick-find commands."""
    print("\n" + "=" * 60)
    print("TEST: Quick Find Commands")
    print("=" * 60)
    
    all_passed = True
    
    # Test find_file
    print("\n1. Testing find_file...")
    result = await client.send_command("find_file", {
        "pattern": "*.gd",
        "max_results": 10
    })
    if result.get("success"):
        count = result.get("result", {}).get("count", 0)
        print(f"   ✓ Found {count} GDScript files")
    else:
        print(f"   ✗ find_file failed: {result.get('error')}")
        all_passed = False
    
    # Test find_resources_by_type
    print("\n2. Testing find_resources_by_type...")
    result = await client.send_command("find_resources_by_type", {
        "type": "PackedScene",
        "max_results": 10
    })
    if result.get("success"):
        count = result.get("result", {}).get("count", 0)
        print(f"   ✓ Found {count} scene files")
    else:
        print(f"   ✗ find_resources_by_type failed: {result.get('error')}")
        all_passed = False
    
    # Test search_in_files
    print("\n3. Testing search_in_files...")
    result = await client.send_command("search_in_files", {
        "query": "func",
        "extensions": ["gd"],
        "max_results": 5
    })
    if result.get("success"):
        files = result.get("result", {}).get("files_with_matches", 0)
        print(f"   ✓ Found 'func' in {files} files")
    else:
        print(f"   ✗ search_in_files failed: {result.get('error')}")
        all_passed = False
    
    return all_passed


async def test_create_complete_scene(client: GodotClient) -> bool:
    """Test creating a complete scene with various node types."""
    print("\n" + "=" * 60)
    print("TEST: Create Complete Scene")
    print("=" * 60)
    
    scene_path = "res://test_generated/particle_scene.tscn"
    
    # Delete test directory first if it exists
    await client.send_command("delete_directory", {
        "path": "res://test_generated",
        "recursive": True
    })
    
    # Create directory
    result = await client.send_command("create_directory", {
        "path": "res://test_generated"
    })
    if not result.get("success"):
        print(f"   ✗ Failed to create directory: {result.get('error')}")
        return False
    
    print("\n1. Creating scene with GPUParticles2D and Sprite2D...")
    result = await client.send_command("create_complete_scene", {
        "scene_path": scene_path,
        "root_type": "Node2D",
        "root_name": "ParticleDemo",
        "nodes": [
            {
                "type": "GPUParticles2D",
                "name": "Particles",
                "parent": ".",
                "properties": {
                    "emitting": False,
                    "amount": 50
                }
            },
            {
                "type": "Sprite2D",
                "name": "Player",
                "parent": ".",
                "properties": {
                    "position": [100, 100]
                }
            },
            {
                "type": "Camera2D",
                "name": "MainCamera",
                "parent": ".",
                "properties": {
                    "zoom": [1, 1]
                }
            },
            {
                "type": "CollisionShape2D",
                "name": "Collision",
                "parent": "Player"
            },
            {
                "type": "Label",
                "name": "ScoreLabel",
                "parent": ".",
                "properties": {
                    "text": "Score: 0"
                }
            }
        ],
        "save": True
    })
    
    if result.get("success"):
        nodes = result.get("result", {}).get("nodes_created", [])
        print(f"   ✓ Created scene with {len(nodes)} nodes: {nodes}")
    else:
        print(f"   ✗ create_complete_scene failed: {result.get('error')}")
        return False
    
    # Verify the scene was created
    print("\n2. Verifying scene file exists...")
    result = await client.send_command("file_exists", {"path": scene_path})
    if result.get("success") and result.get("result", {}).get("exists"):
        print("   ✓ Scene file exists")
    else:
        print("   ✗ Scene file not found")
        return False
    
    # Open and verify the scene
    print("\n3. Opening scene to verify structure...")
    result = await client.send_command("open_scene", {"path": scene_path})
    if result.get("success"):
        print("   ✓ Scene opened successfully")
    else:
        print(f"   ✗ Failed to open scene: {result.get('error')}")
        return False
    
    # Get scene tree
    print("\n4. Getting scene tree...")
    result = await client.send_command("get_scene_tree", {})
    if result.get("success"):
        tree = result.get("result", {})
        print(f"   ✓ Scene tree retrieved, root: {tree.get('name')}")
    else:
        print(f"   ✗ Failed to get scene tree: {result.get('error')}")
        return False
    
    return True


async def test_create_scene_with_script(client: GodotClient) -> bool:
    """Test creating a scene with an attached script."""
    print("\n" + "=" * 60)
    print("TEST: Create Scene With Script")
    print("=" * 60)
    
    scene_path = "res://test_generated/scripted_scene.tscn"
    
    script_content = '''extends Node2D

var score: int = 0
var player_name: String = "Player"

func _ready() -> void:
    print("Scripted scene initialized!")
    score = 100


func add_score(points: int) -> void:
    score += points
    print("Score: ", score)


func _process(delta: float) -> void:
    pass
'''
    
    print("\n1. Creating scene with script...")
    result = await client.send_command("create_scene_with_script", {
        "scene_path": scene_path,
        "script_content": script_content,
        "root_type": "Node2D",
        "root_name": "ScriptedDemo"
    })
    
    if result.get("success"):
        res = result.get("result", {})
        print(f"   ✓ Created scene: {res.get('scene_path')}")
        print(f"   ✓ Created script: {res.get('script_path')}")
    else:
        print(f"   ✗ create_scene_with_script failed: {result.get('error')}")
        return False
    
    # Verify both files exist
    print("\n2. Verifying files...")
    for path in [scene_path, scene_path.replace(".tscn", ".gd")]:
        result = await client.send_command("file_exists", {"path": path})
        if result.get("success") and result.get("result", {}).get("exists"):
            print(f"   ✓ {path} exists")
        else:
            print(f"   ✗ {path} not found")
            return False
    
    return True


async def test_batch_commands(client: GodotClient) -> bool:
    """Test batch command execution."""
    print("\n" + "=" * 60)
    print("TEST: Batch Commands")
    print("=" * 60)
    
    # First open a scene
    print("\n1. Opening particle scene for batch operations...")
    result = await client.send_command("open_scene", {
        "path": "res://test_generated/particle_scene.tscn"
    })
    if not result.get("success"):
        print(f"   ✗ Failed to open scene: {result.get('error')}")
        return False
    
    print("\n2. Executing batch commands...")
    result = await client.send_command("batch_commands", {
        "commands": [
            {
                "command": "create_node",
                "params": {
                    "type": "Timer",
                    "name": "SpawnTimer",
                    "parent": "."
                }
            },
            {
                "command": "create_node",
                "params": {
                    "type": "AudioStreamPlayer",
                    "name": "SoundPlayer",
                    "parent": "."
                }
            },
            {
                "command": "set_node_property",
                "params": {
                    "node_path": "SpawnTimer",
                    "property": "wait_time",
                    "value": 2.5
                }
            }
        ],
        "return_all_results": True
    })
    
    if result.get("success"):
        res = result.get("result", {})
        print(f"   ✓ Executed {res.get('executed')} commands, {res.get('failed')} failed")
        if res.get("results"):
            for r in res["results"]:
                status = "✓" if r.get("success") else "✗"
                print(f"      {status} {r.get('command')}")
    else:
        print(f"   ✗ batch_commands failed: {result.get('error')}")
        return False
    
    return True


async def test_bulk_set_properties(client: GodotClient) -> bool:
    """Test bulk property setting."""
    print("\n" + "=" * 60)
    print("TEST: Bulk Set Properties")
    print("=" * 60)
    
    print("\n1. Setting multiple properties at once...")
    result = await client.send_command("bulk_set_properties", {
        "operations": [
            {
                "node_path": "Particles",
                "properties": {
                    "amount": 100,
                    "emitting": False
                }
            },
            {
                "node_path": "ScoreLabel",
                "property": "text",
                "value": "Score: 9999"
            }
        ]
    })
    
    if result.get("success"):
        res = result.get("result", {})
        print(f"   ✓ Set {res.get('set_count')} properties, {res.get('error_count')} errors")
    else:
        print(f"   ✗ bulk_set_properties failed: {result.get('error')}")
        return False
    
    return True


async def test_file_operations(client: GodotClient) -> bool:
    """Test file operations."""
    print("\n" + "=" * 60)
    print("TEST: File Operations")
    print("=" * 60)
    
    test_file = "res://test_generated/test_file.txt"
    test_content = "Hello from MCP automation test!\nLine 2\nLine 3"
    
    # Write file
    print("\n1. Writing test file...")
    result = await client.send_command("write_file", {
        "path": test_file,
        "content": test_content
    })
    if result.get("success"):
        print(f"   ✓ Wrote {len(test_content)} bytes")
    else:
        print(f"   ✗ write_file failed: {result.get('error')}")
        return False
    
    # Read file
    print("\n2. Reading test file...")
    result = await client.send_command("read_file", {"path": test_file})
    if result.get("success"):
        content = result.get("result", {}).get("content", "")
        if content == test_content:
            print("   ✓ Content matches")
        else:
            print("   ✗ Content mismatch")
            return False
    else:
        print(f"   ✗ read_file failed: {result.get('error')}")
        return False
    
    # Get file info
    print("\n3. Getting file info...")
    result = await client.send_command("get_file_info", {"path": test_file})
    if result.get("success"):
        info = result.get("result", {})
        print(f"   ✓ Size: {info.get('size')} bytes, Type: {info.get('type')}")
    else:
        print(f"   ✗ get_file_info failed: {result.get('error')}")
        return False
    
    # Copy file
    copy_path = "res://test_generated/test_file_copy.txt"
    print("\n4. Copying file...")
    result = await client.send_command("copy_file", {
        "from_path": test_file,
        "to_path": copy_path
    })
    if result.get("success"):
        print("   ✓ File copied")
    else:
        print(f"   ✗ copy_file failed: {result.get('error')}")
        return False
    
    # Delete file
    print("\n5. Deleting original file...")
    result = await client.send_command("delete_file", {"path": test_file})
    if result.get("success"):
        print("   ✓ File deleted")
    else:
        print(f"   ✗ delete_file failed: {result.get('error')}")
        return False
    
    return True


async def cleanup(client: GodotClient):
    """Clean up test files."""
    print("\n" + "=" * 60)
    print("CLEANUP")
    print("=" * 60)
    
    result = await client.send_command("delete_directory", {
        "path": "res://test_generated",
        "recursive": True
    })
    if result.get("success"):
        print("✓ Test directory cleaned up")
    else:
        print(f"⚠ Cleanup failed (may not exist): {result.get('error')}")


async def main():
    print("=" * 60)
    print("COMPREHENSIVE MCP AUTOMATION TESTS")
    print("=" * 60)
    print("\nConnecting to Godot MCP server...")
    
    client = GodotClient()
    try:
        await client.connect()
        print("✓ Connected to Godot\n")
    except Exception as e:
        print(f"✗ Failed to connect: {e}")
        print("\nMake sure Godot is running with the Codot plugin enabled!")
        return 1
    
    results = {}
    
    try:
        # Run all tests
        results["Connection"] = await test_connection(client)
        results["Quick Find"] = await test_quick_find_commands(client)
        results["Complete Scene"] = await test_create_complete_scene(client)
        results["Scene With Script"] = await test_create_scene_with_script(client)
        results["Batch Commands"] = await test_batch_commands(client)
        results["Bulk Properties"] = await test_bulk_set_properties(client)
        results["File Operations"] = await test_file_operations(client)
        
        # Cleanup
        await cleanup(client)
        
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        await client.close()
    
    # Print summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    
    passed = 0
    failed = 0
    for name, result in results.items():
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"  {status}: {name}")
        if result:
            passed += 1
        else:
            failed += 1
    
    print(f"\nTotal: {passed} passed, {failed} failed")
    
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
