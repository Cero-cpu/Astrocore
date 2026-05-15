extends Node2D

@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@onready var player = $Player
var boss_alarm_sound = preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/09 Retro Space Alarm #1.mp3")
var powerup_sound = preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/22 Retro Space Power Up #1.mp3")

# Cached UI references (avoid repeated get_node calls)
var _ui: Control
var _score_label: Label
var _lvl_label: Label
var _burst_label: Label
var _player_hp: ProgressBar
var _boss_hp: ProgressBar

var spawn_timer: float = 2.5
var min_spawn_time: float = 0.5
var difficulty_timer: float = 0.0
var game_time: float = 0.0
var score: int = 0
var game_level: int = 1
var boss_scene: PackedScene = preload("res://boss.tscn")
var boss_2_scene: PackedScene = preload("res://boss_2.tscn")
var powerup_scene: PackedScene = preload("res://powerup.tscn")
var total_kills: int = 0
var last_boss_kill_threshold: int = 0
var boss_active: bool = false
var game_over: bool = false
var recent_powerups: Array = []
var last_powerup_time: float = 0.0

# Limit max enemies on screen to prevent lag
const MAX_ENEMIES: int = 30
const MAX_PROJECTILES: int = 80

var themes = [
	{"bg": Color(0.01, 0.01, 0.05), "stars": Color(0.2, 0.8, 1), "tex": preload("res://Skyel Space Shooter - FREE/Backgrounds/spr_background_01.png")},
	{"bg": Color(0.05, 0.01, 0.01), "stars": Color(1, 0.2, 0.2), "tex": preload("res://Skyel Space Shooter - FREE/Backgrounds/spr_background_02.png")},
	{"bg": Color(0.01, 0.05, 0.01), "stars": Color(0.2, 1, 0.2), "tex": preload("res://Skyel Space Shooter - FREE/Backgrounds/spr_background_01.png")},
	{"bg": Color(0.05, 0.01, 0.05), "stars": Color(0.8, 0.2, 1), "tex": preload("res://Skyel Space Shooter - FREE/Backgrounds/spr_background_02.png")},
	{"bg": Color(0.05, 0.05, 0.01), "stars": Color(1, 1, 0.2), "tex": preload("res://Skyel Space Shooter - FREE/Backgrounds/spr_background_01.png")}
]
var current_theme_idx: int = 0

func _ready() -> void:
	# Dynamic background scaling for full-screen expand mode
	var screen_size = get_viewport_rect().size
	
	# Fix Background ColorRect (Make it wider for safe areas)
	$Background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Background.offset_left = -200
	$Background.offset_right = 200
	
	# Fix Texture layers (expand to fill dynamic screen width + extra for safety)
	for node_name in ["BackgroundTex", "BackgroundTexNext", "Stars", "StarsNext"]:
		var node = get_node(node_name)
		if node is Sprite2D:
			node.centered = true
			node.position = screen_size / 2
			node.region_enabled = true
			# 50% extra width/height to avoid black bars on any aspect ratio
			node.region_rect = Rect2(Vector2.ZERO, screen_size * 1.5)
	
	draw_grid()
	setup_ui()
	# Cache UI references once
	_ui = $CanvasLayer/UI
	_score_label = _ui.get_node("InfoContainer/ScoreLabel")
	_lvl_label = _ui.get_node("InfoContainer/LvlLabel")
	_burst_label = _ui.get_node("InfoContainer/BurstLabel")
	_player_hp = _ui.get_node("PlayerHPContainer/PlayerHP")
	_boss_hp = _ui.get_node("BossUI/BossHP")

