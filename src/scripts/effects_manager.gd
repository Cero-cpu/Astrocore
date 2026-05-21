extends CanvasLayer

## EffectsManager — Central VFX system inspired by modern arcade shooters.
## Handles: Screen Flash, Chromatic Aberration, Slow Motion, Boss Intro text,
## Kill Combo counter, Weapon name popup, and cinematic vignette.

@onready var fx_rect = $FXRect

var _combo_count: int = 0
var _combo_timer: float = 0.0
var _combo_label: Label
var _weapon_label: Label
var _boss_warning_label: Label

func _ready() -> void:
	fx_rect.material = ShaderMaterial.new()
	fx_rect.material.shader = _create_fx_shader()
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Combo Label (center of screen, big and flashy)
	_combo_label = Label.new()
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font = load("res://fonts-ttf/BlockyPixel.ttf")
	if font: _combo_label.add_theme_font_override("font", font)
	_combo_label.add_theme_font_size_override("font_size", 44)
	_combo_label.add_theme_color_override("font_color", Color(5, 5, 0, 1))
	_combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_combo_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_combo_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_combo_label.offset_top = -220
	_combo_label.offset_bottom = -120
	_combo_label.offset_left = -300
	_combo_label.offset_right = 300
	_combo_label.modulate.a = 0.0
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combo_label)
	
	# Weapon Name popup
	_weapon_label = Label.new()
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font: _weapon_label.add_theme_font_override("font", font)
	_weapon_label.add_theme_font_size_override("font_size", 44)
	_weapon_label.add_theme_color_override("font_color", Color(0.3, 1, 5, 1))
	_weapon_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_weapon_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_weapon_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_weapon_label.offset_top = 100
	_weapon_label.offset_bottom = 150
	_weapon_label.offset_left = -300
	_weapon_label.offset_right = 300
	_weapon_label.modulate.a = 0.0
	_weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_weapon_label)
	
	# Boss Warning
	_boss_warning_label = Label.new()
	_boss_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font: _boss_warning_label.add_theme_font_override("font", font)
	_boss_warning_label.add_theme_font_size_override("font_size", 100)
	_boss_warning_label.add_theme_color_override("font_color", Color(5, 0.1, 0.1, 1))
	_boss_warning_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_warning_label.modulate.a = 0.0
	_boss_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_warning_label)

func _process(delta: float) -> void:
	# Combo decay
	if _combo_timer > 0:
		_combo_timer -= delta
		if _combo_timer <= 0:
			_combo_count = 0

# ——— Visual Effects ———

func flash(color: Color = Color.WHITE, duration: float = 0.2) -> void:
	var tween = create_tween()
	fx_rect.modulate = color
	fx_rect.modulate.a = 0.8
	tween.tween_property(fx_rect, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT)

func glitch(intensity: float = 0.5, duration: float = 0.3) -> void:
	var tween = create_tween()
	tween.tween_method(func(val): fx_rect.material.set_shader_parameter("glitch_intensity", val), intensity, 0.0, duration)
	chromatic_pulse(intensity * 4.0, duration)

func chromatic_pulse(amount: float = 2.0, duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_method(func(val): fx_rect.material.set_shader_parameter("chaos", val), amount, 0.0, duration).set_ease(Tween.EASE_OUT)

func slow_motion(duration: float = 0.5, scale: float = 0.3) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration * scale, true, false, true).timeout
	Engine.time_scale = 1.0

# ——— UI Popups ———

