extends "res://src/scripts/boss.gd"

func _ready() -> void:
	# Initialize Boss 2 specifics
	max_health = 600
	health = 600
	shoot_rate = 0.5 # Even faster
	
	add_to_group("enemies")
	add_to_group("boss")
	
	$Sprite2D.texture = preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/large_enemy_02.png")
	$Sprite2D.modulate = Color(0.2, 5, 2, 1) # Emerald Neon
	
	$HealthBar.max_value = max_health
	$HealthBar.value = health
	$HealthBar.visible = false
	
	var game = get_parent()
	if game and game.has_node("CanvasLayer/UI/BossUI"):
		var global_ui = game.get_node("CanvasLayer/UI/BossUI")
		var global_bar = global_ui.get_node("BossHP")
		global_bar.max_value = max_health
		global_bar.value = health
		global_ui.visible = true

func shoot() -> void:
	# Boss 2 has a deadly spiral pattern
	for i in range(12):
		var angle = i * 30 + (Time.get_ticks_msec() / 10.0)
		var p = projectile_scene.instantiate()
		p.global_position = global_position + Vector2(0, 40)
		p.speed = 220.0
		var dir = Vector2.DOWN.rotated(deg_to_rad(angle - 180))
		get_parent().add_child(p)
		p.direction = dir
		p.rotation = dir.angle() + PI/2
