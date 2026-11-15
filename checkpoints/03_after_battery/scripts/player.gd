extends CharacterBody2D

# PLAYER — movement, animation, and the quiet front-facing sensor.
# Input.get_vector() turns WASD/arrow keys into a movement direction.
# RayCast2D tells us whether a wall is in front of the player; SensorBeam
# draws a separate visual line so players understand what was detected.
# Unlike the big radar scan, this front sensor does NOT alert drones.

class_name RescuePlayer
## The robot you control with WASD or arrow keys.
## It has TWO different sensors:
## 1. ForwardRay: short, silent, always available.
## 2. Radar: circular scan, but the drones can hear it.

@export var speed: float = 180.0
@export var sensor_range: float = 80.0
@export var show_sensor_beam: bool = true
@export var auto_stop_on_wall: bool = false  # Optional FRC extension.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var forward_ray: RayCast2D = $ForwardRay
@onready var sensor_beam: ForwardSensorBeam = $SensorBeam
@onready var radar: RadarPulse = $Radar

var last_direction: Vector2 = Vector2.DOWN
var obstacle_ahead: bool = false

# Start with the idle animation and hide/show the decorative sensor beam
# based on the Inspector checkbox.
func _ready() -> void:
    sprite.play("idle_down")
    sensor_beam.visible = show_sensor_beam

# Every physics frame, read keyboard input and turn it into movement.
# Update the robot's facing first so the ray checks the correct direction.
# If the optional auto-stop is enabled and the sensor sees a wall, stop
# forward movement; turning or backing away still works.
func _physics_process(_delta: float) -> void:
    var movement := Input.get_vector("left", "right", "up", "down")
    _update_facing(movement)
    _check_forward_sensor()  # Sense before moving, so auto-stop can act.

    velocity = movement * speed
    if auto_stop_on_wall and obstacle_ahead and movement.dot(last_direction) > 0.9:
        velocity = Vector2.ZERO
    move_and_slide()
    _play_animation(movement)

# Pick one of four directions by comparing horizontal vs vertical input.
# For diagonals, the larger axis wins so the sprite faces only one way.
# When standing still, keep checking the last direction we faced.
func _update_facing(movement: Vector2) -> void:
    if movement.length() < 0.01:
        return  # Continue sensing in our last facing direction.
    if absf(movement.x) > absf(movement.y):
        last_direction = Vector2.RIGHT if movement.x > 0 else Vector2.LEFT
    else:
        last_direction = Vector2.DOWN if movement.y > 0 else Vector2.UP

# Aim the ray in the direction the player faces and check if it hits.
# RayCast2D's collision point is in GLOBAL (world) coordinates; the drawing
# needs a LOCAL endpoint because SensorBeam is a child of Player.
# to_local() performs that coordinate conversion.
# STARTER: students replace the placeholder code in this function.
func _check_forward_sensor() -> void:
    # CHALLENGE 1: Point the ray, detect a wall, and draw the beam.
    forward_ray.target_position = last_direction * sensor_range
    forward_ray.force_raycast_update()  # Update immediately after turning.
    obstacle_ahead = forward_ray.is_colliding()

    var beam_tip := forward_ray.target_position
    if obstacle_ahead:
        # RayCast2D returns a WORLD point. Convert it to PLAYER coordinates.
        beam_tip = to_local(forward_ray.get_collision_point())
    sensor_beam.update_beam(beam_tip, obstacle_ahead)

# Choose a sprite animation name such as walk_left or idle_down.
# Only switch animation if it changed so it doesn't restart every frame.
func _play_animation(movement: Vector2) -> void:
    var facing := "down"
    if last_direction == Vector2.UP:
        facing = "up"
    elif last_direction == Vector2.LEFT:
        facing = "left"
    elif last_direction == Vector2.RIGHT:
        facing = "right"

    var action := "walk_" if movement.length() > 0.01 else "idle_"
    if sprite.animation != action + facing:
        sprite.play(action + facing)

# Called by a battery. The mission controller owns the actual cooldown,
# so we forward the message instead of giving Player its own second Timer.
func recharge_radar() -> void:
    get_node("../../MissionController").recharge_radar()
