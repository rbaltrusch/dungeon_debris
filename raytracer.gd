extends Node2D
class_name RayTracer

signal took_damage(damage)
signal blocked_damage(damage)
signal increased_block(block)
signal dealt_damage(damage)
signal failed_to_attack_due_to_no_weapon
signal failed_to_block_due_to_missing_shield
signal failed_to_attack_due_to_cooldown
signal failed_to_block_due_to_cooldown
signal exitted_dungeon
signal player_rooted
signal player_died
signal enemy_killed(enemy)

const Item = preload("res://item.gd")
const ItemType = preload("res://item_type.gd").ItemType
const Map = preload("res://map.gd")
const MapGenerator = preload("res://map_generator.gd")
const Enemy = preload("res://enemy.gd")
const Player = preload("res://player.gd")
const TextureRenderer = preload("res://texture_renderer.gd")
const DamageType = preload("res://damage_type.gd").DamageType
const Constants = preload("res://consts.gd")
const GrubblerData = preload("res://grubbler.gd")
const DungeonSignals = preload("res://dungeon_signals.gd")
const Shield = preload("res://shield.gd")
const Weapon = preload("res://weapon.gd")

const SCREEN_WIDTH = Constants.SCREEN_WIDTH
const SCREEN_HEIGHT = Constants.SCREEN_HEIGHT
const FPS = Constants.FPS

var exitted = false
var map: Map
var items: Array
var shader: ShaderMaterial = self.material
var item_bobbing = Vector2(0, 0)
const COLLECTION_DISTANCE = 0.5

var player: Player
var camera_plane = Vector2(0, 0.8) # FOV in degrees

var z_buffer = []
var item_textures = {}
var wall_textures = {}
var background_texture
var enemies: Array[Enemy] = []
var texture_renderer: TextureRenderer

func _ready():
	player = Player.new()
	player.equip_shield(Shield.new(10, 5))
	player.equip_weapon(Weapon.new(10, 2, 1.5))
	add_child(player.shield)
	add_child(player.weapon)
	player.took_damage.connect($HitSound.play)
	player.took_damage.connect(func(damage): took_damage.emit(damage))
	player.blocked_damage.connect(func(damage): blocked_damage.emit(damage))
	player.increased_block.connect(func(block): increased_block.emit(block))
	player.failed_to_attack_due_to_cooldown.connect(failed_to_attack_due_to_cooldown.emit)
	player.failed_to_attack_due_to_no_weapon.connect(failed_to_attack_due_to_no_weapon.emit)
	player.failed_to_block_due_to_cooldown.connect(failed_to_block_due_to_cooldown.emit)
	player.failed_to_block_due_to_missing_shield.connect(failed_to_block_due_to_missing_shield.emit)
	player.rooted.connect(player_rooted.emit)
	player.died.connect(player_died.emit)
	player.attacked.connect(process_player_attack)
	dealt_damage.connect(func(damage): player.set_attack_on_cooldown())

	texture_renderer = TextureRenderer.new(draw_strip_texture, player)

	var grubbler_texture = load("res://sprites/grubbler.png")
	var dagger_texture = load("res://sprites/dagger.png")
	var grubbler_data = GrubblerData.new(grubbler_texture, dagger_texture)
	grubbler_data.just_attacked.connect($SmallSlam.play)
	grubbler_data.started_hunting.connect($GrubblerHunt.play)
	grubbler_data.started_attack.connect($GrubblerHunt.stop)
	grubbler_data.started_attack.connect($GrubblerAttack.play)
	#grubbler_data.state = GrubblerData.State.HUNTING
	spawn_enemy(Enemy.new(Vector2(1, 1), grubbler_data))

	var height = randi_range(10, 20)
	var width = randi_range(10, 20)
	var map_data = MapGenerator.new().generate(width, height)
	map = Map.new(map_data)
	map.debug_print()
	rotate_player(player.determine_angle_looking_into_open_corridor(map))

	var large_potion = Item.new(Vector2(3, 1.5), ItemType.LARGE_HEALTH_POTION)
	large_potion.was_collected.connect($PotionPickup.play)
	var small_potion = Item.new(Vector2(5, 1.5), ItemType.SMALL_HEALTH_POTION)
	small_potion.was_collected.connect($PotionPickup.play)
	var key = Item.new(Vector2(6, 1.5), ItemType.KEY)
	key.was_collected.connect($KeyPickup.play)
	items = [large_potion, small_potion, key]

	background_texture = load("res://sprites/background.png")
	item_textures[ItemType.LARGE_HEALTH_POTION] = load("res://sprites/health_potion.png")
	item_textures[ItemType.SMALL_HEALTH_POTION] = load("res://sprites/small_health_potion.png")
	item_textures[ItemType.GOLD] = load("res://sprites/gold.png")
	item_textures[ItemType.KEY] = load("res://sprites/key.png")

	wall_textures[MapGenerator.Tile.WALL] = load("res://sprites/wall2.png")
	wall_textures[MapGenerator.Tile.DOOR] = load("res://sprites/door.png")

