"""
Script to create an ethereal shield effect in Godot using the Codot MCP bridge.

This demonstrates the full capability of setting textures, materials, and shaders on nodes.
"""

import asyncio
from codot.godot_client import GodotClient


async def main():
    client = GodotClient()
    await client.connect()
    
    if not client.is_connected:
        print("Failed to connect to Godot!")
        return
    
    print("Connected to Godot!")
    
    # Step 1: Create the refraction shader file first
    print("\n1. Creating refraction shader...")
    
    shader_code = '''shader_type canvas_item;

// Ethereal shield shader with refraction and golden pulse effects

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float refraction_strength : hint_range(0.0, 0.1) = 0.02;
uniform float pulse_phase : hint_range(0.0, 6.28318) = 0.0;
uniform float shield_scale : hint_range(0.5, 1.5) = 1.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform vec4 pulse_color : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;

void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5, 0.5);
    vec2 to_center = center - uv;
    float dist = length(to_center);
    
    // Base texture
    vec4 tex_color = texture(TEXTURE, uv);
    
    // Calculate refraction based on shield scale (more refraction when shrinking)
    float refract_amount = refraction_strength * (1.5 - shield_scale);
    refract_amount = max(0.0, refract_amount);
    
    // Apply refraction to screen behind
    vec2 refracted_uv = SCREEN_UV + to_center * refract_amount * tex_color.a;
    vec4 screen_color = texture(screen_texture, refracted_uv);
    
    // Calculate pulse wave (ripples when growing)
    float grow_factor = max(0.0, shield_scale - 1.0);
    float wave = sin(dist * 20.0 - pulse_phase * 2.0) * 0.5 + 0.5;
    wave *= grow_factor * 2.0; // Only show waves when growing
    
    // Golden pulse color
    vec4 pulse = pulse_color * wave * tex_color.a;
    
    // Ethereal glow
    float glow = tex_color.a * glow_intensity;
    vec4 glow_effect = glow_color * glow;
    
    // Pulsating brightness
    float pulse_brightness = 0.8 + 0.2 * sin(pulse_phase);
    
    // Combine: refracted background + glow + pulse
    vec4 final_color = mix(screen_color, glow_effect, tex_color.a * 0.7);
    final_color += pulse;
    final_color *= pulse_brightness;
    final_color.a = tex_color.a;
    
    COLOR = final_color;
}
'''
    
    result = await client.send_command("write_file", {
        "path": "res://ethereal_shield.gdshader",
        "content": shader_code
    })
    print(f"   Shader created: {result.get('success')}")
    
    # Step 2: Create the controller script
    print("\n2. Creating controller script...")
    
    script_code = '''extends Node2D
## Ethereal Shield Effect Controller
##
## This script manages a pulsating ethereal shield with:
## - Slow breathing/pulsation effect (grow/shrink)
## - Golden ripple pulses when growing
## - Refraction effect when shrinking

@onready var particles: GPUParticles2D = $ShieldParticles
@onready var shield_sprite: Sprite2D = $ShieldSprite

## Shield pulsation settings
@export var pulse_speed: float = 0.5  ## Speed of the breathing effect
@export var min_scale: float = 0.8    ## Minimum shield size
@export var max_scale: float = 1.2    ## Maximum shield size
@export var glow_intensity: float = 1.5

var time: float = 0.0
var shader_material: ShaderMaterial

func _ready() -> void:
	# Center the shield in the viewport
	position = get_viewport_rect().size / 2
	
	# Set up the shader material
	if shield_sprite and shield_sprite.material is ShaderMaterial:
		shader_material = shield_sprite.material

func _process(delta: float) -> void:
	time += delta * pulse_speed
	
	# Calculate pulsation (sine wave for smooth breathing)
	var pulse = (sin(time * TAU) + 1.0) / 2.0  # 0 to 1
	var current_scale = lerp(min_scale, max_scale, pulse)
	
	# Apply scale to the shield sprite
	if shield_sprite:
		shield_sprite.scale = Vector2(current_scale, current_scale)
	
	# Update shader uniforms
	if shader_material:
		shader_material.set_shader_parameter("shield_scale", current_scale)
		shader_material.set_shader_parameter("pulse_phase", time * TAU)
		shader_material.set_shader_parameter("glow_intensity", glow_intensity)
	
	# Also pulse the particles
	if particles and particles.process_material:
		var pm = particles.process_material as ParticleProcessMaterial
		if pm:
			# Increase emission when growing
			pm.emission_sphere_radius = 50.0 + pulse * 30.0
'''
    
    result = await client.send_command("write_file", {
        "path": "res://ethereal_shield.gd",
        "content": script_code
    })
    print(f"   Script created: {result.get('success')}")
    
    # Step 3: Create the scene
    print("\n3. Creating new scene...")
    result = await client.send_command("create_scene", {
        "path": "res://ethereal_shield.tscn",
        "root_type": "Node2D",
        "root_name": "EtherealShield"
    })
    print(f"   Result: {result.get('success')}")
    
    if not result.get("success"):
        print(f"Failed to create scene: {result}")
        return
    
    # Step 4: Attach script to root node
    print("\n4. Attaching script to root node...")
    result = await client.send_command("set_node_property", {
        "path": ".",
        "property": "script",
        "value": "res://ethereal_shield.gd"
    })
    print(f"   Script attached: {result.get('success')}")
    if not result.get("success"):
        print(f"   Error: {result}")
    
    # Step 5: Create ShieldSprite with texture and shader material
    print("\n5. Creating ShieldSprite...")
    result = await client.send_command("create_node", {
        "type": "Sprite2D",
        "name": "ShieldSprite",
        "parent": "."
    })
    print(f"   Created: {result.get('success')}")
    
    # Set texture
    print("   Setting texture...")
    result = await client.send_command("set_node_property", {
        "path": "ShieldSprite",
        "property": "texture",
        "value": "res://icon.svg"
    })
    print(f"   Texture set: {result.get('success')}")
    if not result.get("success"):
        print(f"   Error: {result}")
    
    # Create and set shader material
    print("   Setting shader material...")
    result = await client.send_command("set_node_property", {
        "path": "ShieldSprite",
        "property": "material",
        "value": {
            "_type": "ShaderMaterial",
            "shader": "res://ethereal_shield.gdshader"
        }
    })
    print(f"   Material set: {result.get('success')}")
    if not result.get("success"):
        print(f"   Error: {result}")
    
    # Scale up the sprite
    result = await client.send_command("set_node_property", {
        "path": "ShieldSprite",
        "property": "scale",
        "value": {"x": 2.0, "y": 2.0}
    })
    print(f"   Scale set: {result.get('success')}")
    
    # Step 6: Create GPUParticles2D
    print("\n6. Creating ShieldParticles (GPUParticles2D)...")
    result = await client.send_command("create_node", {
        "type": "GPUParticles2D",
        "name": "ShieldParticles",
        "parent": "."
    })
    print(f"   Created: {result.get('success')}")
    
    # Set particle texture
    print("   Setting particle texture...")
    result = await client.send_command("set_node_property", {
        "path": "ShieldParticles",
        "property": "texture",
        "value": "res://icon.svg"
    })
    print(f"   Texture set: {result.get('success')}")
    if not result.get("success"):
        print(f"   Error: {result}")
    
    # Configure particle amount
    result = await client.send_command("set_node_property", {
        "path": "ShieldParticles",
        "property": "amount",
        "value": 32
    })
    print(f"   Amount set: {result.get('success')}")
    
    # Set particle lifetime
    result = await client.send_command("set_node_property", {
        "path": "ShieldParticles",
        "property": "lifetime",
        "value": 2.0
    })
    print(f"   Lifetime set: {result.get('success')}")
    
    # Create ParticleProcessMaterial with golden color and sphere emission
    print("   Setting process material...")
    result = await client.send_command("set_node_property", {
        "path": "ShieldParticles",
        "property": "process_material",
        "value": {
            "_type": "ParticleProcessMaterial",
            "emission_shape": 1,  # EMISSION_SHAPE_SPHERE
            "emission_sphere_radius": 60.0,
            "direction": {"x": 0, "y": 0, "z": 0},
            "spread": 180.0,
            "gravity": {"x": 0, "y": 0, "z": 0},
            "initial_velocity_min": 5.0,
            "initial_velocity_max": 15.0,
            "scale_min": 0.1,
            "scale_max": 0.3,
            "color": {"r": 1.0, "g": 0.85, "b": 0.3, "a": 0.6}
        }
    })
    print(f"   Process material set: {result.get('success')}")
    if not result.get("success"):
        print(f"   Error: {result}")
    
    # Step 7: Add a background so we can see the refraction effect
    print("\n7. Creating background for refraction visibility...")
    result = await client.send_command("create_node", {
        "type": "ColorRect",
        "name": "Background",
        "parent": "."
    })
    print(f"   Created: {result.get('success')}")
    
    # Move it behind everything
    result = await client.send_command("set_node_property", {
        "path": "Background",
        "property": "z_index",
        "value": -10
    })
    
    # Set size and position
    result = await client.send_command("set_node_property", {
        "path": "Background",
        "property": "size",
        "value": {"x": 1920, "y": 1080}
    })
    result = await client.send_command("set_node_property", {
        "path": "Background",
        "property": "position",
        "value": {"x": -960, "y": -540}
    })
    
    # Give it a gradient-like color
    result = await client.send_command("set_node_property", {
        "path": "Background",
        "property": "color",
        "value": {"r": 0.1, "g": 0.1, "b": 0.2, "a": 1.0}
    })
    print(f"   Background configured: {result.get('success')}")
    
    # Step 8: Save the scene
    print("\n8. Saving scene...")
    result = await client.send_command("save_scene", {})
    print(f"   Saved: {result.get('success')}")
    
    # Step 9: Get final scene tree
    print("\n9. Final scene tree:")
    result = await client.send_command("get_scene_tree", {})
    if result.get("success"):
        def print_tree(node, indent=0):
            prefix = "  " * indent
            name = node.get("name", "?")
            ntype = node.get("type", "?")
            print(f"{prefix}- {name} ({ntype})")
            for child in node.get("children", []):
                print_tree(child, indent + 1)
        print_tree(result.get("result", {}))
    
    print("\n" + "="*60)
    print("Scene created successfully!")
    print("="*60)
    print("""
The ethereal shield scene has been created with:
- ShieldSprite: Sprite2D with icon.svg and the refraction shader
- ShieldParticles: GPUParticles2D with golden glowing particles  
- Background: Dark ColorRect for refraction visibility
- Controller script attached to root for pulsation animation

Run the scene with godot_play to see the effect!
""")
    
    await client.disconnect()
    print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
