extends Area2D

@export var speed: float = 400.0
@export var damage: int = 1
var direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	$Sprite2D.modulate = Color(5, 0.1, 0.1, 1) # Red neon
	add_to_group("enemy_projectiles")

func _process(delta: float) -> void:
	position += direction * speed * delta
	# Clean up off-screen projectiles (Dynamic based on screen size)
	var screen_size = get_viewport_rect().size
	if position.y > screen_size.y + 100 or position.y < -100 or position.x < -100 or position.x > screen_size.x + 100:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if area.has_method("take_damage"):
			area.take_damage(20)
		queue_free()
