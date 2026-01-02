"""
Script to create an ethereal shield effect by writing the scene file directly.

This approach embeds resources properly in the .tscn file for persistence.
"""

import asyncio
from codot.godot_client import GodotClient


SCENE_CONTENT = '''[gd_scene load_steps=5 format=3 uid="uid://ethereal_shield_scene"]

[ext_resource type="Texture2D" uid="uid://ccpq8cxgbod4l" path="res://icon.svg" id="1_icon"]
[ext_resource type="Shader" path="res://ethereal_shield.gdshader" id="2_shader"]
[ext_resource type="Script" path="res://ethereal_shield.gd" id="3_script"]

[sub_resource type="ShaderMaterial" id="ShaderMaterial_shield"]
shader = ExtResource("2_shader")
shader_parameter/refraction_strength = 0.02
shader_parameter/pulse_phase = 0.0
shader_parameter/shield_scale = 1.0
shader_parameter/glow_color = Color(1, 0.85, 0.4, 1)
shader_parameter/pulse_color = Color(1, 0.9, 0.3, 1)
shader_parameter/glow_intensity = 1.5

[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_particles"]
emission_shape = 1
emission_sphere_radius = 60.0
direction = Vector3(0, 0, 0)
spread = 180.0
gravity = Vector3(0, 0, 0)
initial_velocity_min = 5.0
initial_velocity_max = 15.0
scale_min = 0.1
scale_max = 0.3
color = Color(1, 0.85, 0.3, 0.6)

[node name="EtherealShield" type="Node2D"]
script = ExtResource("3_script")

[node name="Background" type="ColorRect" parent="."]
z_index = -10
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -576.0
offset_top = -324.0
offset_right = 576.0
offset_bottom = 324.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.08, 0.08, 0.15, 1)

[node name="ShieldSprite" type="Sprite2D" parent="."]
material = SubResource("ShaderMaterial_shield")
scale = Vector2(2.5, 2.5)
texture = ExtResource("1_icon")

[node name="ShieldParticles" type="GPUParticles2D" parent="."]
amount = 48
process_material = SubResource("ParticleProcessMaterial_particles")
texture = ExtResource("1_icon")
lifetime = 2.5
'''

SHADER_CODE = '''shader_type canvas_item;

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

SCRIPT_CODE = '''extends Node2D
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
		shield_sprite.scale = Vector2.ONE * current_scale * 2.5  # Base scale is 2.5
	
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


async def main():
    client = GodotClient()
    await client.connect()
    
    if not client.is_connected:
        print("Failed to connect to Godot!")
        return
    
    print("Connected to Godot!")
    
    # Step 1: Write the shader file
    print("\n1. Creating shader file...")
    result = await client.send_command("write_file", {
        "path": "res://ethereal_shield.gdshader",
        "content": SHADER_CODE
    })
    print(f"   Shader: {result.get('success')}")
    
    # Step 2: Write the script file
    print("\n2. Creating script file...")
    result = await client.send_command("write_file", {
        "path": "res://ethereal_shield.gd",
        "content": SCRIPT_CODE
    })
    print(f"   Script: {result.get('success')}")
    
    # Step 3: Write the scene file directly
    print("\n3. Creating scene file...")
    result = await client.send_command("write_file", {
        "path": "res://ethereal_shield.tscn",
        "content": SCENE_CONTENT
    })
    print(f"   Scene: {result.get('success')}")
    
    # Step 4: Open and run the scene
    print("\n4. Opening scene...")
    result = await client.send_command("open_scene", {
        "path": "res://ethereal_shield.tscn"
    })
    print(f"   Opened: {result.get('success')}")
    
    print("\n5. Running scene...")
    result = await client.send_command("play_current", {})
    print(f"   Playing: {result.get('success')}")
    
    if result.get("success"):
        print("\n" + "="*60)
        print("SUCCESS! Ethereal Shield scene is now running!")
        print("="*60)
        print("""
You should see:
- A pulsating golden shield effect using the Godot icon
- The shield grows and shrinks with a breathing effect
- Golden ripple pulses appear when the shield grows
- Refraction distortion when the shield shrinks
- Particle effects orbiting the shield

Press Ctrl+C or use godot_stop to stop the game.
""")
    
    await client.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
