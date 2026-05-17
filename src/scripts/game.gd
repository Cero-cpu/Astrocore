extends Node2D

@export var enemy_scene: PackedScene = preload("res://src/scenes/enemy.tscn")
@onready var player = $Player
var boss_alarm_sound = preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/09 Retro Space Alarm #1.mp3")
var powerup_sound = preload("res://Free Retro Sci-Fi Sound Fx/Free Retro Sci-Fi Sound Fx/22 Retro Space Power Up #1.mp3")
var main_font = preload("res://fonts-ttf/BlockyPixel.ttf")

# Cached UI references (avoid repeated get_node calls)
var _ui: Control
var _score_label: Label
var _lvl_label: Label
var _burst_label: Label
var _player_hp: ProgressBar
var _boss_hp: ProgressBar
var _fx: Node

var spawn_timer: float = 2.5
var min_spawn_time: float = 0.5
var difficulty_timer: float = 0.0
var game_time: float = 0.0
var score: int = 0
var game_level: int = 1
var boss_scene: PackedScene = preload("res://src/scenes/boss.tscn")
var boss_2_scene: PackedScene = preload("res://src/scenes/boss_2.tscn")
var powerup_scene: PackedScene = preload("res://src/scenes/powerup.tscn")
var total_kills: int = 0
var last_boss_kill_threshold: int = 0
var boss_active: bool = false
var game_over: bool = false
var recent_powerups: Array = []
var last_powerup_time: float = 0.0
var combo_count: int = 0
var combo_timer: float = 0.0

# Limit max enemies on screen to prevent lag
const MAX_ENEMIES: int = 30
const MAX_PROJECTILES: int = 80
const KILLS_PER_BOSS: int = 50

