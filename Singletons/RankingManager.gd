extends Node

signal leaderboard_updated(leaderboard: Array)
signal sync_complete
signal offline_mode_enabled

const LEADERBOARD_LIMIT = 100
const OFFLINE_QUEUE_FILE = "user://tower_defense_data/offline_queue.json"

var firebase_integration: Node
var offline_queue: Array = []
var leaderboard_cache: Array = []
var _display_name_migration_attempted: bool = false
var _device_display_name_migration_attempted: bool = false
var _fetch_in_progress: bool = false
var _refresh_requested_while_fetching: bool = false
var _queued_fetch_limit: int = LEADERBOARD_LIMIT

func _ready():
	firebase_integration = FirebaseIntegration.new()
	add_child(firebase_integration)
	
	# Listen for network changes
	NetworkStatus.connection_changed.connect(_on_connection_changed)
	AccountManager.account_authenticated.connect(_on_account_authenticated)

	# Restore any queued results that survived a previous crash/close
	_load_offline_queue()

	# Initial leaderboard fetch — fire-and-forget so _ready() doesn't block.
	request_leaderboard_refresh(LEADERBOARD_LIMIT)

func request_leaderboard_refresh(limit: int = LEADERBOARD_LIMIT) -> void:
	var requested_limit = max(limit, 1)
	if _fetch_in_progress:
		_queued_fetch_limit = max(_queued_fetch_limit, requested_limit)
		_refresh_requested_while_fetching = true
		print("[RankingManager] Refresh requested while fetch is in progress")
		return

	fetch_leaderboard.call_deferred(requested_limit)

# Fetch leaderboard from Firebase
func fetch_leaderboard(limit: int = LEADERBOARD_LIMIT) -> Array:
	var requested_limit = max(limit, 1)
	if _fetch_in_progress:
		_queued_fetch_limit = max(_queued_fetch_limit, requested_limit)
		_refresh_requested_while_fetching = true
		print("[RankingManager] Fetch already in progress - returning cached leaderboard")
		return leaderboard_cache

	if not NetworkStatus.get_is_online():
		print("[RankingManager] Offline - returning cached leaderboard")
		return leaderboard_cache

	_fetch_in_progress = true
	
	print("[RankingManager] Fetching leaderboard from Firebase...")
	var result = await firebase_integration.get_data("/leaderboards/waves_survived")
	print("[RankingManager] Firebase response: %s" % result)
	
	if result.has("error"):
		print("[RankingManager] ERROR fetching leaderboard: %s" % result.get("error"))
		return _finish_leaderboard_fetch(leaderboard_cache)
	
	var data = result.get("data")
	print("[RankingManager] Leaderboard data: %s" % data)
	
	# Handle case where data is null or not a Dictionary
	if data == null or not data is Dictionary:
		print("[RankingManager] ERROR: Data is not a dictionary")
		return _finish_leaderboard_fetch(leaderboard_cache)

	await _migrate_local_display_name_if_missing(data)
	await _migrate_local_device_display_name_if_missing()
	
	var leaderboard = []
	
	for device_uuid in data.keys():
		var entry = data[device_uuid]
		var resolved_name = _resolve_entry_display_name(entry, device_uuid)
		leaderboard.append({
			"device_uuid": device_uuid,
			"display_name": resolved_name,
			"total_waves": int(entry.get("total_waves", 0)),
			"best_waves": int(entry.get("best_waves", 0)),
			"wins": int(entry.get("wins", 0)),
			"games_count": int(entry.get("games_count", 0)),
			"last_updated": entry.get("last_updated", 0)
		})
		print("[RankingManager] Added leaderboard entry: %s - total %d waves, best %d, %d wins" % [resolved_name, int(entry.get("total_waves", 0)), int(entry.get("best_waves", 0)), int(entry.get("wins", 0))])
	
	# Sort by total_waves descending, then best_waves as tiebreaker
	leaderboard.sort_custom(func(a, b):
		if a["total_waves"] != b["total_waves"]:
			return a["total_waves"] > b["total_waves"]
		return a["best_waves"] > b["best_waves"])
	leaderboard = leaderboard.slice(0, requested_limit)
	
	leaderboard_cache = leaderboard
	print("[RankingManager] Leaderboard cache updated with %d entries" % leaderboard_cache.size())
	leaderboard_updated.emit(leaderboard)
	return _finish_leaderboard_fetch(leaderboard)

