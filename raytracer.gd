extends Node2D
class_name RayTracer

signal took_damage(damage)
signal blocked_damage(damage)
signal increased_block(block)
signal reduced_block(block)
signal dealt_damage(damage)
signal failed_to_attack_due_to_no_weapon
signal failed_to_block_due_to_missing_shield
signal failed_to_attack_due_to_cooldown
signal failed_to_block_due_to_cooldown
signal failed_to_use_no_item_equipped
signal failed_to_exit_dungeon_should_equip_key
signal failed_to_exit_dungeon_no_key
signal failed_to_exit_dungeon_no_door
signal exitted_dungeon
signal player_rooted
signal player_died
signal player_hp_updated(hp)
signal enemy_killed(enemy)
signal item_collected(item)
signal item_used(item)
signal player_healed(hp)
signal equipped_left_hand_item(item)
signal equipped_shield(shield)
signal full_strangeness_reached
signal increased_strangeness(strangeness)
signal asked_to_display_help

const Item = preload("res://item.gd")
const ItemType = preload("res://item_type.gd").ItemType
const ItemDescription = preload("res://item_type.gd").ItemDescription
const Map = preload("res://map.gd")
const MapGenerator = preload("res://map_generator.gd")
const Enemy = preload("res://enemy.gd")
const Player = preload("res://player.gd")
const TextureRenderer = preload("res://texture_renderer.gd")
const DamageType = preload("res://damage_type.gd").DamageType
const Constants = preload("res://consts.gd")
const GrubblerData = preload("res://grubbler.gd")
const ZombieData = preload("res://zombie.gd")
const DungeonSignals = preload("res://dungeon_signals.gd")
const Shield = preload("res://shield.gd")
const Weapon = preload("res://weapon.gd")
const Key = preload("res://key.gd")
const PathFinder = preload("res://pathfinder.gd")

const SCREEN_WIDTH = Constants.SCREEN_WIDTH
const SCREEN_HEIGHT = Constants.SCREEN_HEIGHT
const FPS = Constants.FPS

var fadeout = 0
var exitting = false
var exitted = false

var map: Map
var pathfinder: PathFinder

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

@onready var block_strip_timer = $BlockStripTimer
@onready var spawn_timer = $SpawnTimer
@onready var zombie_spawn_timer = $ZombieSpawnTimer

var can_exit = false
var can_warn = true
@onready var failed_to_exit_dungeon_timer = $FailedToExitTimer

var can_scroll = true
@onready var scroll_timer = $ScrollTimer

@onready var exit_timer = $ExitTimer

@onready var use_sword_sound = $UseSword

@onready var torch_timer = $TorchTimer
var torch_level = 50

var banged_against_door = 0
var strangeness = 0
const FULL_STRANGENESS = 50
var dungeon_number = 1
var min_dungeon_size = 5

