"""Test the VS Code Codot Bridge connection."""
import asyncio
import json
import websockets

VSCODE_BRIDGE_PORT = 6851


async def test_bridge():
    """Test connecting to the VS Code bridge and sending a prompt."""
    uri = f"ws://127.0.0.1:{VSCODE_BRIDGE_PORT}"
    
    print(f"Connecting to VS Code bridge at {uri}...")
    
    try:
        async with websockets.connect(uri) as ws:
            print("Connected!")
            
            # Wait for welcome message
            response = await asyncio.wait_for(ws.recv(), timeout=2.0)
            data = json.loads(response)
            print(f"Welcome message: {data}")
            
            # Send a ping
            print("\nSending ping...")
            await ws.send(json.dumps({"type": "ping"}))
            response = await asyncio.wait_for(ws.recv(), timeout=2.0)
            data = json.loads(response)
            print(f"Pong response: {data}")
            
            # Send a test prompt
            print("\nSending test prompt...")
            prompt_message = {
                "type": "prompt",
                "prompt": "This is a test prompt from the Godot plugin test script.",
                "context": {
                    "current_scene": "res://test_scene.tscn",
                    "selected_nodes": ["/root/TestNode"]
                },
                "timestamp": 1234567890
            }
            await ws.send(json.dumps(prompt_message))
            response = await asyncio.wait_for(ws.recv(), timeout=5.0)
            data = json.loads(response)
            print(f"Prompt response: {data}")
            
            print("\n=== All tests passed! ===")
            return True
            
    except ConnectionRefusedError:
        print("ERROR: Could not connect to VS Code bridge.")
        print("Make sure:")
        print("  1. VS Code is running")
        print("  2. The Codot Bridge extension is installed and activated")
        print("  3. Run 'Codot: Start Bridge Server' command in VS Code")
        return False
    except asyncio.TimeoutError:
        print("ERROR: Timeout waiting for response")
        return False
    except Exception as e:
        print(f"ERROR: {e}")
        return False


if __name__ == "__main__":
    result = asyncio.run(test_bridge())
    exit(0 if result else 1)
