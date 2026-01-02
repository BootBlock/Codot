import asyncio
from codot.godot_client import GodotClient

async def full_test():
    client = GodotClient()
    await client.connect()
    
    tests = [
        ('ping', {}),
        ('get_status', {}),
        ('get_scene_tree', {}),
        ('get_plugins', {}),
        ('get_debugger_status', {}),
        ('get_project_files', {'path': 'res://addons/codot/', 'extension': '.gd'}),
        ('get_open_scenes', {}),
        ('get_input_actions', {}),
        ('get_performance_info', {}),
        ('list_audio_buses', {}),
    ]
    
    passed = 0
    failed = 0
    
    for cmd, params in tests:
        result = await client.send_command(cmd, params)
        if result.get('success'):
            passed += 1
            print(f'{cmd}: PASS')
        else:
            failed += 1
            err = result.get('error', {})
            print(f'{cmd}: FAIL - {err}')
    
    await client.disconnect()
    print(f'\n=== Results: {passed} passed, {failed} failed ===')

if __name__ == '__main__':
    asyncio.run(full_test())
