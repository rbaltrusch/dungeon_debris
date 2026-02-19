extends Node
class_name Map

var width
var height
var data
const OUT_OF_BOUNDS = -1

# Array[Array[int]]
func _init(map_data: Array):
	data = map_data
	height = data.size()
	width = map_data[0].size() if height else 0

func get_tile(position: Vector2) -> int:
	var x = position.x
	var y = position.y
	if x < 0 || y < 0 || x >= width || y >= height:
		return OUT_OF_BOUNDS
	return data[y][x]

func is_out_of_bounds(position: Vector2) -> bool:
	return get_tile(position) == OUT_OF_BOUNDS

func debug_print():
	for row in data:
		print(row)
