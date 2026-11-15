extends Area2D

# CHARGING STATION — the exit gate at the end of a rescue mission.
# Scanning can reveal it. Once all helpers are rescued it becomes active.
# Touching it emits a signal; the MissionController decides if you can win.

class_name ChargingStation
## The exit platform: it activates once all three helpers are rescued.
signal player_arrived

@onready var art: Sprite2D = $Sprite2D
var discovered := false
var active := false

# Start hidden until the player scans/discovers the exit.
# Connect the overlap signal so the controller can decide if the mission ends.
func _ready() -> void:
    visible = false
    body_entered.connect(_on_body_entered)

# The radar has revealed the exit, so show it with a translucent sprite.
# discovered prevents repeated re-initialization from multiple scans.
func discover() -> void:
    if discovered:
        return
    discovered = true
    visible = true
    art.modulate = Color(0.75, 0.85, 1.0, 0.65)

# All rescues are complete; show the charger at full brightness.
func activate() -> void:
    active = true
    visible = true
    art.modulate = Color.WHITE

# Signal that the player touched the exit. A signal tells the controller
# what happened without making the charger responsible for score rules.
func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        player_arrived.emit()
