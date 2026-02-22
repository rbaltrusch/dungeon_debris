# walks to you
extends Enemy.EnemyData

const Constants = preload("res://consts.gd")

signal just_attacked

const SCREEN_WIDTH = Constants.SCREEN_WIDTH
const SCREEN_HEIGHT = Constants.SCREEN_HEIGHT
const FPS = Constants.FPS

enum State {WALKING, ATTACK}

var path_index = 0
var path = null  # PackedVector2Array
var state: State
var attack_loadup = 0
var path_factory: Callable # takes position and gives back PackedVector2Array
var path_staleness = 0

const DAMAGE = 4
const MAX_PATH_STALENESS = 0.5
const speed = 0.9
const attack_range_squared = 1.15 ** 2
const smell_range_squared = 10 ** 2
const ATTACK_LOADUP_THRESHOLD = 1
const TILE_LATCHON_THRESHOLD = 0.1

func _init(texture: Texture2D, path_factory: Callable):
	super._init(texture)
	self.path_factory = path_factory

func update(delta: float, enemy: Enemy, player: Player, map: Map) -> void:
	var in_attack_range = player.position.distance_squared_to(enemy.position) < attack_range_squared
	if state == State.WALKING:
		path_staleness += delta
		if not path or path_staleness > MAX_PATH_STALENESS:
			update_path(enemy)
		follow_path(delta, enemy)

		if in_attack_range:
			state = State.ATTACK
			path = null
			attack_loadup = 0

	if state ==State.ATTACK:
		if not in_attack_range:
			state = State.WALKING

		if is_loading_up_attack():
			attack_loadup += delta
		else:
			attack_loadup = 0
			player.take_damage(DAMAGE, DamageType.PHYSICAL)
			just_attacked.emit()

func follow_path(delta, enemy):
	if path.size() == 0:
		return

	if path_index >= path.size():
		return

	var target = path[path_index]

	var dir = (target - enemy.position).normalized()

	enemy.position += dir * speed * delta

	if enemy.position.distance_to(target) < TILE_LATCHON_THRESHOLD:
		path_index += 1

func update_path(enemy: Enemy):
	var new_path = path_factory.call(enemy.position)
	if new_path == path:
		return
	path = new_path
	path_index = 0
	path_staleness = 0

func is_loading_up_attack():
	return state == State.ATTACK and attack_loadup < ATTACK_LOADUP_THRESHOLD
