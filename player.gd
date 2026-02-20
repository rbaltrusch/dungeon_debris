class_name Player

signal took_damage(damage)
signal blocked_damage(damage)
signal increased_block(block)
signal attacked(damage)
signal failed_to_attack_due_to_no_weapon
signal failed_to_block_due_to_missing_shield
signal failed_to_attack_due_to_cooldown
signal failed_to_block_due_to_cooldown
signal died
signal rooted

const DamageType = preload("res://damage_type.gd").DamageType
const Map = preload("res://map.gd")
const MapGenerator = preload("res://map_generator.gd")
const Weapon = preload("res://weapon.gd")
const Shield = preload("res://shield.gd")

const radius = 0.25
var position = Vector2(1.5, 1.5)
var dir = Vector2(1, 0)
var move_speed = 2.0
var rot_speed = 2.5
var hp = 100
var block = 0
var armour = 0
var locked_in_place = false
var alive = true

var shield: Shield
var weapon: Weapon # nullable

func determine_angle_looking_into_open_corridor(map: Map) -> float:
	var next_tile: Vector2 = position.floor() + dir.normalized()
	if map.get_tile(next_tile) != MapGenerator.Tile.EMPTY:
		return PI / 2
	return 0

func take_damage(damage: float, type: DamageType):
	var actual_damage = max(0, damage - armour)
	block = max(0, block - actual_damage)
	var remaining_damage = max(0, actual_damage - block)
	hp = max(0, hp - remaining_damage)
	print("damaged. remaining hp: ", hp)
	if hp == 0:
		die()
	elif remaining_damage > 0:
		took_damage.emit(remaining_damage)

func die() -> void:
	if not alive:
		return
	alive = false
	died.emit()
	print("died")

func lock_in_place() -> void:
	print("locked in place")
	locked_in_place = true
	rooted.emit()

func release_locked_in_place() -> void:
	print("released lock in place")
	locked_in_place = false

func equip_weapon(weapon: Weapon) -> void:
	self.weapon = weapon

func equip_shield(shield: Shield) -> void:
	self.shield = shield

func attack() -> void:
	if not self.weapon:
		failed_to_attack_due_to_no_weapon.emit()
		return

	if not self.weapon.can_use:
		failed_to_attack_due_to_cooldown.emit()
		return

	# attacks hitting nothing should not consume weapon cooldown
	#self.weapon.use()
	attacked.emit(self.weapon.damage)

func set_attack_on_cooldown() -> void:
	self.weapon.use()

func use_shield() -> void:
	if not self.shield:
		failed_to_block_due_to_missing_shield.emit()
		return

	if not self.shield.can_use:
		failed_to_block_due_to_cooldown.emit()
		print(self.shield.timer.time_left)
		return

	self.shield.use()
	increased_block.emit(self.shield.block)
	self.block += self.shield.block
