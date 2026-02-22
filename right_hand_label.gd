extends Label

@onready var ray_tracer = $"../../SubViewport/Dungeon"


func _ready() -> void:
	ray_tracer.equipped_shield.connect(equip_item)

func equip_item(item):
	var name: String = item.get_item_name() if item and item.has_method("get_item_name") else "Item"
	text = "Shield: %s" % name.capitalize()
