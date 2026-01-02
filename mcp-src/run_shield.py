"""Quick test script to run the ethereal shield scene."""
import asyncio
from codot.godot_client import GodotClient

async def run():
    c = GodotClient()
    await c.connect()
    
    # First open the scene
    print("Opening ethereal shield scene...")
    result = await c.send_command('open_scene', {'path': 'res://ethereal_shield.tscn'})
    print(f"Open: {result.get('success')}")
    
    # Then play
    print("Playing...")
    result = await c.send_command('play_current', {})
    print(f"Play: {result}")
    
    await c.disconnect()

asyncio.run(run())
