extends Node2D

const Item = preload("res://item.gd")
const ItemType = preload("res://item_type.gd").ItemType
const Map = preload("res://map.gd")
const MapGenerator = preload("res://map_generator.gd")
const Enemy = preload("res://enemy.gd")
const Player = preload("res://player.gd")
const TextureRenderer = preload("res://texture_renderer.gd")
const DamageType = preload("res://damage_type.gd").DamageType

const SCREEN_WIDTH = 1152
const SCREEN_HEIGHT = 648
const FPS = 60

		
# teleports behind you
class GrubblerData extends Enemy.EnemyData:

	signal released_locked_in_place

	const ATTACK_LOADUP_THRESHOLD = 2
	const SPAWN_CHANCE_PER_SECOND = 0.05
	const DAMAGE = 10
	static var is_attacking = false

	enum State {INIT, HIDING, ATTACK}

	var attack_loadup = 0
	var state: State = State.INIT

	func update(delta: float, enemy: Enemy, player: Player, map: Map) -> void:
		if state == State.INIT:
			enemy.hide()
			state = State.HIDING

		if state == State.HIDING:
			if is_attacking: # another grubbler is already attacking
				return

			var behind_player: Vector2 = (player.position - player.dir.normalized()).round()
			var can_spawn = map.get_tile(behind_player) == MapGenerator.Tile.EMPTY
			if SPAWN_CHANCE_PER_SECOND / FPS > randf():
				state = State.ATTACK
				enemy.position = behind_player
				player.lock_in_place()
				released_locked_in_place.connect(player.release_locked_in_place)
				enemy.show()

		if state == State.ATTACK:
			if is_loading_up_attack():
				attack_loadup += delta
			else:
				attack_loadup = 0
				player.take_damage(DAMAGE, DamageType.PHYSICAL)
				# TODO: play attack sound

	func is_loading_up_attack():
		return state == State.ATTACK and attack_loadup < ATTACK_LOADUP_THRESHOLD

	func render(renderer: TextureRenderer, enemy: Enemy):
		super.render(renderer, enemy)
		if is_loading_up_attack():
			pass
			# TODO: display little attack icon

	func die() -> void:
		released_locked_in_place.emit()

var exitted = false
var map: Map
var items: Array
var shader: ShaderMaterial = self.material
var item_bobbing = Vector2(0, 0)
const COLLECTION_DISTANCE = 0.5

var player: Player
var camera_plane = Vector2(0, 0.66) # FOV ~66°

var z_buffer = []
var item_textures = {}
var wall_textures = {}
var background_texture
var enemies: Array[Enemy] = []
var texture_renderer: TextureRenderer

func _ready():
	player = Player.new()

	texture_renderer = TextureRenderer.new(draw_strip_texture, player)

	var grubbler_texture = load("res://sprites/wall.png")
	enemies.append(Enemy.new(Vector2(1, 1), GrubblerData.new(grubbler_texture)))

	var height = randi_range(10, 20)
	var width = randi_range(10, 20)
	var map_data = MapGenerator.new().generate(width, height)
	map = Map.new(map_data)
	map.debug_print()

	items = [
		Item.new(Vector2(3, 1.5), ItemType.LARGE_HEALTH_POTION),
		Item.new(Vector2(5, 1.5), ItemType.SMALL_HEALTH_POTION),
	]

	background_texture = load("res://sprites/background.png")
	item_textures[ItemType.LARGE_HEALTH_POTION] = load("res://sprites/health_potion.png")
	item_textures[ItemType.SMALL_HEALTH_POTION] = load("res://sprites/small_health_potion.png")
	item_textures[ItemType.GOLD] = load("res://sprites/gold.png")
	item_textures[ItemType.KEY] = load("res://sprites/key.png")

	wall_textures[MapGenerator.Tile.WALL] = load("res://sprites/wall2.png")
	wall_textures[MapGenerator.Tile.DOOR] = load("res://sprites/wall.png")

