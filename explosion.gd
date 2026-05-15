extends Sprite2D

func _ready() -> void:
	hframes = 8 # Assumption for a strip
	var tween = create_tween()
	tween.tween_property(self, "frame", 7, 0.4)
	tween.finished.connect(queue_free)
	
	modulate = Color(2, 1, 0.5, 1) # Glowing explosion
	scale = Vector2(4, 4)
