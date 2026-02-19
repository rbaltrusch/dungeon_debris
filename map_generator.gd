class_name HybridDungeonGenerator

enum Tile {
	EMPTY = 0,
	WALL = 1,
	DOOR = 2,
}

const loop_chance = 0.08
var rng := RandomNumberGenerator.new()
var NULL_ROOM := Rect2i(0, 0, 0, 0)

func generate(width: int, height: int) -> Array:
	var room_attempts = round(Vector2(width, height).length())
	rng.randomize()

	if width % 2 == 0:
		width += 1
	if height % 2 == 0:
		height += 1

	var map := _create_filled_map(width, height)

	# -------------------------------------------------
	# 1. Enforce spawn corner FIRST
	# -------------------------------------------------
	# Required:
	# 11
	# 10
	map[0][0] = Tile.WALL
	map[0][1] = Tile.WALL
	map[1][0] = Tile.WALL
	map[1][1] = Tile.EMPTY

	# -------------------------------------------------
	# 2. Carve maze from spawn
	# -------------------------------------------------
	_carve_maze(Vector2i(1, 1), map, width, height)

	# -------------------------------------------------
	# 3. Add rooms (carved into walls only)
	# -------------------------------------------------
	var rooms = []
	for i in range(room_attempts):
		var room = _try_place_room(map, width, height)
		if room != NULL_ROOM:
			rooms.append(room)

	# -------------------------------------------------
	# 4. Connect rooms to existing corridors
	# -------------------------------------------------
	for room in rooms:
		_connect_room_to_corridor(room, map)

	# -------------------------------------------------
	# 5. Add loops
	# -------------------------------------------------
	_add_loops(map, width, height, loop_chance)

	# -------------------------------------------------
	# 6. Add doors
	# -------------------------------------------------
	_add_doors(map, width, height)

	return map


# -------------------------------------------------
# Base Maze
# -------------------------------------------------

func _carve_maze(pos: Vector2i, map: Array, w: int, h: int) -> void:
	map[pos.y][pos.x] = Tile.EMPTY

	var directions = [
		Vector2i(0, -2),
		Vector2i(0, 2),
		Vector2i(-2, 0),
		Vector2i(2, 0)
	]
	directions.shuffle()

	for dir in directions:
		var next = pos + dir
		if _in_bounds(next, w, h) and map[next.y][next.x] == Tile.WALL:
			map[pos.y + dir.y / 2][pos.x + dir.x / 2] = Tile.EMPTY
			_carve_maze(next, map, w, h)


# -------------------------------------------------
# Rooms
# -------------------------------------------------

func _try_place_room(map: Array, w: int, h: int) -> Rect2i:
	var rw = rng.randi_range(3, 7)
	var rh = rng.randi_range(3, 7)

	if rw % 2 == 0: rw += 1
	if rh % 2 == 0: rh += 1

	var rx = rng.randi_range(1, w - rw - 2)
	var ry = rng.randi_range(1, h - rh - 2)

	var rect = Rect2i(rx, ry, rw, rh)

	# Check overlap
	for y in range(rect.position.y - 1, rect.end.y + 1):
		for x in range(rect.position.x - 1, rect.end.x + 1):
			if map[y][x] == Tile.EMPTY:
				return NULL_ROOM

	# Carve room
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			map[y][x] = Tile.EMPTY

	return rect


func _connect_room_to_corridor(room: Rect2i, map: Array) -> void:
	var possible_connections = []

	for x in range(room.position.x, room.end.x):
		possible_connections.append(Vector2i(x, room.position.y - 1))
		possible_connections.append(Vector2i(x, room.end.y))

	for y in range(room.position.y, room.end.y):
		possible_connections.append(Vector2i(room.position.x - 1, y))
		possible_connections.append(Vector2i(room.end.x, y))

	possible_connections.shuffle()

	for pos in possible_connections:
		if map[pos.y][pos.x] == Tile.WALL:
			map[pos.y][pos.x] = Tile.EMPTY
			return


# -------------------------------------------------
# Loops
# -------------------------------------------------

func _add_loops(map: Array, w: int, h: int, chance: float) -> void:
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if map[y][x] == Tile.WALL:
				if rng.randf() < chance:
					var open_neighbors = 0
					for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
						var n = Vector2i(x, y) + dir
						if map[n.y][n.x] == Tile.EMPTY:
							open_neighbors += 1
					if open_neighbors >= 2:
						map[y][x] = Tile.EMPTY


# -------------------------------------------------
# Doors
# -------------------------------------------------

func _add_doors(map: Array, w: int, h: int) -> void:
	var exit_count = clamp((w * h) / 400, 1, 4)

	for i in range(exit_count):
		var side = rng.randi_range(0, 3)

		match side:
			0: # top
				var x = rng.randi_range(1, w - 2)
				map[0][x] = Tile.DOOR
			1: # bottom
				var x = rng.randi_range(1, w - 2)
				map[h - 1][x] = Tile.DOOR
			2: # left
				var y = rng.randi_range(1, h - 2)
				map[y][0] = Tile.DOOR
			3: # right
				var y = rng.randi_range(1, h - 2)
				map[y][w - 1] = Tile.DOOR


# -------------------------------------------------

func _create_filled_map(w: int, h: int) -> Array:
	var map := []
	for y in range(h):
		var row := []
		for x in range(w):
			row.append(Tile.WALL)
		map.append(row)
	return map


func _in_bounds(pos: Vector2i, w: int, h: int) -> bool:
	return pos.x > 0 and pos.x < w - 1 and pos.y > 0 and pos.y < h - 1
