extends Node2D

@onready var ui = $CanvasLayer/UI
@onready var player_preview = $PlayerPreview
@onready var stars = $Stars
@onready var stars_far = $StarsFar if has_node("StarsFar") else null

var main_font = preload("res://fonts-ttf/BlockyPixel.ttf")
var scroll_speed = 50.0
var scroll_offset = 0.0

# Mobile touch-swipe drag scroll variables
var touch_active: bool = false
var touch_dragging: bool = false
var touch_start_pos: Vector2 = Vector2.ZERO
var touch_scroll_start: float = 0.0

func _ready() -> void:
	# Ensure game is not paused
	get_tree().paused = false
	
	# Initial skin restoration
	var player_script = load("res://src/scripts/player.gd")
	if player_script.selected_skin_path != "":
		player_preview.set_skin(player_script.selected_skin_path)
	
	# Add engine particles to preview if possible
	_enhance_preview()
	
	_setup_lobby_ui()
	_animate_entrance()
	
	# Play lobby music smoothly
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").play_lobby_music()

func _process(delta: float) -> void:
	# Scroll background
	scroll_offset += scroll_speed * delta
	stars.region_rect.position.y = -scroll_offset
	if stars_far:
		stars_far.region_rect.position.y = -scroll_offset * 0.5
	
	# Floating ship effect
	player_preview.position.y = 480 + sin(Time.get_ticks_msec() * 0.002) * 15

func _enhance_preview() -> void:
	# Disable player controls for preview
	if player_preview.has_method("set_process"):
		player_preview.set_process(false)
		player_preview.set_physics_process(false)
	
	# Add a glow effect behind the ship
	var glow = PointLight2D.new()
	glow.texture = preload("res://Pixel SHMUP Free 1.3/Pixel SHMUP Free/main_ship-1.png") # Placeholder texture for light shape
	glow.color = Color(0.2, 0.5, 1.0)
	glow.energy = 2.0
	glow.texture_scale = 2.0
	player_preview.add_child(glow)