func show_combo(count: int) -> void:
	_combo_count = count
	_combo_timer = 2.0
	if _combo_count < 3: return # Only show for 3+
	
	_combo_label.text = "%d COMBO!" % _combo_count
	var size = 44 + min(_combo_count * 6, 80)
	_combo_label.add_theme_font_size_override("font_size", size)
	
	# Color escalation
	if _combo_count >= 15:
		_combo_label.add_theme_color_override("font_color", Color(5, 0, 5, 1)) # Cosmic Purple
	elif _combo_count >= 10:
		_combo_label.add_theme_color_override("font_color", Color(5, 0, 0, 1)) # Danger Red
	elif _combo_count >= 7:
		_combo_label.add_theme_color_override("font_color", Color(5, 2, 0, 1)) # Gold
	else:
		_combo_label.add_theme_color_override("font_color", Color(5, 5, 0, 1)) # Yellow
	
	var tween = create_tween()
	_combo_label.modulate.a = 1.0
	_combo_label.scale = Vector2(1.8, 1.8)
	_combo_label.rotation_degrees = randf_range(-10, 10)
	tween.set_parallel(true)
	tween.tween_property(_combo_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_combo_label, "rotation_degrees", 0.0, 0.3)
	tween.tween_property(_combo_label, "modulate:a", 0.0, 1.2).set_delay(0.6)

func show_weapon_name(weapon_name: String) -> void:
	_weapon_label.text = ">> %s <<" % weapon_name
	var tween = create_tween()
	_weapon_label.modulate.a = 1.0
	_weapon_label.position.y = 120
	tween.tween_property(_weapon_label, "modulate:a", 0.0, 2.0).set_delay(1.0)
	tween.parallel().tween_property(_weapon_label, "position:y", 100, 3.0)

func show_boss_warning() -> void:
	_boss_warning_label.text = "⚠ WARNING ⚠"
	var tween = create_tween()
	_boss_warning_label.modulate.a = 0.0
	
	# Blink 3 times
	for i in range(3):
		tween.tween_property(_boss_warning_label, "modulate:a", 1.0, 0.2)
		tween.tween_property(_boss_warning_label, "modulate:a", 0.0, 0.2)
	tween.tween_property(_boss_warning_label, "modulate:a", 1.0, 0.15)
	tween.tween_property(_boss_warning_label, "modulate:a", 0.0, 0.8)

func show_boss_defeated() -> void:
	_boss_warning_label.text = "BOSS DEFEATED"
	_boss_warning_label.add_theme_color_override("font_color", Color(0, 5, 0, 1))
	var tween = create_tween()
	_boss_warning_label.modulate.a = 1.0
	_boss_warning_label.scale = Vector2(0.5, 0.5)
	tween.tween_property(_boss_warning_label, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_boss_warning_label, "modulate:a", 0.0, 1.5).set_delay(1.0)
	# Reset color for next boss
	tween.tween_callback(func(): _boss_warning_label.add_theme_color_override("font_color", Color(5, 0.1, 0.1, 1)))

func update_vignette(intensity: float, color: Color = Color.BLACK) -> void:
	if is_instance_valid(fx_rect):
		fx_rect.material.set_shader_parameter("vignette_intensity", intensity)
		fx_rect.material.set_shader_parameter("vignette_color", color)

# ——— Shader ———

func _create_fx_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float chaos : hint_range(0, 10) = 0.0;
uniform float vignette_intensity : hint_range(0, 2) = 0.7;
uniform vec4 vignette_color : source_color = vec4(0, 0, 0, 1);
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 screen_col;
	if (chaos > 0.01) {
		float shift = chaos * 0.005;
		float r = texture(SCREEN_TEXTURE, uv + vec2(shift, 0.0)).r;
		float g = texture(SCREEN_TEXTURE, uv).g;
		float b = texture(SCREEN_TEXTURE, uv - vec2(shift, 0.0)).b;
		screen_col = vec4(r, g, b, 1.0);
	} else {
		screen_col = texture(SCREEN_TEXTURE, uv);
	}
	
	// Cinematic Vignette
	float dist = distance(uv, vec2(0.5));
	float vignette = smoothstep(0.8, 0.4, dist * vignette_intensity);
	COLOR.rgb = mix(vignette_color.rgb, screen_col.rgb, vignette);
	COLOR.a = 1.0;
}
"""
	return shader
