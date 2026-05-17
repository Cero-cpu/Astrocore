extends Area2D
class_name Player

@export var speed: float = 400.0
@export var projectile_scene: PackedScene = preload("res://src/scenes/projectile.tscn")
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

# Skin system
static var selected_skin_path: String = ""
var projectile_color: Color = Color(0.1, 0.8, 5, 1) # Default: cyan

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
	
	# Restore last selected skin if any
	if selected_skin_path != "":
		set_skin(selected_skin_path)
	
	# Ensure continuous shooting sound is strategically quiet for perfect mixing
	if has_node("LaserSound"):
		$LaserSound.volume_db = -14.0
	
	_create_engine_particles()

func _create_engine_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.name = "EngineParticles"
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	particles.lifetime_randomness = 0.3
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(8, 2)
	particles.direction = Vector2(0, 1)
	particles.spread = 15.0
	particles.gravity = Vector2(0, 150)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	
	# Color gradient (yellow -> red -> transparent)
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 0.8, 0, 1)) # Yellow
	gradient.add_point(0.5, Color(1, 0.2, 0, 0.8)) # Red
	gradient.add_point(1.0, Color(0.2, 0.2, 0.2, 0)) # Transparent
	particles.color_ramp = gradient
	
	particles.position = Vector2(0, 25)
	particles.z_index = -1
	add_child(particles)

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

