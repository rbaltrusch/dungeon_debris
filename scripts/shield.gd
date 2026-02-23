class_name Shield
extends CooldownItem

var block = 0

func _init(block: float, cooldown: float, type: ItemType.ItemType):
	super._init(cooldown, type)
	self.block = block