func _process(delta):
	var time = 1.0 * Time.get_ticks_msec() / 1000
	shader.set_shader_parameter("u_time", time)

	var bob = 0.025 * sin(2 * PI * 0.35 * time)
	item_bobbing = Vector2(bob, bob)

	#print(player.position)
	#var behind_player: Vector2 = (player.position - player.dir.normalized()).round()
	#print(map.get_tile(behind_player) == 0)

	handle_input(delta)
	for enemy in enemies:
		enemy.update(delta, player, map)

	queue_redraw()


func is_wall(x: int, y: int) -> bool:
	for angle in range(0, 360, 45):
		var dir = Vector2.RIGHT.rotated(deg_to_rad(angle))
		var offset = dir.x * player.radius
		var pos = (Vector2(x, y) + Vector2(offset, offset)).round()
		if map.get_tile(pos) > 0:
			return true
	return false

func try_to_move_to(velocity: Vector2):
	if player.locked_in_place:
		return

	var new_pos = player.position + velocity

	# Check X separately
	if not is_wall(new_pos.x, player.position.y):
		player.position.x = new_pos.x

	# Check Y separately
	if not is_wall(player.position.x, new_pos.y):
		player.position.y = new_pos.y

func handle_input(delta):
	if Input.is_action_pressed("forward"):
		try_to_move_to(player.dir * player.move_speed * delta)

	if Input.is_action_pressed("backward"):
		try_to_move_to(-player.dir * player.move_speed * delta)

	if Input.is_action_pressed("left"):
		rotate_player(-player.rot_speed * delta)

	if Input.is_action_pressed("right"):
		rotate_player(player.rot_speed * delta)

	if Input.is_action_just_pressed("attack"):
		print("attack")

	if Input.is_action_just_pressed("block"):
		print("block")

func rotate_player(angle):
	player.dir = player.dir.rotated(angle)
	camera_plane = camera_plane.rotated(angle)

func exit_dungeon():
	if exitted:
		return
	exitted = true
	print("exitted")
	queue_free()

func draw_strip_texture(sprite_pos: Vector2, texture: Texture2D):

	var inv_det = 1.0 / (camera_plane.x * player.dir.y - player.dir.x * camera_plane.y)

	var transform_x = inv_det * (player.dir.y * sprite_pos.x - player.dir.x * sprite_pos.y)
	var transform_y = inv_det * (-camera_plane.y * sprite_pos.x + camera_plane.x * sprite_pos.y)

	if transform_y <= 0:
		return

	var sprite_screen_x = int((SCREEN_WIDTH / 2) * (1 + transform_x / transform_y))
	var sprite_height = abs(int(SCREEN_HEIGHT / transform_y))
	var sprite_width = sprite_height

	var draw_start_y = -sprite_height / 2 + SCREEN_HEIGHT / 2
	var draw_end_y = sprite_height / 2 + SCREEN_HEIGHT / 2

	var draw_start_x = -sprite_width / 2 + sprite_screen_x
	var draw_end_x = sprite_width / 2 + sprite_screen_x

	var tex_width = texture.get_width()
	var tex_height = texture.get_height()

	for stripe in range(draw_start_x, draw_end_x):
		if stripe < 0 or stripe >= SCREEN_WIDTH:
			continue
		if transform_y >= z_buffer[stripe]:
			continue  # Behind wall

		var tex_x = int((stripe - draw_start_x) * tex_width / sprite_width)

		draw_texture_rect_region(
			texture,
			Rect2(stripe, draw_start_y, 1, sprite_height),
			Rect2(tex_x, 0, 1, tex_height)
		)

func collect_item(item: Item):
	print("collected", item)
	item.collected = true

