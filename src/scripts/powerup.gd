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
	
	# Dynamically slice the beautiful 5-frame spinning/glowing animation from Shoot'em Up bonuses pack
	var atlas_tex = preload("res://Shoot`em Up/Bonuses-0001.png")
	var sprite_frames = SpriteFrames.new()
	
	# "default" is automatically created in Godot 4 SpriteFrames.new(), so we just configure and clear it
	sprite_frames.set_animation_speed("default", 10.0) # 10 FPS for smooth retro rotation
	sprite_frames.set_animation_loop("default", true)
	sprite_frames.clear("default")
	
	var row = type % 5 # 5 distinct beautiful rows of 32x32 in spritesheet
	var cell_size = 32
	for col in range(5): # 5 frames per animation
		var frame_tex = AtlasTexture.new()
		frame_tex.atlas = atlas_tex
		frame_tex.region = Rect2(col * cell_size, row * cell_size, cell_size, cell_size)
		sprite_frames.add_frame("default", frame_tex)
		
	$AnimatedSprite2D.sprite_frames = sprite_frames
	$AnimatedSprite2D.play("default")
	
	# Add a smooth arcade pulsing effect
	$AnimatedSprite2D.scale = Vector2(2.0, 2.0) # 32x32 scaled by 2 is 64x64, which is a perfect arcade size!
	var tween = create_tween().set_loops()
	tween.tween_property($AnimatedSprite2D, "scale", Vector2(2.4, 2.4), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property($AnimatedSprite2D, "scale", Vector2(2.0, 2.0), 0.6).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	position.y += speed * delta
	if position.y > _screen_height + 100:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if area.has_method("apply_powerup"):
			area.apply_powerup(type)
		_spawn_collect_particles()
		# Use a tiny delay or hide sprite before queue_free for particles to show
		$AnimatedSprite2D.visible = false
		set_deferred("monitoring", false)
		await get_tree().create_timer(0.5).timeout
		queue_free()

func _spawn_collect_particles() -> void:
	var particles = CPUParticles2D.new()
	particles.amount = 25
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 300.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	
	# Match powerup color
	var color = Color(0.2, 0.8, 1.0, 1.0)
	match type:
		Type.SPREAD, Type.MULTISHOT: color = Color(0.1, 0.8, 1.0, 1.0) # Cyan/Blue
		Type.RAPID, Type.GATLING: color = Color(1.0, 0.2, 0.5, 1.0) # Hot Pink
		Type.HEAVY, Type.SPIRAL: color = Color(1.0, 0.8, 0.1, 1.0) # Gold
		Type.BURST, Type.WAVE: color = Color(0.8, 0.1, 1.0, 1.0) # Purple
		Type.LIFE: color = Color(0.1, 1.0, 0.3, 1.0) # Emerald Green
		Type.SHIELD: color = Color(1.0, 1.0, 1.0, 1.0) # White/Shield
		Type.SPEED: color = Color(0.1, 0.5, 1.0, 1.0) # Cobalt Blue
		_: color = Color(0.9, 0.9, 0.1, 1.0) # Yellow
		
	particles.color = color
	
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	
	var t = get_tree().create_timer(0.5)
	t.timeout.connect(particles.queue_free)
