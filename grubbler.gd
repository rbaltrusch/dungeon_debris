# teleports behind you
extends Enemy.EnemyData

const MapGenerator = preload("res://map_generator.gd")
const DamageType = preload("res://damage_type.gd").DamageType
const Constants = preload("res://consts.gd")

const SCREEN_WIDTH = Constants.SCREEN_WIDTH
const SCREEN_HEIGHT = Constants.SCREEN_HEIGHT
const FPS = Constants.FPS

signal released_locked_in_place
signal started_hunting
signal just_attacked
signal started_attack

const MAX_HUNT = 15
const ATTACK_LOADUP_THRESHOLD = 2
const SPAWN_CHANCE_PER_SECOND = 0.05
const ATTACK_START_CHANCE_PER_SECOND = 0.2
const DAMAGE = 10
static var is_attacking = false

enum State {INIT, HIDING, HUNTING, ATTACK}

var dagger_texture: Texture2D

var hunt_loadup = 0
var attack_loadup = 0
var state: State = State.INIT
var bobbing = Vector2()
var dagger_position = Vector2()

func _init(texture: Texture2D, dagger_texture: Texture2D):
	super._init(texture)
	self.dagger_texture = dagger_texture

func update(delta: float, enemy: Enemy, player: Player, map: Map) -> void:
	var time = 1.0 * Time.get_ticks_msec() / 1000
	var bob = 0.025 * sin(2 * PI * 0.35 * time)
	bobbing = Vector2(bob, bob)

	if state == State.INIT:
		enemy.hide()
		state = State.HIDING

	if is_attacking and not state == State.ATTACK: # another grubbler is already attacking
		return

	if state == State.HIDING:
		if SPAWN_CHANCE_PER_SECOND / FPS > randf():
			state = State.HUNTING
			started_hunting.emit()

	if state == State.HUNTING:
		# tries to spawn one tile behind player
		var behind_player: Vector2 = (player.position - player.dir.normalized()).round()
		var can_spawn = map.get_tile(behind_player) == MapGenerator.Tile.EMPTY \
			and map.get_tile(behind_player + Vector2(1, 1)) == MapGenerator.Tile.EMPTY
		if can_spawn and (hunt_loadup >= MAX_HUNT or ATTACK_START_CHANCE_PER_SECOND / FPS > randf()):
			started_attack.emit()
			state = State.ATTACK
			enemy.position = behind_player + Vector2(0.5, 0.5)
			dagger_position = player.position - player.dir.normalized() * 0.5
			player.lock_in_place()
			enemy.died.connect(self.die)
			released_locked_in_place.connect(player.release_locked_in_place)
			enemy.show()
		else:
			hunt_loadup += delta
	
	if state == State.ATTACK:
		is_attacking = true
		if is_loading_up_attack():
			attack_loadup += delta
		else:
			attack_loadup = 0
			player.take_damage(DAMAGE, DamageType.PHYSICAL)
			just_attacked.emit()

func is_loading_up_attack():
	return state == State.ATTACK and attack_loadup < ATTACK_LOADUP_THRESHOLD

func render(renderer: TextureRenderer, enemy: Enemy):
	if not enemy.visible:
		return
	renderer.render(texture, enemy.position + bobbing)
	if is_loading_up_attack():
		var scale = 0.1 + 0.25 * sin(PI / 2 * attack_loadup / ATTACK_LOADUP_THRESHOLD)
		var rendered_rect = renderer.render(dagger_texture, dagger_position + bobbing, scale)
		# TODO: render attack damage

func die() -> void:
	is_attacking = false
	released_locked_in_place.emit()