# Submit game result (upload or queue if offline)
func submit_game_result(map_name: String, waves_survived: int, won: bool = false):
	print("[RankingManager] Submitting game result: %s, waves=%d, won=%s" % [map_name, waves_survived, won])
	var stats = DataPersistence.get_local_stats()
	var local_best_waves = _get_best_waves_for_map(map_name, stats)
	
	if waves_survived > local_best_waves:
		local_best_waves = waves_survived
	
	# Save first so the updated game count is included in the upload
	DataPersistence.save_game_result(map_name, waves_survived, won)
	var updated_stats = DataPersistence.get_local_stats()
	
	if NetworkStatus.get_is_online():
		print("[RankingManager] Online - uploading result")
		await _upload_result(local_best_waves, updated_stats["total_games"], updated_stats["total_waves"], updated_stats["wins"])
	else:
		print("[RankingManager] Offline - queuing result")
		_queue_result(map_name, waves_survived)
		offline_mode_enabled.emit()

# Upload result to Firebase
func _upload_result(best_waves: int, games_count: int, total_waves: int = 0, wins: int = 0):
	var device_id = AccountManager.get_device_id()
	print("[RankingManager] Uploading: device=%s, best=%d, total=%d, wins=%d, games=%d" % [device_id.substr(0, 8), best_waves, total_waves, wins, games_count])
	var display_name = _get_local_display_name()
	var timestamp = Time.get_ticks_msec()
	
	# First, ensure device record exists in /devices/{device_id}
	print("[RankingManager] Creating device record...")
	var device_path = "/devices/%s" % device_id
	var device_data = {
		"display_name": display_name,
		"created_at": timestamp,
		"last_sync": timestamp,
		"stats": {
			"total_games_played": games_count,
			"best_waves_map_1": 0,
			"best_waves_map_2": 0,
			"best_waves_map_3": 0
		}
	}
	
	var device_result = await firebase_integration.put_data(device_path, device_data)
	if device_result.has("error"):
		print("[RankingManager] Failed to create device record: %s" % device_result.get("error"))
		return
	
	print("[RankingManager] Device record created, now uploading leaderboard entry...")
	
	# Now write to leaderboard
	var leaderboard_path = "/leaderboards/waves_survived/%s" % device_id
	var leaderboard_data = {
		"display_name": display_name,
		"best_waves": best_waves,
		"total_waves": total_waves,
		"wins": wins,
		"games_count": games_count,
		"last_updated": timestamp
	}
	
	var result = await firebase_integration.put_data(leaderboard_path, leaderboard_data)
	print("[RankingManager] Leaderboard upload result: %s" % result)
	
	if not result.has("error"):
		print("[RankingManager] Sync successful!")
		sync_complete.emit()
	else:
		print("[RankingManager] Sync failed: %s" % result.get("error", "Unknown error"))

# Queue result for later sync
func _queue_result(map_name: String, waves_survived: int):
	offline_queue.append({
		"map": map_name,
		"waves": waves_survived,
		"timestamp": Time.get_ticks_msec()
	})
	_save_offline_queue()

# Persist offline queue so it survives crashes and force-closes
func _save_offline_queue() -> void:
	var f = FileAccess.open(OFFLINE_QUEUE_FILE, FileAccess.WRITE)
	if not f:
		push_error("[RankingManager] Could not write offline queue: " + OFFLINE_QUEUE_FILE)
		return
	f.store_string(JSON.stringify(offline_queue))
	f.close()

func _load_offline_queue() -> void:
	if not FileAccess.file_exists(OFFLINE_QUEUE_FILE):
		return
	var f = FileAccess.open(OFFLINE_QUEUE_FILE, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Array:
		offline_queue = parsed
		if offline_queue.size() > 0:
			print("[RankingManager] Restored %d queued result(s) from disk" % offline_queue.size())

# Sync offline queue when internet returns
func _on_connection_changed(online: bool):
	if not online:
		return

	if offline_queue.size() > 0:
		await sync_offline_queue()

	request_leaderboard_refresh()

func _on_account_authenticated() -> void:
	if NetworkStatus.get_is_online():
		request_leaderboard_refresh()

# Batch upload queued results
func sync_offline_queue():
	var stats = DataPersistence.get_local_stats()
	var best_waves = _get_best_waves_overall(stats)

	await _upload_result(best_waves, stats["total_games"], stats["total_waves"], stats["wins"])
	offline_queue.clear()
	# Remove persisted queue file now that it's been synced
	if FileAccess.file_exists(OFFLINE_QUEUE_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OFFLINE_QUEUE_FILE))
	sync_complete.emit()

func _get_best_waves_for_map(map_name: String, stats: Dictionary) -> int:
	if map_name.contains("Map1"):
		return stats.get("best_waves_map_1", 0)
	elif map_name.contains("Map2"):
		return stats.get("best_waves_map_2", 0)
	else:
		return stats.get("best_waves_map_3", 0)

func _get_best_waves_overall(stats: Dictionary) -> int:
	return max(
		stats.get("best_waves_map_1", 0),
		max(stats.get("best_waves_map_2", 0), stats.get("best_waves_map_3", 0))
	)

