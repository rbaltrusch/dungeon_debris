extends Label

@onready var ray_tracer = $"../../SubViewport/Dungeon"

var hp = 0

func _ready() -> void:
	ray_tracer.player_hp_updated.connect(update_hp)
	hp = ray_tracer.player.hp if ray_tracer.player else 100
	update_hp(hp)

func update_hp(hp):
	self.hp = hp
	self.text = "HP: %s" % int(self.hp)
