class_name Enemy

const Player = preload("res://player.gd")
const Map = preload("res://map.gd")
const TextureRenderer = preload("res://texture_renderer.gd")
const DamageType = preload("res://damage_type.gd").DamageType

signal took_damage(damage)
signal died

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

var hp = 50
var block = 0
var armour = 0
var alive = true

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

func take_damage(damage: float, type: DamageType):
	var actual_damage = max(0, damage - armour)
	block = max(0, block - actual_damage)
	var remaining_damage = max(0, actual_damage - block)
	hp = max(0, hp - remaining_damage)
	print("enemy damaged. remaining hp: ", hp)
	if hp == 0:
		die()
	elif remaining_damage > 0:
		took_damage.emit(remaining_damage)

func die() -> void:
	if not alive:
		return
	alive = false
	died.emit()
	print("died")
