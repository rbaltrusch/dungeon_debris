class_name Player

signal took_damage(damage)
signal blocked_damage(damage)
signal blocked_full_damage
signal increased_block(block)
signal reduced_block(block)
signal attacked(damage)
signal failed_to_attack_due_to_no_weapon
signal failed_to_block_due_to_missing_shield
signal failed_to_attack_due_to_cooldown
signal failed_to_block_due_to_cooldown
signal failed_to_use_no_item_equipped
signal died
signal rooted
signal hp_updated(hp)
signal healed
signal equipped_left_hand_item(item)
signal equipped_shield(item)
signal picked_up_weapon(item)

const DamageType = preload("res://damage_type.gd").DamageType
const Map = preload("res://map.gd")
const MapGenerator = preload("res://map_generator.gd")
const Weapon = preload("res://weapon.gd")
const Shield = preload("res://shield.gd")

const radius = 0.25
var position = Vector2(1.5, 1.5)
var dir = Vector2(1, 0)

var locked_in_place = false
var alive = true

var move_speed = 2.0
var rot_speed = 2.5
var hp = 100
var max_hp = 100
var block = 0
var armour = 0

var shield: Shield # nullable
var weapon: Weapon # nullable
var left_hand_item: Variant # nullable  # type: Usable (can call .use())
var left_hand_items: Array[Variant] = []
var current_left_hand_item_index = 0

func determine_angle_looking_into_open_corridor(map: Map) -> float:
	var next_tile: Vector2 = position.floor() + dir.normalized()
	if map.get_tile(next_tile) != MapGenerator.Tile.EMPTY:
		return PI / 2
	return 0

func heal(amount: float) -> void:
	var old_hp = hp
	hp = min(max_hp, hp + amount)
	var hp_healed = hp - old_hp
	if hp_healed:
		healed.emit(hp_healed)
		hp_updated.emit(hp)

func take_damage(damage: float, type: DamageType):
	var actual_damage = max(0, damage - armour)
	var remaining_damage = max(0, actual_damage - block)
	var blocked_damage_number = actual_damage - remaining_damage
	reduce_block(blocked_damage_number)
	if blocked_damage_number:
		blocked_damage.emit(blocked_damage_number)

	if remaining_damage == 0:
		blocked_full_damage.emit()
		return

	hp = max(0, hp - remaining_damage)
	hp_updated.emit(hp)
	print("player damaged. remaining hp: ", hp)
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

# Weapon or usable item
func pickup_left_hand_item(item: Variant) -> void:
	if item is Item and item.used:
		return

	if item is Weapon and self.weapon:
		left_hand_items = left_hand_items.filter(func(x): return x != self.weapon)
		self.weapon.drop()
		self.weapon = null

	left_hand_items.append(item)
	print("picked up left hand item")
	equip_last_left_hand_item()

func equip_shield(shield: Shield) -> void:
	if self.shield:
		self.shield.drop()
	self.shield = shield
	equipped_shield.emit(shield)

func equip_last_left_hand_item() -> void:
	var size = left_hand_items.size()
	if size == 0:
		return
	current_left_hand_item_index = size - 1
	set_left_hand_item(left_hand_items[current_left_hand_item_index])

func set_left_hand_item(item: Variant) -> void:
	if item is Weapon:
		self.weapon = item
		picked_up_weapon.emit(item)
	left_hand_item = item
	equipped_left_hand_item.emit(item)
	print(current_left_hand_item_index, left_hand_item.get_item_name())

func equip_next_left_hand_item() -> void:
	_equip_left_hand_item(1)

func equip_previous_left_hand_item() -> void:
	_equip_left_hand_item(-1)

func _equip_left_hand_item(offset: int) -> void:
	var size = left_hand_items.size()
	if size == 0:
		return

	current_left_hand_item_index = (current_left_hand_item_index + offset) % size
	set_left_hand_item(left_hand_items[current_left_hand_item_index])

func use_left_hand_item() -> void:
	if not left_hand_item:
		failed_to_use_no_item_equipped.emit()
		return

	if left_hand_item == self.weapon:
		attack()
	elif left_hand_item.has_method("use"):
		left_hand_item.use()

	if left_hand_item is Item and left_hand_item.used:
		left_hand_items.remove_at(current_left_hand_item_index)
		_equip_left_hand_item(0)

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

func reduce_block(block: float) -> void:
	if block <= 0:
		return
	var new_block = max(0, self.block - block)
	var block_reduction = self.block - new_block
	self.block = new_block
	if block_reduction:
		reduced_block.emit(-block_reduction)
