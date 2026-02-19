class_name Enemy

class EnemyData:
	var texture: Texture2D

	func _init(texture: Texture2D):
		self.texture = texture

	func run() -> void:
		pass

var position: Vector2
var data: EnemyData

func _init(position: Vector2, enemy_data: EnemyData):
	self.position = position
	data = enemy_data