func _draw():
	# Ceiling
	#draw_rect(Rect2(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT / 2), Color(0.1, 0.1, 0.1, 0.2))
	draw_texture(background_texture, Vector2.ZERO, Color(0.3, 0.3, 0.3, 1))

	# Floor
	draw_rect(Rect2(0, SCREEN_HEIGHT / 2, SCREEN_WIDTH, SCREEN_HEIGHT / 2), Color("#1a0f14"))

	z_buffer.resize(SCREEN_WIDTH)
	for x in SCREEN_WIDTH:
		var camera_x = 2 * x / float(SCREEN_WIDTH) - 1
		var ray_dir = player.dir + camera_plane * camera_x

		var map_pos = Vector2(int(player.position.x), int(player.position.y))

		var delta_dist = Vector2(
			abs(1.0 / ray_dir.x) if ray_dir.x != 0 else 1e30,
			abs(1.0 / ray_dir.y) if ray_dir.y != 0 else 1e30
		)

		var step = Vector2()
		var side_dist = Vector2()

		if ray_dir.x < 0:
			step.x = -1
			side_dist.x = (player.position.x - map_pos.x) * delta_dist.x
		else:
			step.x = 1
			side_dist.x = (map_pos.x + 1.0 - player.position.x) * delta_dist.x

		if ray_dir.y < 0:
			step.y = -1
			side_dist.y = (player.position.y - map_pos.y) * delta_dist.y
		else:
			step.y = 1
			side_dist.y = (map_pos.y + 1.0 - player.position.y) * delta_dist.y

		var hit = false
		var side = 0

		# DDA
		var counter = 0
		while not hit:
			if side_dist.x < side_dist.y:
				side_dist.x += delta_dist.x
				map_pos.x += step.x
				side = 0
			else:
				side_dist.y += delta_dist.y
				map_pos.y += step.y
				side = 1

			if map.get_tile(map_pos.round()) > 0:
				hit = true
			counter += 1
			if counter % 1000 == 0:
				print(counter)
			if counter > 10_000:
				break

		var perp_wall_dist
		if side == 0:
			perp_wall_dist = (map_pos.x - player.position.x + (1 - step.x) / 2) / ray_dir.x
		else:
			perp_wall_dist = (map_pos.y - player.position.y + (1 - step.y) / 2) / ray_dir.y
		z_buffer[x] = perp_wall_dist

		var wall_x

		if side == 0:
			wall_x = player.position.y + perp_wall_dist * ray_dir.y
		else:
			wall_x = player.position.x + perp_wall_dist * ray_dir.x

		wall_x -= floor(wall_x)
		var texture_index = map.get_tile(map_pos.round())
		if not texture_index: # empty
			continue

		if texture_index == MapGenerator.Tile.DOOR && perp_wall_dist < COLLECTION_DISTANCE:
			exit_dungeon.call_deferred()

		var tex = wall_textures[texture_index]
		if not tex:
			print("error looking up texture: ", texture_index)
			continue
		var tex_width = tex.get_width()
		var tex_height = tex.get_height()

		var tex_x = int(wall_x * tex_width)

		# Flip texture for correct orientation
		if side == 0 and ray_dir.x > 0:
			tex_x = tex_width - tex_x - 1
		if side == 1 and ray_dir.y < 0:
			tex_x = tex_width - tex_x - 1

		var line_height = int(SCREEN_HEIGHT / perp_wall_dist)

		var draw_start = -line_height / 2 + SCREEN_HEIGHT / 2
		var draw_end = line_height / 2 + SCREEN_HEIGHT / 2
		var color = Color("#40242f")
		var modulator_color = Color(color * 0.5, 1) if side == 1 else color

		draw_texture_rect_region(
			tex,
			Rect2(x, draw_start, 1, draw_end - draw_start),
			Rect2(tex_x, 0, 1, tex_height),
			modulator_color
		)

	items.sort_custom(func(a, b):
		return player.position.distance_to(b.position) < player.position.distance_to(a.position)
	)
	for item in items:
		if item.collected:
			continue

		var texture = item_textures[item.type]
		var sprite_pos = item.position + item_bobbing - player.position
		draw_strip_texture(sprite_pos, texture)

		# Collect item
		if sprite_pos.length() < COLLECTION_DISTANCE:
			collect_item(item)

	for enemy in enemies:
		enemy.render(texture_renderer)
