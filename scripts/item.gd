class_name Item

signal was_collected(item)
signal was_used(item)

var used = false
var collected = false
var position
var type
var use_fn: Callable

const ItemType = preload("res://scripts/item_type.gd")

func _init(position: Vector2, type: ItemType.ItemType, use_fn: Callable = func(item): null) -> void:
	self.position = position
	self.type = type
	self.use_fn = use_fn

func use() -> void:
	if used:
		return

	use_fn.call(self)
	used = true
	was_used.emit(self)

func get_item_name() -> String:
	return ItemType.item_descriptions[type].name.to_lower()

func collect():
	collected = true
	was_collected.emit(self)
