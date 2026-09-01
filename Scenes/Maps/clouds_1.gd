extends Sprite2D

@export var speed: float = 20.0
@export var left_limit: float = -500.0
@export var right_limit: float = 2500.0

func _process(delta):
	position.x += speed * delta

	if position.x > right_limit:
		position.x = left_limit
