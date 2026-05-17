extends Sprite2D

func _ready() -> void:
	hframes = 8 # Assumption for a strip
	var tween = create_tween()
	tween.tween_property(self, "frame", 7, 0.4)
	tween.finished.connect(queue_free)
	
	modulate = Color(2, 1, 0.5, 1) # Glowing explosion
	scale = Vector2(4, 4)
	
	# Small impact shake
	var game = get_parent()
	if game and game.has_method("shake_screen"):
		game.shake_screen(0.1, 3.0)
