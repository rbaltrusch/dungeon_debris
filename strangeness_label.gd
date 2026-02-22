extends Label

@onready var ray_tracer = $"../../SubViewport/Dungeon"

var strangeness = 0

func _ready() -> void:
	ray_tracer.increased_strangeness.connect(update_strangeness)

func update_strangeness(strangeness):
	self.strangeness += strangeness
	self.text = "Strangeness: %s" % int(self.strangeness)
