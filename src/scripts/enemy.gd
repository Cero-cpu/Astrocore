extends Area2D

@export var min_speed: float = 100.0
@export var max_speed: float = 250.0

var explosion_scene: PackedScene = preload("res://src/scenes/explosion.tscn")
var enemy_projectile_scene: PackedScene = preload("res://src/scenes/enemy_projectile.tscn")
var hit_sound: AudioStream = preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/07 Retro Lazer #7.mp3")
var death_sound: AudioStream = preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/19 Retro Enemy Dying #1.mp3")

var sprites = [
	# Skyel Pack
	preload("res://Skyel Space Shooter - FREE/Enemy spaceships/spr_enemy_spaceship_01_static.png"),
	preload("res://Skyel Space Shooter - FREE/Enemy spaceships/spr_enemy_spaceship_02_static.png"),
	preload("res://Skyel Space Shooter - FREE/Enemy spaceships/spr_enemy_spaceship_03_static.png"),
	preload("res://Skyel Space Shooter - FREE/Asteroids/spr_asteroid_01.png"),
	preload("res://Skyel Space Shooter - FREE/Asteroids/spr_asteroid_02.png"),
	preload("res://Skyel Space Shooter - FREE/Asteroids/spr_asteroid_03.png"),
	# Pixel SHMUP Pack
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_1_1.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_1_2.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_1_3.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_2_1.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_2_2.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/enemy_2_3.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/red_01.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/blue_01.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/green_06.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/orange_03.png"),
	preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/purple_03.png")
]

var health: int = 1
var speed: float = 0.0
var rotation_speed: float = 0.0
var is_asteroid: bool = false
var _screen_height: float
var original_modulate: Color
var original_sprite_scale: Vector2

var shoot_timer: float = 0.0
var can_shoot: bool = false

func _ready() -> void:
	_screen_height = get_viewport_rect().size.y
	
	# Random sprite
	var tex = sprites[randi() % sprites.size()]
	$Sprite2D.texture = tex
	
	# Store original scale
	original_sprite_scale = $Sprite2D.scale
	
	# Dynamic collision shape matching texture size scaled by Sprite2D scale
	var tex_size = tex.get_size()
	var visual_size = tex_size * original_sprite_scale
	
	# Set a generous collision shape (adding 8 pixels of padding) so hits register beautifully
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = visual_size + Vector2(8, 8)
	$CollisionShape2D.shape = rect_shape
	
	# Clamp horizontal position dynamically to prevent any part of the ship/wing/asteroid clipping out of screen
	var screen_width = get_viewport_rect().size.x
	var half_w = (visual_size.x / 2.0) + 12.0 # 12px visual safety buffer for rotations and wing tips
	position.x = clamp(position.x, half_w, screen_width - half_w)
	
	# Asteroid tumbling
	is_asteroid = "asteroid" in tex.resource_path
	if is_asteroid:
		rotation_speed = randf_range(-2.0, 2.0)
		var s = randf_range(0.8, 1.2)
		scale = Vector2(s, s)
	
	# Speed scales with time
	var time_bonus: float = 0.0
	var game_node = get_parent()
	if game_node and "game_time" in game_node:
		time_bonus = game_node.game_time * 2.0
		
	speed = randf_range(min_speed, max_speed) + time_bonus
	add_to_group("enemies")
	
	# Neon enemy colors
	original_modulate = Color(randf_range(1.0, 2.0), randf_range(0.1, 0.3), randf_range(1.0, 3.0))
	$Sprite2D.modulate = original_modulate
	
	# Only ships shoot, not asteroids
	if not is_asteroid:
		can_shoot = true
		shoot_timer = randf_range(1.0, 5.0)

func _process(delta: float) -> void:
	position.y += speed * delta
	if rotation_speed != 0.0:
		$Sprite2D.rotation += rotation_speed * delta
		
	# Enemy shooting logic (low difficulty)
	if can_shoot:
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot()
			shoot_timer = randf_range(3.0, 6.0) # Low frequency
			
	if position.y > _screen_height + 100:
		queue_free()

