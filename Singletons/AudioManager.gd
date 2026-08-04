extends Node
## AudioManager - Handles all sound effects and background music
## This is an autoload singleton (see project.godot)

# Audio player nodes for different channels
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var ui_player: AudioStreamPlayer

# Audio file paths
var sfx_paths = {
	"tower_fire": "res://Assets/Audio/SFX/tower_fire.ogg",
	"tower_fire_alt": "res://Assets/Audio/SFX/tower_fire_alt.ogg",
	"enemy_hit": "res://Assets/Audio/SFX/enemy_hit.ogg",
	"enemy_death": "res://Assets/Audio/SFX/enemy_death.ogg",
	"explosion": "res://Assets/Audio/SFX/explosion.ogg",
	"pitik_fire": "res://Assets/Audio/SFX/pitik_fire.ogg",
	"pitik_impact": "res://Assets/Audio/SFX/pitik_impact.ogg",
	"kampilan_fire": "res://Assets/Audio/SFX/kampilan_fire.ogg",
	"kampilan_impact": "res://Assets/Audio/SFX/kampilan_impact.ogg",
	"bawang_fire": "res://Assets/Audio/SFX/bawang_fire.ogg",
	"bawang_impact": "res://Assets/Audio/SFX/bawang_impact.ogg",
	"mutya_fire": "res://Assets/Audio/SFX/mutya_fire.ogg",
	"mutya_impact": "res://Assets/Audio/SFX/mutya_impact.ogg",
	"agimat_fire": "res://Assets/Audio/SFX/agimat_fire.ogg",
	"agimat_impact": "res://Assets/Audio/SFX/agimat_impact.ogg",
	"parol_fire": "res://Assets/Audio/SFX/parol_fire.ogg",
	"parol_impact": "res://Assets/Audio/SFX/parol_impact.ogg",
	"balete_fire": "res://Assets/Audio/SFX/balete_fire.ogg",
	"balete_impact": "res://Assets/Audio/SFX/balete_impact.ogg",
	"kidlat_fire": "res://Assets/Audio/SFX/kidlat_fire.ogg",
	"kidlat_impact": "res://Assets/Audio/SFX/kidlat_impact.ogg",
	"sibat_fire": "res://Assets/Audio/SFX/sibat_fire.ogg",
	"sibat_impact": "res://Assets/Audio/SFX/sibat_impact.ogg",
	"habing_fire": "res://Assets/Audio/SFX/habing_fire.ogg",
	"habing_impact": "res://Assets/Audio/SFX/habing_impact.ogg",
	"button_click": "res://Assets/Audio/UI/button_click.ogg",
	"button_hover": "res://Assets/Audio/UI/button_hover.ogg",
	"coin_collect": "res://Assets/Audio/SFX/coin_collect.ogg",
	"tower_place": "res://Assets/Audio/SFX/tower_place.ogg",
	"tower_sell": "res://Assets/Audio/SFX/tower_sell.ogg",
	"tower_upgrade": "res://Assets/Audio/Packs/(Not A Placeholder) Free Sounds Pack/Magical Interface 5-1.wav",
	"upgrade_panel_open": "res://Assets/Audio/Packs/JDSherbert - Ultimate UI SFX Pack (FREE)/Stereo/JDSherbert - Ultimate UI SFX Pack - Popup Open - 1.ogg",
	"upgrade_panel_close": "res://Assets/Audio/Packs/JDSherbert - Ultimate UI SFX Pack (FREE)/Stereo/JDSherbert - Ultimate UI SFX Pack - Popup Close - 1.ogg",
	"wave_start": "res://Assets/Audio/SFX/wave_start.ogg",
	"game_over": "res://Assets/Audio/SFX/game_over.ogg",
	"game_win": "res://Assets/Audio/SFX/game_win.ogg",
}

