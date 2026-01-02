#!/usr/bin/env python3
"""
Test the new automation commands for Codot.

Usage:
    python test_automation.py

Requirements:
    - Godot editor running with Codot plugin enabled
    - WebSocket server listening on port 6850
"""

import asyncio
import json
import websockets

async def send_command(ws, command: str, params: dict = None):
    """Send a command and return the response."""
    msg = {
        "id": f"test-{command}",
        "command": command,
        "params": params or {}
    }
    await ws.send(json.dumps(msg))
    response = await asyncio.wait_for(ws.recv(), timeout=60)
    return json.loads(response)

async def test_automation():
    """Test the new automation commands."""
    uri = "ws://localhost:6850"
    
    async with websockets.connect(uri) as ws:
        print("=" * 60)
        print("Testing Automation Commands")
        print("=" * 60)
        
        # Test 1: get_game_state
        print("\n1. Testing get_game_state...")
        result = await send_command(ws, "get_game_state")
        print(f"   Success: {result.get('success')}")
        if result.get('success'):
            data = result.get('result', {})
            print(f"   Is Playing: {data.get('is_playing')}")
            print(f"   Debugger Available: {data.get('debugger_available')}")
        else:
            print(f"   Error: {result.get('error')}")
        
        # Test 2: run_and_capture (if not already playing)
        print("\n2. Testing run_and_capture...")
        result = await send_command(ws, "run_and_capture", {
            "duration": 2.0,
            "filter": "all",
        })
        print(f"   Success: {result.get('success')}")
        if result.get('success'):
            data = result.get('result', {})
            print(f"   Duration Actual: {data.get('duration_actual'):.2f}s")
            print(f"   Stopped Early: {data.get('stopped_early')}")
            print(f"   Error Count: {data.get('error_count')}")
            print(f"   Warning Count: {data.get('warning_count')}")
            print(f"   Entries Captured: {len(data.get('entries', []))}")
            if data.get('errors'):
                print(f"   First Error: {data['errors'][0].get('message', '')[:60]}...")
        else:
            print(f"   Error: {result.get('error')}")
        
        # Test 3: Play and test ping_game
        print("\n3. Testing ping_game (starting game first)...")
        await send_command(ws, "play_current")
        await asyncio.sleep(1)  # Wait for game to start
        
        result = await send_command(ws, "ping_game", {"timeout": 3.0})
        print(f"   Success: {result.get('success')}")
        if result.get('success'):
            data = result.get('result', {})
            print(f"   Pong Received: {data.get('pong')}")
            if data.get('pong'):
                print(f"   Latency: {data.get('latency', 0):.4f}s")
        else:
            print(f"   Error: {result.get('error')}")
        
        # Test 4: wait_for_output
        print("\n4. Testing wait_for_output...")
        result = await send_command(ws, "wait_for_output", {
            "wait_for": "any",
            "timeout": 2.0,
        })
        print(f"   Success: {result.get('success')}")
        if result.get('success'):
            data = result.get('result', {})
            print(f"   Found: {data.get('found')}")
            print(f"   Elapsed: {data.get('elapsed', 0):.2f}s")
            if data.get('matched_entry'):
                print(f"   Match Type: {data['matched_entry'].get('type')}")
        else:
            print(f"   Error: {result.get('error')}")
        
        # Stop the game
        await send_command(ws, "stop")
        
        # Test 5: gut_get_summary
        print("\n5. Testing gut_get_summary...")
        result = await send_command(ws, "gut_get_summary")
        print(f"   Success: {result.get('success')}")
        if result.get('success'):
            data = result.get('result', {})
            print(f"   Total Entries: {data.get('total_entries')}")
            print(f"   Passed: {data.get('passed')}")
            print(f"   Failed: {data.get('failed')}")
            print(f"   Scripts Run: {len(data.get('scripts_run', []))}")
        else:
            print(f"   Error: {result.get('error')}")
        
        print("\n" + "=" * 60)
        print("Automation Tests Complete!")
        print("=" * 60)

if __name__ == "__main__":
    asyncio.run(test_automation())
