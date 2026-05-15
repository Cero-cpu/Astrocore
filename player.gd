extends Area2D

@export var speed: float = 400.0
@export var projectile_scene: PackedScene = preload("res://projectile.tscn")
var hurt_sound: AudioStream = preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/13 Retro Space Alarm #5.mp3")
var death_sound: AudioStream = preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/16 Retro Explosion #3.mp3")

var health: int = 100
var max_health: int = 100
var is_invincible: bool = false
var invincibility_time: float = 1.0
var flicker_timer: float = 0.0

var shoot_timer: float = 0.0
var fire_rate: float = 0.5
var base_speed: float = 400.0
var burst_count: int = 1
var evolution_level: int = 1

enum WeaponStyle { 
	NORMAL, SPREAD, RAPID, HEAVY, BURST, MULTISHOT, WAVE, BACKSHOT, CIRCLE, STREAK,
	SPIRAL, CROSS, ORBIT, TSUNAMI, GATLING, SNAKE
}
var current_style: WeaponStyle = WeaponStyle.NORMAL
var style_timer: float = 0.0
var shield_timer: float = 0.0
var speed_boost_timer: float = 0.0
var is_shielded: bool = false
var touch_pos: Vector2 = Vector2.ZERO
var is_touching: bool = false
var spiral_angle: float = 0.0

# Cache references
var _screen_width: float

func _ready() -> void:
	add_to_group("player")
	var screen_size = get_viewport_rect().size
	_screen_width = screen_size.x
	position = Vector2(_screen_width / 2, screen_size.y - 100)
	
	# Custom neon color to make the ship unique
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = _create_recolor_shader()
	$AnimatedSprite2D.material = shader_mat

