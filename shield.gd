class_name Shield
extends CooldownItem

var block = 0

func _init(block: float, cooldown: float):
	super._init(cooldown)
	self.block = block
