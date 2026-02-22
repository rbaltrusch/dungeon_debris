extends Label

@onready var ray_tracer = $"../../SubViewport/Dungeon"

var block = 0

func _ready() -> void:
	ray_tracer.increased_block.connect(update_block)
	ray_tracer.reduced_block.connect(update_block)

func update_block(block):
	self.block += block
	self.text = "Block: %s" % int(self.block)
