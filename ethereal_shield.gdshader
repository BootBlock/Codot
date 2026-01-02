shader_type canvas_item;

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
