import asyncio
import websockets

async def test_raw():
    """Test raw websocket connection."""
    print("Testing raw WebSocket connection...")
    try:
        ws = await asyncio.wait_for(
            websockets.connect("ws://127.0.0.1:6850"),
            timeout=5
        )
        print("Connected!")
        
        # Send ping command
        await ws.send('{"id": "test1", "command": "ping", "params": {}}')
        print("Sent ping command")
        
        response = await asyncio.wait_for(ws.recv(), timeout=5)
        print(f"Response: {response}")
        
        await ws.close()
        print("Connection closed")
    except asyncio.TimeoutError:
        print("Connection timed out")
    except Exception as e:
        print(f"Error: {type(e).__name__}: {e}")


async def test_client():
    """Test GodotClient class."""
    from codot.godot_client import GodotClient
    
    print("\nTesting GodotClient...")
    client = GodotClient()
    
    connected = await client.connect()
    print(f"Connected: {connected}")
    
    if connected:
        # Test ping
        result = await client.send_command("ping", {})
        print(f"Ping result: {result}")
        
        # Test get_status
        result = await client.send_command("get_status", {})
        print(f"Status result: {result}")
        
        await client.disconnect()
        print("Disconnected")


async def main():
    await test_raw()
    await test_client()


if __name__ == "__main__":
    asyncio.run(main())
