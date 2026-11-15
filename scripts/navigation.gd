extends Node

# NAVIGATION — a simple GPS shared by all security drones.
# Each warehouse wall occupies a tile on an invisible grid. We tell AStarGrid2D
# which tiles are blocked, and Godot finds a route through the free tiles.
# This is called PATHFINDING. The algorithm compares possible routes and
# favors the cheapest available path instead of moving straight through walls.
# TRY IT: Turn diagonal_mode on (with care around corners) to see new routes.

class_name WarehouseNavigation
## A tiny GPS for our security drones.
##
## The walls are 32-pixel blocks. We turn those blocks into a grid of
## walkable squares, then ask Godot's AStarGrid2D to find a route.
## Students do NOT need to edit this during the workshop.

const TILE_SIZE := 32
const FIRST_TILE := Vector2(48, 48)
const COLUMNS := 34
const ROWS := 20

var routes := AStarGrid2D.new()

# Build the invisible navigation map when the mission starts.
# region says which tile coordinates exist. cell_size is 32 pixels per tile.
# update() creates AStarGrid2D's internal graph; do this BEFORE blocking cells.
# Then each wall is converted from its world position to a tile and marked
# solid, meaning A* must route around it. Diagonals are off to avoid cutting
# through the corners of wall tiles.
func build_map(wall_parent: Node2D) -> void:
    # Set up the same 32 x 32 grid used by the visible warehouse walls.
    routes.region = Rect2i(0, 0, COLUMNS, ROWS)
    routes.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
    # No diagonal shortcuts: moving across a blocked corner would look wrong.
    routes.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    routes.update()

    # Each physical wall becomes a blocked square on the navigation map.
    # Every wall instance becomes one impassable tile in the A* grid.
    for wall in wall_parent.get_children():
        var tile := world_to_tile(wall.global_position)
        if routes.is_in_boundsv(tile):
            routes.set_point_solid(tile)

# Convert a pixel position (like 112, 80) to a grid address (2, 1).
# Subtract FIRST_TILE to measure from the top-left tile center, divide by
# TILE_SIZE, and round to the nearest tile. clampi() keeps coordinates inside
# the grid so a drone can never request a cell outside the map.
func world_to_tile(world_position: Vector2) -> Vector2i:
    var column := roundi((world_position.x - FIRST_TILE.x) / TILE_SIZE)
    var row := roundi((world_position.y - FIRST_TILE.y) / TILE_SIZE)
    return Vector2i(clampi(column, 0, COLUMNS - 1), clampi(row, 0, ROWS - 1))

# Reverse the conversion above: turn a grid address into the center of
# that tile in game-world pixels. Drones walk toward these pixel positions.
func tile_to_world(tile: Vector2i) -> Vector2:
    return FIRST_TILE + Vector2(tile) * TILE_SIZE

# Ask Godot's A* pathfinder for the cells between start and goal.
# Because a target might stand on/near a blocked cell, first choose nearby
# open cells. get_id_path() returns a list of tile coordinates. We translate
# each tile back to a world position to create a trail of waypoints for drones.
# An empty path means no valid route was found.
func find_route(start: Vector2, goal: Vector2) -> PackedVector2Array:
    # We calculate a path only when the drone needs one, not every frame.
    var first := nearest_open_tile(world_to_tile(start))
    var last := nearest_open_tile(world_to_tile(goal))
    if first == Vector2i(-1, -1) or last == Vector2i(-1, -1):
        return PackedVector2Array()

    # A* returns grid coordinates for the route from one cell to another.
    var cells := routes.get_id_path(first, last)
    var result := PackedVector2Array()
    for cell in cells:
        result.append(tile_to_world(cell))
    return result

# Choose an unblocked cell close to a possibly blocked target tile.
# Start at radius 1, then search a larger square of surrounding candidates.
# This is a simple neighborhood search, not another A* search: it's only used
# to select a valid beginning/end tile. The first free tile found is returned.
# Vector2i(-1, -1) is a special 'not found' result.
func nearest_open_tile(tile: Vector2i) -> Vector2i:
    # Usually the chosen cell is free. If an object is close to a wall,
    # choose the closest open cell rather than giving up on navigation.
    if not routes.is_point_solid(tile):
        return tile
    # Look outward up to three tiles if the target happens to be blocked.
    for radius in range(1, 4):
        for x in range(-radius, radius + 1):
            for y in range(-radius, radius + 1):
                var option := tile + Vector2i(x, y)
                if routes.is_in_boundsv(option) and not routes.is_point_solid(option):
                    return option
    return Vector2i(-1, -1)
