extends Area2D

enum Type { 
	SPREAD, RAPID, HEAVY, BURST, LIFE, SHIELD, MULTISHOT, SPEED, WAVE, BACKSHOT, CIRCLE, STREAK,
	SPIRAL, CROSS, ORBIT, TSUNAMI, GATLING, SNAKE
}

var type: Type
var speed: float = 150.0
var _screen_height: float

func _ready() -> void:
	_screen_height = get_viewport_rect().size.y
	# Type is assigned by game.gd to avoid repeats, but fallback here
	if type == null: type = Type.values()[randi() % Type.size()]
	
	# Visuals based on type
	var color: Color
	match type:
		Type.SPREAD: color = Color(0.1, 0.8, 5, 1) # Cyan
		Type.RAPID: color = Color(5, 0.1, 0.8, 1) # Pink
		Type.HEAVY: color = Color(5, 0.8, 0.1, 1) # Gold
		Type.BURST: color = Color(0.8, 0.1, 5, 1) # Purple
		Type.LIFE: color = Color(0.1, 5, 0.1, 1) # Green
		Type.SHIELD: color = Color(5, 5, 5, 1) # White
		Type.MULTISHOT: color = Color(5, 0.5, 0.1, 1) # Orange
		Type.SPEED: color = Color(0.1, 5, 5, 1) # Electric Blue
		_: # Others get random neon colors
			color = Color(randf_range(1, 5), randf_range(1, 5), randf_range(1, 5), 1)
	
	# Since sprites are red, we use a shader to replace Red with our target color
	var mat = ShaderMaterial.new()
	mat.shader = _create_recolor_shader()
	mat.set_shader_parameter("target_color", color)
	$AnimatedSprite2D.material = mat
	
	# Add a pulse effect
	var tween = create_tween().set_loops()
	tween.tween_property($AnimatedSprite2D, "scale", Vector2(4.0, 4.0), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property($AnimatedSprite2D, "scale", Vector2(3.0, 3.0), 0.6).set_trans(Tween.TRANS_SINE)

func _create_recolor_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 target_color : source_color;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	if (tex.a > 0.1) {
		COLOR = vec4(target_color.rgb * (luma * 2.0), tex.a);
	} else {
		COLOR = tex;
	}
	COLOR.rgb *= 1.5 + sin(TIME * 5.0) * 0.5;
}
"""
	return shader

func _process(delta: float) -> void:
	position.y += speed * delta
	if position.y > _screen_height + 100:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if area.has_method("apply_powerup"):
			area.apply_powerup(type)
		queue_free()
