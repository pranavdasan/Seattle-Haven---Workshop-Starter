extends Area2D

# BATTERY PICKUP — an example of event-driven programming.
# Area2D detects when a physics body enters the pickup area.
# The body_entered signal calls our function; we check whether it's the player.
# The starter project leaves the final pickup action for students to code.

class_name RadarBattery
## Battery pickup: touching it refills the radar cooldown.
## The scene already contains the artwork and collision shape.

# Connect a built-in signal to a function.
# Godot automatically calls _on_body_entered when something overlaps us.
func _ready() -> void:
    # Area2D sends body_entered whenever the player touches the battery.
    body_entered.connect(_on_body_entered)

# Only the Player (identified by its group name) may collect the battery.
# recharge_radar() resets the cooldown. queue_free() removes this pickup
# AFTER the current frame, avoiding changes during a physics callback.
# STARTER: the two actions are left as a TODO for students.
func _on_body_entered(body: Node2D) -> void:
    # CHALLENGE 3: Only the player can pick up the battery.
    if body.is_in_group("player"):
        pass  # TODO 3: body.recharge_radar() and queue_free()