func _process(delta: float) -> void:
	if game_over:
		return
		
	game_time += delta
	difficulty_timer += delta
	
	# Scroll stars and backgrounds (Synchronized to avoid jumps)
	var star_scroll = delta * 20.0
	var bg_scroll = delta * 10.0
	
	$Stars.region_rect.position.y -= star_scroll
	$StarsNext.region_rect.position.y = $Stars.region_rect.position.y
	
	$BackgroundTex.region_rect.position.y -= bg_scroll
	$BackgroundTexNext.region_rect.position.y = $BackgroundTex.region_rect.position.y
	
	# Spawn enemy (Disabled during boss, capped for performance)
	if not boss_active:
		spawn_timer -= delta
		if spawn_timer <= 0:
			var enemy_count = get_tree().get_nodes_in_group("enemies").size()
			if enemy_count < MAX_ENEMIES:
				spawn_enemy()
			# Scaling difficulty (faster spawns)
			spawn_timer = max(min_spawn_time, 2.5 - (game_time / 15.0))
	
	# Spawn Power-up fallback every 20 seconds (Always active)
	if int(game_time) % 20 == 0 and int(game_time) != 0:
		if not has_node("PowerUpTimer"):
			var t = Timer.new()
			t.name = "PowerUpTimer"
			t.one_shot = true
			t.wait_time = 1.0
			add_child(t)
			call_deferred("spawn_powerup")
	
	# Extra buffs during boss fight (More frequent)
	if boss_active:
		if not has_node("BossBuffTimer"):
			var t = Timer.new()
			t.name = "BossBuffTimer"
			t.one_shot = false # Continuous during boss
			t.wait_time = 6.0 
			t.timeout.connect(func(): if boss_active: call_deferred("spawn_powerup"))
			add_child(t)
			t.start()
	elif has_node("BossBuffTimer"):
		get_node("BossBuffTimer").queue_free()
	
	# Upgrade player every 12 seconds
	if difficulty_timer >= 12.0:
		upgrade_player()
		difficulty_timer = 0.0
	
	# Update UI (cached references = no overhead)
	_score_label.text = "SCORE: %d" % score
	_lvl_label.text = "LVL: %d" % game_level
	if is_instance_valid(player):
		_burst_label.text = "BURST: %d" % player.burst_count
	elif not game_over:
		_show_game_over()

func _play_sfx(stream: AudioStream) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = -3.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func upgrade_player() -> void:
	if not is_instance_valid(player):
		return
		
	$LevelUpPlayer.play()
	_play_sfx(powerup_sound)
	game_level += 1
	transition_theme()
	var current_burst = player.burst_count
	var current_rate = player.fire_rate
	
	if current_burst < 10:
		player.upgrade_burst(current_burst + 1)
	else:
		player.upgrade_fire_rate(current_rate * 0.9)

func transition_theme() -> void:
	current_theme_idx = (current_theme_idx + 1) % themes.size()
	var next_theme = themes[current_theme_idx]
	
	# Prepare next textures and colors
	$StarsNext.modulate = next_theme.stars
	$StarsNext.modulate.a = 0.0
	$BackgroundTexNext.texture = next_theme.tex
	$BackgroundTexNext.modulate = Color(1, 1, 1, 0.0)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property($Stars, "modulate:a", 0.0, 2.0)
	tween.tween_property($BackgroundTex, "modulate:a", 0.0, 2.0)
	tween.tween_property($StarsNext, "modulate:a", 1.0, 2.0)
	tween.tween_property($BackgroundTexNext, "modulate:a", 0.4, 2.0)
	tween.tween_property($Background, "color", next_theme.bg, 2.0)
	
	await tween.finished
	$Stars.modulate = $StarsNext.modulate
	$BackgroundTex.texture = $BackgroundTexNext.texture
	$BackgroundTex.modulate.a = 0.4
	
	$StarsNext.modulate.a = 0.0
	$BackgroundTexNext.modulate.a = 0.0

func on_enemy_killed() -> void:
	score += 100
	total_kills += 1
	print("Kills: %d" % total_kills)
	
	# Chance to drop powerup (12%)
	if randf() < 0.12:
		call_deferred("spawn_powerup")
	
	# Boss spawning logic: Every 15 kills
	if not boss_active:
		var boss_threshold = (total_kills / 15) * 15
		if boss_threshold > last_boss_kill_threshold and total_kills >= 15:
			last_boss_kill_threshold = boss_threshold
			var selected_boss = boss_scene if randi() % 2 == 0 else boss_2_scene
			spawn_boss(selected_boss)

func spawn_boss(scene: PackedScene) -> void:
	boss_active = true
	_play_sfx(boss_alarm_sound)
	var boss = scene.instantiate()
	var screen_size = get_viewport_rect().size
	boss.global_position = Vector2(screen_size.x / 2, -100)
	add_child.call_deferred(boss)

func on_boss_killed() -> void:
	boss_active = false
	score += 5000
	spawn_timer = 3.0
	# Bosses drop 2-3 powerups
	for i in range(randi_range(2, 3)):
		call_deferred("spawn_powerup")

func spawn_enemy() -> void:
	var enemy = enemy_scene.instantiate()
	var screen_size = get_viewport_rect().size
	enemy.position = Vector2(randf_range(50, screen_size.x - 50), -50)
	# Increase enemy health over time
	enemy.health = 1 + int(game_time / 60.0)
	add_child(enemy)

