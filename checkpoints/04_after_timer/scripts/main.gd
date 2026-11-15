extends Node

# MISSION CONTROLLER — the referee for our rescue game.
# All characters, walls, sensors and HUD pieces are real nodes in the scene.
# This script connects their signals, keeps score, and applies game rules.
# It doesn't draw the world or create characters: those belong to other scenes.
# STARTER PROJECT: the TODO blocks are for students to code themselves.

## Mission coordinator. All the visual objects are REAL nodes in main.tscn.
## This script connects them and keeps track of the rescue mission.
## Workshop exercise 4 lives near the bottom in _update_hud().

@export var mission_seconds: float = 150.0
@export var radar_cooldown: float = 5.0
@export var drone_alert_range: float = 365.0
@export var capture_penalty_seconds: float = 12.0

@onready var player: RescuePlayer = $"../Actors/Player"
@onready var walls: Node2D = $"../World/Walls"
@onready var nav_grid: WarehouseNavigation = $"../World/NavigationGrid"
@onready var rescue_targets: Node2D = $"../Actors/RescueTargets"
@onready var drones_parent: Node2D = $"../Actors/Drones"
@onready var charger: ChargingStation = $"../Actors/ChargingStation"
@onready var fog: WarehouseFog = $"../FogOfWar"
@onready var hud: MissionHUD = $"../HUD"
@onready var mission_timer: Timer = $MissionTimer
@onready var cooldown: Timer = $RadarCooldown

var helpers: Array[RescueHelper] = []
var drones: Array[SecurityDrone] = []
var rescues := 0
var catches := 0
var scans := 0
var game_over := false
var respawn_protection := 0.0
var message_time := 0.0
var spawn_point := Vector2.ZERO

# Run once as the mission enters the scene tree.
# Set up the timer durations, connect events (signals), choose helper robots,
# and give each drone the shared navigation map.
# IMPORTANT HUD FIX: MissionController and HUD are sibling nodes. The HUD
# might not have initialized its @onready Labels when this function runs.
# call_deferred("_update_hud") safely waits for scene initialization.
func _ready() -> void:
    RenderingServer.set_default_clear_color(Color("101e31"))
    spawn_point = player.global_position

    # Connect the visible scene objects to our game logic.
    fog.tracked_player = player
    mission_timer.wait_time = mission_seconds
    cooldown.wait_time = radar_cooldown
    mission_timer.timeout.connect(_on_mission_timeout)
    charger.player_arrived.connect(_on_charger_arrived)

    _choose_rescue_robots()
    _set_up_drones()
    mission_timer.start()
    # HUD is another sibling, so wait until all Labels are ready.
    call_deferred("_update_hud")

# The level contains six possible helper positions, but only three spawn.
# shuffle() changes their order so rescues feel different on each playthrough.
# The first three become active; unused helpers are removed via queue_free().
# Each active helper's rescued signal tells us when it was collected.
func _choose_rescue_robots() -> void:
    # We have six possible locations, but only three robots per mission.
    var candidates := rescue_targets.get_children()
    candidates.shuffle()
    for index in range(candidates.size()):
        var helper: RescueHelper = candidates[index]
        if index < 3:
            helpers.append(helper)
            helper.rescued.connect(_on_helper_rescued)
        else:
            helper.queue_free()

# Build the navigation grid ONCE using all the visible wall nodes.
# Then share this map with each drone. This avoids building identical maps
# inside every drone scene.
func _set_up_drones() -> void:
    # One navigation map is shared by both drones.
    nav_grid.build_map(walls)
    for node in drones_parent.get_children():
        var drone: SecurityDrone = node
        drones.append(drone)
        drone.set_up(nav_grid, player)

# Run each rendered frame: handle restart/scan input, advance small timers,
# check whether a drone touched the player, and update the HUD numbers.
# delta is the number of seconds since the previous frame, so subtracting
# delta makes temporary protections last the same time across frame rates.
func _process(delta: float) -> void:
    if Input.is_action_just_pressed("restart"):
        get_tree().reload_current_scene()
        return
    if game_over:
        return

    respawn_protection = maxf(0.0, respawn_protection - delta)
    message_time = maxf(0.0, message_time - delta)
    if message_time <= 0.0 and rescues < 3:
        hud.show_message("RESCUE 3 ROBOTS • STAY HIDDEN • SPACE: RADAR • R: RESTART")

    if Input.is_action_just_pressed("radar"):
        _try_scan()

    if respawn_protection <= 0.0:
        _check_drone_contact()

    _update_hud()

# Start a radar pulse ONLY if the cooldown Timer has finished.
# Tell fog.gd to create a new brightening event, then let radar.gd animate.
# Nearby drones react to the pulse: information has a gameplay cost.
# STARTER: this function is a hands-on challenge; keep its TODOs intact.
func _try_scan() -> void:
    # Only scan if the radar has recharged.
    if not cooldown.is_stopped():
        return
    cooldown.start()
    scans += 1

    fog.pulse_at(player.global_position)
    player.radar.start_scan(_reveal_nearby_objects)

    # Scanning is useful but risky: nearby drones hear the pulse.
    for drone in drones:
        if drone.global_position.distance_to(player.global_position) < drone_alert_range:
            drone.investigate(player.global_position)
            _show_temporary_message("ALERT! A DRONE HEARD YOUR RADAR")

