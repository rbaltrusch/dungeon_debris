extends ItemData
class_name HealthPotionData

@export var heal_amount: int = 20

func apply(player):
	player.health += heal_amount
