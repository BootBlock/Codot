"""Quick test for open_script command."""
import asyncio
from codot.godot_client import GodotClient

async def test():
    client = GodotClient()
    await client.connect()
    
    # Open a script at line 50
    result = await client.send_command('open_script', {
        'path': 'res://addons/codot/websocket_server.gd',
        'line': 50
    })
    print("open_script result:", result)
    
    await client.disconnect()

if __name__ == "__main__":
    asyncio.run(test())
