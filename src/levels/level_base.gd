extends Node2D

@export var scroll_speed: float = 10.0

func _ready() -> void:
	# Make background fill screen dynamically
	var screen_size = get_viewport_rect().size
	$Background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Background.offset_left = -200
	$Background.offset_right = 200
	
	if has_node("BackgroundTex"):
		$BackgroundTex.centered = true
		$BackgroundTex.position = screen_size / 2
		$BackgroundTex.region_enabled = true
		$BackgroundTex.region_rect = Rect2(Vector2.ZERO, screen_size * 1.5)

func _process(delta: float) -> void:
	if get_tree().paused: return
	if has_node("BackgroundTex"):
		$BackgroundTex.region_rect.position.y -= delta * scroll_speed
