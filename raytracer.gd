extends Node2D

const Item = preload("res://_old_item.gd")
const ItemType = preload("res://item_type.gd").ItemType

#const ItemScene = preload("res://item.tscn")
#const HealthPotion = preload("res://items/HealthPotion.tres")
#
#func spawn_health_potion(position: Vector2):
	#var item = ItemScene.instantiate()
	#item.position = position
	#item.item_data = HealthPotion
	#add_child(item)

const SCREEN_WIDTH = 1152
const SCREEN_HEIGHT = 648

class Map:
	var width
	var height
	var data
	const EMPTY_TILE = -1

	# Array[Array[int]]
	func _init(map_data: Array):
		data = map_data
		height = data.size()
		width = map_data[0].size() if height else 0

	func get_tile(x: int, y: int) -> int:
		if x < 0 || y < 0 || x >= width || y >= height:
			return EMPTY_TILE
		return data[y][x]

	func is_empty_tile(tile: int) -> bool:
		return tile == EMPTY_TILE

# Simple dungeon layout (1 = wall, 0 = empty)
const world_map_data = [
	[1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,0,0,0,0,0,1],
	[1,0,1,0,1,0,1,1,0,1],
	[1,0,1,0,0,0,0,1,0,1],
	[1,0,1,1,1,1,0,1,0,1],
	[1,0,0,0,0,1,0,0,0,1],
	[1,1,1,1,0,1,1,1,0,1],
	[1,0,0,1,0,0,0,1,0,1],
	[1,0,0,0,0,1,0,0,0,1],
	[1,1,1,1,1,1,1,1,1,1],
]

var map = Map.new(world_map_data)



var items = [
	Item.new(Vector2(3, 1.5), ItemType.LARGE_HEALTH_POTION),
	Item.new(Vector2(5, 1.5), ItemType.SMALL_HEALTH_POTION),
]
var item_bobbing = Vector2(0, 0)

var shader: ShaderMaterial = self.material

class Player:
	const radius = 0.45
	var position = Vector2(1.5, 1.5)
	var dir = Vector2(1, 0)
	var move_speed = 2.0
	var rot_speed = 1.5

var player = Player.new()
var camera_plane = Vector2(0, 0.66) # FOV ~66°

var z_buffer = []
var item_textures = {}
var wall_textures = {}
var background_texture

func _ready():
	background_texture = load("res://sprites/background.png")
	item_textures[ItemType.LARGE_HEALTH_POTION] = load("res://sprites/health_potion.png")
	item_textures[ItemType.SMALL_HEALTH_POTION] = load("res://sprites/small_health_potion.png")

	wall_textures[1] = load("res://sprites/wall2.png")
	#item_textures[ItemType.GOLD] = load("res://sprites/gold.png")
	#item_textures[ItemType.POTION] = load("res://sprites/potion.png")
	#item_textures[ItemType.KEY] = load("res://sprites/key.png")

#func is_wall(x: int, y: int) -> bool:
	#if x < 0 || y < 0 || x >= MAP_WIDTH || y >= MAP_HEIGHT || world_map[y][x] > 0:
		#print("wall", x, y)
		#return true
	#return false

func is_wall(x: int, y: int) -> bool:
	for angle in range(0, 360, 45):
		var dir = Vector2.RIGHT.rotated(deg_to_rad(angle))
		x = round(x + dir.x * player.radius)
		y = round(y + dir.y * player.radius)
		if map.get_tile(x, y) > 0:
			return true
	return false

func try_to_move_to(velocity: Vector2):
	var new_pos = player.position + velocity

	# Check X separately
	if not is_wall(new_pos.x, player.position.y):
		player.position.x = new_pos.x
	
	# Check Y separately
	if not is_wall(player.position.x, new_pos.y):
		player.position.y = new_pos.y

#func _ready():
	#spawn_health_potion(Vector2(300, 300))

func _process(delta):
	var time = 1.0 * Time.get_ticks_msec() / 1000
	shader.set_shader_parameter("u_time", time)

	var bob = 0.025 * sin(2 * PI * 0.35 * time)
	item_bobbing = Vector2(bob, bob)

	print(player.position)

	handle_input(delta)
	queue_redraw()

func handle_input(delta):
	if Input.is_action_pressed("forward"):
		print("up")
		try_to_move_to(player.dir * player.move_speed * delta)

	if Input.is_action_pressed("backward"):
		print("down")
		try_to_move_to(-player.dir * player.move_speed * delta)

	if Input.is_action_pressed("left"):
		print("left")
		rotate_player(-player.rot_speed * delta)

	if Input.is_action_pressed("right"):
		print("right")
		rotate_player(player.rot_speed * delta)

	if Input.is_action_just_pressed("attack"):
		print("attack")

	if Input.is_action_just_pressed("block"):
		print("block")

func rotate_player(angle):
	player.dir = player.dir.rotated(angle)
	camera_plane = camera_plane.rotated(angle)

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
		while not hit:
			if side_dist.x < side_dist.y:
				side_dist.x += delta_dist.x
				map_pos.x += step.x
				side = 0
			else:
				side_dist.y += delta_dist.y
				map_pos.y += step.y
				side = 1

			if map.get_tile(round(map_pos.y), round(map_pos.x)) > 0:
				hit = true

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
		var texture_index = world_map[int(map_pos.y)][int(map_pos.x)]
		if not texture_index: # empty
			continue
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
		#if side == 1:
			#color = Color(color * 0.7, 1) # simple shading
		draw_texture_rect_region(
			tex,
			Rect2(x, draw_start, 1, draw_end - draw_start),
			Rect2(tex_x, 0, 1, tex_height),
			modulator_color
		)
#
		#var color = Color("#40242f")
		#if side == 1:
			#color = Color(color * 0.7, 1) # simple shading
#
		#draw_line(
			#Vector2(x, draw_start),
			#Vector2(x, draw_end),
			#color
		#)

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
		if sprite_pos.length() < 0.5:
			collect_item(item)
