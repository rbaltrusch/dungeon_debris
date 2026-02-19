class_name TextureRenderer

const Player = preload("res://player.gd")

# takes params texture: Vector2, Texture2D
var render_fn: Callable
var player: Player

func _init(render_fn: Callable, player: Player):
	self.render_fn = render_fn
	self.player = player

func render(texture: Texture2D, position: Vector2):
	render_fn.call(position - player.position, texture)
