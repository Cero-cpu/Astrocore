extends Area2D

@export var speed: float = 400.0
@export var damage: int = 1
var direction: Vector2 = Vector2.DOWN
var _screen_size: Vector2

func _ready() -> void:
	$Sprite2D.modulate = Color(5, 0.1, 0.1, 1) # Red neon
	add_to_group("enemy_projectiles")
	_screen_size = get_viewport_rect().size
	
	# Spawn squash and stretch
	var original_scale = $Sprite2D.scale
	$Sprite2D.scale = original_scale * Vector2(0.3, 1.8)
	var tween = create_tween()
	tween.tween_property($Sprite2D, "scale", original_scale, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# --- Shader de Luz Pequeño y Sombra ---
	var smat = ShaderMaterial.new()
	smat.shader = preload("res://src/shaders/aura.gdshader")
	smat.set_shader_parameter("aura_color", $Sprite2D.modulate)
	$Sprite2D.material = smat
	
	# --- Creative Particle Trail ---
	var particles = CPUParticles2D.new()
	particles.amount = 10
	particles.lifetime = 0.2
	particles.local_coords = false
	particles.gravity = Vector2.ZERO
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 5.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = $Sprite2D.modulate
	var color_ramp = Gradient.new()
	color_ramp.set_color(0, Color(1, 1, 1, 0.8))
	color_ramp.set_color(1, Color(1, 1, 1, 0.0))
	particles.color_ramp = color_ramp
	particles.z_index = z_index - 1
	add_child(particles)
func _process(delta: float) -> void:
	position += direction * speed * delta
	
	# Clean up off-screen projectiles (Highly optimized)
	if position.y > _screen_size.y + 100.0 or position.y < -100.0 or position.x < -100.0 or position.x > _screen_size.x + 100.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if area.has_method("take_damage"):
			area.take_damage(20)
		queue_free()
