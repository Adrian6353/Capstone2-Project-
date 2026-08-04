extends Node

const DATA_DIR = "user://tower_defense_data/"
const PROFILE_FILE = "player_profile.cfg"
const SESSIONS_FILE = "game_sessions.json"
const SETTINGS_FILE = "settings.cfg"

func _ready():
	_ensure_data_dir()

func _ensure_data_dir():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("tower_defense_data"):
		dir.make_dir("tower_defense_data")

# Save completed game session
func save_game_result(map_name: String, waves_survived: int, won: bool = false) -> bool:
	var sessions = _load_sessions()
	
	var session = {
		"timestamp": Time.get_ticks_msec(),
		"map": map_name,
		"waves": waves_survived,
		"won": won,
		"synced": false
	}
	
	sessions.append(session)
	return _save_sessions(sessions)

# Load all saved sessions
func load_game_sessions() -> Array:
	return _load_sessions()

# Get unsync'd sessions for offline queue
func get_unsynced_sessions() -> Array:
	var sessions = _load_sessions()
	var unsynced = []
	for session in sessions:
		if not session.get("synced", false):
			unsynced.append(session)
	return unsynced

# Mark session as synced
func mark_session_synced(timestamp: int):
	var sessions = _load_sessions()
	for session in sessions:
		if session["timestamp"] == timestamp:
			session["synced"] = true
			break
	_save_sessions(sessions)

# Get local stats (best waves per map)
func get_local_stats() -> Dictionary:
	var sessions = _load_sessions()
	var stats = {
		"total_games": sessions.size(),
		"total_waves": 0,
		"wins": 0,
		"best_waves_map_1": 0,
		"best_waves_map_2": 0,
		"best_waves_map_3": 0,
		# Dynamic per-map bests keyed by map name, for story maps and beyond.
		"best_waves_by_map": {}
	}
	
	for session in sessions:
		var map = session.get("map", "")
		var waves = session.get("waves", 0)
		var won = session.get("won", false)
		
		stats["total_waves"] += waves
		if won:
			stats["wins"] += 1
		
		# Legacy 3-map keys kept for RankingManager compatibility
		if map.contains("Map1"):
			stats["best_waves_map_1"] = max(stats["best_waves_map_1"], waves)
		elif map.contains("Map2"):
			stats["best_waves_map_2"] = max(stats["best_waves_map_2"], waves)
		elif map.contains("Map3") or map.contains("MultiplayerMap"):
			stats["best_waves_map_3"] = max(stats["best_waves_map_3"], waves)
		
		# Per-map bests for all maps (including story mode)
		if map != "":
			var current_best = stats["best_waves_by_map"].get(map, 0)
			stats["best_waves_by_map"][map] = max(current_best, waves)
	
	return stats

# Reset all local progress (clears game sessions / personal bests)
func reset_local_stats() -> bool:
	return _save_sessions([])

# Load sessions from file
func _load_sessions() -> Array:
	var file_path = DATA_DIR + SESSIONS_FILE
	if not ResourceLoader.exists(file_path):
		return []
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return []
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error:
		return []
	
	return json.data if json.data is Array else []

# Save sessions to file — atomic write (temp + rename) so a mid-write crash
# never corrupts the existing save file.
func _save_sessions(sessions: Array) -> bool:
	var file_path = DATA_DIR + SESSIONS_FILE
	var tmp_path  = DATA_DIR + SESSIONS_FILE + ".tmp"

	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(sessions))
	file = null  # ensure the file is flushed and closed

	# Atomically replace the real file with the temp file.
	var dir = DirAccess.open(DATA_DIR)
	if dir == null:
		return false
	return dir.rename(SESSIONS_FILE + ".tmp", SESSIONS_FILE) == OK

# --- Settings persistence (tutorial flags, etc.) ---

func save_setting(key: String, value) -> void:
	var config = ConfigFile.new()
	var file_path = DATA_DIR + SETTINGS_FILE
	# Load existing settings first
	if FileAccess.file_exists(file_path):
		config.load(file_path)
	config.set_value("settings", key, value)
	config.save(file_path)

func load_setting(key: String, default_value = null):
	var config = ConfigFile.new()
	var file_path = DATA_DIR + SETTINGS_FILE
	if not FileAccess.file_exists(file_path):
		return default_value
	var err = config.load(file_path)
	if err != OK:
		return default_value
	return config.get_value("settings", key, default_value)

# --- Lootbox / gacha persistence ---

const LOOTBOX_FILE = "lootbox_data.cfg"

func save_lootbox_data(data: Dictionary) -> void:
	var config = ConfigFile.new()
	var file_path = DATA_DIR + LOOTBOX_FILE
	if FileAccess.file_exists(file_path):
		config.load(file_path)
	# Store arrays as JSON strings so ConfigFile handles them cleanly.
	config.set_value("lootbox", "unlocked_families", JSON.stringify(data.get("unlocked_families", [])))
	config.set_value("lootbox", "shards", data.get("shards", 0))
	var boxes: Dictionary = data.get("pending_boxes", {})
	config.set_value("lootbox", "boxes_common",    boxes.get("common",    0))
	config.set_value("lootbox", "boxes_rare",      boxes.get("rare",      0))
	config.set_value("lootbox", "boxes_legendary", boxes.get("legendary", 0))
	config.set_value("lootbox", "family_shards", JSON.stringify(data.get("family_shards", {})))
	config.save(file_path)

func load_lootbox_data() -> Dictionary:
	var config = ConfigFile.new()
	var file_path = DATA_DIR + LOOTBOX_FILE
	if not FileAccess.file_exists(file_path):
		return {}
	var err = config.load(file_path)
	if err != OK:
		return {}
	var families_raw: String = config.get_value("lootbox", "unlocked_families", "[]")
	var json := JSON.new()
	var families: Array = []
	if json.parse(families_raw) == OK and json.data is Array:
		families = json.data
	var family_shards_raw: String = config.get_value("lootbox", "family_shards", "{}")
	var json2 := JSON.new()
	var family_shards: Dictionary = {}
	if json2.parse(family_shards_raw) == OK and json2.data is Dictionary:
		family_shards = json2.data
	return {
		"unlocked_families": families,
		"shards": config.get_value("lootbox", "shards", 0),
		"pending_boxes": {
			"common":    config.get_value("lootbox", "boxes_common",    0),
			"rare":      config.get_value("lootbox", "boxes_rare",      0),
			"legendary": config.get_value("lootbox", "boxes_legendary", 0),
		},
		"family_shards": family_shards,
	}