func set_skin(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if not packed:
		push_warning("Skin scene not found: %s" % scene_path)
		return
	
	selected_skin_path = scene_path
	
	# Assign a unique neon color per skin (HDR values for glow)
	var skin_colors: Dictionary = {
		"player_skin_01": Color(0.1, 1.5, 5.0, 1),   # Glow Cyan
		"player_skin_02": Color(5.0, 0.1, 1.5, 1),   # Glow Hot Pink
		"player_skin_03": Color(0.1, 5.0, 0.5, 1),   # Glow Neon Green
		"player_skin_04": Color(5.0, 2.5, 0.1, 1),   # Glow Solar Orange
		"player_skin_05": Color(1.5, 0.1, 5.0, 1),   # Glow Electric Purple
		"player_skin_06": Color(5.0, 5.0, 0.1, 1),   # Glow Golden Yellow
		"player_skin_07": Color(5.0, 0.1, 0.1, 1),   # Glow Laser Red
		"player_skin_08": Color(5.0, 0.1, 0.1, 1),   # Glow Crimson (Red Commander)
		"player_skin_09": Color(0.1, 1.5, 5.0, 1),   # Glow Cyan (Valkyrie One)
		"player_skin_10": Color(0.1, 5.0, 0.5, 1),   # Glow Emerald (Chrono Guardian)
		"player_skin_11": Color(5.0, 4.0, 0.1, 1),   # Glow Solar Gold (Golden Harbinger)
	}
	
	var is_base_ship = scene_path.contains("player.tscn")
	
	if is_base_ship:
		projectile_color = Color(0.2, 1.5, 5, 1) # Original Cyan Neon
	else:
		for key in skin_colors:
			if scene_path.contains(key):
				projectile_color = skin_colors[key]
				break
	
	# Instantiate temporarily OUTSIDE the tree to extract SpriteFrames
	var temp := packed.instantiate()
	var temp_sprite := temp.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if temp_sprite and temp_sprite.sprite_frames:
		# Duplicate so the resource is independent of the temp instance
		$AnimatedSprite2D.sprite_frames = temp_sprite.sprite_frames.duplicate()
		$AnimatedSprite2D.visible = true
		$AnimatedSprite2D.play("idle")
		
		# Restore or remove recolor shader
		if is_base_ship:
			var mat = ShaderMaterial.new()
			mat.shader = _create_recolor_shader()
			$AnimatedSprite2D.material = mat
		else:
			# Remove recolor shader so skin shows its original colors
			$AnimatedSprite2D.material = null
	else:
		push_warning("Skin scene has no valid SpriteFrames: %s" % scene_path)
	# Node was never added to the tree — use free(), NOT queue_free()
	temp.free()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var game = get_parent()
		if game:
			var pause_btn = game.get_node_or_null("CanvasLayer/UI/PauseBtn")
			if pause_btn and pause_btn.is_visible_in_tree():
				if pause_btn.get_global_rect().has_point(event.position):
					return
					
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
	
	# Animation based on relative movement
	var move_diff = target_pos.x - position.x
	
	# Polish: Tilt ship based on horizontal velocity
	var tilt_target = clamp(move_diff * 0.05, -0.4, 0.4)
	$AnimatedSprite2D.rotation = lerp($AnimatedSprite2D.rotation, tilt_target, 0.1)
	
	# Apply visual effects (Speed boost)
	if speed_boost_timer > 0:
		speed_boost_timer -= delta
		if int(Time.get_ticks_msec() / 100.0) % 2 == 0:
			$AnimatedSprite2D.modulate = Color(0.5, 2, 5, 1)
		else:
			$AnimatedSprite2D.modulate = Color(1, 1, 1, 1)
	elif not is_shielded:
		$AnimatedSprite2D.modulate = Color(1, 1, 1, 1)
	
	# Clamp to screen with dynamic bounds (never clip texture edges)
	var screen_size = get_viewport_rect().size
	var half_w = 40.0
	var half_h = 40.0
	var sprite = $AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.animation:
		var tex = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if tex:
			var current_scale = scale * sprite.scale
			half_w = (tex.get_size().x * current_scale.x) / 2.0
			half_h = (tex.get_size().y * current_scale.y) / 2.0
	
	# Add a tiny visual safety buffer of 5 pixels
	half_w += 5.0
	half_h += 5.0
	
	position.x = clamp(position.x, half_w, screen_size.x - half_w)
	position.y = clamp(position.y, half_h, screen_size.y - half_h)
	
	# Animation based on relative movement
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
	if "direction" in proj:
		proj.direction = dir
	if "skin_color" in proj:
		proj.skin_color = projectile_color
	get_parent().add_child(proj)
	return proj

func apply_powerup(type: int) -> void:
	# PowerUp.Type enum mapping
	# SPREAD=0, RAPID=1, HEAVY=2, BURST=3, LIFE=4, SHIELD=5, MULTISHOT=6, SPEED=7, WAVE=8, BACKSHOT=9, CIRCLE=10
	
	_play_sfx(preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/22 Retro Space Power Up #1.mp3"), -6.0)
	
	# Visual evolution (More subtle scaling: max 20% larger)
	evolution_level = min(5, evolution_level + 1)
	scale = Vector2(1.0, 1.0) + Vector2(0.04, 0.04) * evolution_level
	
	# Weapon Name Mapping for UI popup
	var weapon_names = {
		0: "SPREAD", 1: "RAPID FIRE", 2: "HEAVY CANNON", 3: "BURST",
		4: "LIFE +40", 5: "SHIELD", 6: "DUAL SHOT", 7: "SPEED BOOST",
		8: "WAVE", 9: "BACK SHOT", 10: "CIRCLE", 11: "STREAK",
		12: "SPIRAL", 13: "CROSS FIRE", 14: "ORBIT", 15: "TSUNAMI",
		16: "GATLING", 17: "SNAKE"
	}
	var game = get_parent()
	if game and game._fx:
		game._fx.show_weapon_name(weapon_names.get(type, "UNKNOWN"))
	
	match type:
		0, 1, 2, 3, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17:
			style_timer = 15.0 # More time for crazy patterns
			if game and game.has_method("show_powerup_status"):
				game.show_powerup_status(weapon_names.get(type, "WEAPON"), 15.0)
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
			if game and game.has_method("show_powerup_status"):
				game.show_powerup_status("SHIELD", 8.0)
		7: # SPEED
			speed_boost_timer = 10.0
			if game and game.has_method("show_powerup_status"):
				game.show_powerup_status("SPEED BOOST", 10.0)
	
	# Update UI
	if game and game._player_hp:
		game._player_hp.value = health

func _play_sfx(stream: AudioStream, volume: float = -8.0) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = volume
	sfx.bus = &"SFX"
	get_parent().add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func take_damage(amount: int = 10) -> void:
	if is_invincible:
		return
		
	health -= amount
	is_invincible = true
	flicker_timer = 0.0
	_play_sfx(hurt_sound, -5.0)
	
	var game = get_parent()
	if game and game._player_hp:
		game._player_hp.value = health
	
	# Hit-stop effect
	Engine.time_scale = 0.1
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0
	
	# Global effects
	if game:
		if game.has_method("shake_screen"):
			game.shake_screen(0.2, 8.0) # More intense shake
		var fx = game.get_node_or_null("EffectsManager")
		if fx and fx.has_method("flash"):
			fx.flash(Color(1, 0, 0, 0.3), 0.2) # Red flash on damage
		if fx and fx.has_method("glitch"):
			fx.glitch(0.4, 0.3)
	
	if health <= 0:
		_play_sfx(death_sound, -3.0)
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
