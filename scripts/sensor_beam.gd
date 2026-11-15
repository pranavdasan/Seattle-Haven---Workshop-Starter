extends Node2D

# SENSOR BEAM — only the drawing for the robot's forward sensor.
# ForwardRay (RayCast2D) performs the real collision test.
# This script gets a beam endpoint and a true/false hit result, draws a line,
# and changes its color when it hits a wall. Detection and display are separate.

class_name ForwardSensorBeam
## Draws the light-blue line for our forward obstacle sensor.
## IMPORTANT: This is only a picture. ForwardRay does the real sensing.
## Put this node under Player so the beam moves with the robot.

@export var beam_color: Color = Color(0.20, 0.95, 1.0, 0.85)
@export var blocked_color: Color = Color(1.0, 0.32, 0.42, 0.95)

var end_point: Vector2 = Vector2(0, 80)
var has_hit: bool = false

# Receive an endpoint and blocked state from Player.
# Store the values and queue a redraw to show the new direction/color.
func update_beam(hit_position: Vector2, blocked: bool) -> void:
    end_point = hit_position
    has_hit = blocked
    queue_redraw()  # Tell Godot to call _draw() again.

# Draw from the robot's origin to the sensor's endpoint.
# The beam is cyan when clear and red when blocked. draw_circle adds a dot
# on the sensor tip so the player can see exactly where it ends.
func _draw() -> void:
    var line_color := blocked_color if has_hit else beam_color
    draw_line(Vector2.ZERO, end_point, line_color, 2.0, true)
    draw_circle(end_point, 4.0, line_color)
