class_name Weapon
extends CooldownItem

var damage = 0
var range = 0
var cone = deg_to_rad(60) # 60° cone

func _init(damage: float, cooldown: float, range: float, type: ItemType.ItemType):
	super._init(cooldown, type)
	self.damage = damage
	self.range = range
