extends RefCounted

const Map = preload("res://scripts/map.gd")
const MapGenerator = preload("res://scripts/map_generator.gd")

var astar = AStarGrid2D.new()

func _init(map: Map):
	astar.region = Rect2i(0, 0, map.width, map.height)
	astar.cell_size = Vector2(1,1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	
	astar.update()
	
	# Mark walls as solid
	for y in map.height:
		for x in map.width:
			var tile = map.get_tile(Vector2(x, y))
			if MapGenerator.is_wall(tile):
				astar.set_point_solid(Vector2i(x,y), true)

func get_path(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var start = Vector2i(start_pos)
	var end = Vector2i(end_pos)
	return astar.get_point_path(start, end)
