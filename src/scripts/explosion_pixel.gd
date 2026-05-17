extends Sprite2D

func _ready():
	hframes = 8
	var tween = create_tween()
	# Animate frames from 0 to 7
	tween.tween_property(self, "frame", 7, 0.4)
	tween.finished.connect(queue_free)
	modulate = Color(2, 1.5, 0.5, 1) # Glowing effect
