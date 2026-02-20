class_name CooldownItem
extends Node

signal cooldown_refreshed

var cooldown = 0
var timer: Timer
var can_use: bool = true

func _init(cooldown: float):
	self.cooldown = cooldown

func _ready():
	timer = Timer.new()
	timer.timeout.connect(func(): can_use = true)
	timer.timeout.connect(cooldown_refreshed.emit)
	add_child(timer)

func use():
	if not can_use:
		return
	timer.start(self.cooldown)
	can_use = false

func drop():
	timer.queue_free()
	queue_free()
