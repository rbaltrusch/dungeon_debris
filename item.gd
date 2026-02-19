extends Area2D

@export var item_name: String
@export var value: int = 1
var item_data: Resource

@onready var sprite: Sprite2D = $Sprite2D


func _ready():
	body_entered.connect(_on_body_entered)
	if item_data and item_data.sprite:
		sprite.texture = item_data.sprite

func _on_body_entered(body):
	if body.has_method("collect_item"):
		body.collect_item(self)
		queue_free()
