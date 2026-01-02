extends Node2D
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