func spawn_powerup() -> void:
	# Prevent clumping: Cooldown of 1.5 seconds between buffs
	if game_time - last_powerup_time < 1.5:
		return
	
	last_powerup_time = game_time
	var pu = powerup_scene.instantiate()
	var screen_size = get_viewport_rect().size
	pu.position = Vector2(randf_range(100, screen_size.x - 100), -50)
	
	# Intelligent randomization: avoid repeating the last 5 types
	var possible_types = []
	for i in range(18): possible_types.append(i)
	
	for r in recent_powerups:
		if possible_types.size() > 6: # Keep some randomness
			possible_types.erase(r)
	
	var selected_type = possible_types[randi() % possible_types.size()]
	pu.type = selected_type
	recent_powerups.push_back(selected_type)
	if recent_powerups.size() > 3:
		recent_powerups.pop_front()
		
	add_child(pu)

func draw_grid() -> void:
	var grid_node = $Grid
	var step = 64
	var screen_size = get_viewport_rect().size
	for x in range(0, int(screen_size.x), step):
		var line = Line2D.new()
		line.points = PackedVector2Array([Vector2(x, 0), Vector2(x, screen_size.y)])
		line.width = 1.0
		line.default_color = Color(0.2, 0.5, 1.0, 0.3)
		grid_node.add_child(line)
	for y in range(0, int(screen_size.y), step):
		var line = Line2D.new()
		line.points = PackedVector2Array([Vector2(0, y), Vector2(screen_size.x, y)])
		line.width = 1.0
		line.default_color = Color(0.2, 0.5, 1.0, 0.3)
		grid_node.add_child(line)

func setup_ui() -> void:
	var ui = $CanvasLayer/UI
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font_path = "res://fonts-ttf/BlockyPixel.ttf"
	var main_font = load(font_path)
	
	# Player HP Container
	var player_hp_container = HBoxContainer.new()
	player_hp_container.name = "PlayerHPContainer"
	ui.add_child(player_hp_container)
	# Use Top Wide with margins for safe area
	player_hp_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	player_hp_container.offset_left = 60
	player_hp_container.offset_right = -60
	player_hp_container.offset_top = 100
	player_hp_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	
	var hp_label = Label.new()
	hp_label.text = "HP"
	hp_label.add_theme_color_override("font_color", Color(0.1, 5, 0.1, 1)) # Neon Green
	if main_font: hp_label.add_theme_font_override("font", main_font)
	hp_label.add_theme_font_size_override("font_size", 18)
	player_hp_container.add_child(hp_label)
	
	# Player Health Bar (Flexible width)
	var hp_bar = ProgressBar.new()
	hp_bar.name = "PlayerHP"
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.custom_minimum_size = Vector2(0, 14) # Thinner bar
	hp_bar.show_percentage = false
	player_hp_container.add_child(hp_bar)
	
	var hp_bg_style = StyleBoxFlat.new()
	hp_bg_style.bg_color = Color(0, 0.1, 0, 0.5)
	hp_bg_style.border_width_left = 1
	hp_bg_style.border_width_top = 1
	hp_bg_style.border_width_right = 1
	hp_bg_style.border_width_bottom = 1
	hp_bg_style.border_color = Color(0.1, 0.3, 0.1, 1)
	hp_bar.add_theme_stylebox_override("background", hp_bg_style)
	
	var hp_fill_style = StyleBoxFlat.new()
	hp_fill_style.bg_color = Color(0.1, 0.8, 0.1, 1)
	hp_fill_style.border_width_right = 2
	hp_fill_style.border_color = Color(0.5, 5, 0.5, 1) # Neon glow edge
	hp_bar.add_theme_stylebox_override("fill", hp_fill_style)
	
	# Boss UI Container
	var boss_ui = VBoxContainer.new()
	boss_ui.name = "BossUI"
	ui.add_child(boss_ui)
	# Use Top Wide with margins for safe area
	boss_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_ui.offset_left = 60
	boss_ui.offset_right = -60
	boss_ui.offset_top = 160 # Lower than player HP
	boss_ui.visible = false
	
	var boss_name = Label.new()
	boss_name.text = "BOSS"
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_color_override("font_color", Color(5, 0.1, 0.1, 1))
	if main_font: boss_name.add_theme_font_override("font", main_font)
	boss_name.add_theme_font_size_override("font_size", 20)
	boss_ui.add_child(boss_name)
	
	# Boss Health Bar (Premium look)
	var boss_bar = ProgressBar.new()
	boss_bar.name = "BossHP"
	boss_bar.custom_minimum_size = Vector2(0, 18) # Thinner bar
	boss_bar.show_percentage = false
	boss_ui.add_child(boss_bar)
	
	var boss_bg_style = StyleBoxFlat.new()
	boss_bg_style.bg_color = Color(0.1, 0.05, 0.05, 0.8)
	boss_bg_style.border_width_left = 2
	boss_bg_style.border_width_top = 2
	boss_bg_style.border_width_right = 2
	boss_bg_style.border_width_bottom = 2
	boss_bg_style.border_color = Color(0.3, 0, 0, 1)
	boss_bar.add_theme_stylebox_override("background", boss_bg_style)
	
	var boss_fill_style = StyleBoxFlat.new()
	boss_fill_style.bg_color = Color(0.9, 0.1, 0.1, 1)
	boss_fill_style.border_width_left = 1
	boss_fill_style.border_width_top = 1
	boss_fill_style.border_width_right = 1
	boss_fill_style.border_width_bottom = 1
	boss_fill_style.border_color = Color(5, 0.2, 0.2, 1) # Neon glow edge
	boss_bar.add_theme_stylebox_override("fill", boss_fill_style)
	
	# Top Info Container (Score, Level, Burst)
	var info_container = HBoxContainer.new()
	info_container.name = "InfoContainer"
	ui.add_child(info_container)
	info_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	info_container.offset_left = 60
	info_container.offset_right = -60
	info_container.offset_top = 40
	
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "SCORE: 0"
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.add_theme_color_override("font_color", Color(0.3, 0.8, 4, 1))
	if main_font: score_label.add_theme_font_override("font", main_font)
	score_label.add_theme_font_size_override("font_size", 22)
	info_container.add_child(score_label)
	
	var lvl_label = Label.new()
	lvl_label.name = "LvlLabel"
	lvl_label.text = "LVL: 1"
	lvl_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_label.add_theme_color_override("font_color", Color(0.3, 0.8, 4, 1))
	if main_font: lvl_label.add_theme_font_override("font", main_font)
	lvl_label.add_theme_font_size_override("font_size", 22)
	info_container.add_child(lvl_label)
	
	var burst_label = Label.new()
	burst_label.name = "BurstLabel"
	burst_label.text = "BURST: 1"
	burst_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	burst_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	burst_label.add_theme_color_override("font_color", Color(0.3, 0.8, 4, 1))
	if main_font: burst_label.add_theme_font_override("font", main_font)
	burst_label.add_theme_font_size_override("font_size", 22)
	info_container.add_child(burst_label)
	
	# Credits Label
	var credits = Label.new()
	credits.text = "Creado por: julian.dev \"BydiamondGames\""
	credits.add_theme_color_override("font_color", Color(0.2, 0.9, 5, 0.9)) # Brighter neon cyan
	if main_font: credits.add_theme_font_override("font", main_font)
	credits.add_theme_font_size_override("font_size", 24)
	ui.add_child(credits)
	
	# Proper anchoring to bottom-right
	credits.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credits.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	credits.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Adjust offsets so it's inside the screen
	credits.offset_left = -450
	credits.offset_top = -60
	credits.offset_right = -20
	credits.offset_bottom = -20
	
	# Virtual Joystick (Disabled for touch-follow mode)
	# ... (Removed logic)

