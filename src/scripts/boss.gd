extends Area2D

@export var health: int = 25
@export var max_health: int = 25
@export var shoot_rate: float = 1.0
var shoot_timer: float = 0.0

@export var projectile_scene: PackedScene = preload("res://src/scenes/enemy_projectile.tscn")
@export var explosion_scene: PackedScene = preload("res://src/scenes/explosion_pixel.tscn")

var target_y = 120
var moving_right = true
var speed = 150
var texture_to_set: Texture2D = null
var is_dying: bool = false

func _ready() -> void:
	if texture_to_set:
		$Sprite2D.texture = texture_to_set
	add_to_group("enemies")
	add_to_group("boss")
	
	var game = get_parent()
	if game and "boss_stage" in game:
		if game.boss_stage == 2:
			max_health = 500
			health = 500
			shoot_rate = 0.6 # Faster
			$Sprite2D.modulate = Color(0.5, 5, 2, 1) # Green neon
		else:
			max_health = 200
			health = 200
			$Sprite2D.modulate = Color(2, 0.5, 5, 1) # Purple neon
			
	$HealthBar.max_value = max_health
	$HealthBar.value = health
	$HealthBar.visible = false # Hide local bar
	
	if game and game.has_node("CanvasLayer/UI/BossUI"):
		var global_ui = game.get_node("CanvasLayer/UI/BossUI")
		var global_bar = global_ui.get_node("BossHP")
		global_bar.max_value = max_health
		global_bar.value = 0 # Start at zero
		global_ui.visible = true
		
		# Animate the bar filling up
		var tween = create_tween()
		tween.tween_property(global_bar, "value", max_health, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if is_dying: return
	
	# Move to position
	if position.y < target_y:
		position.y += speed * delta
	else:
		# Horizontal movement with dynamic bounds (never clip texture edges)
		var screen_width = get_viewport_rect().size.x
		var half_w = 80.0
		var sprite = $Sprite2D
		if sprite and sprite.texture:
			half_w = (sprite.texture.get_size().x * sprite.scale.x) / 2.0
		# Add a tiny visual safety buffer of 10 pixels
		half_w = max(80.0, half_w + 10.0)
		
		if moving_right:
			position.x += speed * delta
			if position.x > screen_width - half_w: moving_right = false
		else:
			position.x -= speed * delta
			if position.x < half_w: moving_right = true
			
		# Shooting
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot()
			shoot_timer = shoot_rate

func shoot() -> void:
	var game = get_parent()
	var is_stage_2 = game and "boss_stage" in game and game.boss_stage == 2
	
	if is_stage_2:
		# Circular spray for Boss 2
		for angle in range(0, 181, 30):
			var p = projectile_scene.instantiate()
			p.global_position = global_position + Vector2(0, 50)
			p.speed = 250.0
			var dir = Vector2.DOWN.rotated(deg_to_rad(angle - 90))
			get_parent().add_child(p)
			p.direction = dir
			p.rotation = dir.angle() + PI/2 # Rotate sprite to face direction
	else:
		# Triple shot for Boss 1
		for i in [-1, 0, 1]:
			var p = projectile_scene.instantiate()
			p.global_position = global_position + Vector2(i * 40, 50)
			get_parent().add_child(p)

func take_damage(amount: int) -> void:
	if is_dying: return
	
	health -= amount
	var game = get_parent()
	if game and game.has_node("CanvasLayer/UI/BossUI/BossHP"):
		game.get_node("CanvasLayer/UI/BossUI/BossHP").value = health
	
	# Flash effect
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate:v", 10.0, 0.05)
	tween.tween_property($Sprite2D, "modulate:v", 1.0, 0.05)
	
	if health <= 0:
		is_dying = true
		die()

func die() -> void:
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Epic Death sequence
	var game = get_parent()
	var fx = game.get_node_or_null("EffectsManager")
	
	if fx:
		fx.slow_motion(0.5, 0.4) # Crisper slow-motion (no "game freeze" lag spike)
		fx.chromatic_pulse(3.5, 0.6) # Punchy neon chromatic aberration (no blindness)
	
	if game and game.has_method("shake_screen"):
		game.shake_screen(0.8, 8.0) # Balanced strong rumble instead of endless earthquake
	
	# Chain of explosions
	for i in range(12):
		var small_exp = explosion_scene.instantiate()
		var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		small_exp.global_position = global_position + offset
		small_exp.scale = Vector2(3, 3)
		
		# Prevent audio blowout by turning down the volume of these chain pops
		var sfx = small_exp.get_node_or_null("AudioStreamPlayer2D")
		if sfx:
			sfx.volume_db = -12.0 # Subdued secondary popping sound
			
		get_parent().add_child(small_exp)
		
		# Flicker boss
		$Sprite2D.modulate.a = 0.5 if i % 2 == 0 else 1.0
		
		await get_tree().create_timer(0.12, true, false, true).timeout
	
	# Final Massive blast
	var final_exp = explosion_scene.instantiate()
	final_exp.global_position = global_position
	final_exp.scale = Vector2(15, 15)
	
	# Play the final blast at normal full volume
	var final_sfx = final_exp.get_node_or_null("AudioStreamPlayer2D")
	if final_sfx:
		final_sfx.volume_db = 0.0 # Full impact blast!
		
	get_parent().add_child(final_exp)
	
	if fx:
		fx.flash(Color.WHITE, 0.5)
	
	if get_parent().has_node("CanvasLayer/UI/BossUI"):
		get_parent().get_node("CanvasLayer/UI/BossUI").visible = false
		
	if get_parent().has_method("on_boss_killed"):
		get_parent().on_boss_killed()
	
	queue_free()
