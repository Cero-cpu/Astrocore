import os
import re

# Themes from game.gd
themes = [
    # 0
    {"bg": "Color(0.01, 0.01, 0.05, 1)", "tex": "res://Skyel Space Shooter - FREE/Backgrounds/spr_background_01.png"},
    # 1
    {"bg": "Color(0.05, 0.01, 0.01, 1)", "tex": "res://Skyel Space Shooter - FREE/Backgrounds/spr_background_02.png"},
    # 2
    {"bg": "Color(0.01, 0.05, 0.02, 1)", "tex": "res://Shoot`em Up/Background_Full-0001.png"},
    # 3
    {"bg": "Color(0.04, 0.01, 0.06, 1)", "tex": "res://Skyel Space Shooter - FREE/Backgrounds/spr_background_01.png"},
    # 4
    {"bg": "Color(0.05, 0.04, 0.01, 1)", "tex": "res://Shoot`em Up/Background_Full-0001.png"},
    # 5
    {"bg": "Color(0, 0, 0.03, 1)", "tex": "res://Skyel Space Shooter - FREE/Backgrounds/spr_background_02.png"},
    # 6
    {"bg": "Color(0.05, 0.02, 0, 1)", "tex": "res://Skyel Space Shooter - FREE/Backgrounds/spr_background_02.png"},
    # 7
    {"bg": "Color(0.01, 0.01, 0.04, 1)", "tex": "res://Shoot`em Up/Background_Full-0001.png"},
    # 8
    {"bg": "Color(0.03, 0, 0.05, 1)", "tex": "res://Skyel Space Shooter - FREE/Backgrounds/spr_background_01.png"},
    # 9
    {"bg": "Color(0.02, 0.02, 0.04, 1)", "tex": "res://Shoot`em Up/Background_Full-0001.png"}
]

base_dir = "/home/julian/brotito"
levels_dir = os.path.join(base_dir, "src", "levels")
os.makedirs(levels_dir, exist_ok=True)

level_script = """extends Node2D

@export var scroll_speed: float = 10.0

func _ready() -> void:
	# Make background fill screen dynamically
	var screen_size = get_viewport_rect().size
	$Background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Background.offset_left = -200
	$Background.offset_right = 200
	
	if has_node("BackgroundTex"):
		$BackgroundTex.centered = true
		$BackgroundTex.position = screen_size / 2
		$BackgroundTex.region_enabled = true
		$BackgroundTex.region_rect = Rect2(Vector2.ZERO, screen_size * 1.5)

func _process(delta: float) -> void:
	if get_tree().paused: return
	if has_node("BackgroundTex"):
		$BackgroundTex.region_rect.position.y -= delta * scroll_speed
"""

script_path = os.path.join(levels_dir, "level_base.gd")
with open(script_path, "w") as f:
    f.write(level_script)

# Create level scenes
for i in range(10):
    theme = themes[i]
    tscn_content = f"""[gd_scene load_steps=3 format=3 uid="uid://level{i}uid_placeholder"]

[ext_resource type="Script" path="res://src/levels/level_base.gd" id="1_script"]
[ext_resource type="Texture2D" path="{theme['tex']}" id="2_bg"]

[node name="Level_{i+1}" type="Node2D"]
script = ExtResource("1_script")

[node name="Background" type="ColorRect" parent="."]
offset_left = -200.0
offset_right = 920.0
offset_bottom = 1280.0
color = {theme['bg']}
metadata/_edit_use_anchors_ = true

[node name="BackgroundTex" type="Sprite2D" parent="."]
texture_repeat = 2
position = Vector2(360, 640)
scale = Vector2(4.5, 4.5)
texture = ExtResource("2_bg")
region_enabled = true
region_rect = Rect2(0, 0, 1080, 1920)
"""
    with open(os.path.join(levels_dir, f"level_{i+1}.tscn"), "w") as f:
        f.write(tscn_content)
