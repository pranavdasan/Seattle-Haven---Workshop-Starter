extends Node2D

# RADAR — draws an expanding ring and reports what its wave reaches.
# A Tween changes a number gradually over time (here: the radar's radius).
# Every time that number changes, we redraw the ring and call back into
# the MissionController so it can reveal walls and other targets.
# TRY IT: Change pulse_duration to see the scan speed change.

class_name RadarPulse
## An expanding circular radar wave. The drawing is prepared for students.
## Students complete the Tween in start_scan() for Challenge 2.

@export var max_radius: float = 240.0
@export var pulse_duration: float = 0.5

var radius := 0.0
var scanning := false
var tween: Tween
var on_radius_changed: Callable

# Called when the player presses Space and the cooldown is ready.
# Remember the supplied reveal_function callback. This is a Callable:
# a function we can call later without knowing which object owns it.
# tween_method() gradually changes a NUMBER from 0 to max_radius, invoking
# _grow() at each step. tween_callback() runs _finish() after the animation.
# STARTER: students change the placeholder wait into this Tween.
func start_scan(reveal_function: Callable) -> void:
    if scanning:
        return

    on_radius_changed = reveal_function
    radius = 0.0
    scanning = true
    queue_redraw()

    # CHALLENGE 2: Animate the radius from zero to maximum.
    tween = create_tween()
    tween.tween_interval(pulse_duration)  # TODO 2: Replace with tween_method(_grow, ...)
    tween.tween_callback(_finish)

# The Tween calls this with the new radius on every animation step.
# Redraw the ring AND ask the mission to reveal anything the wave reaches.
# This connects a visual effect to real game logic.
func _grow(new_radius: float) -> void:
    radius = new_radius
    queue_redraw()  # Ask Godot to redraw the circle on screen.
    if on_radius_changed.is_valid():
        on_radius_changed.call(radius)  # Reveal walls reached by the pulse.

# Clear the animated circle when the pulse finishes so it can be reused.
func _finish() -> void:
    scanning = false
    radius = 0.0
    queue_redraw()

# Godot calls this when queue_redraw() requests a refresh.
# Draw two circular arcs: a bright outer ring and a faint inner echo.
# TAU is a full turn (2*pi radians); 96 makes the circle look smooth.
func _draw() -> void:
    # Godot calls _draw whenever queue_redraw() runs.
    if not scanning:
        return
    draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(0.16, 0.94, 1.0, 0.95), 3.0)
    if radius > 20.0:
        draw_arc(Vector2.ZERO, radius * 0.8, 0.0, TAU, 96, Color(0.1, 0.73, 0.91, 0.35), 1.0)
