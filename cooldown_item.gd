class_name CooldownItem
extends Node

const ItemType = preload("res://item_type.gd")

signal cooldown_refreshed

var cooldown = 0
var timer: Timer
var type: ItemType.ItemType
var can_use: bool = true

func _init(cooldown: float, type: ItemType.ItemType):
	self.cooldown = cooldown
	self.type = type

func _ready():
	timer = Timer.new()
	timer.timeout.connect(func(): can_use = true)
	timer.timeout.connect(cooldown_refreshed.emit)
	add_child(timer)

func use() -> void:
	if not can_use:
		return
	timer.start(self.cooldown)
	can_use = false

func drop():
	timer.queue_free()
	queue_free()

func get_item_name() -> String:
	return ItemType.item_descriptions[type].name
