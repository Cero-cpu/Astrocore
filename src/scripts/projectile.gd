extends Area2D

@export var speed: float = 600.0

enum Type { 
	SPREAD, RAPID, HEAVY, BURST, LIFE, SHIELD, MULTISHOT, SPEED, WAVE, BACKSHOT, CIRCLE, STREAK,
	SPIRAL, CROSS, ORBIT, TSUNAMI, GATLING, SNAKE
}

var direction: Vector2 = Vector2.UP
var skin_color: Color = Color(-1, -1, -1, -1) # Sentinel: -1 means "use random"
var _screen_size: Vector2

func _ready() -> void:
	add_to_group("player_projectiles")
	# Use skin color if set, otherwise fall back to random neon
	if skin_color.r >= 0:
		$Sprite2D.modulate = skin_color
	elif randi() % 2 == 0:
		$Sprite2D.modulate = Color(0.2, 1.5, 5, 1) # Glow Cyan Neon
	else:
		$Sprite2D.modulate = Color(5, 0.2, 1.5, 1) # Glow Pink Neon
	
	_screen_size = get_viewport_rect().size

func _process(delta: float) -> void:
	if is_in_group("wave_projectiles"):
		var time = Time.get_ticks_msec() / 1000.0
		var wave_x = sin(time * 10.0) * 10.0
		if has_meta("wave_flip"): wave_x *= -1
		position.x += wave_x
	elif is_in_group("snake_projectiles"):
		var time = Time.get_ticks_msec() / 1000.0
		var wave_x = cos(time * 20.0) * 20.0
		position.x += wave_x
	elif is_in_group("orbit_projectiles"):
		var center = get_meta("orbit_center")
		if is_instance_valid(center):
			var angle = get_meta("orbit_angle") + delta * 5.0
			set_meta("orbit_angle", angle)
			var offset = Vector2(120, 0).rotated(angle)
			global_position = center.global_position + offset
			return # Don't apply direction
	
	position += direction * speed * delta
	
	# High-performance dynamic cleanup for off-screen bounds
	if position.y < -150.0 or position.y > _screen_size.y + 150.0 or position.x < -150.0 or position.x > _screen_size.x + 150.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		area.take_damage(1)
		queue_free()
