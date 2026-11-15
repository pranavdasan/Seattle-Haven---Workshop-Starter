extends StaticBody2D

# WALL BLOCK — a solid physics wall with a glowing scan effect.
# StaticBody2D + CollisionShape2D keeps the robot from walking through.
# Sprite2D can be nearly invisible without disabling that collision.
# A Tween fades the wall after a scan, leaving a faint visual memory.

class_name RadarWall
## A solid wall whose sprite glows when the radar reaches it.
## Even when nearly invisible, the CollisionShape2D still blocks movement.

@export_range(0.0, 1.0) var idle_alpha := 0.02
@export_range(0.0, 1.0) var after_scan_alpha := 0.06
@export var glow_seconds := 2.5

@onready var wall_art: Sprite2D = $Sprite2D
var fade: Tween

# Set the initial sprite transparency. The collision body stays solid.
func _ready() -> void:
    wall_art.modulate = Color(0.75, 0.88, 1.0, idle_alpha)

# Make a scanned wall shine bright, then fade it to its memory outline.
# If a second scan arrives while a fade is running, kill the old Tween first
# so two animations don't fight over the same modulate property.
# tween_interval() holds the glow; tween_property() fades it afterward.
func reveal() -> void:
    # Stop the previous fade if this wall is scanned again.
    if fade != null and fade.is_running():
        fade.kill()
    wall_art.modulate = Color(0.55, 1.0, 1.0, 1.0)
    fade = create_tween()
    # Hold a bright wall for a moment before fading back to a faint hint.
    fade.tween_interval(glow_seconds)
    fade.tween_property(wall_art, "modulate", Color(0.75, 0.88, 1.0, after_scan_alpha), 0.7)