var themes = [
	# Theme 0: Classic Cosmic Cyan
	{
		"bg": Color(0.01, 0.01, 0.05),
		"tex": preload("res://Skyel Space Shooter - FREE/Backgrounds/spr_background_01.png")
	},
	# Theme 1: Crimson Void
	{
		"bg": Color(0.05, 0.01, 0.01),
		"tex": preload("res://Skyel Space Shooter - FREE/Backgrounds/spr_background_02.png")
	},
	# Theme 2: Deep Emerald Nebula
	{
		"bg": Color(0.01, 0.05, 0.02),
		"tex": preload("res://Shoot`em Up/Background_Full-0001.png")
	},
	# Theme 3: Amethyst Cosmic Cloud
	{
		"bg": Color(0.04, 0.01, 0.06),
		"tex": preload("res://Skyel Space Shooter - FREE/Backgrounds/spr_background_01.png")
	},
	# Theme 4: Sovereign Gold
	{
		"bg": Color(0.05, 0.04, 0.01),
		"tex": preload("res://Shoot`em Up/Background_Full-0001.png")
	},
	# Theme 5: Deep Space Void
	{
		"bg": Color(0.0, 0.0, 0.03),
		"tex": preload("res://Skyel Space Shooter - FREE/Backgrounds/spr_background_02.png")
	},
	# Theme 6: Nebula Orange Flare
	{
		"bg": Color(0.05, 0.02, 0.0),
		"tex": preload("res://Skyel Space Shooter - FREE/Backgrounds/spr_background_02.png")
	},
	# Theme 7: Cobalt Stardust
	{
		"bg": Color(0.01, 0.01, 0.04),
		"tex": preload("res://Shoot`em Up/Background_Full-0001.png")
	},
	# Theme 8: Violet Cosmos
	{
		"bg": Color(0.03, 0.0, 0.05),
		"tex": preload("res://Skyel Space Shooter - FREE/Backgrounds/spr_background_01.png")
	},
	# Theme 9: Infinite Horizon
	{
		"bg": Color(0.02, 0.02, 0.04),
		"tex": preload("res://Shoot`em Up/Background_Full-0001.png")
	}
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
	for node_name in ["BackgroundTex", "BackgroundTexNext"]:
		var node = get_node(node_name)
		if node is Sprite2D:
			node.centered = true
			node.position = screen_size / 2
			node.region_enabled = true
			# 50% extra width/height to avoid black bars on any aspect ratio
			node.region_rect = Rect2(Vector2.ZERO, screen_size * 1.5)
	
	# draw_grid() # Disabled at user request to keep maps clean and clear
	setup_ui()
	# Cache UI references once (using find_child for robustness)
	_ui = $CanvasLayer/UI
	_score_label = _ui.find_child("ScoreLabel", true, false)
	_lvl_label = _ui.find_child("LvlLabel", true, false)
	_burst_label = _ui.find_child("BurstLabel", true, false)
	_player_hp = _ui.find_child("PlayerHP", true, false)
	_boss_hp = _ui.find_child("BossHP", true, false)
	_fx = $EffectsManager
	
	# Allow UI and Game manager to work during pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	$CanvasLayer.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Strategically balance node sound volumes
	if has_node("LevelUpPlayer"):
		$LevelUpPlayer.volume_db = -6.0
	
	# Transition to game music smoothly
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").play_game_music()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
		
	if game_over:
		return
		
	game_time += delta
	difficulty_timer += delta
	
	# Scroll backgrounds
	var bg_scroll = delta * 10.0
	
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
	
	# Update Level Progress Bar (towards next boss)
	var progress_node = _ui.get_node_or_null("LevelProgress")
	if progress_node:
		var current_kills_in_cycle = total_kills % KILLS_PER_BOSS
		var target_val = (float(current_kills_in_cycle) / float(KILLS_PER_BOSS)) * 100.0
		progress_node.value = lerp(progress_node.value, target_val, 0.1)
		# Pulse color if near boss (last 10% of kills)
		if current_kills_in_cycle >= int(KILLS_PER_BOSS * 0.9):
			progress_node.modulate = Color(2, 2, 2, 1) if int(game_time * 5) % 2 == 0 else Color(1, 1, 1, 1)
		else:
			progress_node.modulate = Color(1, 1, 1, 1)
	
	# Update UI (cached references = no overhead)
	_score_label.text = "%07d" % score
	_lvl_label.text = "LEVEL %02d" % game_level
	# Update health-based vignette
	if is_instance_valid(player):
		_burst_label.text = "BURST: %d" % player.burst_count
		
		# Low health effects (pulsing red vignette)
		var hp_percent = float(player.health) / 100.0
		if hp_percent < 0.35:
			var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
			var intensity = 0.7 + (0.35 - hp_percent) * 2.0
			_fx.update_vignette(intensity, Color(0.8, 0, 0, 1.0).lerp(Color(0.2, 0, 0, 1.0), pulse))
		else:
			_fx.update_vignette(0.7, Color.BLACK)
	elif not game_over:
		_show_game_over()
	
	# Combo decay
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0

func _play_sfx(stream: AudioStream, volume: float = -8.0) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = volume
	sfx.bus = &"SFX"
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func upgrade_player() -> void:
	if not is_instance_valid(player):
		return
		
	$LevelUpPlayer.play()
	_play_sfx(powerup_sound, -6.0)
	_fx.chromatic_pulse(4.0, 1.0)
	_fx.flash(Color(0.2, 0.8, 1, 0.5), 0.4)
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
	
	# Prepare next textures and colors (nebula background)
	$BackgroundTexNext.texture = next_theme.tex
	$BackgroundTexNext.modulate = Color(1, 1, 1, 0.0)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property($BackgroundTex, "modulate:a", 0.0, 2.0)
	tween.tween_property($BackgroundTexNext, "modulate:a", 0.4, 2.0)
	tween.tween_property($Background, "color", next_theme.bg, 2.0)
	
	await tween.finished
	$BackgroundTex.texture = $BackgroundTexNext.texture
	$BackgroundTex.modulate.a = 0.4
	
	$BackgroundTexNext.modulate.a = 0.0

func on_enemy_killed() -> void:
	# Combo system
	combo_count += 1
	combo_timer = 2.0
	
	# Score scales with combo
	var combo_multiplier = 1 + int(combo_count / 3.0)
	score += 100 * combo_multiplier
	total_kills += 1
	
	# Show combo effect
	_fx.show_combo(combo_count)
	
	# Chance to drop powerup (12%)
	if randf() < 0.12:
		call_deferred("spawn_powerup")
	
	# Boss spawning logic: Every KILLS_PER_BOSS kills
	if not boss_active:
		var boss_threshold = total_kills - (total_kills % KILLS_PER_BOSS)
		if boss_threshold > last_boss_kill_threshold and total_kills >= KILLS_PER_BOSS:
			last_boss_kill_threshold = boss_threshold
			var selected_boss = boss_scene if randi() % 2 == 0 else boss_2_scene
			spawn_boss(selected_boss)

func spawn_boss(scene: PackedScene) -> void:
	boss_active = true
	_play_sfx(boss_alarm_sound, -5.0)
	
	# Epic boss intro sequence
	_fx.show_boss_warning()
	_fx.flash(Color(1, 0, 0, 0.5), 0.6)
	_fx.chromatic_pulse(6.0, 1.5)
	shake_screen(0.4, 8.0)
	
	# Delay boss entrance for dramatic effect
	await get_tree().create_timer(1.5).timeout
	
	var boss = scene.instantiate()
	var screen_size = get_viewport_rect().size
	boss.global_position = Vector2(screen_size.x / 2, -100)
	add_child.call_deferred(boss)

func on_boss_killed() -> void:
	boss_active = false
	score += 5000
	spawn_timer = 3.0
	
	# Epic victory sequence
	_fx.show_boss_defeated()
	_fx.flash(Color.WHITE, 0.8)
	_fx.chromatic_pulse(10.0, 2.0)
	shake_screen(0.6, 20.0)
	_fx.slow_motion(0.8, 0.2)
	
	# Bosses drop 2-3 powerups
	for i in range(randi_range(2, 3)):
		call_deferred("spawn_powerup")
		
	# Upgrade player status and trigger dynamic level background theme transition!
	upgrade_player()

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
	
	# Using class-level main_font
	
	# ——— Level Progress Bar (Topmost) ———
	var progress_bar = ProgressBar.new()
	progress_bar.name = "LevelProgress"
	ui.add_child(progress_bar)
	progress_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	progress_bar.custom_minimum_size = Vector2(0, 8)
	progress_bar.show_percentage = false
	progress_bar.value = 0
	
	var prog_bg = StyleBoxFlat.new()
	prog_bg.bg_color = Color(0, 0, 0, 0.4)
	progress_bar.add_theme_stylebox_override("background", prog_bg)
	
	var prog_fill = StyleBoxFlat.new()
	prog_fill.bg_color = Color(0.2, 0.6, 1.0, 0.8)
	prog_fill.border_width_right = 2
	prog_fill.border_color = Color(0.5, 2, 5, 1) # Glowing edge
	progress_bar.add_theme_stylebox_override("fill", prog_fill)
	
	# ——— Main HUD Container (Top) ———
	var hud_top = MarginContainer.new()
	hud_top.name = "HUDTop"
	ui.add_child(hud_top)
	hud_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud_top.add_theme_constant_override("margin_left", 30)
	hud_top.add_theme_constant_override("margin_right", 30)
	hud_top.add_theme_constant_override("margin_top", 40)
	
	var hud_hbox = HBoxContainer.new()
	hud_hbox.name = "HUDHBox"
	hud_top.add_child(hud_hbox)
	
	# Player Info (Left)
	var player_vbox = VBoxContainer.new()
	player_vbox.name = "PlayerVBox"
	player_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_hbox.add_child(player_vbox)
	
	var hp_hbox = HBoxContainer.new()
	hp_hbox.name = "HPHBox"
	player_vbox.add_child(hp_hbox)
	
	var hp_label = Label.new()
	hp_label.text = "SYS_HP"
	hp_label.add_theme_color_override("font_color", Color(0.1, 5, 0.1, 1))
	if main_font: hp_label.add_theme_font_override("font", main_font)
	hp_label.add_theme_font_size_override("font_size", 44)
	hp_hbox.add_child(hp_label)
	
	var hp_bar = ProgressBar.new()
	hp_bar.name = "PlayerHP"
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.custom_minimum_size = Vector2(0, 36)
	hp_bar.show_percentage = false
	hp_hbox.add_child(hp_bar)
	
	var hp_bg_style = StyleBoxFlat.new()
	hp_bg_style.bg_color = Color(0.05, 0.1, 0.05, 0.6)
	hp_bg_style.border_width_left = 1
	hp_bg_style.border_width_top = 1
	hp_bg_style.border_width_right = 1
	hp_bg_style.border_width_bottom = 1
	hp_bg_style.border_color = Color(0.1, 0.5, 0.1, 0.4)
	hp_bg_style.corner_radius_top_left = 4
	hp_bg_style.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("background", hp_bg_style)
	
	var hp_fill_style = StyleBoxFlat.new()
	hp_fill_style.bg_color = Color(0.1, 0.9, 0.1, 1)
	hp_fill_style.border_width_right = 2
	hp_fill_style.border_color = Color(0.5, 5, 0.5, 1)
	hp_fill_style.corner_radius_top_left = 4
	hp_fill_style.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("fill", hp_fill_style)
	
	# Score & Level (Right)
	var stats_vbox = VBoxContainer.new()
	stats_vbox.name = "StatsVBox"
	stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_hbox.add_child(stats_vbox)
	
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "0000000"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_color_override("font_color", Color(0.3, 0.8, 5, 1))
	if main_font: score_label.add_theme_font_override("font", main_font)
	score_label.add_theme_font_size_override("font_size", 44)
	stats_vbox.add_child(score_label)
	
	var lvl_label = Label.new()
	lvl_label.name = "LvlLabel"
	lvl_label.text = "LEVEL 01"
	lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvl_label.add_theme_color_override("font_color", Color(0.3, 0.8, 5, 0.6))
	if main_font: lvl_label.add_theme_font_override("font", main_font)
	lvl_label.add_theme_font_size_override("font_size", 44)
	stats_vbox.add_child(lvl_label)
	
	# ——— Power-up Container (Left Side) ———
	var pu_container = VBoxContainer.new()
	pu_container.name = "PowerUpContainer"
	ui.add_child(pu_container)
	pu_container.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	pu_container.offset_left = 20
	pu_container.offset_top = 180
	pu_container.add_theme_constant_override("separation", 10)
	
	# ——— Boss UI (Centered Top) ———
	var boss_ui = VBoxContainer.new()
	boss_ui.name = "BossUI"
	ui.add_child(boss_ui)
	boss_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_ui.offset_top = 100
	boss_ui.visible = false
	
	var boss_name = Label.new()
	boss_name.text = "::: WARNING: CAPITAL SHIP DETECTED :::"
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_color_override("font_color", Color(5, 0.1, 0.1, 1))
	if main_font: boss_name.add_theme_font_override("font", main_font)
	boss_name.add_theme_font_size_override("font_size", 44)
	boss_ui.add_child(boss_name)
	
	var boss_bar = ProgressBar.new()
	boss_bar.name = "BossHP"
	boss_bar.custom_minimum_size = Vector2(500, 24)
	boss_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boss_bar.show_percentage = false
	boss_ui.add_child(boss_bar)
	
	var boss_bg_style = StyleBoxFlat.new()
	boss_bg_style.bg_color = Color(0.1, 0.05, 0.05, 0.8)
	boss_bg_style.border_width_left = 2
	boss_bg_style.border_width_top = 2
	boss_bg_style.border_width_right = 2
	boss_bg_style.border_width_bottom = 2
	boss_bg_style.border_color = Color(0.5, 0, 0, 1)
	boss_bar.add_theme_stylebox_override("background", boss_bg_style)
	
	var boss_fill_style = StyleBoxFlat.new()
	boss_fill_style.bg_color = Color(1.0, 0.1, 0.1, 1)
	boss_fill_style.border_width_right = 3
	boss_fill_style.border_color = Color(5, 0.5, 0.5, 1)
	boss_bar.add_theme_stylebox_override("fill", boss_fill_style)
	
	# ——— Pause Button (Top-Right Corner) ———
	var pause_btn = TextureButton.new()
	pause_btn.name = "PauseBtn"
	var pause_tex = load("res://boton_pausar.png")
	if pause_tex:
		pause_btn.texture_normal = pause_tex
		pause_btn.ignore_texture_size = true
		pause_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	pause_btn.custom_minimum_size = Vector2(50, 50)
	ui.add_child(pause_btn)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -70
	pause_btn.offset_top = 120
	pause_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pause_btn.mouse_entered.connect(func(): pause_btn.modulate = Color(1.5, 1.5, 1.5, 1.0))
	pause_btn.mouse_exited.connect(func(): pause_btn.modulate = Color(1.0, 1.0, 1.0, 1.0))
	pause_btn.pressed.connect(_toggle_pause)
	
	# ——— Credits (Bottom) ———
	var footer = HBoxContainer.new()
	footer.name = "HUDPathFooter"
	ui.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_bottom = -20
	footer.offset_left = 30
	footer.offset_right = -30
	
	var credits = Label.new()
	credits.text = "TERMINAL v2.0 // julian.dev"
	credits.add_theme_color_override("font_color", Color(0.3, 0.8, 5, 0.4))
	if main_font: credits.add_theme_font_override("font", main_font)
	credits.add_theme_font_size_override("font_size", 32)
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(credits)
	
	var burst_label = Label.new()
	burst_label.name = "BurstLabel"
	burst_label.text = "BURST: 1"
	burst_label.add_theme_color_override("font_color", Color(1, 0.8, 0.1, 0.8))
	if main_font: burst_label.add_theme_font_override("font", main_font)
	burst_label.add_theme_font_size_override("font_size", 44)
	footer.add_child(burst_label)
	
	
	# ——— Pause Overlay ———
	var pause_panel = ColorRect.new()
	pause_panel.name = "PausePanel"
	pause_panel.color = Color(0.01, 0.01, 0.03, 0.94)
	pause_panel.visible = false
	ui.add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var pause_center = CenterContainer.new()
	pause_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(pause_center)
	
	var pause_vbox = VBoxContainer.new()
	pause_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var paused_title = Label.new()
	paused_title.text = "MISSION PAUSED"
	paused_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused_title.add_theme_color_override("font_color", Color(0.3, 0.8, 5, 1))
	if main_font: paused_title.add_theme_font_override("font", main_font)
	paused_title.add_theme_font_size_override("font_size", 100)
	pause_vbox.add_child(paused_title)
	
	var resume_btn = Button.new()
	resume_btn.text = "RESUME MISSION"
	resume_btn.custom_minimum_size = Vector2(320, 80)
	if main_font: resume_btn.add_theme_font_override("font", main_font)
	resume_btn.add_theme_font_size_override("font_size", 44)
	var resume_style = StyleBoxFlat.new()
	resume_style.bg_color = Color(0.1, 0.4, 0.1, 0.8)
	resume_style.border_width_left = 2
	resume_style.border_width_top = 2
	resume_style.border_width_right = 2
	resume_style.border_width_bottom = 2
	resume_style.border_color = Color(0.3, 0.8, 0.3, 0.5)
	resume_style.corner_radius_top_left = 10
	resume_style.corner_radius_bottom_right = 10
	resume_btn.add_theme_stylebox_override("normal", resume_style)
	
	var resume_hover = resume_style.duplicate()
	resume_hover.bg_color = Color(0.2, 0.6, 0.2, 0.9)
	resume_hover.border_color = Color(0.5, 5.0, 0.5, 1)
	resume_btn.add_theme_stylebox_override("hover", resume_hover)
	pause_vbox.add_child(resume_btn)
	resume_btn.pressed.connect(_toggle_pause)
	
	# Lobby Button
	var lobby_btn = Button.new()
	lobby_btn.text = "ABORT MISSION"
	lobby_btn.custom_minimum_size = Vector2(320, 80)
	if main_font: lobby_btn.add_theme_font_override("font", main_font)
	lobby_btn.add_theme_font_size_override("font_size", 44)
	
	var lobby_style = StyleBoxFlat.new()
	lobby_style.bg_color = Color(0.05, 0.2, 0.4, 0.8)
	lobby_style.border_width_left = 2
	lobby_style.border_width_top = 2
	lobby_style.border_width_right = 2
	lobby_style.border_width_bottom = 2
	lobby_style.border_color = Color(0.2, 0.6, 1.0, 0.5)
	lobby_style.corner_radius_top_left = 10
	lobby_style.corner_radius_bottom_right = 10
	lobby_btn.add_theme_stylebox_override("normal", lobby_style)
	
	var lobby_hover = lobby_style.duplicate()
	lobby_hover.bg_color = Color(0.1, 0.4, 0.8, 0.9)
	lobby_hover.border_color = Color(0.4, 0.8, 5, 1)
	lobby_btn.add_theme_stylebox_override("hover", lobby_hover)
	pause_vbox.add_child(lobby_btn)
	lobby_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://src/scenes/lobby.tscn"))
	pause_center.add_child(pause_vbox)

func _toggle_pause() -> void:
	var pause_panel = _ui.get_node("PausePanel")
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	pause_panel.visible = is_paused
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS

func _show_game_over() -> void:
	game_over = true
	_fx.slow_motion(1.0, 0.3)
	_fx.chromatic_pulse(8.0, 3.0)
	# Using class-level main_font
	
	var panel = ColorRect.new()
	panel.name = "GameOverPanel"
	panel.color = Color(0.02, 0.02, 0.06, 0.0)
	_ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Fade in the dark overlay
	var fade_tween = create_tween()
	fade_tween.tween_property(panel, "color:a", 0.92, 1.5)
	
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center_container)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center_container.add_child(vbox)
	
	# Animate content in after a delay
	var content_tween = create_tween()
	content_tween.tween_interval(0.8)
	content_tween.tween_property(vbox, "modulate:a", 1.0, 0.5)
	vbox.modulate.a = 0.0
	
	# GAME OVER title
	var halt_label = Label.new()
	halt_label.text = "GAME OVER"
	halt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	halt_label.add_theme_color_override("font_color", Color(5, 0.1, 0.1, 1))
	if main_font: halt_label.add_theme_font_override("font", main_font)
	halt_label.add_theme_font_size_override("font_size", 100)
	vbox.add_child(halt_label)
	
	# Decorative line
	var separator = ColorRect.new()
	separator.custom_minimum_size = Vector2(300, 2)
	separator.color = Color(5, 0.1, 0.1, 0.6)
	var hbox_sep = HBoxContainer.new()
	hbox_sep.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_sep.add_child(separator)
	vbox.add_child(hbox_sep)
	
	# Stats
	var stats = [
		["SCORE", "%d" % score],
		["ENEMIES", "%d" % total_kills],
		["LEVEL", "%d" % game_level],
		["TIME", "%d:%02d" % [int(game_time / 60.0), int(game_time) % 60]],
	]
	
	for stat in stats:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		
		var key = Label.new()
		key.text = stat[0]
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7, 1))
		if main_font: key.add_theme_font_override("font", main_font)
		key.add_theme_font_size_override("font_size", 44)
		row.add_child(key)
		
		var val = Label.new()
		val.text = stat[1]
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.add_theme_color_override("font_color", Color(0.3, 0.8, 5, 1))
		if main_font: val.add_theme_font_override("font", main_font)
		val.add_theme_font_size_override("font_size", 44)
		row.add_child(val)
		
		vbox.add_child(row)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# Retry button
	var reboot_btn = Button.new()
	reboot_btn.text = "RETRY"
	reboot_btn.custom_minimum_size = Vector2(300, 80)
	if main_font: reboot_btn.add_theme_font_override("font", main_font)
	reboot_btn.add_theme_font_size_override("font_size", 60)
	
	var retry_style = StyleBoxFlat.new()
	retry_style.bg_color = Color(0.4, 0.05, 0.05, 0.8)
	retry_style.border_width_left = 2
	retry_style.border_width_top = 2
	retry_style.border_width_right = 2
	retry_style.border_width_bottom = 2
	retry_style.border_color = Color(0.8, 0.2, 0.2, 0.5)
	retry_style.corner_radius_top_left = 12
	retry_style.corner_radius_bottom_right = 12
	reboot_btn.add_theme_stylebox_override("normal", retry_style)
	
	var retry_hover = retry_style.duplicate()
	retry_hover.bg_color = Color(0.6, 0.1, 0.1, 0.9)
	retry_hover.border_color = Color(5.0, 0.3, 0.3, 1) # Neon red glow
	reboot_btn.add_theme_stylebox_override("hover", retry_hover)
	
	var center_btn = HBoxContainer.new()
	center_btn.alignment = BoxContainer.ALIGNMENT_CENTER
	center_btn.add_child(reboot_btn)
	vbox.add_child(center_btn)
	
	reboot_btn.pressed.connect(func(): get_tree().reload_current_scene())
	# Lobby Button in Game Over
	var go_lobby_btn = Button.new()
	go_lobby_btn.text = "EXIT TO LOBBY"
	go_lobby_btn.custom_minimum_size = Vector2(300, 70)
	if main_font: go_lobby_btn.add_theme_font_override("font", main_font)
	go_lobby_btn.add_theme_font_size_override("font_size", 44)
	
	var go_lobby_style = StyleBoxFlat.new()
	go_lobby_style.bg_color = Color(0.05, 0.15, 0.3, 0.8)
	go_lobby_style.border_width_left = 2
	go_lobby_style.border_width_top = 2
	go_lobby_style.border_width_right = 2
	go_lobby_style.border_width_bottom = 2
	go_lobby_style.border_color = Color(0.2, 0.5, 1.0, 0.6)
	go_lobby_style.corner_radius_top_left = 12
	go_lobby_style.corner_radius_bottom_right = 12
	go_lobby_btn.add_theme_stylebox_override("normal", go_lobby_style)
	
	var go_lobby_hover = go_lobby_style.duplicate()
	go_lobby_hover.bg_color = Color(0.1, 0.3, 0.6, 0.9)
	go_lobby_hover.border_color = Color(0.3, 0.8, 5, 1)
	go_lobby_btn.add_theme_stylebox_override("hover", go_lobby_hover)
	
	var center_go_lobby = HBoxContainer.new()
	center_go_lobby.alignment = BoxContainer.ALIGNMENT_CENTER
	center_go_lobby.add_child(go_lobby_btn)
	vbox.add_child(center_go_lobby)
	
	go_lobby_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://src/scenes/lobby.tscn"))

