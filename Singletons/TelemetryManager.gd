extends Node
## TelemetryManager — Session data logger for academic playtesting study.
##
## Silently tracks co-op gameplay events and writes a structured JSON file to
## user://tower_defense_data/ at the end of each session.  Works in both solo
## and co-op modes (is_coop_session flag distinguishes them).
##
## Autoloaded AFTER CoopManager so CoopManager state is already valid in _ready().

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

const DATA_DIR := "user://tower_defense_data/"

# ─────────────────────────────────────────────────────────────────────────────
# Internal state
# ─────────────────────────────────────────────────────────────────────────────

var _session_active: bool = false
var _planning_start_time: float = 0.0
var _planning_durations: Array = []   # per-wave planning window lengths (seconds)
var _is_in_planning: bool = false
var _session_data: Dictionary = {}

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_ensure_data_dir()

func _ensure_data_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("tower_defense_data"):
		dir.make_dir("tower_defense_data")

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Called once at the start of every game session (solo or co-op).
func start_session() -> void:
	if _session_active:
		return

	var is_coop: bool = CoopManager.is_coop_active
	var local_uuid: String = AccountManager.device_uuid
	var unix_ts: int = int(Time.get_unix_time_from_system())
	var session_id: String = local_uuid.left(8) + "_" + str(unix_ts)

	# Determine role names
	var local_role: String = "PlayerA" if (not is_coop or CoopManager.is_host) else "PlayerB"

	_session_data = {
		"session_id": session_id,
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"is_coop_session": is_coop,
		"role_assignment": {
			"device_a": "Mandirigma",
			"device_b": "Babaylan"
		},
		"local_role": local_role,
		"device_a_id": local_uuid if (not is_coop or CoopManager.is_host) else "",
		"device_b_id": local_uuid if (is_coop and not CoopManager.is_host) else "",
		"stage_cleared": false,
		"total_waves": GameData.selected_wave_count,
		"waves_completed": 0,
		"final_base_hp": 100,
		"planning_phase_metrics": {
			"average_planning_duration_seconds": 0.0,
			"next_wave_preview_view_time_seconds": 0.0,
			"total_towers_placed_during_planning": 0,
			"total_cooldown_forced_role_switches": 0
		},
		"real_time_combat_metrics": {
			"total_towers_placed_mid_wave": 0,
			"role_a_cards_activated": 0,
			"role_b_cards_activated": 0,
			"cooldown_blocks_triggered": 0
		},
		"coop_interaction_logs": []
	}

	_session_active = true
	_planning_start_time = Time.get_ticks_msec() / 1000.0
	_is_in_planning = true   # wave 1 pre-planning starts immediately

	print("[Telemetry] Session started: ", session_id, "  role=", local_role)


## Called via RPC to set the partner device's UUID into the correct slot.
func set_partner_device_id(partner_uuid: String) -> void:
	if not _session_active:
		return
	if CoopManager.is_host:
		_session_data["device_b_id"] = partner_uuid
	else:
		_session_data["device_a_id"] = partner_uuid


## Called when a wave ends (planning phase begins).
func start_planning_phase(wave_just_finished: int) -> void:
	if not _session_active:
		return
	_is_in_planning = true
	_planning_start_time = Time.get_ticks_msec() / 1000.0
	log_coop_event("planning_phase_started", {"after_wave": wave_just_finished})


## Called when a player confirms ready / wave is about to start (planning ends).
func end_planning_phase() -> void:
	if not _session_active or not _is_in_planning:
		return
	var duration: float = (Time.get_ticks_msec() / 1000.0) - _planning_start_time
	_planning_durations.append(duration)
	_is_in_planning = false
	_recalculate_planning_metrics()


