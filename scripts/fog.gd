extends Node2D

# FOG OF WAR — the dark layer over the warehouse.
# Think of a transparent sheet placed over the whole level. We draw darker
# or lighter small squares on this sheet to control what the player sees.
# The actual maze and collision shapes never disappear: only visibility changes.
# TRY IT: Increase vision_radius to give the robot a bigger flashlight.
# TRY IT: Decrease memory_opacity to make previously scanned areas easier to see.

class_name WarehouseFog
## Dark overlay for the warehouse. Instructor-provided; no workshop edits.
## A small circle stays visible around the robot, and scans light up the map.

@export var vision_radius: float = 72.0
@export var memory_opacity: float = 0.94
@export var dark_opacity: float = 0.985
@export var scan_persist_seconds: float = 2.5

const CELL := 16
const MAP_WIDTH := 1152
const MAP_HEIGHT := 704

var tracked_player: Node2D
var active_scans: Array[Dictionary] = []
var explored: Dictionary = {}

# Called once per frame. Drop scan lights whose expiration time has passed.
# Time.get_ticks_msec() is elapsed real time, so a scan lasts the same length
# even when the game renders more or fewer frames. queue_redraw() asks Godot
# to call _draw() again using the latest visibility values.
func _process(_delta: float) -> void:
    # Remove old radar lights after a short delay.
    var current_time := Time.get_ticks_msec() / 1000.0
    # filter() keeps only entries where the condition is true: unexpired scans.
    active_scans = active_scans.filter(func(scan): return scan["until"] > current_time)
    queue_redraw()

# Begin a radar scan centered at position.
# The Dictionary stores where the scan started, its current radius, and when
# the temporary brightening should expire. Scans are kept in an array so
# multiple recent pulses can overlap without deleting each other.
func pulse_at(position: Vector2) -> void:
    active_scans.append({
        "position": position,
        "radius": 0.0,
        "until": Time.get_ticks_msec() / 1000.0 + scan_persist_seconds
    })

# The Tween in radar.gd calls this repeatedly as its circle expands.
# We update the newest pulse radius, then visit each 16-pixel grid square.
# If the CENTER of a square is inside the new circle, mark that square as
# explored. Explored squares remain in memory even after the bright pulse fades.
# distance_to() uses the straight-line distance between two points.
func advance_pulse(new_radius: float) -> void:
    if active_scans.is_empty():
        return
    var latest := active_scans.size() - 1
    active_scans[latest]["radius"] = new_radius
    var center: Vector2 = active_scans[latest]["position"]
    # Nested loops cover each row/column of 16-pixel squares in the map.
    for y in range(int(MAP_HEIGHT / CELL) + 1):
        for x in range(int(MAP_WIDTH / CELL) + 1):
            var square := Vector2(x * CELL + CELL / 2, y * CELL + CELL / 2)
            if square.distance_to(center) <= new_radius:
                # Dictionary keys are grid addresses; true means seen before.
                explored[Vector2i(x, y)] = true

# Paint the darkness overlay one small rectangle at a time.
# First choose full darkness. If we scanned the square before, use the lighter
# memory opacity. Active scans brighten squares temporarily. Finally, the
# player's small nearby view wins and stays clear even without a scan.
# smoothstep() blends between near/clear and far/dark; this avoids a hard edge.
# Important: low alpha means MORE visible because the black overlay is thinner.
func _draw() -> void:
    if not is_instance_valid(tracked_player):
        return
    var player_position := tracked_player.global_position
    # Nested loops cover each row/column of 16-pixel squares in the map.
    for y in range(int(MAP_HEIGHT / CELL) + 1):
        for x in range(int(MAP_WIDTH / CELL) + 1):
            var point := Vector2(x * CELL + CELL / 2, y * CELL + CELL / 2)
            var darkness := dark_opacity
            # Old discoveries remain faintly visible after a pulse disappears.
            if explored.has(Vector2i(x, y)):
                darkness = memory_opacity

            # Radar lights up all squares inside the current scan ring.
            # Each recent pulse can temporarily make this cell nearly clear.
            for scan in active_scans:
                if point.distance_to(scan["position"]) <= scan["radius"]:
                    darkness = minf(darkness, 0.08)

            # Soft edge around the little circle of local vision.
            var distance := point.distance_to(player_position)
            if distance < vision_radius * 0.8:
                darkness = 0.0
            # Fade gently between clear center and the dark surroundings.
            elif distance < vision_radius * 1.2:
                darkness = minf(darkness, smoothstep(vision_radius * 0.8, vision_radius * 1.2, distance) * 0.98)

            draw_rect(Rect2(x * CELL, y * CELL, CELL + 1, CELL + 1), Color(0.012, 0.019, 0.047, darkness))