func _setup_lobby_ui() -> void:
	# Clean up UI
	for child in ui.get_children():
		child.queue_free()
	
	# Main layout (Center container for perfect alignment)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 40)
	center.add_child(vbox)
	
	# Header
	var title_vbox = VBoxContainer.new()
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(title_vbox)
	
	var title = Label.new()
	title.text = "ASTROCORE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if main_font: title.add_theme_font_override("font", main_font)
	title.add_theme_font_size_override("font_size", 100)
	title.add_theme_color_override("font_color", Color(0.2, 1.5, 5, 1)) # HDR Cyan
	title_vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "ELITE PILOT TERMINAL"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if main_font: subtitle.add_theme_font_override("font", main_font)
	subtitle.add_theme_font_size_override("font_size", 44)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.8, 1, 0.6))
	title_vbox.add_child(subtitle)
	
	# Ship Preview Area Spacer
	var ship_spacer = Control.new()
	ship_spacer.custom_minimum_size = Vector2(0, 280)
	vbox.add_child(ship_spacer)
	
	# Skin Selection Label
	var select_label = Label.new()
	select_label.text = "--- SHIP CONFIGURATION ---"
	select_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if main_font: select_label.add_theme_font_override("font", main_font)
	select_label.add_theme_font_size_override("font_size", 44)
	select_label.modulate.a = 0.7
	vbox.add_child(select_label)
	
	# Skin Grid
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 320)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)
	
	# ScrollContainer touch swipe scrolling for mobile margins
	scroll.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					touch_active = true
					touch_dragging = false
					touch_start_pos = event.global_position
					touch_scroll_start = scroll.scroll_vertical
				else:
					touch_active = false
					touch_dragging = false
					
		elif event is InputEventMouseMotion:
			if touch_active:
				var diff = event.global_position - touch_start_pos
				if not touch_dragging and abs(diff.y) > 8.0:
					touch_dragging = true
				
				if touch_dragging:
					scroll.scroll_vertical = touch_scroll_start - diff.y
	)
	
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(grid)
	
	var skin_scenes: Array = [
		"res://src/scenes/player.tscn",
		"res://skins/player_skin_01.tscn",
		"res://skins/player_skin_02.tscn",
		"res://skins/player_skin_03.tscn",
		"res://skins/player_skin_04.tscn",
		"res://skins/player_skin_05.tscn",
		"res://skins/player_skin_06.tscn",
		"res://skins/player_skin_07.tscn",
		"res://skins/player_skin_08.tscn",
		"res://skins/player_skin_09.tscn",
		"res://skins/player_skin_10.tscn",
		"res://skins/player_skin_11.tscn",
	]
	
	for path in skin_scenes:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(110, 110)
		
		# Dynamically extract first frame of idle animation from the .tscn scene file!
		var tex: Texture2D = null
		var packed = load(path) as PackedScene
		if packed:
			var temp = packed.instantiate()
			var temp_sprite = temp.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if temp_sprite and temp_sprite.sprite_frames:
				if temp_sprite.sprite_frames.has_animation("idle"):
					var count = temp_sprite.sprite_frames.get_frame_count("idle")
					if count > 0:
						tex = temp_sprite.sprite_frames.get_frame_texture("idle", 0)
			temp.free()
			
		# Centered TextureRect layout to ensure uniform centering, aspect ratios, and crisp pixel art scaling
		if tex:
			var btn_center = CenterContainer.new()
			btn_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			btn_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(btn_center)
			
			var rect = TextureRect.new()
			rect.texture = tex
			rect.custom_minimum_size = Vector2(72, 72)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			btn_center.add_child(rect)
		
		var style = StyleBoxTexture.new()
		style.texture = load("res://ui_pack/scifi pack2/HUD/character profile frame.png")
		style.texture_margin_left = 20
		style.texture_margin_right = 20
		style.texture_margin_top = 20
		style.texture_margin_bottom = 20
		style.modulate_color = Color(0.8, 0.9, 1.0, 0.9)
		btn.add_theme_stylebox_override("normal", style)
		
		var hover = StyleBoxTexture.new()
		hover.texture = load("res://ui_pack/scifi pack2/HUD/character profile frame.png")
		hover.texture_margin_left = 20
		hover.texture_margin_right = 20
		hover.texture_margin_top = 20
		hover.texture_margin_bottom = 20
		hover.modulate_color = Color(1.2, 1.5, 2.0, 1.0) # Bright neon glow effect
		btn.add_theme_stylebox_override("hover", hover)
		
		# Mobile touch-swipe drag scroll system for buttons
		btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if event.pressed:
						touch_active = true
						touch_dragging = false
						touch_start_pos = event.global_position
						touch_scroll_start = scroll.scroll_vertical
					else:
						touch_active = false
						if not touch_dragging:
							_select_skin(path, btn)
						touch_dragging = false
						
			elif event is InputEventMouseMotion:
				if touch_active:
					var diff = event.global_position - touch_start_pos
					if not touch_dragging and abs(diff.y) > 8.0:
						touch_dragging = true
					
					if touch_dragging:
						scroll.scroll_vertical = touch_scroll_start - diff.y
		)
		grid.add_child(btn)
	
	# Footer Spacer
	vbox.add_spacer(false)
	
	# START button
	var start_btn = Button.new()
	start_btn.text = "LAUNCH MISSION"
	start_btn.custom_minimum_size = Vector2(400, 90)
	if main_font: start_btn.add_theme_font_override("font", main_font)
	start_btn.add_theme_font_size_override("font_size", 52)
	
	var start_style = StyleBoxTexture.new()
	start_style.texture = load("res://ui_pack/scifi pack2/buttons/buttons without icons/variation1/blue-normal.png")
	start_style.texture_margin_left = 25
	start_style.texture_margin_right = 25
	start_style.texture_margin_top = 25
	start_style.texture_margin_bottom = 25
	start_btn.add_theme_stylebox_override("normal", start_style)
	
	var start_hover = StyleBoxTexture.new()
	start_hover.texture = load("res://ui_pack/scifi pack2/buttons/buttons without icons/variation1/blue-hovered.png")
	start_hover.texture_margin_left = 25
	start_hover.texture_margin_right = 25
	start_hover.texture_margin_top = 25
	start_hover.texture_margin_bottom = 25
	start_btn.add_theme_stylebox_override("hover", start_hover)
	start_btn.add_theme_stylebox_override("pressed", start_hover)
	
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)
	
	# Footer text
	var footer = Label.new()
	footer.text = "SYSTEM READY // V.2.0.4"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if main_font: footer.add_theme_font_override("font", main_font)
	footer.add_theme_font_size_override("font_size", 32)
	footer.modulate.a = 0.4
	vbox.add_child(footer)

func _select_skin(path: String, btn: Button) -> void:
	player_preview.set_skin(path)
	MusicManager.play_ui_click()
	
	# Animation for button
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Animation for preview ship
	var p_tween = create_tween()
	p_tween.tween_property(player_preview, "scale", Vector2(1.8, 1.8), 0.1)
	p_tween.tween_property(player_preview, "scale", Vector2(1.5, 1.5), 0.2)

func _animate_entrance() -> void:
	ui.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(ui, "modulate:a", 1.0, 0.5)
	
	# Animate the ship flying into position
	player_preview.position.y += 200
	var ship_tween = create_tween()
	ship_tween.tween_property(player_preview, "position:y", 480, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_start_pressed() -> void:
	MusicManager.play_ui_start()
	var tween = create_tween()
	tween.tween_property(ui, "modulate:a", 0.0, 0.3)
	await tween.finished
	get_tree().change_scene_to_file("res://src/scenes/game.tscn")