func _ready():
	player = Player.new()
	player.took_damage.connect($HitSound.play)
	player.took_damage.connect(took_damage.emit)
	player.blocked_damage.connect(blocked_damage.emit)
	player.blocked_full_damage.connect($BlockedAttack.play)
	player.reduced_block.connect(reduced_block.emit)
	player.increased_block.connect(increased_block.emit)
	player.increased_block.connect($BlockIncreased.play)
	player.failed_to_attack_due_to_cooldown.connect(failed_to_attack_due_to_cooldown.emit)
	player.failed_to_attack_due_to_no_weapon.connect(failed_to_attack_due_to_no_weapon.emit)
	player.failed_to_block_due_to_cooldown.connect(failed_to_block_due_to_cooldown.emit)
	player.failed_to_block_due_to_missing_shield.connect(failed_to_block_due_to_missing_shield.emit)
	player.failed_to_use_no_item_equipped.connect(failed_to_use_no_item_equipped.emit)
	player.rooted.connect(player_rooted.emit)
	player.died.connect(player_died.emit)
	player.attacked.connect(process_player_attack)
	player.attacked.connect(func(damage): use_sword_sound.play())
	player.hp_updated.connect(player_hp_updated.emit)
	player.healed.connect(player_healed.emit)
	player.equipped_left_hand_item.connect(equipped_left_hand_item.emit)
	player.equipped_shield.connect(equipped_shield.emit)
	player.equipped_shield.connect(add_child)
	player.picked_up_weapon.connect(add_child)
	dealt_damage.connect(func(damage): player.set_attack_on_cooldown())
	dealt_damage.connect(func(damage): use_sword_sound.play)
	player.equip_shield.call_deferred(Shield.new(6, 3.5, ItemType.WOODEN_SHIELD))
	player.pickup_left_hand_item(create_torch(Vector2(0, 0)))
	player.pickup_left_hand_item(create_potion(Vector2(0, 0), false))
	player.pickup_left_hand_item.call_deferred(Weapon.new(10, 1, 2.5, ItemType.DAGGER))

	exitted_dungeon.connect($DoorUnlock.play)
	exitted_dungeon.connect(generate_dungeon)
	exitted_dungeon.connect(func(): dungeon_number += 1)
	exitted_dungeon.connect(func(): min_dungeon_size += 2)
	full_strangeness_reached.connect($Win.play)

	block_strip_timer.timeout.connect(func():
		player.reduce_block(1)
		if player.block > 0:
			block_strip_timer.start()
	)
	player.increased_block.connect(func(block): block_strip_timer.start())
	spawn_timer.timeout.connect(func(): spawn_enemy(create_grubbler(Vector2())); spawn_timer.start())
	zombie_spawn_timer.timeout.connect(func(): spawn_enemy(create_zombie(get_random_empty_tile())); zombie_spawn_timer.start())
	scroll_timer.timeout.connect(func(): can_scroll = true)
	failed_to_exit_dungeon_timer.timeout.connect(func(): can_warn = true)
	torch_timer.timeout.connect(func():
		increase_torch_level(-1)
		torch_timer.start()
		#print("torch_level", torch_level)
	)

	texture_renderer = TextureRenderer.new(draw_strip_texture, player)
	generate_dungeon()
	exit_timer.timeout.connect(exit_dungeon)

	background_texture = load("res://sprites/background.png")
	item_textures[ItemType.LARGE_HEALTH_POTION] = load("res://sprites/health_potion.png")
	item_textures[ItemType.SMALL_HEALTH_POTION] = load("res://sprites/small_health_potion.png")
	item_textures[ItemType.STRANGE_DEBRIS] = load("res://sprites/strange_debris_small.png")
	item_textures[ItemType.KEY] = load("res://sprites/key.png")
	item_textures[ItemType.TORCH] = load("res://sprites/torch.png")

	wall_textures[MapGenerator.Tile.WALL] = load("res://sprites/wall2.png")
	wall_textures[MapGenerator.Tile.DOOR] = load("res://sprites/door.png")
	wall_textures[MapGenerator.Tile.TORCH_WALL] = load("res://sprites/wall3.png")

func generate_dungeon() -> void:
	var height = randi_range(min_dungeon_size, min_dungeon_size + 10)
	var width = randi_range(min_dungeon_size, min_dungeon_size + 10)
	var map_data = MapGenerator.new().generate(width, height)
	map = Map.new(map_data)
	pathfinder = PathFinder.new(map)
	map.debug_print()
	rotate_player(player.determine_angle_looking_into_open_corridor(map))
	spawn_items(map)
	spawn_enemies(map)
	fadeout = 0
	exitting = false
	exitted = false
	increase_torch_level(25)
	$UseTorch.play()
	player.position = Vector2(1.5, 1.5)

func spawn_enemies(map: Map) -> void:
	spawn_entity_of_type(150, create_grubbler, spawn_enemy)
	spawn_entity_of_type(85, create_zombie, spawn_enemy)
	
func spawn_items(map: Map) -> void:
	spawn_entity_of_type(25, create_torch, spawn_item)
	spawn_entity_of_type(200, create_key, spawn_item, 1)
	spawn_entity_of_type(80, create_potion, spawn_item)
	spawn_entity_of_type(25, create_strange_debris, spawn_item)

