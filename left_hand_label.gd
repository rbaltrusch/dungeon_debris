extends Label

@onready var ray_tracer = $"../../SubViewport/Dungeon"


func _ready() -> void:
	ray_tracer.equipped_left_hand_item.connect(equip_item)

func equip_item(item):
	var name: String = item.get_item_name() if item and item.has_method("get_item_name") else "Item"
	text = "Item: %s" % name.capitalize()