var music_paths = {
	"main_menu": "res://Assets/Audio/Music/MainMenu-TitleScreenMusic",
	"new_game": "res://Assets/Audio/Music/NewGameMusic",
	"leaderboard": "res://Assets/Audio/Music/LeaderboardsMusic",
	"gameplay": "res://Assets/Audio/Music/gameplay_loop",
	"bosswave": "res://Assets/Audio/Music/BossWave",
	"boss_wave": "res://Assets/Audio/Music/BossWave",
	"normal_wave": "res://Assets/Audio/Music/NormalWave",
	"map_selection": "res://Assets/Audio/Music/MainMenu-TitleScreenMusic",
}

# Track currently playing music name to avoid restarting the same track
var current_music_track: String = ""
# Active fade tween — killed before starting a new one to prevent overlapping plays
var _music_tween: Tween = null

# Settings
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 0.8
var ui_volume: float = 0.9
var sounds_enabled: bool = true

# Number of SFX players to create for polyphony
const NUM_SFX_CHANNELS = 8

func _ready() -> void:
	# Setup music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	# Setup UI player
	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "UI"
	add_child(ui_player)
	
	# Setup multiple SFX players for polyphony
	for i in range(NUM_SFX_CHANNELS):
		var sfx = AudioStreamPlayer.new()
		sfx.bus = "SFX"
		add_child(sfx)
		sfx_players.append(sfx)
	
	# Load settings from GameData if available
	if GameData and GameData.has_method("load_audio_settings"):
		var settings = GameData.load_audio_settings()
		master_volume = clamp(settings.get("master_volume", 1.0), 0.0, 1.0)
		sfx_volume = clamp(settings.get("sfx_volume", 1.0), 0.0, 1.0)
		music_volume = clamp(settings.get("music_volume", 0.8), 0.0, 1.0)
		ui_volume = clamp(settings.get("ui_volume", 0.9), 0.0, 1.0)
		sounds_enabled = settings.get("sounds_enabled", true)
	
	# Ensure volumes are valid after loading
	if is_nan(master_volume):
		master_volume = 1.0
	if is_nan(sfx_volume):
		sfx_volume = 1.0
	if is_nan(music_volume):
		music_volume = 0.8
	if is_nan(ui_volume):
		ui_volume = 0.9
	
	update_volumes()

func get_audio_path(base_path: String) -> String:
	"""Check for audio file in OGG or WAV format."""
	# Try OGG first
	if ResourceLoader.exists(base_path + ".ogg"):
		return base_path + ".ogg"
	# Fall back to WAV
	if ResourceLoader.exists(base_path + ".wav"):
		return base_path + ".wav"
	# Fall back to MP3
	if ResourceLoader.exists(base_path + ".mp3"):
		return base_path + ".mp3"
	# Return default OGG path for error messages
	return base_path + ".ogg"

func play_sfx(sound_name: String, pitch_variation: float = 0.0) -> void:
	if not sounds_enabled:
		return
	
	if not sfx_paths.has(sound_name):
		push_warning("Sound effect not found: " + sound_name)
		return
	
	var base_path = sfx_paths[sound_name].trim_suffix(".ogg").trim_suffix(".wav").trim_suffix(".mp3")
	var sound_path = get_audio_path(base_path)
	
	if not ResourceLoader.exists(sound_path):
		push_warning("Sound file not found: " + sound_path + " - Add audio files to Assets/Audio/")
		return
	
	var audio_stream = load(sound_path)
	if audio_stream == null:
		return
	
	# Find the next available SFX player
	var player = get_available_sfx_player()
	if player == null:
		player = sfx_players[0]  # Fallback to first player
	
	player.stream = audio_stream
	player.pitch_scale = 1.0 + pitch_variation
	player.play()

