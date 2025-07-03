shader_type canvas_item;

// Speed and motion effects
uniform float speed_effect_strength : hint_range(0.0, 1.0) = 0.5;
uniform float motion_blur_strength : hint_range(0.0, 0.1) = 0.02;
uniform vec2 motion_direction = vec2(1.0, 0.0);

// Chromatic aberration (speed distortion)
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.01;
uniform float aberration_falloff : hint_range(0.1, 2.0) = 1.0;

// Vignette effect
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float vignette_smoothness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Color grading
uniform float saturation : hint_range(0.0, 2.0) = 1.2;
uniform float contrast : hint_range(0.0, 2.0) = 1.1;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform vec4 color_tint : source_color = vec4(1.0, 0.95, 0.9, 1.0);

// Screen distortion (heat/speed waves)
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;
uniform float distortion_frequency : hint_range(0.0, 50.0) = 10.0;
uniform float distortion_speed : hint_range(0.0, 10.0) = 3.0;

// Scanlines (optional retro effect)
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_frequency : hint_range(50.0, 500.0) = 200.0;

// Glitch effect (for impacts/boosts)
uniform float glitch_strength : hint_range(0.0, 1.0) = 0.0;
uniform float glitch_block_size : hint_range(0.01, 0.2) = 0.05;

void vertex() {
	// Standard vertex processing
}

// Helper functions
vec3 apply_color_grading(vec3 color) {
	// Brightness
	color *= brightness;

	// Contrast
	color = (color - 0.5) * contrast + 0.5;

	// Saturation
	vec3 grayscale = vec3(dot(color, vec3(0.299, 0.587, 0.114)));
	color = mix(grayscale, color, saturation);

	// Color tint
	color *= color_tint.rgb;

	return clamp(color, 0.0, 1.0);
}

float random(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 apply_distortion(vec2 uv, float time) {
	float wave = sin(uv.y * distortion_frequency + time * distortion_speed) * distortion_strength;
	wave *= speed_effect_strength;
	return vec2(uv.x + wave, uv.y);
}

vec3 apply_chromatic_aberration(sampler2D tex, vec2 uv) {
	vec2 center = vec2(0.5, 0.5);
	vec2 offset = (uv - center) * chromatic_aberration * speed_effect_strength;
	offset *= pow(length(uv - center), aberration_falloff);

	float r = texture(tex, uv + offset).r;
	float g = texture(tex, uv).g;
	float b = texture(tex, uv - offset).b;

	return vec3(r, g, b);
}

vec3 apply_motion_blur(sampler2D tex, vec2 uv) {
	vec3 color = vec3(0.0);
	float total_weight = 0.0;
	int samples = 8;

	for (int i = 0; i < samples; i++) {
		float t = float(i) / float(samples - 1) - 0.5;
		vec2 offset = motion_direction * motion_blur_strength * t * speed_effect_strength;
		float weight = 1.0 - abs(t);

		color += texture(tex, uv + offset).rgb * weight;
		total_weight += weight;
	}

	return color / total_weight;
}

float apply_vignette(vec2 uv) {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(uv, center);
	float vignette = smoothstep(1.0 - vignette_smoothness, 1.0, 1.0 - dist * 1.4);
	return mix(1.0, vignette, vignette_intensity);
}

vec3 apply_glitch(sampler2D tex, vec2 uv, float time) {
	if (glitch_strength <= 0.0) return texture(tex, uv).rgb;

	vec2 block = floor(uv / glitch_block_size) * glitch_block_size;
	float glitch_offset = random(block + vec2(time)) * glitch_strength;

	if (glitch_offset > 0.7) {
		// Horizontal displacement
		uv.x += (random(block + vec2(time * 2.0)) - 0.5) * 0.1 * glitch_strength;
	}

	vec3 color = texture(tex, uv).rgb;

	// Random color channel shifting
	if (glitch_offset > 0.8) {
		color.r = texture(tex, uv + vec2(0.01, 0.0) * glitch_strength).r;
		color.b = texture(tex, uv - vec2(0.01, 0.0) * glitch_strength).b;
	}

	return color;
}

void fragment() {
	vec2 uv = UV;

	// Apply screen distortion
	uv = apply_distortion(uv, TIME);

	// Get base color with motion blur
	vec3 color = apply_motion_blur(TEXTURE, uv);

	// Apply chromatic aberration
	if (chromatic_aberration > 0.0) {
		color = apply_chromatic_aberration(TEXTURE, uv);
	}

	// Apply glitch effect
	color = apply_glitch(TEXTURE, uv, TIME);

	// Apply color grading
	color = apply_color_grading(color);

	// Apply vignette
	float vignette_factor = apply_vignette(UV);
	color = mix(vignette_color.rgb, color, vignette_factor);

	// Apply scanlines
	if (scanline_strength > 0.0) {
		float scanline = sin(UV.y * scanline_frequency) * 0.5 + 0.5;
		scanline = mix(1.0, scanline, scanline_strength * 0.3);
		color *= scanline;
	}

	COLOR = vec4(color, 1.0);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
