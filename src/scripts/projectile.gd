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
	
	# Initial spawn stretch effect (Juice!)
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
	particles.amount = 12
	particles.lifetime = 0.15
	particles.local_coords = false
	particles.gravity = Vector2.ZERO
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 4.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = $Sprite2D.modulate
	var color_ramp = Gradient.new()
	color_ramp.set_color(0, Color(1, 1, 1, 0.7))
	color_ramp.set_color(1, Color(1, 1, 1, 0.0))
	particles.color_ramp = color_ramp
	particles.z_index = z_index - 1
	add_child(particles)
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
	if position.y < -30.0 or position.y > _screen_size.y + 100.0 or position.x < -50.0 or position.x > _screen_size.x + 50.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		# Prevent killing enemies before they enter the screen!
		if area.position.y < 10.0:
			return 
			
		area.take_damage(1)
		queue_free()
