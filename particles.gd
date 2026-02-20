extends CanvasLayer

const RayTracer = preload("res://raytracer.gd")
const Dungeon = preload("res://dungeon.tscn")

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
			spawn_floating_text("Took %s damage!" % damage, Vector2(150, 150), 30)
		)
	)

	ray_tracer.blocked_damage.connect(func(damage):
		add_child(
			spawn_floating_text("Blocked %s damage!" % damage, Vector2(150, 150), 30)
		)
	)

	ray_tracer.increased_block.connect(func(block):
		add_child(
			spawn_floating_text("Block %s!" % block, Vector2(150, 150), 30)
		)
	)

	ray_tracer.dealt_damage.connect(func(damage):
		add_child(
			spawn_floating_text("Dealt %s damage!" % damage, Vector2(150, 150), 30)
		)
	)

	ray_tracer.player_rooted.connect(func():
		add_child(
			spawn_floating_text("Rooted...", Vector2(150, 150), 30)
		)
	)

	ray_tracer.player_died.connect(func():
		add_child(
			spawn_floating_text("Died...", Vector2(150, 150), 30)
		)
	)

	ray_tracer.failed_to_attack_due_to_no_weapon.connect(func():
		add_child(
			spawn_floating_text("No weapon!", Vector2(150, 150), 30)
		)
	)

	ray_tracer.failed_to_block_due_to_missing_shield.connect(func():
		add_child(
			spawn_floating_text("No shield!", Vector2(150, 150), 30)
		)
	)

	ray_tracer.failed_to_attack_due_to_cooldown.connect(func():
		add_child(
			spawn_floating_text("Attack on cooldown...", Vector2(150, 150), 30)
		)
	)

	ray_tracer.failed_to_block_due_to_cooldown.connect(func():
		add_child(
			spawn_floating_text("Block on cooldown...", Vector2(150, 150), 30)
		)
	)

	ray_tracer.exitted_dungeon.connect(func():
		add_child(
			spawn_floating_text("Exited...", Vector2(150, 150), 30)
		)
	)
