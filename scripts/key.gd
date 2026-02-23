class_name Key
extends Item

signal tried_to_use

func _init(position: Vector2, type: ItemType.ItemType, use_fn: Callable = func(item): null) -> void:
	super._init(position, type, use_fn)

func use() -> void:
	use_fn.call(self)
	tried_to_use.emit()