func _input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_R) and game_over:
		get_tree().reload_current_scene()

func show_powerup_status(type_name: String, duration: float) -> void:
	var container = _ui.get_node_or_null("PowerUpContainer")
	if not container: return
	
	# Check if already exists to refresh duration
	for child in container.get_children():
		if child.name == type_name:
			child.set_meta("time_left", duration)
			return
			
	# Create new indicator
	var panel = PanelContainer.new()
	panel.name = type_name
	panel.custom_minimum_size = Vector2(100, 30)
	panel.set_meta("time_left", duration)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.6)
	style.border_width_left = 2
	style.border_color = Color(0.3, 0.8, 5, 1)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = type_name
	if main_font: label.add_theme_font_override("font", main_font)
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var bar = ProgressBar.new()
	bar.max_value = duration
	bar.value = duration
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(bar)
	
	container.add_child(panel)
	
	# Logic to update and remove
	var timer_node = Timer.new()
	timer_node.wait_time = 0.1
	timer_node.autostart = true
	panel.add_child(timer_node)
	
	timer_node.timeout.connect(func():
		var time = panel.get_meta("time_left") - 0.1
		if time <= 0:
			panel.queue_free()
		else:
			panel.set_meta("time_left", time)
			bar.value = time
	)

func shake_screen(duration: float, intensity: float) -> void:
	var cam = $Camera2D
	var original_offset = cam.offset
	var timer = 0.0
	while timer < duration:
		cam.offset = original_offset + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		timer += get_process_delta_time()
		await get_tree().process_frame
	cam.offset = original_offset
