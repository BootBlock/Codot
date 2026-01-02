"""Demo: Create a particle scene in Godot via MCP."""
import asyncio
from codot.godot_client import GodotClient


async def create_particles_scene():
    client = GodotClient()
    await client.connect()
    
    # Create a new scene with Node2D root
    print('Creating new scene...')
    result = await client.send_command('create_scene', {
        'path': 'res://particle_demo.tscn',
        'root_type': 'Node2D',
        'root_name': 'ParticleDemo'
    })
    print(f"Create scene: {result.get('success', False)}")
    
    # Add GPUParticles2D node
    print('Adding GPUParticles2D...')
    result = await client.send_command('create_node', {
        'type': 'GPUParticles2D',
        'name': 'Sparkles',
        'parent': '.'
    })
    print(f"Create GPUParticles2D: {result.get('success', False)}")
    
    # Set particles to emit
    print('Configuring particles...')
    result = await client.send_command('set_node_property', {
        'path': 'Sparkles',
        'property': 'emitting',
        'value': True
    })
    print(f"Set emitting: {result.get('success', False)}")
    
    # Set amount
    result = await client.send_command('set_node_property', {
        'path': 'Sparkles',
        'property': 'amount',
        'value': 50
    })
    print(f"Set amount: {result.get('success', False)}")
    
    # Position it in center-ish
    result = await client.send_command('set_node_property', {
        'path': 'Sparkles',
        'property': 'position',
        'value': {'x': 500, 'y': 300}
    })
    print(f"Set position: {result.get('success', False)}")
    
    # Save the scene
    print('Saving scene...')
    result = await client.send_command('save_scene', {})
    print(f"Save scene: {result.get('success', False)}")
    
    # Get the scene tree to confirm
    result = await client.send_command('get_scene_tree', {})
    if result.get('success'):
        tree = result.get('result', {}).get('tree', {})
        print(f"\nScene tree: {tree.get('name')} ({tree.get('type')})")
        for child in tree.get('children', []):
            print(f"  - {child.get('name')} ({child.get('type')})")
    
    await client.disconnect()
    print('\n=== Done! Check Godot - new scene should be open ===')


if __name__ == '__main__':
    asyncio.run(create_particles_scene())
