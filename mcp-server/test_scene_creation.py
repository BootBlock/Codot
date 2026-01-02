"""Test scene creation and node manipulation commands."""

import asyncio
import json
from codot.godot_client import GodotClient


async def test_scene_creation():
    client = GodotClient()
    
    if not await client.connect():
        print("Failed to connect to Godot!")
        return
    
    print("=" * 60)
    print("Testing Scene Creation and Node Manipulation")
    print("=" * 60)
    
    # 1. Create a new scene
    print("\n>>> Creating new scene: res://test_scene.tscn")
    result = await client.send_command("create_scene", {
        "path": "res://test_scene.tscn",
        "root_type": "Node2D",
        "root_name": "TestRoot"
    })
    print(json.dumps(result, indent=2))
    await asyncio.sleep(0.5)
    
    # 2. Get the scene tree
    print("\n>>> Getting scene tree")
    result = await client.send_command("get_scene_tree", {"max_depth": 5})
    print(json.dumps(result, indent=2))
    await asyncio.sleep(0.3)
    
    # 3. Create some nodes
    nodes_to_create = [
        {"type": "Sprite2D", "name": "PlayerSprite", "parent": "."},
        {"type": "Label", "name": "ScoreLabel", "parent": "."},
        {"type": "Node2D", "name": "Enemies", "parent": "."},
        {"type": "CharacterBody2D", "name": "Enemy1", "parent": "Enemies"},
    ]
    
    for node_params in nodes_to_create:
        print(f"\n>>> Creating node: {node_params['name']} ({node_params['type']})")
        result = await client.send_command("create_node", node_params)
        print(json.dumps(result, indent=2))
        await asyncio.sleep(0.2)
    
    # 4. Get updated scene tree
    print("\n>>> Getting updated scene tree")
    result = await client.send_command("get_scene_tree", {"max_depth": 5})
    print(json.dumps(result, indent=2))
    await asyncio.sleep(0.3)
    
    # 5. Set some properties
    print("\n>>> Setting PlayerSprite position to (100, 200)")
    result = await client.send_command("set_node_property", {
        "path": "PlayerSprite",
        "property": "position",
        "value": {"x": 100, "y": 200}
    })
    print(json.dumps(result, indent=2))
    
    print("\n>>> Setting ScoreLabel text")
    result = await client.send_command("set_node_property", {
        "path": "ScoreLabel",
        "property": "text",
        "value": "Score: 0"
    })
    print(json.dumps(result, indent=2))
    
    # 6. Get node info
    print("\n>>> Getting PlayerSprite info")
    result = await client.send_command("get_node_info", {"path": "PlayerSprite"})
    print(json.dumps(result, indent=2))
    
    # 7. Duplicate a node
    print("\n>>> Duplicating Enemy1")
    result = await client.send_command("duplicate_node", {"path": "Enemies/Enemy1"})
    print(json.dumps(result, indent=2))
    
    # 8. Rename a node
    print("\n>>> Renaming duplicated node to Enemy2")
    result = await client.send_command("rename_node", {
        "path": "Enemies/Enemy12",  # Godot adds numbers
        "name": "Enemy2"
    })
    print(json.dumps(result, indent=2))
    
    # 9. Final scene tree
    print("\n>>> Final scene tree")
    result = await client.send_command("get_scene_tree", {"max_depth": 5})
    print(json.dumps(result, indent=2))
    
    # 10. Save the scene
    print("\n>>> Saving scene")
    result = await client.send_command("save_scene", {})
    print(json.dumps(result, indent=2))
    
    await client.disconnect()
    print("\n" + "=" * 60)
    print("Test complete! Check Godot for the created scene.")


if __name__ == "__main__":
    asyncio.run(test_scene_creation())