# Called repeatedly by the radar Tween with the current scan radius.
# To light a wall, we find the closest point of its 32x32 square to the robot.
# clampf(..., -16, 16) picks the nearest location inside its half-width.
# The distance from that point to the robot tells us whether the expanding
# radar circle has reached the wall, even if its CENTER is still far away.
# Helpers and charger use simpler center-distance checks plus small margins.
func _reveal_nearby_objects(radius: float) -> void:
    # This method is called repeatedly as the radar ring grows outward.
    fog.advance_pulse(radius)
    var origin := player.global_position

    for wall in walls.get_children():
        # Find the closest point on each 32-pixel-wide wall block.
        var relative: Vector2 = origin - wall.global_position
        var nearest := Vector2(clampf(relative.x, -16, 16), clampf(relative.y, -16, 16))
        if (relative - nearest).length() <= radius:
            wall.reveal()

    for helper in helpers:
        if is_instance_valid(helper) and origin.distance_to(helper.global_position) <= radius + 15:
            helper.reveal()

    if origin.distance_to(charger.global_position) <= radius + 34:
        charger.discover()

# Touch detection for drones uses distance instead of an Area2D trigger.
# If the center points are closer than 25 pixels, the player is caught.
func _check_drone_contact() -> void:
    for drone in drones:
        if drone.global_position.distance_to(player.global_position) < 25.0:
            _caught_by_drone()
            return

# Reset the player to the starting point and subtract time as a penalty.
# Give a short protection window so the drone can't immediately catch us
# again on the next frame. Tell drones to return to normal patrol behavior.
func _caught_by_drone() -> void:
    catches += 1
    respawn_protection = 2.2
    player.global_position = spawn_point

    # A caught player loses time, not a life.
    var remaining := mission_timer.time_left - capture_penalty_seconds
    if remaining <= 0.0:
        _on_mission_timeout()
        return
    mission_timer.start(remaining)

    for drone in drones:
        drone.forget_alert()
    _show_temporary_message("CAUGHT! -12 SECONDS • BACK TO BASE")

# The battery tells the Player to recharge, and the Player forwards it here.
# Stopping the cooldown Timer means the next scan is immediately available.
func recharge_radar() -> void:
    # Battery pickup calls this through the player's recharge_radar method.
    cooldown.stop()
    _update_hud()

# A RescueHelper emits this signal when the player touches it.
# Update the count, remove it from the remaining helper list, and unlock
# the charging station once all three are rescued.
func _on_helper_rescued(helper: RescueHelper) -> void:
    if game_over:
        return
    rescues += 1
    helpers.erase(helper)
    if rescues == 3:
        charger.activate()
        hud.show_message("ALL ROBOTS RESCUED! REACH THE CHARGER!")
        message_time = 999.0
    _update_hud()

# The charger signals when the player touches it. Win only after 3 rescues.
# Compute time used and a simple rank: no catches is better, and using
# fewer scans plus finishing quickly earns the best rank.
func _on_charger_arrived() -> void:
    if game_over:
        return
    if rescues < 3:
        _show_temporary_message("RESCUE ALL 3 ROBOTS FIRST")
        return

    game_over = true
    var time_used := mission_seconds - mission_timer.time_left
    mission_timer.stop()
    var grade := "B"
    if catches == 0:
        grade = "A"
        if scans <= 9 and time_used <= 100:
            grade = "S"
    hud.show_message("MISSION COMPLETE! RANK %s | %.0fs | CAUGHT %d | SCANS %d | R: REPLAY" % [grade, time_used, catches, scans])

# The mission Timer emits timeout when its countdown hits zero.
# Stop gameplay, freeze the timer, and show the failure message.
func _on_mission_timeout() -> void:
    if game_over:
        return
    game_over = true
    mission_timer.stop()
    hud.show_message("MISSION FAILED — TIME'S UP! PRESS R TO RESTART")
    _update_hud()

# Show an alert for two seconds, then let _process restore the hint text.
func _show_temporary_message(message: String) -> void:
    hud.show_message(message)
    message_time = 2.0

# Gather the latest status and hand it to hud.gd for display.
# This function only supplies information; the HUD script handles labels.
# ceil() rounds UP so 0.4 seconds remaining displays as 1 rather than 0.
# STARTER: the timer read is a student coding challenge.
func _update_hud() -> void:
    var radar_status := "READY"
    if not cooldown.is_stopped():
        radar_status = "%.1fs" % cooldown.time_left

    # CHALLENGE 4: Read the real mission timer for the HUD.
    var seconds_left := int(ceil(mission_timer.time_left))
    hud.display_status(rescues, radar_status, seconds_left, player.obstacle_ahead, catches)
