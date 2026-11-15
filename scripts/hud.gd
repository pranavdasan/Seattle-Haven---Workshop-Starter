extends CanvasLayer

# HUD (Heads-Up Display) — information that stays on screen.
# This script receives game values and writes them into existing Label nodes.
# It should not decide who wins; the MissionController handles game rules.
# @onready means Godot finds child Labels AFTER this node enters the scene.
# The MissionController defers its first HUD update until these are ready.

class_name MissionHUD
## Heads-Up Display (HUD): screen information that stays in place.
## The mission controller gives us values; the HUD simply shows them.

@onready var status: Label = $Status
@onready var message_label: Label = $Message
@onready var sensor_label: Label = $SensorPanel/SensorText

# Display live values sent from the mission controller.
# The %d placeholders format integer counts; %03d pads time with zeros.
# The sensor warning uses a conditional expression to choose text and color.
# HUD Labels are found by @onready; the first caller must wait until ready.
func display_status(rescued: int, radar: String, seconds: int, blocked: bool, caught: int) -> void:
    status.text = "NRG 948 | RESCUE %d/3 | RADAR %s | TIME %03d | CAUGHT %d" % [rescued, radar, seconds, caught]
    sensor_label.text = "FORWARD SENSOR: WALL AHEAD" if blocked else "FORWARD SENSOR: PATH CLEAR"
    sensor_label.add_theme_color_override("font_color", Color("ff7388") if blocked else Color("6ef8cd"))

# Show a temporary mission hint or a win/lose message at screen bottom.
func show_message(message: String) -> void:
    message_label.text = message