func _create_recolor_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Convert to grayscale then recolor with cyan-magenta neon
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	
	// Neon cyan body with magenta highlights
	vec3 neon_color;
	if (gray > 0.6) {
		// Bright parts -> hot cyan/white
		neon_color = mix(vec3(0.0, 2.0, 2.5), vec3(2.0, 2.0, 3.0), gray);
	} else if (gray > 0.3) {
		// Mid tones -> electric blue
		neon_color = mix(vec3(0.1, 0.4, 2.0), vec3(0.0, 2.0, 2.5), (gray - 0.3) / 0.3);
	} else {
		// Dark parts -> deep purple
		neon_color = mix(vec3(0.2, 0.0, 0.5), vec3(0.1, 0.4, 2.0), gray / 0.3);
	}
	
	COLOR = vec4(neon_color * tex.a, tex.a);
}
"""
	return shader

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		is_touching = event.pressed
		if is_touching:
			touch_pos = event.position
	elif event is InputEventScreenDrag:
		touch_pos = event.position

func _process(delta: float) -> void:
	# 1. Combined Movement Logic
	var input_vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var target_pos = position
	
	if is_touching:
		# Direct finger follow with offset so the finger doesn't hide the ship
		target_pos = touch_pos + Vector2(0, -100)
	else:
		target_pos += input_vec * base_speed * delta
	
	# Smooth LERP for fluid movement
	position = position.lerp(target_pos, 0.25)
	
	# Apply visual effects (Speed boost)
	if speed_boost_timer > 0:
		speed_boost_timer -= delta
		if int(Time.get_ticks_msec() / 100.0) % 2 == 0:
			$AnimatedSprite2D.modulate = Color(0.5, 2, 5, 1)
		else:
			$AnimatedSprite2D.modulate = Color(1, 1, 1, 1)
	elif not is_shielded:
		$AnimatedSprite2D.modulate = Color(1, 1, 1, 1)
	
	# Clamp to screen
	var screen_size = get_viewport_rect().size
	position.x = clamp(position.x, 32, screen_size.x - 32)
	position.y = clamp(position.y, 32, screen_size.y - 32)
	
	# Animation based on relative movement
	var move_diff = target_pos.x - position.x
	if move_diff < -10:
		$AnimatedSprite2D.play("left")
	elif move_diff > 10:
		$AnimatedSprite2D.play("right")
	else:
		$AnimatedSprite2D.play("idle")
	
	# Style timer (styles are temporary)
	if current_style != WeaponStyle.NORMAL:
		style_timer -= delta
		if style_timer <= 0:
			current_style = WeaponStyle.NORMAL
			fire_rate = 0.5
			burst_count = evolution_level
	
	# Shooting logic
	shoot_timer -= delta
	if shoot_timer <= 0:
		if get_tree().get_nodes_in_group("player_projectiles").size() < 150: # Increased cap
			shoot()
		
		# Dynamic fire rate
		var base_rate = fire_rate
		match current_style:
			WeaponStyle.RAPID, WeaponStyle.GATLING: base_rate *= 0.2
			WeaponStyle.SPIRAL, WeaponStyle.CROSS: base_rate *= 0.15
			WeaponStyle.TSUNAMI: base_rate *= 2.0
		
		shoot_timer = max(0.03, base_rate / 3.0)
	
	# Spiral rotation
	spiral_angle += delta * 15.0
		
	# Shield logic
	if is_shielded:
		shield_timer -= delta
		# Visual shield effect (rapid flicker or color change)
		$AnimatedSprite2D.modulate = Color(2, 2, 5, 1) if int(Time.get_ticks_msec() / 50.0) % 2 == 0 else Color(1, 1, 1, 1)
		if shield_timer <= 0:
			is_shielded = false
			$AnimatedSprite2D.modulate = Color(1, 1, 1, 1)
	
	# Invincibility flicker
	if is_invincible and not is_shielded:
		flicker_timer += delta * 20.0
		$AnimatedSprite2D.visible = int(flicker_timer) % 2 == 0
	elif not $AnimatedSprite2D.visible:
		$AnimatedSprite2D.visible = true

func shoot() -> void:
	$LaserSound.play()
	match current_style:
		WeaponStyle.NORMAL:
			_spawn_projectile(Vector2.ZERO)
		WeaponStyle.SPREAD:
			for i in range(3 + evolution_level):
				var angle = (i - 1) * 15.0
				_spawn_projectile(Vector2.ZERO, Vector2.UP.rotated(deg_to_rad(angle)))
		WeaponStyle.RAPID:
			_spawn_projectile(Vector2(randf_range(-5, 5), 0))
		WeaponStyle.HEAVY:
			var p = _spawn_projectile(Vector2.ZERO)
			p.scale = Vector2(3, 3)
			p.modulate = Color(5, 5, 0) # Golden
		WeaponStyle.BURST:
			for i in range(8):
				var angle = i * 45.0
				_spawn_projectile(Vector2.ZERO, Vector2.UP.rotated(deg_to_rad(angle)))
		WeaponStyle.MULTISHOT:
			_spawn_projectile(Vector2(-15, 0))
			_spawn_projectile(Vector2(15, 0))
		WeaponStyle.WAVE:
			for i in range(2):
				var p = _spawn_projectile(Vector2.ZERO)
				p.add_to_group("wave_projectiles")
				if i == 1: p.set_meta("wave_flip", true)
		WeaponStyle.BACKSHOT:
			_spawn_projectile(Vector2.ZERO, Vector2.UP)
			_spawn_projectile(Vector2.ZERO, Vector2.DOWN)
			_spawn_projectile(Vector2(-20, 0), Vector2.UP)
			_spawn_projectile(Vector2(20, 0), Vector2.UP)
		WeaponStyle.CIRCLE:
			for i in range(12):
				var angle = i * 30.0
				_spawn_projectile(Vector2.ZERO, Vector2.UP.rotated(deg_to_rad(angle)))
		WeaponStyle.STREAK:
			for i in range(5):
				if not is_inside_tree(): break
				_spawn_projectile(Vector2.ZERO)
				await get_tree().create_timer(0.05, false).timeout
		WeaponStyle.SPIRAL:
			for i in range(2):
				var angle = spiral_angle + (i * 180.0)
				_spawn_projectile(Vector2.ZERO, Vector2.UP.rotated(angle))
		WeaponStyle.CROSS:
			for i in range(4):
				var angle = spiral_angle + (i * 90.0)
				_spawn_projectile(Vector2.ZERO, Vector2.UP.rotated(angle))
		WeaponStyle.ORBIT:
			var p = _spawn_projectile(Vector2.ZERO)
			p.add_to_group("orbit_projectiles")
			p.set_meta("orbit_center", self)
			p.set_meta("orbit_angle", randf() * TAU)
		WeaponStyle.TSUNAMI:
			for i in range(10):
				var p = _spawn_projectile(Vector2((i - 5) * 40, 0))
				p.scale = Vector2(4, 1)
				p.modulate = Color(0, 1, 5, 1) # Deep blue
		WeaponStyle.GATLING:
			var spread = deg_to_rad(randf_range(-15, 15))
			_spawn_projectile(Vector2.ZERO, Vector2.UP.rotated(spread))
		WeaponStyle.SNAKE:
			var p = _spawn_projectile(Vector2.ZERO)
			p.add_to_group("snake_projectiles")

func _spawn_projectile(offset: Vector2, dir: Vector2 = Vector2.UP) -> Area2D:
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position + Vector2(0, -20) + offset
	if "direction" in proj: # Ensure projectile.gd has direction
		proj.direction = dir
	get_parent().add_child(proj)
	return proj

func apply_powerup(type: int) -> void:
	# PowerUp.Type enum mapping
	# SPREAD=0, RAPID=1, HEAVY=2, BURST=3, LIFE=4, SHIELD=5, MULTISHOT=6, SPEED=7, WAVE=8, BACKSHOT=9, CIRCLE=10
	
	_play_sfx(preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/22 Retro Space Power Up #1.mp3"))
	
	# Visual evolution (More subtle scaling: max 20% larger)
	evolution_level = min(5, evolution_level + 1)
	scale = Vector2(1.0, 1.0) + Vector2(0.04, 0.04) * evolution_level
	
	match type:
		0, 1, 2, 3, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17:
			style_timer = 15.0 # More time for crazy patterns
			match type:
				0: current_style = WeaponStyle.SPREAD
				1: current_style = WeaponStyle.RAPID
				2: current_style = WeaponStyle.HEAVY
				3: current_style = WeaponStyle.BURST
				6: current_style = WeaponStyle.MULTISHOT
				8: current_style = WeaponStyle.WAVE
				9: current_style = WeaponStyle.BACKSHOT
				10: current_style = WeaponStyle.CIRCLE
				11: current_style = WeaponStyle.STREAK
				12: current_style = WeaponStyle.SPIRAL
				13: current_style = WeaponStyle.CROSS
				14: current_style = WeaponStyle.ORBIT
				15: current_style = WeaponStyle.TSUNAMI
				16: current_style = WeaponStyle.GATLING
				17: current_style = WeaponStyle.SNAKE
		4: # LIFE
			health = min(max_health, health + 40)
		5: # SHIELD
			is_shielded = true
			shield_timer = 8.0
		7: # SPEED
			speed_boost_timer = 10.0
	
	# Update UI
	var game = get_parent()
	if game and game._player_hp:
		game._player_hp.value = health

func _play_sfx(stream: AudioStream) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = -3.0
	get_parent().add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func take_damage(amount: int = 10) -> void:
	if is_invincible:
		return
		
	health -= amount
	is_invincible = true
	flicker_timer = 0.0
	_play_sfx(hurt_sound)
	
	var game = get_parent()
	if game and game._player_hp:
		game._player_hp.value = health
	
	# Hit-stop effect
	Engine.time_scale = 0.1
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0
	
	# Screen shake
	if game and game.has_method("shake_screen"):
		game.shake_screen(0.2, 5.0)
	
	if health <= 0:
		_play_sfx(death_sound)
		queue_free()
	else:
		await get_tree().create_timer(invincibility_time).timeout
		if is_instance_valid(self):
			is_invincible = false
			$AnimatedSprite2D.visible = true

func upgrade_fire_rate(new_rate: float) -> void:
	fire_rate = max(0.1, new_rate)

func upgrade_burst(new_count: int) -> void:
	burst_count = new_count
