extends Node

# Music Paths (Directly linked to your uploaded files)
var lobby_music_path: String = "res://src/sounds/loby/loby_primera_musica.mp3"
var game_music_path: String = "res://src/sounds/game/game_music.mp3"

var player1: AudioStreamPlayer
var player2: AudioStreamPlayer
var active_player: AudioStreamPlayer = null

var target_volume_db: float = -6.0 # Premium balanced volume level
var crossfade_duration: float = 1.5

func _ready() -> void:
	# Keep music playing even when the game is paused!
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Instantiate two players for dynamic crossfading
	player1 = AudioStreamPlayer.new()
	player1.bus = &"Music" # Fallback to Master if Music bus is not created
	add_child(player1)
	
	player2 = AudioStreamPlayer.new()
	player2.bus = &"Music"
	add_child(player2)
	
	active_player = player1

func play_lobby_music() -> void:
	play_track(lobby_music_path)

func play_game_music() -> void:
	play_track(game_music_path)

func play_track(path: String) -> void:
	if path == "":
		push_warning("[MusicManager] Empty track path provided.")
		return
		
	# Safeguard: if the file does not exist, do not crash!
	if not FileAccess.file_exists(path):
		push_warning("[MusicManager] Music track not found: %s. Placeholder state active." % path)
		return
		
	var stream = load(path) as AudioStream
	if not stream:
		push_warning("[MusicManager] Failed to load audio stream from path: %s" % path)
		return
		
	# Determine which player to use for crossfading
	var next_player = player2 if active_player == player1 else player1
	
	# If this track is already playing on the active player, don't restart it!
	if active_player.playing and active_player.stream and active_player.stream.resource_path == path:
		return
		
	# Setup next player
	next_player.stream = stream
	next_player.volume_db = -80.0 # Start completely silent
	next_player.play()
	
	# Create smooth crossfade tween
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade out current active player
	var old_player = active_player
	if old_player.playing:
		tween.tween_property(old_player, "volume_db", -80.0, crossfade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Fade in next player
	tween.tween_property(next_player, "volume_db", target_volume_db, crossfade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# When crossfade is complete, stop the old player
	tween.chain().tween_callback(func():
		if old_player.playing:
			old_player.stop()
	)
	
	# Instantly switch roles so future calls know what the current active player is
	active_player = next_player
