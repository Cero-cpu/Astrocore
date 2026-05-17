extends CharacterBody2D

@export var SPEED = 100.0
@export var direction = 1

@onready var sprite = $AnimatedSprite2D
@onready var ray_cast = $RayCast2D

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Movimiento horizontal
	velocity.x = direction * SPEED
	
	# Girar si choca con una pared o llega a un borde
	if is_on_wall() or not ray_cast.is_colliding():
		direction *= -1
		ray_cast.position.x *= -1 # Mover el rayo al otro lado
	
	# Actualizar Sprite
	sprite.flip_h = direction > 0 # Ajusta esto según cómo esté dibujado tu sprite
	if sprite.sprite_frames.has_animation("caminar"):
		sprite.play("caminar")
	
	move_and_slide()
