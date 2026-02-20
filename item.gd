class_name Item

signal was_collected(item)

var collected = false
var position
var type

const ItemType = preload("res://item_type.gd")

func _init(position: Vector2, type: ItemType.ItemType) -> void:
	self.position = position
	self.type = type

func get_name() -> String:
	return ItemType.item_descriptions[type].name

func collect():
	collected = true
	was_collected.emit(self)
