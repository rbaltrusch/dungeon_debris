class_name TextureRenderer

const Player = preload("res://scripts/player.gd")

# takes params texture: Vector2, Texture2D, float, returns Rect2
var render_fn: Callable
var player: Player

func _init(render_fn: Callable, player: Player):
	self.render_fn = render_fn
	self.player = player

func render(texture: Texture2D, position: Vector2, scale: float = 1.0) -> Rect2:
	return render_fn.call(position - player.position, texture, scale)