func get_leaderboard() -> Array:
	return leaderboard_cache

# Delete the player's own leaderboard and device records from Firebase
func reset_remote_entry() -> bool:
	if not NetworkStatus.get_is_online():
		print("[RankingManager] Offline - cannot reset remote entry")
		return false

	var device_id = AccountManager.get_device_id()

	var lb_result = await firebase_integration.delete_data("/leaderboards/waves_survived/%s" % device_id)
	if lb_result.has("error"):
		print("[RankingManager] Failed to delete leaderboard entry: %s" % lb_result.get("error"))
		return false

	var dev_result = await firebase_integration.delete_data("/devices/%s" % device_id)
	if dev_result.has("error"):
		print("[RankingManager] Failed to delete device record: %s" % dev_result.get("error"))
		return false

	# Remove from local cache so the leaderboard UI updates immediately
	leaderboard_cache = leaderboard_cache.filter(func(e): return e["device_uuid"] != device_id)
	leaderboard_updated.emit(leaderboard_cache)
	print("[RankingManager] Remote entry reset for device %s" % device_id.substr(0, 8))
	return true

func get_player_rank() -> int:
	var device_id = AccountManager.get_device_id()
	for i in range(leaderboard_cache.size()):
		if leaderboard_cache[i]["device_uuid"] == device_id:
			return i + 1
	return -1

func _finish_leaderboard_fetch(leaderboard: Array) -> Array:
	_fetch_in_progress = false

	if _refresh_requested_while_fetching:
		var retry_limit = _queued_fetch_limit
		_refresh_requested_while_fetching = false
		_queued_fetch_limit = LEADERBOARD_LIMIT
		request_leaderboard_refresh(retry_limit)
	else:
		_queued_fetch_limit = LEADERBOARD_LIMIT

	return leaderboard

func _get_local_display_name() -> String:
	var name_candidate = AccountManager.get_display_name().strip_edges()
	if name_candidate != "":
		return name_candidate

	var username_candidate = AccountManager.get_username().strip_edges()
	if username_candidate != "":
		return username_candidate

	return "Player"

func _resolve_entry_display_name(entry: Variant, device_uuid: String) -> String:
	# Always prefer the locally-known name for our own device
	if device_uuid == AccountManager.get_device_id():
		return _get_local_display_name()

	if entry is Dictionary:
		var candidate = str(entry.get("display_name", "")).strip_edges()
		if candidate != "":
			return candidate

	return "Unknown"

func _migrate_local_display_name_if_missing(data: Dictionary) -> void:
	if _display_name_migration_attempted:
		return

	_display_name_migration_attempted = true

	var device_id = AccountManager.get_device_id()
	if device_id == "" or not data.has(device_id):
		return

	var entry = data[device_id]
	if not entry is Dictionary:
		return

	var corrected_name = _get_local_display_name()
	var existing_name = str(entry.get("display_name", "")).strip_edges()
	if existing_name == corrected_name:
		return
	var update = entry.duplicate(true)
	update["display_name"] = corrected_name
	update["last_updated"] = Time.get_ticks_msec()

	var leaderboard_path = "/leaderboards/waves_survived/%s" % device_id
	var leaderboard_result = await firebase_integration.put_data(leaderboard_path, update)
	if leaderboard_result.has("error"):
		print("[RankingManager] Display name migration failed: %s" % leaderboard_result.get("error"))
		_display_name_migration_attempted = false
		return

	print("[RankingManager] Display name migration completed for local leaderboard entry")

func _migrate_local_device_display_name_if_missing() -> void:
	if _device_display_name_migration_attempted:
		return

	_device_display_name_migration_attempted = true

	var device_id = AccountManager.get_device_id()
	if device_id == "":
		return

	var corrected_name = _get_local_display_name()
	var device_path = "/devices/%s" % device_id
	var device_result = await firebase_integration.get_data(device_path)

	if device_result.has("error"):
		print("[RankingManager] Device display name migration read failed: %s" % device_result.get("error"))
		_device_display_name_migration_attempted = false
		return

	var device_data = device_result.get("data")
	if device_data == null or not device_data is Dictionary:
		return

	var existing_name = str(device_data.get("display_name", "")).strip_edges()
	if existing_name == corrected_name:
		return

	var update = device_data.duplicate(true)
	update["display_name"] = corrected_name
	update["last_sync"] = Time.get_ticks_msec()

	var write_result = await firebase_integration.put_data(device_path, update)
	if write_result.has("error"):
		print("[RankingManager] Device display name migration write failed: %s" % write_result.get("error"))
		_device_display_name_migration_attempted = false
		return

	print("[RankingManager] Device display name migration completed for local device record")
