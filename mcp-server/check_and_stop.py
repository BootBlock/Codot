"""Check for errors and stop the game."""
import asyncio
import time
from codot.godot_client import GodotClient

async def run():
    c = GodotClient()
    await c.connect()
    
    # Wait a moment for any errors to appear
    print("Waiting for game to run...")
    await asyncio.sleep(2)
    
    # Get debug output
    print("\nChecking for errors...")
    result = await c.send_command('get_debug_output', {'filter': 'error'})
    
    if result.get('success'):
        data = result.get('result', {})
        errors = data.get('errors', [])
        warnings = data.get('warnings', [])
        
        print(f"Source: {data.get('source')}")
        print(f"Errors: {len(errors)}")
        print(f"Warnings: {len(warnings)}")
        
        for err in errors[:5]:
            print(f"  ERROR: {err.get('message', err)}")
        for warn in warnings[:5]:
            print(f"  WARNING: {warn.get('message', warn)}")
    else:
        print(f"Failed: {result}")
    
    # Stop the game
    print("\nStopping game...")
    result = await c.send_command('stop', {})
    print(f"Stopped: {result.get('success')}")
    
    await c.disconnect()

asyncio.run(run())