func spawn_entity_of_type(rarity_per_type: int, item_factory: Callable, item_consumer: Callable, min_count: int = 0) -> void:
	var tiles = map.width * map.height
	const factor = 1  # rarities were too low...
	var amount = ceil(1.0 * factor * tiles / rarity_per_type)
	var spawned = 0
	while spawned <= min_count:
		for i in amount:
			var position = Vector2(randi_range(1, map.width - 2), randi_range(1, map.height - 2))
			if map.get_tile(position) != MapGenerator.Tile.EMPTY:
				continue
			#print("item spawned at: ", position + Vector2(0, 0.5))
			var item = item_factory.call(position + Vector2(0.5, 0.5))
			item_consumer.call(item)
			spawned += 1
			if spawned > amount and spawned > min_count:
				break
	print("spawned in total: ", spawned, ". rarity: ", rarity_per_type)

func get_random_empty_tile() -> Vector2:
	while true:
		var position = Vector2(randi_range(1, map.width - 2), randi_range(1, map.height - 2))
		if map.get_tile(position) == MapGenerator.Tile.EMPTY:
			return position
	return Vector2()

func create_strange_debris(position: Vector2) -> Item:
	var item = Item.new(position, ItemType.STRANGE_DEBRIS, func(item): increase_strangeness(1))
	item.was_collected.connect($StrangeDebrisPickup.play)
	item.was_collected.connect(func(item): item.use())
	return item
	
func create_key(position: Vector2) -> Key:
	var key = Key.new(position, ItemType.KEY, start_exit_dungeon)
	key.was_collected.connect($KeyPickup.play)
	key.tried_to_use.connect($KeyUse.play)
	return key

func create_torch(position: Vector2) -> Item:
	var torch = Item.new(position, ItemType.TORCH, func(item): increase_torch_level(25))
	torch.was_collected.connect($PickupTorch.play)
	torch.was_used.connect($UseTorch.play)
	return torch

func create_potion(position: Vector2, big = null) -> Item:
	# only 30% chance it will be a big potion. overriden if big parameter is given
	var is_big = (big == null and 0.3 > randf()) or big
	var heal_amount = 50 if is_big else 20
	var type = ItemType.LARGE_HEALTH_POTION if is_big else ItemType.SMALL_HEALTH_POTION
	var potion = Item.new(position, type, func(item): player.heal(heal_amount))
	potion.was_collected.connect($PotionPickup.play)
	potion.was_used.connect($UsePotion.play)
	return potion

func create_grubbler(position: Vector2) -> Enemy:
	var grubbler_texture = load("res://sprites/grubbler.png")
	var dagger_texture = load("res://sprites/dagger.png")
	var grubbler_data = GrubblerData.new(grubbler_texture, dagger_texture)
	grubbler_data.just_attacked.connect($SmallSlam.play)
	grubbler_data.started_hunting.connect($GrubblerHunt.play)
	grubbler_data.started_attack.connect($GrubblerHunt.stop)
	grubbler_data.started_attack.connect($GrubblerAttack.play)
	#grubbler_data.state = GrubblerData.State.HUNTING
	return Enemy.new(position, grubbler_data)

func create_zombie(position: Vector2) -> Enemy:
	var texture = load("res://sprites/zombie.png")
	var zombie_data = ZombieData.new(texture, func(pos): return pathfinder.get_path(pos, player.position))
	zombie_data.just_attacked.connect($SmallSlam.play)
	return Enemy.new(position, zombie_data)

func spawn_enemy(enemy: Enemy) -> void:
	print("spawned enemy")
	enemies.append(enemy)
	enemy.died.connect(func(): enemy_killed.emit(enemy))
	enemy.died.connect($EnemyDeath.play)
	enemy.died.connect(increase_strangeness.bind(1))
	enemy.took_damage.connect(dealt_damage.emit)

func spawn_item(item: Item) -> void:
	items.append(item)
	item.was_collected.connect(item_collected.emit)
	item.was_collected.connect(player.pickup_left_hand_item)
	item.was_used.connect(item_used.emit)

