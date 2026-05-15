extends Area2D

@export var min_speed: float = 100.0
@export var max_speed: float = 250.0

var explosion_scene: PackedScene = preload("res://explosion.tscn")
var enemy_projectile_scene: PackedScene = preload("res://enemy_projectile.tscn")
var hit_sound: AudioStream = preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/07 Retro Lazer #7.mp3")
var death_sound: AudioStream = preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/19 Retro Enemy Dying #1.mp3")

var sprites = [
	# Skyel Pack
	preload("res://Skyel Space Shooter - FREE/Enemy spaceships/spr_enemy_spaceship_01_static.png"),
	preload("res://Skyel Space Shooter - FREE/Enemy spaceships/spr_enemy_spaceship_02_static.png"),
	preload("res://Skyel Space Shooter - FREE/Enemy spaceships/spr_enemy_spaceship_03_static.png"),
	preload("res://Skyel Space Shooter - FREE/Asteroids/spr_asteroid_01.png"),
	preload("res://Skyel Space Shooter - FREE/Asteroids/spr_asteroid_02.png"),
	preload("res://Skyel Space Shooter - FREE/Asteroids/spr_asteroid_03.png"),
	# Pixel SHMUP Pack
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_1_1.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_1_2.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_1_3.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_2_1.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_2_2.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_2_3.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/red_01.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/blue_01.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/green_06.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/orange_03.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/purple_03.png")
]

var health: int = 1
var speed: float = 0.0
var rotation_speed: float = 0.0
var is_asteroid: bool = false
var _screen_height: float

var shoot_timer: float = 0.0
var can_shoot: bool = false

func _ready() -> void:
	_screen_height = get_viewport_rect().size.y
	
	# Random sprite
	var tex = sprites[randi() % sprites.size()]
	$Sprite2D.texture = tex
	
	# Asteroid tumbling
	is_asteroid = "asteroid" in tex.resource_path
	if is_asteroid:
		rotation_speed = randf_range(-2.0, 2.0)
		var s = randf_range(0.8, 1.2)
		scale = Vector2(s, s)
	
	# Speed scales with time
	var time_bonus: float = 0.0
	var game_node = get_parent()
	if game_node and "game_time" in game_node:
		time_bonus = game_node.game_time * 2.0
		
	speed = randf_range(min_speed, max_speed) + time_bonus
	add_to_group("enemies")
	
	# Neon enemy colors
	$Sprite2D.modulate = Color(randf_range(1.0, 2.0), randf_range(0.1, 0.3), randf_range(1.0, 3.0))
	
	# Only ships shoot, not asteroids
	if not is_asteroid:
		can_shoot = true
		shoot_timer = randf_range(1.0, 5.0)

func _process(delta: float) -> void:
	position.y += speed * delta
	if rotation_speed != 0.0:
		$Sprite2D.rotation += rotation_speed * delta
		
	# Enemy shooting logic (low difficulty)
	if can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot()
			shoot_timer = randf_range(3.0, 6.0) # Low frequency
			
	if position.y > _screen_height + 100:
		queue_free()

func shoot() -> void:
	if not is_instance_valid(get_parent()): return
	var p = enemy_projectile_scene.instantiate()
	p.global_position = global_position + Vector2(0, 30)
	p.speed = 300.0 # Slow enough to dodge
	get_parent().add_child(p)

func _play_sfx(stream: AudioStream) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = -5.0
	get_parent().add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func take_damage(amount: int) -> void:
	health -= amount
	if health > 0:
		_play_sfx(hit_sound)
		var tween = create_tween()
		tween.tween_property($Sprite2D, "modulate:v", 10.0, 0.05)
		tween.tween_property($Sprite2D, "modulate:v", 1.0, 0.05)
		return
		
	# Spawn explosion
	_play_sfx(death_sound)
	var exp_inst = explosion_scene.instantiate()
	exp_inst.global_position = global_position
	get_parent().add_child(exp_inst)
	
	if get_parent().has_method("on_enemy_killed"):
		get_parent().on_enemy_killed()
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if area.has_method("take_damage"):
			var dmg: int = 10 if is_asteroid else 15
			area.take_damage(dmg)
		queue_free()
