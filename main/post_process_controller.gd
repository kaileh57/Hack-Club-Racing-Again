extends Node

# Reference to the shader material
@onready var shader_material : ShaderMaterial = $"../TextureRect".material as ShaderMaterial
@onready var car = $"../../SubViewport/Car"

# Configuration
var base_speed_effect = 0.0
var max_speed_effect = 1.0
var speed_threshold = 20.0  # Speed at which effects start
var max_speed = 100.0  # Speed for maximum effect

# Smooth transitions
var current_speed_effect = 0.0
var target_speed_effect = 0.0
var effect_smoothing = 5.0

# Boost/nitro effect
var boost_active = false
var boost_timer = 0.0
var boost_duration = 0.5

# Impact/collision effect
var impact_timer = 0.0
var impact_duration = 0.3

func _ready():
	# Set default values
	if shader_material:
		shader_material.set_shader_parameter("speed_effect_strength", 0.0)
		shader_material.set_shader_parameter("glitch_strength", 0.0)

func _process(delta):
	if !shader_material or !car:
		return
	
	# Get car speed (assuming the car script has a velocity property)
	var car_speed = 0.0
	if car.has_method("get_speed"):
		car_speed = car.get_speed()
	elif "linear_velocity" in car:
		car_speed = car.linear_velocity.length()
	
	# Calculate target speed effect based on speed
	if car_speed > speed_threshold:
		var speed_factor = (car_speed - speed_threshold) / (max_speed - speed_threshold)
		speed_factor = clamp(speed_factor, 0.0, 1.0)
		target_speed_effect = lerp(base_speed_effect, max_speed_effect, speed_factor)
	else:
		target_speed_effect = base_speed_effect
	
	# Apply boost effect
	if boost_active:
		target_speed_effect = max_speed_effect
		boost_timer -= delta
		if boost_timer <= 0:
			boost_active = false
	
	# Smooth transition
	current_speed_effect = lerp(current_speed_effect, target_speed_effect, delta * effect_smoothing)
	
	# Update shader parameters
	shader_material.set_shader_parameter("speed_effect_strength", current_speed_effect)
	
	# Motion blur increases with speed
	var motion_blur = lerp(0.0, 0.05, current_speed_effect)
	shader_material.set_shader_parameter("motion_blur_strength", motion_blur)
	
	# Chromatic aberration increases with speed
	var chromatic = lerp(0.0, 0.03, current_speed_effect)
	shader_material.set_shader_parameter("chromatic_aberration", chromatic)
	
	# Screen distortion for heat effect at high speeds
	var distortion = lerp(0.0, 0.05, current_speed_effect)
	shader_material.set_shader_parameter("distortion_strength", distortion)
	
	# Vignette intensity increases slightly with speed
	var vignette = lerp(0.3, 0.5, current_speed_effect * 0.5)
	shader_material.set_shader_parameter("vignette_intensity", vignette)
	
	# Update motion direction based on car movement
	if car_speed > 0.1 and "linear_velocity" in car:
		var velocity_2d = Vector2(car.linear_velocity.x, car.linear_velocity.z).normalized()
		shader_material.set_shader_parameter("motion_direction", velocity_2d)
	
	# Handle impact effect
	if impact_timer > 0:
		impact_timer -= delta
		var impact_strength = impact_timer / impact_duration
		shader_material.set_shader_parameter("glitch_strength", impact_strength * 0.7)
		
		# Add screen shake via distortion
		var shake_distortion = sin(impact_timer * 50.0) * impact_strength * 0.1
		shader_material.set_shader_parameter("distortion_strength", distortion + shake_distortion)
	else:
		shader_material.set_shader_parameter("glitch_strength", 0.0)

# Call this when boost/nitro is activated
func activate_boost():
	boost_active = true
	boost_timer = boost_duration
	
	# Flash effect
	shader_material.set_shader_parameter("brightness", 1.5)
	var tween = create_tween()
	tween.tween_property(shader_material, "shader_parameter/brightness", 1.0, 0.3)

# Call this on collision/impact
func trigger_impact(strength: float = 1.0):
	impact_timer = impact_duration * strength
	
	# Brief color shift
	shader_material.set_shader_parameter("saturation", 0.5)
	var tween = create_tween()
	tween.tween_property(shader_material, "shader_parameter/saturation", 1.2, 0.3)

# Toggle retro mode
func set_retro_mode(enabled: bool):
	if enabled:
		shader_material.set_shader_parameter("scanline_strength", 0.3)
		shader_material.set_shader_parameter("saturation", 0.8)
		shader_material.set_shader_parameter("color_tint", Color(0.9, 0.85, 0.7))
	else:
		shader_material.set_shader_parameter("scanline_strength", 0.0)
		shader_material.set_shader_parameter("saturation", 1.2)
		shader_material.set_shader_parameter("color_tint", Color(1.0, 0.95, 0.9)) 