## Called when the local player successfully places a tower.
## is_combat — true if wave_in_progress was already true at placement time.
## player_role — CoopManager.get_local_player_id() or 1 for solo.
func on_tower_placed(is_combat: bool, player_role: int, tower_type: String, position: Vector2) -> void:
	if not _session_active:
		return
	var phase: String = "combat" if is_combat else "planning"
	if is_combat:
		_session_data["real_time_combat_metrics"]["total_towers_placed_mid_wave"] += 1
	else:
		_session_data["planning_phase_metrics"]["total_towers_placed_during_planning"] += 1

	# Track per-role card (tower) activations
	if player_role == 1:
		_session_data["real_time_combat_metrics"]["role_a_cards_activated"] += 1
	else:
		_session_data["real_time_combat_metrics"]["role_b_cards_activated"] += 1

	log_coop_event("card_activated", {
		"role": "PlayerA" if player_role == 1 else "PlayerB",
		"card_id": tower_type,
		"phase": phase,
		"tile": str(position)
	})


## Called on the REMOTE peer inside _coop_sync_tower() to count partner's builds.
func on_partner_tower_placed(tower_type: String, is_combat: bool) -> void:
	if not _session_active:
		return
	# Partner's role is the opposite of ours
	var partner_role: int = 2 if CoopManager.is_host else 1
	if is_combat:
		_session_data["real_time_combat_metrics"]["total_towers_placed_mid_wave"] += 1
	else:
		_session_data["planning_phase_metrics"]["total_towers_placed_during_planning"] += 1
	if partner_role == 1:
		_session_data["real_time_combat_metrics"]["role_a_cards_activated"] += 1
	else:
		_session_data["real_time_combat_metrics"]["role_b_cards_activated"] += 1


## Called when a player tries to place a card that is still on cooldown.
func on_cooldown_blocked(tower_type: String, player_role: int) -> void:
	if not _session_active:
		return
	_session_data["real_time_combat_metrics"]["cooldown_blocks_triggered"] += 1
	log_coop_event("cooldown_blocked", {
		"role": "PlayerA" if player_role == 1 else "PlayerB",
		"card_id": tower_type,
		"phase": "combat" if not _is_in_planning else "planning"
	})


## Called when a card/tower is collected from an enemy drop.
func on_card_collected(tower_type: String, player_role: int) -> void:
	if not _session_active:
		return
	log_coop_event("card_collected", {
		"role": "PlayerA" if player_role == 1 else "PlayerB",
		"card_id": tower_type
	})


## Append a timestamped entry to the co-op interaction log.
func log_coop_event(event_type: String, details: Dictionary) -> void:
	if not _session_active:
		return
	var entry: Dictionary = {
		"timestamp": snappedf(Time.get_ticks_msec() / 1000.0, 0.1),
		"event": event_type
	}
	entry.merge(details)
	_session_data["coop_interaction_logs"].append(entry)


## Called at game_over (host) and _client_game_over (client).
func finish_session(won: bool, final_hp: int, waves_done: int) -> void:
	if not _session_active:
		return
	# Close any open planning window
	if _is_in_planning:
		end_planning_phase()

	_session_data["stage_cleared"] = won
	_session_data["final_base_hp"] = final_hp
	_session_data["waves_completed"] = waves_done

	log_coop_event("session_ended", {
		"stage_cleared": won,
		"final_base_hp": final_hp,
		"waves_completed": waves_done
	})

	save_session_log()
	_session_active = false


## Write the session JSON to disk.
func save_session_log() -> void:
	var unix_ts: int = int(Time.get_unix_time_from_system())
	var file_path: String = DATA_DIR + "telemetry_" + str(unix_ts) + ".json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_session_data, "\t"))
		file.close()
		print("[Telemetry] Session log saved → ", file_path)
	else:
		push_error("[Telemetry] Failed to write session log to: " + file_path)

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _recalculate_planning_metrics() -> void:
	var count: int = _planning_durations.size()
	if count == 0:
		return
	var total: float = 0.0
	for d in _planning_durations:
		total += d
	_session_data["planning_phase_metrics"]["next_wave_preview_view_time_seconds"] = snappedf(total, 0.1)
	_session_data["planning_phase_metrics"]["average_planning_duration_seconds"] = snappedf(total / count, 0.1)
