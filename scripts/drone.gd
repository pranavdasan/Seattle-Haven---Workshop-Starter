extends CharacterBody2D

# DRONE AI — three small behaviors, rather than one complicated brain.
# PATROL: travel between two points. INVESTIGATE: check where radar sounded.
# CHASE: move toward a player who is close enough and visible.
# The NavigationGrid gives the drone waypoints around walls. The drone simply
# moves to the next waypoint. This is a great pattern for enemy AI in any maze.

class_name SecurityDrone
## A security drone that follows paths around walls.
##
## State 1 — PATROL: follow the route between two inspection points.
## State 2 — INVESTIGATE: visit the location of a radar pulse.
## State 3 — CHASE: pursue a player that is close AND visible.
##
## The pathfinding is provided by the NavigationGrid node in main.tscn.
## This is intentionally simple AI; there are no behavior trees or complex math.

@export var patrol_speed: float = 88.0
@export var chase_speed: float = 125.0
@export var sight_distance: float = 125.0
@export var investigation_seconds: float = 5.0
@export var patrol_offset: Vector2 = Vector2(100, 0)

const ROUTE_REFRESH := 0.35
const WAYPOINT_DISTANCE := 7.0

@onready var sight_ray: RayCast2D = $SightRay

var player: RescuePlayer
var navigation: WarehouseNavigation
var patrol_start := Vector2.ZERO
var patrol_end := Vector2.ZERO
var going_to_end := true
var alert_location := Vector2.ZERO
var alert_time_left := 0.0
var route := PackedVector2Array()
var next_waypoint := 0
var route_timer := 0.0

# The MissionController gives this drone its shared pathfinder and player.
# Save the starting point for patrol and calculate the second patrol point.
func set_up(map: WarehouseNavigation, target_player: RescuePlayer) -> void:
    navigation = map
    player = target_player
    patrol_start = global_position
    patrol_end = patrol_start + patrol_offset
    route_timer = 0.0

# Physics frames are where movement happens.
# Priority order: can see the player -> CHASE; heard radar recently ->
# INVESTIGATE; otherwise -> PATROL. This is a simple state machine expressed
# with if/elif/else instead of a separate class for each state.
# We refresh the A* route periodically, not every frame, to save CPU.
func _physics_process(delta: float) -> void:
    if navigation == null or not is_instance_valid(player):
        return

    # Decide where to go: chase has priority, then investigate, then patrol.
    var destination := patrol_end if going_to_end else patrol_start
    var movement_speed := patrol_speed
    var can_see_player := _can_see_player()

    if can_see_player:
        destination = player.global_position
        movement_speed = chase_speed
        alert_location = destination
        alert_time_left = investigation_seconds
    # No sight of player, but a recent noise still deserves investigation.
    elif alert_time_left > 0.0:
        alert_time_left = maxf(0.0, alert_time_left - delta)
        destination = alert_location
        movement_speed = chase_speed
    elif global_position.distance_to(destination) < 18.0:
        going_to_end = not going_to_end
        destination = patrol_end if going_to_end else patrol_start

    # Ask for a new path a few times a second, not on every physics tick.
    # Reuse the current route between refreshes instead of running A* 60x/sec.
    route_timer -= delta
    if route_timer <= 0.0:
        route = navigation.find_route(global_position, destination)
        next_waypoint = 0
        route_timer = ROUTE_REFRESH

    _follow_route(movement_speed)
    queue_redraw()

# First check distance: faraway players are never seen.
# Then aim SightRay toward the player and ask whether it hit a wall.
# If it hits a wall, line of sight is blocked. (This assumes the ray's
# collision mask checks walls and not the target player itself.)
func _can_see_player() -> bool:
    if global_position.distance_to(player.global_position) > sight_distance:
        return false
    # A wall between the two robots blocks the drone's view.
    sight_ray.target_position = to_local(player.global_position)
    sight_ray.force_raycast_update()
    return not sight_ray.is_colliding()

# A route is an ordered list of world positions (waypoints).
# Skip a waypoint when we're within WAYPOINT_DISTANCE of it. If there are no
# more waypoints, stop. Otherwise point the velocity at the next one.
# move_and_slide() handles the physical collision so a drone can't walk
# through a wall even if a waypoint is imperfect.
func _follow_route(movement_speed: float) -> void:
    # Skip waypoints that we have already reached.
    # Advance through the breadcrumb trail as the drone reaches each tile.
    while next_waypoint < route.size():
        if global_position.distance_to(route[next_waypoint]) > WAYPOINT_DISTANCE:
            break
        next_waypoint += 1

    if next_waypoint >= route.size():
        velocity = Vector2.ZERO
    else:
        var destination := route[next_waypoint]
        velocity = global_position.direction_to(destination) * movement_speed

    # CharacterBody2D collision still prevents accidentally crossing walls.
    move_and_slide()

# Radar pulses call this to give the drone a temporary destination.
# Clearing route_timer forces pathfinding to update on the next physics tick.
func investigate(where: Vector2) -> void:
    # The player's radar is noisy. Drones hear it and move to its location.
    alert_location = where
    alert_time_left = investigation_seconds
    route_timer = 0.0

# Used after the player is caught. End the current investigation
# and recalculate the next patrol route instead.
func forget_alert() -> void:
    alert_time_left = 0.0
    route_timer = 0.0

# Draw a small red status ring around the drone.
# Its alpha (transparency) is lower when calm and higher when alert.
func _draw() -> void:
    # A small ring makes alerted drones easier to recognize.
    var ring_color := Color(1.0, 0.25, 0.35, 0.8)
    if alert_time_left <= 0.0:
        ring_color.a = 0.35
    draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 36, ring_color, 2.0)
