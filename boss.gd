extends Area2D

@export var health: int = 25
@export var max_health: int = 25
@export var shoot_rate: float = 1.0
var shoot_timer: float = 0.0

@export var projectile_scene: PackedScene = preload("res://enemy_projectile.tscn")
@export var explosion_scene: PackedScene = preload("res://explosion_pixel.tscn")

var target_y = 120
var moving_right = true
var speed = 150
var texture_to_set: Texture2D = null

func _ready() -> void:
	if texture_to_set:
		$Sprite2D.texture = texture_to_set
	add_to_group("enemies")
	add_to_group("boss")
	
	var game = get_parent()
	if game and "boss_stage" in game:
		if game.boss_stage == 2:
			max_health = 500
			health = 500
			shoot_rate = 0.6 # Faster
			$Sprite2D.modulate = Color(0.5, 5, 2, 1) # Green neon
		else:
			max_health = 200
			health = 200
			$Sprite2D.modulate = Color(2, 0.5, 5, 1) # Purple neon
			
	$HealthBar.max_value = max_health
	$HealthBar.value = health
	$HealthBar.visible = false # Hide local bar
	
	if game and game.has_node("CanvasLayer/UI/BossUI"):
		var global_ui = game.get_node("CanvasLayer/UI/BossUI")
		var global_bar = global_ui.get_node("BossHP")
		global_bar.max_value = max_health
		global_bar.value = health
		global_ui.visible = true

func _process(delta: float) -> void:
	# Move to position
	if position.y < target_y:
		position.y += speed * delta
	else:
		# Horizontal movement
		var screen_width = get_viewport_rect().size.x
		if moving_right:
			position.x += speed * delta
			if position.x > screen_width - 80: moving_right = false
		else:
			position.x -= speed * delta
			if position.x < 80: moving_right = true
			
		# Shooting
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot()
			shoot_timer = shoot_rate

func shoot() -> void:
	var game = get_parent()
	var is_stage_2 = game and "boss_stage" in game and game.boss_stage == 2
	
	if is_stage_2:
		# Circular spray for Boss 2
		for angle in range(0, 181, 30):
			var p = projectile_scene.instantiate()
			p.global_position = global_position + Vector2(0, 50)
			p.speed = 250.0
			var dir = Vector2.DOWN.rotated(deg_to_rad(angle - 90))
			get_parent().add_child(p)
			p.direction = dir
			p.rotation = dir.angle() + PI/2 # Rotate sprite to face direction
	else:
		# Triple shot for Boss 1
		for i in [-1, 0, 1]:
			var p = projectile_scene.instantiate()
			p.global_position = global_position + Vector2(i * 40, 50)
			get_parent().add_child(p)

func take_damage(amount: int) -> void:
	health -= amount
	var game = get_parent()
	if game and game.has_node("CanvasLayer/UI/BossUI/BossHP"):
		game.get_node("CanvasLayer/UI/BossUI/BossHP").value = health
	
	# Flash effect
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate:v", 10.0, 0.05)
	tween.tween_property($Sprite2D, "modulate:v", 1.0, 0.05)
	
	if health <= 0:
		die()

func die() -> void:
	var exp = explosion_scene.instantiate()
	exp.global_position = global_position
	exp.scale = Vector2(10, 10) # Massive explosion
	get_parent().add_child(exp)
	
	if get_parent().has_node("CanvasLayer/UI/BossUI"):
		get_parent().get_node("CanvasLayer/UI/BossUI").visible = false
		
	if get_parent().has_method("on_boss_killed"):
		get_parent().on_boss_killed()
	queue_free()
