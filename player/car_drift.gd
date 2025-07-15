extends Node3D

@onready var ball: RigidBody3D = $Ball
@onready var car: Node3D = $Car
@onready var left_wheel: MeshInstance3D = $"Car/wheel-front-left"
@onready var right_wheel: MeshInstance3D = $"Car/wheel-front-right"
@onready var body: MeshInstance3D = $Car/body

@export var acceleration = 70.0
@export var steering = 12.0
@export var turn_speed = 5
@export var body_tilt = 30
@export var jump_force = 40.0

var speed_input = 0
var rotate_input = 0
var is_on_ground = false
var ground_ray: RayCast3D

func _ready() -> void:
	# Create ground detection raycast
	ground_ray = RayCast3D.new()
	ground_ray.name = "GroundRay"
	ground_ray.target_position = Vector3(0, -1.2, 0)
	ground_ray.enabled = true
	ball.add_child(ground_ray)

func _physics_process(delta: float) -> void:
	car.transform.origin = ball.transform.origin
	ball.apply_central_force(-car.global_transform.basis.z * speed_input)
	
	# Check if on ground
	is_on_ground = ground_ray.is_colliding()
	
	# Handle jump input
	if Input.is_action_just_pressed("Jump") and is_on_ground:
		ball.apply_central_impulse(Vector3.UP * jump_force)

func  _process(delta: float) -> void:
	speed_input = (Input.get_action_strength("Backward") - Input.get_action_strength("Forward")) * acceleration
	rotate_input = deg_to_rad(steering) * (Input.get_action_strength("Left") - Input.get_action_strength("Right"))
	
	left_wheel.rotation.y = rotate_input
	right_wheel.rotation.y = rotate_input
	
	if ball.linear_velocity.length() > 0.75:
		rotate_car(delta)

func rotate_car(delta: float) -> void:
	var new_basis = car.global_transform.basis.rotated(car.global_transform.basis.y, rotate_input)
	car.global_transform.basis = car.global_transform.basis.slerp(new_basis, turn_speed * delta)
	car.global_transform = car.global_transform.orthonormalized()
	var tilt = -rotate_input * ball.linear_velocity.length() / body_tilt
	body.rotation.z = lerp(body.rotation.z, tilt, 10 * delta)


