class_name Player

const DamageType = preload("res://damage_type.gd").DamageType

const radius = 0.25
var position = Vector2(1.5, 1.5)
var dir = Vector2(1, 0)
var move_speed = 2.0
var rot_speed = 1.5
var hp = 100
var block = 0
var armour = 0
var locked_in_place = false

func take_damage(damage: float, type: DamageType):
	var actual_damage = max(0, damage - armour)
	block = max(0, block - actual_damage)
	var remaining_damage = max(0, actual_damage - block)
	hp = max(0, hp - remaining_damage)
	print("damaged. remaining hp: ", hp)

func is_alive() -> bool:
	return hp > 0

func lock_in_place() -> void:
	print("locked in place")
	locked_in_place = true

func release_locked_in_place() -> void:
	print("released lock in place")
	locked_in_place = false
