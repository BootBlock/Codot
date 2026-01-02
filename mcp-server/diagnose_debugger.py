"""Diagnose why the debugger isn't capturing errors."""
import asyncio
from codot.godot_client import GodotClient


async def main():
    client = GodotClient()
    await client.connect()
    
    print("Connected to Godot!")
    
    # Check debugger status
    print("\n=== DEBUGGER STATUS ===")
    result = await client.send_command("get_debugger_status", {})
    if result.get("success"):
        data = result.get("result", {})
        for key, value in data.items():
            print(f"  {key}: {value}")
    else:
        print(f"  Error: {result}")
    
    # Check editor log
    print("\n=== EDITOR LOG (last 30 lines) ===")
    result = await client.send_command("get_editor_log", {
        "lines": 30,
        "filter": "all",
        "tail": True
    })
    if result.get("success"):
        data = result.get("result", {})
        print(f"  Log path: {data.get('log_path')}")
        print(f"  Total lines: {data.get('total_lines')}")
        print(f"  Errors: {data.get('error_count')}")
        print(f"  Warnings: {data.get('warning_count')}")
        print("\n  --- Recent entries ---")
        for entry in data.get("entries", [])[-15:]:
            etype = entry.get("type", "?")
            text = entry.get("text", "")[:80]
            print(f"  [{etype}] {text}")
    else:
        print(f"  Error: {result}")
    
    await client.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
