extends CanvasLayer

const Dungeon = preload("res://dungeon.tscn")
const Consts = preload("res://consts.gd")
const Item = preload("res://item.gd")

const TOP_LEFT = Vector2(150, 150)
const TOP_RIGHT = Vector2(Consts.SCREEN_WIDTH - 300, 150)
const MIDDLE = Vector2(Consts.SCREEN_WIDTH / 2, Consts.SCREEN_HEIGHT * 2 / 3)
const OFFSET = Vector2(0, 10)

@onready var font = preload("res://fonts/Tiny5-Regular.ttf")

@onready var ray_tracer = $"../SubViewport/Dungeon"

func spawn_floating_text(text: String, position: Vector2, size: int):
	var label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_font_override("font", font)

	var tween = create_tween()
	const duration = 1
	tween.tween_property(label, "position:y", position.y - 100, duration * 2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration)
	tween.finished.connect(label.queue_free)
	return label

func _ready():
	ray_tracer.took_damage.connect(func(damage):
		add_child(
			spawn_floating_text("Took %s damage!" % int(damage), MIDDLE, 30)
		)
	)

	ray_tracer.blocked_damage.connect(func(damage):
		add_child(
			spawn_floating_text("Blocked %s damage!" % int(damage), MIDDLE + OFFSET, 30)
		)
	)

	ray_tracer.increased_block.connect(func(block):
		add_child(
			spawn_floating_text("Block %s!" % int(block), TOP_RIGHT, 30)
		)
	)

	ray_tracer.player_healed.connect(func(hp):
		add_child(
			spawn_floating_text("Healed %s HP!" % int(hp), MIDDLE, 30)
		)
	)

	ray_tracer.dealt_damage.connect(func(damage):
		add_child(
			spawn_floating_text("Dealt %s damage!" % int(damage), TOP_LEFT, 30)
		)
	)

	ray_tracer.player_rooted.connect(func():
		add_child(
			spawn_floating_text("Rooted...", MIDDLE, 30)
		)
	)

	ray_tracer.player_died.connect(func():
		add_child(
			spawn_floating_text("Died...", MIDDLE, 30)
		)
	)

	ray_tracer.failed_to_attack_due_to_no_weapon.connect(func():
		add_child(
			spawn_floating_text("No weapon!", TOP_LEFT + OFFSET, 30)
		)
	)

	ray_tracer.failed_to_use_no_item_equipped.connect(func():
		add_child(
			spawn_floating_text("No item equipped!", TOP_LEFT + OFFSET, 30)
		)
	)

	ray_tracer.failed_to_block_due_to_missing_shield.connect(func():
		add_child(
			spawn_floating_text("No shield!", TOP_RIGHT + OFFSET, 30)
		)
	)

	ray_tracer.failed_to_attack_due_to_cooldown.connect(func():
		add_child(
			spawn_floating_text("Attack on cooldown...", TOP_LEFT + OFFSET, 30)
		)
	)

	ray_tracer.failed_to_block_due_to_cooldown.connect(func():
		add_child(
			spawn_floating_text("Block on cooldown...", TOP_RIGHT + OFFSET, 30)
		)
	)

	ray_tracer.failed_to_exit_dungeon_should_equip_key.connect(func():
		add_child(
			spawn_floating_text("Equip key to exit!", MIDDLE, 30)
		)
	)

	ray_tracer.failed_to_exit_dungeon_no_key.connect(func():
		add_child(
			spawn_floating_text("No key!", MIDDLE, 30)
		)
	)

	ray_tracer.failed_to_exit_dungeon_no_door.connect(func():
		add_child(
			spawn_floating_text("No door!", MIDDLE, 30)
		)
	)

	ray_tracer.item_collected.connect(func(item: Item):
		add_child(
			spawn_floating_text("Collected %s!" % item.get_item_name(), MIDDLE, 30)
		)
	)

	ray_tracer.item_used.connect(func(item: Item):
		add_child(
			spawn_floating_text("Used %s..." % item.get_item_name(), TOP_LEFT, 30)
		)
	)

	ray_tracer.exitted_dungeon.connect(func():
		add_child(
			spawn_floating_text("Exited...", MIDDLE, 30)
		)
	)
