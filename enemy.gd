class_name Enemy

const Player = preload("res://player.gd")
const Map = preload("res://map.gd")
const TextureRenderer = preload("res://texture_renderer.gd")

class EnemyData:
	var texture: Texture2D

	func _init(texture: Texture2D):
		self.texture = texture

	# to be overridden
	func update(delta: float, enemy: Enemy, player: Player, map: Map) -> void:
		pass

	# to be overridden
	func render(renderer: TextureRenderer, enemy: Enemy):
		renderer.render(texture, enemy.position)

var visible: bool = true
var position: Vector2
var data: EnemyData

func _init(position: Vector2, enemy_data: EnemyData):
	self.position = position
	data = enemy_data

func hide():
	visible = false

func show():
	visible = true

func update(delta: float, player: Player, map: Map):
	data.update(delta, self, player, map)

func render(renderer: TextureRenderer):
	if not self.visible:
		return
	data.render(renderer, self)