func spawn_enemy(enemy: Enemy) -> void:
	enemies.append(enemy)
	enemy.died.connect(func(): enemy_killed.emit(enemy))
	enemy.died.connect($EnemyDeath.play)
	enemy.took_damage.connect(func(damage): dealt_damage.emit(damage))

func process_player_attack(damage: float):
	print("processing player attack...")
	var best_target: Enemy = null
	var closest_distance = INF
	var min_dot = cos(player.weapon.cone * 0.5)
	
	for enemy in enemies:
		if not enemy.alive:
			print("dead enemy")
			continue

		var to_enemy = enemy.position - player.position
		var distance_square = to_enemy.length_squared()
		
		if distance_square > (player.weapon.range ** 2):
			print("enemy out of range")
			continue

		var dot = player.dir.dot(to_enemy.normalized())
		if dot < min_dot:
			print("out of cone")
			continue

		if not has_line_of_sight(enemy.position):
			print("no line of sight to enemy")
			continue

		if distance_square < closest_distance:
			print("found target enemy")
			closest_distance = distance_square
			best_target = enemy

	if best_target:
		best_target.take_damage(player.weapon.damage, DamageType.PHYSICAL)

func has_line_of_sight(target_pos: Vector2) -> bool:
	var ray_dir = (target_pos - player.position).normalized()
	var distance = player.position.distance_to(target_pos)
	
	var check_pos = player.position
	var step = ray_dir * 0.1
	
	var traveled = 0.0
	while traveled < distance:
		check_pos += step
		traveled += 0.1
		
		if is_wall(check_pos.x, check_pos.y):
			return false
	
	return true

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

	for item in items:
		if item.collected:
			continue
		var sprite_pos = item.position - player.position
		if sprite_pos.length() < COLLECTION_DISTANCE:
			item.collect()
	enemies = enemies.filter(func(x): return x.alive)
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
	if not player.alive:
		return

	if Input.is_action_pressed("forward"):
		try_to_move_to(player.dir * player.move_speed * delta)

	if Input.is_action_pressed("backward"):
		try_to_move_to(-player.dir * player.move_speed * delta)

	if Input.is_action_pressed("left"):
		rotate_player(-player.rot_speed * delta)

	if Input.is_action_pressed("right"):
		rotate_player(player.rot_speed * delta)

	if Input.is_action_just_pressed("attack"):
		player.attack()

	if Input.is_action_just_pressed("block"):
		player.use_shield()

func rotate_player(angle):
	player.dir = player.dir.rotated(angle)
	camera_plane = camera_plane.rotated(angle)

func exit_dungeon():
	if exitted:
		return

	# TODO can only exit with key
	exitted = true
	print("exitted")
	queue_free()

# returns the rect of actual screen coordinates drawn
func draw_strip_texture(sprite_pos: Vector2, texture: Texture2D, scale: float = 1.0) -> Rect2:
	scale = clamp(scale, 0, 1)
	if scale == 0:
		return Rect2()
	var inverse_scale = 1 / scale

	var inv_det = 1.0 / (camera_plane.x * player.dir.y - player.dir.x * camera_plane.y)

	var transform_x = inverse_scale * inv_det * (player.dir.y * sprite_pos.x - player.dir.x * sprite_pos.y)
	var transform_y = inverse_scale * inv_det * (-camera_plane.y * sprite_pos.x + camera_plane.x * sprite_pos.y)

	if transform_y <= 0:
		return Rect2()

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
	return Rect2(draw_start_x, draw_start_y, sprite_height, sprite_width)

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
		return player.position.distance_squared_to(b.position) < player.position.distance_squared_to(a.position)
	)
	for item in items:
		if item.collected:
			continue

		var texture = item_textures[item.type]
		var sprite_pos = item.position + item_bobbing - player.position
		draw_strip_texture(sprite_pos, texture)

	enemies.sort_custom(func(a, b):
		return player.position.distance_squared_to(b.position) < player.position.distance_squared_to(a.position)
	)
	for enemy in enemies:
		enemy.render(texture_renderer)
