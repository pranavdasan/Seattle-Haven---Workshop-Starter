extends Area2D

# RESCUE ROBOT — an Area2D collectible with its own custom signal.
# When the player touches a helper, we emit rescued(self).
# Other nodes can listen to that signal; the helper does not need to know
# how the score is drawn or how the charging station works.

class_name RescueHelper
## A small helper robot. Touch it to rescue it.
signal rescued(helper: RescueHelper)
var collected := false

# Register for overlap events; the Level doesn't need to poll every helper.
func _ready() -> void:
    body_entered.connect(_on_body_entered)

# Ignore repeat touches and non-player objects.
# Emit our custom rescued signal before removing the helper scene.
func _on_body_entered(body: Node2D) -> void:
    if collected or not body.is_in_group("player"):
        return
    collected = true
    rescued.emit(self)
    queue_free()

# When the expanding radar reaches a helper, make its sprite visible.
func reveal() -> void:
    modulate = Color.WHITE
