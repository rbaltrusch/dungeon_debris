var collected = false
var position
var type

const ItemType = preload("res://item_type.gd").ItemType

func _init(position: Vector2, type: ItemType) -> void:
	self.position = position
	self.type = type

func collect():
	collected = true
