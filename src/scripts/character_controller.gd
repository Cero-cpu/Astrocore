extends CharacterBody2D
class_name PlayerController

@export_group("Movement Settings")
@export var SPEED = 300.0
@export var JUMP_VELOCITY = -450.0
@export var ACCELERATION = 1200.0
@export var FRICTION = 1000.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking = false

func _ready():
	# Configuración inicial de la cámara
	if camera:
		camera.make_current()
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.0
	
	# Conectar señal de animación
	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	# Aplicar Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta

	# Lógica de Ataque
	if Input.is_action_just_pressed("attack") and not is_attacking:
		perform_attack()

	# Lógica de Movimiento (Solo si no está atacando)
	if not is_attacking:
		# Salto (W / jump)
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		# Dirección (A/D o move_left/move_right)
		var direction = Input.get_axis("move_left", "move_right")
		
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
			sprite.flip_h = direction < 0 # Voltear sprite correctamente
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		
		update_animations(direction)

	move_and_slide()

func update_animations(direction):
	if not is_on_floor():
		sprite.play("jump")
	elif direction != 0:
		sprite.play("walk")
	else:
		sprite.play("idle")

func perform_attack():
	is_attacking = true
	velocity.x = 0 # El personaje se queda quieto al atacar
	sprite.play("attack")

func _on_animation_finished():
	# Volver al estado normal cuando termine la animación de ataque
	if sprite.animation == "attack":
		is_attacking = false
