#!/usr/bin/env python3
"""Test the new plugin management commands"""

import asyncio
import json
from websockets import connect


async def main():
    async with connect("ws://127.0.0.1:6850") as ws:
        # Test get_plugins
        print("=== Testing get_plugins ===")
        await ws.send(json.dumps({"command": "get_plugins"}))
        r = await ws.recv()
        result = json.loads(r)
        
        if result.get("success"):
            plugins = result["result"]["plugins"]
            print(f"Found {len(plugins)} plugins:")
            for p in plugins:
                status = "✓ enabled" if p["enabled"] else "✗ disabled"
                print(f"  - {p['name']} ({p['folder']}) {status}")
        else:
            error = result.get("error", {})
            print(f"Error: {error.get('code')}: {error.get('message')}")
            print("\nNote: You may need to reload the Codot plugin in Godot for the new commands to be available.")
            print("Go to: Project > Project Settings > Plugins")
            print("Disable 'Codot' and re-enable it.")
            return
        
        # Test disable/enable cycle with a test plugin (not Codot itself!)
        print("\n=== Testing enable/disable ===")
        # Find a plugin that's NOT codot to test with
        test_plugin = None
        for p in plugins:
            if p["folder"] != "codot" and p["enabled"]:
                test_plugin = p["folder"]
                break
        
        if test_plugin:
            print(f"Testing with plugin: {test_plugin}")
            
            # Disable it
            await ws.send(json.dumps({"command": "disable_plugin", "params": {"name": test_plugin}}))
            r = await ws.recv()
            result = json.loads(r)
            print(f"  Disable: {result.get('result', result.get('error'))}")
            
            # Re-enable it
            await ws.send(json.dumps({"command": "enable_plugin", "params": {"name": test_plugin}}))
            r = await ws.recv()
            result = json.loads(r)
            print(f"  Enable: {result.get('result', result.get('error'))}")
        else:
            print("No suitable test plugin found (need a non-codot enabled plugin)")
        
        print("\n=== reload_project ===")
        print("Skipping reload_project test (would restart editor)")


if __name__ == "__main__":
    asyncio.run(main())
