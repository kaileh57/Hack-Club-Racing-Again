extends VehicleBody3D

@export_category("Car Settings")
@export var max_steer : float = 0.45
@export var max_torque : float = 300.0
@export var max_brake_force : float = 1.0
@export var max_wheel_rpm : float = 600.0
@export var steer_damping = 2.0
@export var front_wheel_grip : float = 5.0
@export var rear_wheel_grip : float = 5.0

@export_category("Drift Settings")
@export var drift_steer_multiplier : float = 1.6
@export var drift_front_grip_reduction : float = 0.4
@export var drift_rear_grip_reduction : float = 0.3
@export var drift_damping_multiplier : float = 0.6
@export var drift_speed_boost : float = 1.4
@export var drift_transition_speed : float = 12.0

var player_acceleration : float = 0.0
var player_braking : float = 0.0
var player_steer : float = 0.0
var player_input : Vector2 = Vector2.ZERO
var is_drifting : bool = false
var drift_input : bool = false
var drift_intensity : float = 0.0  # 0 = no drift, 1 = full drift

@onready var driving_wheels : Array[VehicleWheel3D] = [$WheelBackLeft,$WheelBackRight]
@onready var steering_wheels : Array[VehicleWheel3D] = [$WheelFrontLeft,$WheelFrontRight]

# Drift particle systems
@export var drift_particles : Array[GPUParticles3D] = []


func _ready() -> void:
	#set wheel friction slip
	for wheel in steering_wheels:
		wheel.wheel_friction_slip = front_wheel_grip
	for wheel in driving_wheels:
		wheel.wheel_friction_slip = rear_wheel_grip



func _physics_process(delta: float) -> void:
	get_input(delta)
	handle_drift_state()
	
	#now process steering and braking
	steering = player_steer
	brake = player_braking
	#cos we want to limit rpm- control each driving wheel individually
	for wheel in driving_wheels:
		#linearly reduce engine force based on the wheels current rpm and the player input
		var base_force : float = player_acceleration * ((-max_torque/max_wheel_rpm) * abs(wheel.get_rpm()) + max_torque)
		#apply drift speed boost based on drift intensity
		var current_speed_boost = lerp(1.0, drift_speed_boost, drift_intensity)
		var actual_force : float = base_force * current_speed_boost
		wheel.engine_force = actual_force


func get_input(delta : float):
	#get drift input
	drift_input = Input.is_action_pressed("Drift")

	#steer first - apply drift multiplier based on drift intensity
	player_input.x = Input.get_axis("Right","Left")
	var current_steer_multiplier = lerp(1.0, drift_steer_multiplier, drift_intensity)
	var current_damping = lerp(steer_damping, steer_damping * drift_damping_multiplier, drift_intensity)
	player_steer = move_toward(player_steer, player_input.x * max_steer * current_steer_multiplier, current_damping * delta)
	
	#now acceleration and/or braking
	player_input.y = Input.get_axis("Backward","Forward")
	if player_input.y > 0.01:
		#accelerating
		player_acceleration = player_input.y
		player_braking = 0.0
	elif player_input.y < -0.01:
		#we are trying to brake or reverse
		if going_forward():
			#brake
			player_braking = -player_input.y * max_brake_force
			player_acceleration = 0.0
		else:
			#reverse
			player_braking = 0.0
			player_acceleration = player_input.y
	else:
		player_acceleration = 0.0
		player_braking = 0.0

func going_forward() -> bool:
	var relative_speed : float = basis.z.dot(linear_velocity.normalized())
	if relative_speed > 0.01:
		return true
	else:
		return false

func handle_drift_state():
	# Calculate target drift intensity
	var target_drift = 0.0
	var should_drift = drift_input and abs(player_input.x) > 0.01
	
	if should_drift:
		# Balanced drift - controllable but still slidey
		var steer_factor = abs(player_input.x)
		var speed_factor = min(linear_velocity.length() / 6.0, 1.0)  # Moderate speed requirement
		speed_factor = max(speed_factor, 0.2)  # Minimum 20% intensity even at low speed
		target_drift = steer_factor * speed_factor  # No extra multiplier for control
	
	# Smooth transition to target drift intensity
	drift_intensity = move_toward(drift_intensity, target_drift, drift_transition_speed * get_physics_process_delta_time())
	
	# Update drift state
	var was_drifting = is_drifting
	is_drifting = drift_intensity > 0.05
	
	# Simple particle control - just follow space key
	var particles_currently_active = false
	if drift_particles.size() > 0 and drift_particles[0] != null:
		particles_currently_active = drift_particles[0].emitting
	
	if drift_input != particles_currently_active:
		activate_drift_particles(drift_input)
	
	# Always update friction to current drift intensity
	update_wheel_friction()

func update_wheel_friction():
	# Interpolate friction based on drift intensity
	var front_friction = lerp(front_wheel_grip, front_wheel_grip * drift_front_grip_reduction, drift_intensity)
	var rear_friction = lerp(rear_wheel_grip, rear_wheel_grip * drift_rear_grip_reduction, drift_intensity)
	
	for wheel in steering_wheels:
		wheel.wheel_friction_slip = front_friction
			
	for wheel in driving_wheels:
		wheel.wheel_friction_slip = rear_friction

func activate_drift_particles(enable: bool):
	# Enable or disable all drift particle systems
	for particles in drift_particles:
		particles.emitting = enable
	
