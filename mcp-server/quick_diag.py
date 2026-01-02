#!/usr/bin/env python3
"""Quick diagnostic to check debugger state"""

import asyncio
import json
from websockets import connect


async def main():
    async with connect("ws://127.0.0.1:6850") as ws:
        # Send raw status command
        await ws.send(json.dumps({"command": "get_debugger_status"}))
        response = await ws.recv()
        result = json.loads(response)
        
        print("=== Debugger Status (All Fields) ===")
        if result.get("success"):
            for k, v in result.get("result", {}).items():
                print(f"  {k}: {v}")
        else:
            print(f"Error: {result}")
        
        # Reset marker and get all entries
        await ws.send(json.dumps({"command": "get_debug_output", "params": {"since_id": -1, "lines": 50}}))
        response = await ws.recv()
        result = json.loads(response)
        
        print("\n=== Debug Output (since_id=-1) ===")
        if result.get("success"):
            output = result.get("result", {})
            print(f"  Source: {output.get('source')}")
            print(f"  Entry count: {len(output.get('entries', []))}")
            print(f"  Last ID: {output.get('last_id')}")
            for entry in output.get("entries", []):
                print(f"    [{entry.get('id')}] {entry.get('type')}: {entry.get('message', '')[:60]}")


if __name__ == "__main__":
    asyncio.run(main())