func play_ui_sound(sound_name: String) -> void:
	if not sounds_enabled:
		return
	
	if not sfx_paths.has(sound_name):
		push_warning("UI sound not found: " + sound_name)
		return
	
	var base_path = sfx_paths[sound_name].trim_suffix(".ogg").trim_suffix(".wav").trim_suffix(".mp3")
	var sound_path = get_audio_path(base_path)
	
	if not ResourceLoader.exists(sound_path):
		push_warning("Sound file not found: " + sound_path)
		return
	
	var audio_stream = load(sound_path)
	if audio_stream == null:
		return
	
	ui_player.stream = audio_stream
	ui_player.play()

func play_music(track_name: String, fade_duration: float = 1.0) -> void:
	if not sounds_enabled:
		return
	
	if not music_paths.has(track_name):
		push_warning("Music track not found: " + track_name)
		return
	
	# Don't restart the same track (guard checked before any async work)
	if track_name == current_music_track and music_player.playing:
		return
	
	var base_path = music_paths[track_name]
	var track_path = get_audio_path(base_path)
	
	if not ResourceLoader.exists(track_path):
		push_warning("Music file not found: " + track_path + " - Add audio files to Assets/Audio/Music/")
		return
	
	var audio_stream = load(track_path)
	if audio_stream == null:
		return
	
	# Enable looping on the stream
	if audio_stream is AudioStreamOggVorbis:
		audio_stream.loop = true
	elif audio_stream is AudioStreamMP3:
		audio_stream.loop = true
	elif audio_stream is AudioStreamWAV:
		audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	# Mark the new track immediately so any concurrent call hits the guard above.
	current_music_track = track_name
	
	# Kill any in-flight fade tween so it can't fire its callback and call play() again.
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
		_music_tween = null
	
	if fade_duration > 0:
		_music_tween = create_tween()
		if music_player.playing:
			_music_tween.tween_property(music_player, "volume_db", -80.0, fade_duration)
		_music_tween.tween_callback(func():
			music_player.stream = audio_stream
			music_player.play()
		)
		_music_tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), fade_duration)
	else:
		music_player.stream = audio_stream
		music_player.play()

func stop_music(fade_duration: float = 1.0) -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
		_music_tween = null
	if fade_duration > 0:
		_music_tween = create_tween()
		_music_tween.tween_property(music_player, "volume_db", -80.0, fade_duration)
		_music_tween.tween_callback(func():
			music_player.stop()
			current_music_track = ""
		)
	else:
		music_player.stop()
		current_music_track = ""

func get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
	return null

func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	if is_nan(master_volume):
		master_volume = 1.0
	update_volumes()
	save_audio_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	if is_nan(sfx_volume):
		sfx_volume = 1.0
	update_volumes()
	save_audio_settings()

func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	if is_nan(music_volume):
		music_volume = 0.8
	update_volumes()
	save_audio_settings()

func set_ui_volume(value: float) -> void:
	ui_volume = clamp(value, 0.0, 1.0)
	if is_nan(ui_volume):
		ui_volume = 0.9
	update_volumes()
	save_audio_settings()

func toggle_sounds() -> void:
	sounds_enabled = not sounds_enabled
	save_audio_settings()

func update_volumes() -> void:
	if music_player:
		var music_vol = clamp(master_volume * music_volume, 0.0, 1.0)
		if not is_nan(music_vol):
			music_player.volume_db = linear_to_db(music_vol)
	if ui_player:
		var ui_vol = clamp(master_volume * ui_volume, 0.0, 1.0)
		if not is_nan(ui_vol):
			ui_player.volume_db = linear_to_db(ui_vol)
	for player in sfx_players:
		if player:
			var sfx_vol = clamp(master_volume * sfx_volume, 0.0, 1.0)
			if not is_nan(sfx_vol):
				player.volume_db = linear_to_db(sfx_vol)

func save_audio_settings() -> void:
	if not GameData:
		return
	
	var settings = {
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"ui_volume": ui_volume,
		"sounds_enabled": sounds_enabled,
	}
	
	if GameData.has_method("save_audio_settings"):
		GameData.save_audio_settings(settings)