func shoot() -> void:
	if not is_instance_valid(get_parent()): return
	var p = enemy_projectile_scene.instantiate()
	p.global_position = global_position + Vector2(0, 30)
	p.speed = 300.0 # Slow enough to dodge
	get_parent().add_child(p)

func _play_sfx(stream: AudioStream, volume: float = -9.0) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = volume
	sfx.bus = &"SFX"
	get_parent().add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func take_damage(amount: int) -> void:
	health -= amount
	if health > 0:
		_play_sfx(hit_sound, -15.0) # Strategic subtle hit tick
		# Hit flash (Store and restore original modulation)
		var tween = create_tween()
		$Sprite2D.modulate = Color(10, 10, 10, 1) # Pure white HDR flash
		tween.tween_property($Sprite2D, "modulate", original_modulate, 0.1)
		
		# Small scale pop (relative to original scale so it doesn't shrink the sprite)
		var s_tween = create_tween()
		$Sprite2D.scale = original_sprite_scale * 1.15
		s_tween.tween_property($Sprite2D, "scale", original_sprite_scale, 0.1)
		
		# Hit particles
		_spawn_hit_particles()
		return
		
	# ——— DEATH LOGIC ———
	# Spawn explosion
	_play_sfx(death_sound, -10.0) # Balanced death sound
	var exp_inst = explosion_scene.instantiate()
	exp_inst.global_position = global_position
	get_parent().add_child(exp_inst)
	
	# Cinematic camera shake for big kills
	var game_node = get_parent()
	if game_node and game_node.has_method("shake_screen"):
		game_node.shake_screen(0.15, 5.0)
	
	# Floating score popup (Bouncy version)
	var score_popup = Label.new()
	var combo = 1
	if game_node and "combo_count" in game_node:
		combo = 1 + int(game_node.combo_count / 3.0)
	score_popup.text = "+%d" % (100 * combo)
	score_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_popup.add_theme_color_override("font_color", Color(5, 5, 0, 1))
	score_popup.add_theme_font_size_override("font_size", 44)
	var font = load("res://fonts-ttf/BlockyPixel.ttf")
	if font: score_popup.add_theme_font_override("font", font)
	
	score_popup.position = get_viewport().get_canvas_transform() * global_position - Vector2(30, 20)
	score_popup.pivot_offset = Vector2(20, 10)
	score_popup.z_index = 100
	
	var ui_layer = game_node.get_node_or_null("CanvasLayer/UI")
	if ui_layer: ui_layer.add_child(score_popup)
	else: game_node.add_child(score_popup)
	
	var ptween = score_popup.create_tween().set_parallel(true)
	score_popup.scale = Vector2(0.5, 0.5)
	ptween.tween_property(score_popup, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK)
	ptween.tween_property(score_popup, "position:y", score_popup.position.y - 100, 0.8).set_ease(Tween.EASE_OUT)
	ptween.tween_property(score_popup, "modulate:a", 0.0, 0.8).set_delay(0.3)
	ptween.chain().tween_callback(score_popup.queue_free)
	
	if get_parent().has_method("on_enemy_killed"):
		get_parent().on_enemy_killed()
	queue_free()

func _spawn_hit_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.amount = 12
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 300.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	
	# Orange -> Red -> Fade
	var gradient = Gradient.new()
	gradient.set_color(0, Color(5, 5, 0, 1)) # Glowing Gold
	gradient.add_point(0.5, Color(5, 0.2, 0, 1)) # Glowing Orange/Red
	gradient.add_point(1.0, Color(1, 0, 0, 0))
	particles.color_ramp = gradient
	
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	
	var t = get_tree().create_timer(0.5)
	t.timeout.connect(particles.queue_free)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if area.has_method("take_damage"):
			var dmg: int = 10 if is_asteroid else 15
			area.take_damage(dmg)
		queue_free()
