import os

tscn_template = """[gd_scene format=3]

[ext_resource type="PackedScene" path="res://src/scenes/player.tscn" id="1_player"]
[ext_resource type="Texture2D" path="res://Shoot`em Up/SpaceShips_Player-0001.png" id="3_anim"]

[sub_resource type="AtlasTexture" id="AtlasTexture_f0"]
atlas = ExtResource("3_anim")
region = Rect2(0, {y_offset}, 64, 64)

[sub_resource type="AtlasTexture" id="AtlasTexture_f1"]
atlas = ExtResource("3_anim")
region = Rect2(64, {y_offset}, 64, 64)

[sub_resource type="AtlasTexture" id="AtlasTexture_f2"]
atlas = ExtResource("3_anim")
region = Rect2(128, {y_offset}, 64, 64)

[sub_resource type="AtlasTexture" id="AtlasTexture_f3"]
atlas = ExtResource("3_anim")
region = Rect2(192, {y_offset}, 64, 64)

[sub_resource type="SpriteFrames" id="SpriteFrames_skin"]
animations = [{
"frames": [{
"duration": 1.0,
"texture": SubResource("AtlasTexture_f0")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_f1")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_f2")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_f3")
}],
"loop": true,
"name": &"idle",
"speed": 8.0
}, {
"frames": [{
"duration": 1.0,
"texture": SubResource("AtlasTexture_f0")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_f1")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_f2")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_f3")
}],
"loop": true,
"name": &"left",
"speed": 8.0
}, {
"frames": [{
"duration": 1.0,
"texture": SubResource("AtlasTexture_f0")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_f1")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_f2")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_f3")
}],
"loop": true,
"name": &"right",
"speed": 8.0
}]

[node name="PlayerNew" instance=ExtResource("1_player")]

[node name="AnimatedSprite2D" parent="." index="0"]
sprite_frames = SubResource("SpriteFrames_skin")
animation = &"idle"
"""

os.makedirs("skins", exist_ok=True)
for i in range(4):
    skin_num = 8 + i
    y_off = i * 64
    content = tscn_template.replace("{y_offset}", str(y_off))
    file_path = f"skins/player_skin_0{skin_num}.tscn" if skin_num < 10 else f"skins/player_skin_{skin_num}.tscn"
    with open(file_path, "w") as f:
        f.write(content)
    print(f"Generated {file_path} with y_offset={y_off}")