var joystick_vector: Vector2 = Vector2.ZERO

func _show_game_over() -> void:
	game_over = true
	var main_font = load("res://fonts-ttf/BlockyPixel.ttf")
	
	var panel = ColorRect.new()
	panel.name = "GameOverPanel"
	panel.color = Color(0.05, 0.05, 0.1, 0.9)
	panel.custom_minimum_size = Vector2(500, 350)
	_ui.add_child(panel)
	
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var border = ReferenceRect.new()
	border.editor_only = false
	border.border_color = Color(5, 0.1, 0.1, 1)
	border.border_width = 4
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(border)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var halt_label = Label.new()
	halt_label.text = "SYSTEM HALT"
	halt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	halt_label.add_theme_color_override("font_color", Color(5, 0.1, 0.1, 1))
	if main_font: halt_label.add_theme_font_override("font", main_font)
	halt_label.add_theme_font_size_override("font_size", 64)
	vbox.add_child(halt_label)
	
	var score_res = Label.new()
	score_res.text = "SCORE: %d" % score
	score_res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_res.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if main_font: score_res.add_theme_font_override("font", main_font)
	score_res.add_theme_font_size_override("font_size", 32)
	vbox.add_child(score_res)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	var reboot_btn = Button.new()
	reboot_btn.text = "REBOOT"
	reboot_btn.custom_minimum_size = Vector2(250, 80)
	if main_font: reboot_btn.add_theme_font_override("font", main_font)
	reboot_btn.add_theme_font_size_override("font_size", 40)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(5, 0.1, 0.1, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	reboot_btn.add_theme_stylebox_override("normal", style)
	vbox.add_child(reboot_btn)
	reboot_btn.pressed.connect(func(): get_tree().reload_current_scene())

func _input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_R) and game_over:
		get_tree().reload_current_scene()

func shake_screen(duration: float, intensity: float) -> void:
	var original_pos = position
	var timer = 0.0
	while timer < duration:
		position = original_pos + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		timer += get_process_delta_time()
		await get_tree().process_frame
	position = original_pos