func increase_strangeness(extra_strangeness: int) -> void:
	if not extra_strangeness:
		return
	strangeness += extra_strangeness
	if strangeness >= FULL_STRANGENESS:
		full_strangeness_reached.emit()
	increased_strangeness.emit(extra_strangeness)

func increase_torch_level(extra_torch: int):
	torch_level = clamp(torch_level + extra_torch, 10, 100)

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

		if not enemy.visible:
			print("invisible enemy")
			continue

		#if not has_line_of_sight(enemy.position):
			#print("no line of sight to enemy")
			#continue

		if distance_square < closest_distance:
			print("found target enemy")
			closest_distance = distance_square
			best_target = enemy

	if best_target:
		best_target.take_damage(player.weapon.damage, DamageType.PHYSICAL)
	elif can_exit:  # banging against door without target
		banged_against_door += 1
		if banged_against_door >= 3:
			player.take_damage(25, DamageType.PHYSICAL)
			start_exit_dungeon()

#func has_line_of_sight(target_pos: Vector2) -> bool:
	#var ray_dir = (target_pos - player.position).normalized()
	#var distance = player.position.distance_to(target_pos)
	#
	#var check_pos = player.position
	#var step = ray_dir * 0.1
	#
	#var traveled = 0.0
	#while traveled < distance:
		#check_pos += step
		#traveled += 0.1
		#
		#if is_wall(check_pos.x, check_pos.y):
			#return false
	#
	#return true

func _process(delta):
	var time = 1.0 * Time.get_ticks_msec() / 1000
	if exitting:
		fadeout = clamp(fadeout + delta, 0, 1)
	elif not player.alive:
		fadeout = clamp(fadeout + delta / 2.5, 0, 0.9)  # slower fadeout

	shader.set_shader_parameter("u_time", time)
	shader.set_shader_parameter("u_fadeout_time", fadeout)
	shader.set_shader_parameter("u_torch_level", (1.0 * torch_level) / 100)

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
	items = items.filter(func(x): return not x.used)
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
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
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
		player.use_left_hand_item()

	if Input.is_action_just_pressed("block"):
		player.use_shield()

	if Input.is_action_just_pressed("item_scroll_up") and can_scroll:
		lock_scroll()
		player.equip_next_left_hand_item()

	if Input.is_action_just_pressed("item_scroll_down") and can_scroll:
		lock_scroll()
		player.equip_previous_left_hand_item()

	if Input.is_action_just_pressed("display_help"):
		print("help")
		asked_to_display_help.emit()

func lock_scroll():
	can_scroll = false
	scroll_timer.start()

func rotate_player(angle):
	player.dir = player.dir.rotated(angle)
	camera_plane = camera_plane.rotated(angle)

func start_exit_dungeon(item: Item = null):
	if not can_exit:
		failed_to_exit_dungeon_no_door.emit()
		return

	if exitting:
		return

	exitting = true
	exit_timer.start()
	exitted_dungeon.emit()

	if item:
		item.used = true
		item.was_used.emit(item)

func exit_dungeon():
	if exitted:
		return
	increase_strangeness(dungeon_number)
	exitted = true
	print("exitted")
	#queue_free()

# returns the rect of actual screen coordinates drawn
func draw_strip_texture(sprite_pos: Vector2, texture: Texture2D, scale: float = 1.0) -> Rect2:
	scale = clamp(scale, 0, 1)
	if scale == 0:
		return Rect2()
	var inverse_scale = 1.0 / scale

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

		can_exit = false
		var door_pos = map_pos - player.position
		if texture_index == MapGenerator.Tile.DOOR and door_pos.length() < COLLECTION_DISTANCE * 4:
			can_exit = true
			var no_key_equipped = not player.left_hand_item or player.left_hand_item.type != ItemType.KEY
			if can_warn and no_key_equipped:
				can_warn = false
				var has_key = player.left_hand_items.any(func(x): return x.type == ItemType.KEY)
				var failure = failed_to_exit_dungeon_should_equip_key if has_key else failed_to_exit_dungeon_no_key
				failure.emit()
				failed_to_exit_dungeon_timer.start()

		var tex = wall_textures[texture_index] if texture_index != -1 else null
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
