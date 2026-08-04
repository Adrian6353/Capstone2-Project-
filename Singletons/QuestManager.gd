extends Node
## QuestManager — Story mode quest / objective system.
##
## Structure: 10 chapters × 4 maps each = 40 stages.
## Maps 1-3 are regular maps; map 4 is the chapter boss.
## Each map has objectives (win, kill, survive) that reward lootboxes on claim.
##
## Progression:
##   - Map N+1 unlocks when map N has been WON (not just objectives claimed).
##   - Chapter N+1 unlocks when chapter N's boss map (map 4) has been WON.
##
## Persistence: local JSON + optional Firebase sync.

signal quest_updated(obj_id: String)
signal quest_completed(obj_id: String)
signal map_unlocked(chapter: int, map_idx: int)

# ---------------------------------------------------------------------------
# Runtime data — populated in _ready()
# ---------------------------------------------------------------------------

## Nested dict: chapter(int) → map_idx(int) → Array of objective dicts.
## Each dict: {id, type, title, target, reward_rarity}
## Objective types: "win_map", "kill_enemies", "survive_waves"
var MAP_OBJECTIVES: Dictionary = {}

## Which maps have been WON. chapter(int) → map_idx(int) → bool
var map_completion: Dictionary = {}

## Per-objective progress. obj_id(String) → {progress, completed, claimed}
var objective_progress: Dictionary = {}

## Whether the prologue cutscene has been shown to the player.
var prologue_seen: bool = false

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const SAVE_PATH := "user://tower_defense_data/quest_data.json"

## Rarity of rewards by chapter range (regular map objectives).
const _CHAPTER_RARITY := {
	"low":    "common",     # chapters 1–3
	"mid":    "rare",       # chapters 4–6
	"high":   "legendary",  # chapters 7–10
}

const _REGULAR_MAP_WAVE_TARGETS := [3, 5, 7]
const _BOSS_MAP_WAVE_TARGET := 7

## Chapter names matching GameData.chapter_enemy_pools.
const CHAPTER_NAMES := {
	1:  "Embers at the Outskirts",
	2:  "The Balete Giant",
	3:  "Wings Over Dapithapon",
	4:  "The Crooked Pass",
	5:  "The Black Swarm",
	6:  "Hunt Beneath Noonday",
	7:  "The Red-Moon Siege",
	8:  "Gate of the Wild Realm",
	9:  "Court of Hollow Roots",
	10: "The Last Weave",
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

var _firebase: Node = null
var _listener_path_quests: String = ""
var _listener_path_story: String = ""

func _get_firebase() -> Node:
	if _firebase == null or not is_instance_valid(_firebase):
		_firebase = preload("res://Scripts/FirebaseIntegration.gd").new()
		add_child(_firebase)
	return _firebase

func _ready() -> void:
	MAP_OBJECTIVES = _build_map_objectives()
	_init_map_completion()
	load_data()
	if AccountManager.is_authenticated:
		_start_firebase_sync()
	else:
		AccountManager.account_authenticated.connect(_on_account_authenticated)

func _on_account_authenticated() -> void:
	_start_firebase_sync()

func _exit_tree() -> void:
	var fb := _get_firebase()
	if not _listener_path_quests.is_empty():
		fb.stop_listener(_listener_path_quests)
	if not _listener_path_story.is_empty():
		fb.stop_listener(_listener_path_story)

## Runs the initial one-time fetch then opens the real-time SSE streams.
func _start_firebase_sync() -> void:
	await _load_from_firebase()
	_start_realtime_listeners()

func _start_realtime_listeners() -> void:
	var username: String = AccountManager.current_username
	if username.is_empty():
		return
	var fb := _get_firebase()
	var path_q: String = "/quests/" + username
	var path_s: String = "/story_progress/" + username
	# Stop old listeners if switching accounts.
	if not _listener_path_quests.is_empty() and _listener_path_quests != path_q:
		fb.stop_listener(_listener_path_quests)
	if not _listener_path_story.is_empty() and _listener_path_story != path_s:
		fb.stop_listener(_listener_path_story)
	if _listener_path_quests != path_q:
		_listener_path_quests = path_q
		fb.start_listener(path_q, _on_quest_sse_event)
	if _listener_path_story != path_s:
		_listener_path_story = path_s
		fb.start_listener(path_s, _on_story_sse_event)

func _on_quest_sse_event(event_type: String, event_path: String, data: Variant) -> void:
	if event_path != "/" or data == null or not data is Dictionary:
		return
	var changed := false
	# Merge: take the maximum progress for each objective (never lose progress).
	for obj_id in data:
		var remote_prog = data[obj_id]
		if not remote_prog is Dictionary:
			continue
		if not objective_progress.has(obj_id):
			objective_progress[obj_id] = {"progress": 0, "completed": false, "claimed": false}
		var local_prog: Dictionary = objective_progress[obj_id]
		var remote_amount: int = int(remote_prog.get("progress", 0))
		if remote_amount > local_prog.get("progress", 0):
			local_prog["progress"] = remote_amount
			changed = true
		if remote_prog.get("completed", false) and not local_prog.get("completed", false):
			local_prog["completed"] = true
			changed = true
			quest_completed.emit(obj_id)
		if remote_prog.get("claimed", false) and not local_prog.get("claimed", false):
			local_prog["claimed"] = true
			changed = true
		if changed:
			quest_updated.emit(obj_id)
	if changed:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file:
			var serial_completion: Dictionary = {}
			for ch in map_completion:
				serial_completion[str(ch)] = {}
				for m in map_completion[ch]:
					serial_completion[str(ch)][str(m)] = map_completion[ch][m]
			file.store_string(JSON.stringify({"map_completion": serial_completion, "objective_progress": objective_progress, "prologue_seen": prologue_seen}, "\t"))
			file.close()

func _on_story_sse_event(event_type: String, event_path: String, data: Variant) -> void:
	if event_path != "/" or data == null or not data is Dictionary:
		return
	var changed := false
	# Merge: mark any newly completed maps (never un-complete).
	for ch_str in data:
		var ch := int(ch_str)
		var ch_data = data[ch_str]
		if not ch_data is Dictionary:
			continue
		if not map_completion.has(ch):
			map_completion[ch] = {}
		for m_str in ch_data:
			var m := int(m_str)
			if ch_data[m_str] and not map_completion[ch].get(m, false):
				map_completion[ch][m] = true
				changed = true
				map_unlocked.emit(ch, m)
	if changed:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file:
			var serial_completion: Dictionary = {}
			for ch in map_completion:
				serial_completion[str(ch)] = {}
				for m in map_completion[ch]:
					serial_completion[str(ch)][str(m)] = map_completion[ch][m]
			file.store_string(JSON.stringify({"map_completion": serial_completion, "objective_progress": objective_progress, "prologue_seen": prologue_seen}, "\t"))
			file.close()

# ---------------------------------------------------------------------------
# Objective definitions
# ---------------------------------------------------------------------------

## Builds the full MAP_OBJECTIVES dictionary from scaled placeholder values.
## Replace individual entries here once real map designs are ready.
func _build_map_objectives() -> Dictionary:
	var objs: Dictionary = {}
	for ch in range(1, 11):
		var reg_rarity := _get_chapter_rarity(ch)
		var boss_rarity := "rare" if ch <= 3 else "legendary"
		objs[ch] = {}
		for m in range(1, 4):  # Maps 1-3 (regular)
			var kill_target: int = (ch - 1) * 20 + m * 10 + 10
			var wave_target: int = _REGULAR_MAP_WAVE_TARGETS[m - 1]
			objs[ch][m] = [
				{
					"id":             "ch%d_m%d_win" % [ch, m],
					"type":           "win_map",
					"title":          "Complete the Map",
					"target":         1,
					"reward_rarity":  reg_rarity,
				},
				{
					"id":             "ch%d_m%d_kill" % [ch, m],
					"type":           "kill_enemies",
					"title":          "Kill %d Enemies" % kill_target,
					"target":         kill_target,
					"reward_rarity":  reg_rarity,
				},
				{
					"id":             "ch%d_m%d_waves" % [ch, m],
					"type":           "survive_waves",
					"title":          "Survive %d Waves" % wave_target,
					"target":         wave_target,
					"reward_rarity":  reg_rarity,
				},
			]
		# Map 4 (boss)
		objs[ch][4] = [
			{
				"id":             "ch%d_m4_win" % ch,
				"type":           "win_map",
				"title":          "Defeat the Chapter Boss",
				"target":         1,
				"reward_rarity":  boss_rarity,
			},
		]
	return objs


func get_story_wave_count(chapter: int, map_idx: int) -> int:
	var map_objectives: Array = MAP_OBJECTIVES.get(chapter, {}).get(map_idx, [])
	for objective in map_objectives:
		if objective.get("type", "") == "survive_waves":
			return int(objective.get("target", 3))
	if map_idx == 4:
		return _BOSS_MAP_WAVE_TARGET
	if map_idx >= 1 and map_idx <= _REGULAR_MAP_WAVE_TARGETS.size():
		return _REGULAR_MAP_WAVE_TARGETS[map_idx - 1]
	return 3


func _get_chapter_rarity(ch: int) -> String:
	if ch <= 3:
		return _CHAPTER_RARITY["low"]
	elif ch <= 6:
		return _CHAPTER_RARITY["mid"]
	else:
		return _CHAPTER_RARITY["high"]


## Initialises map_completion with all-false entries if not already set.
func _init_map_completion() -> void:
	for ch in range(1, 11):
		if not map_completion.has(ch):
			map_completion[ch] = {}
		for m in range(1, 5):
			if not map_completion[ch].has(m):
				map_completion[ch][m] = false

# ---------------------------------------------------------------------------
# Unlock queries
# ---------------------------------------------------------------------------

func is_chapter_unlocked(ch: int) -> bool:
	if ch <= 1:
		return true
	# Previous chapter's boss map (map 4) must have been won.
	return map_completion.get(ch - 1, {}).get(4, false)


func is_map_unlocked(ch: int, map_idx: int) -> bool:
	if not is_chapter_unlocked(ch):
		return false
	if map_idx <= 1:
		return true
	return map_completion.get(ch, {}).get(map_idx - 1, false)

# ---------------------------------------------------------------------------
# Progress queries
# ---------------------------------------------------------------------------

## Returns all objective dicts for the given stage, merged with live progress.
func get_objectives_for_map(ch: int, map_idx: int) -> Array:
	var defs: Array = MAP_OBJECTIVES.get(ch, {}).get(map_idx, [])
	var result: Array = []
	for def in defs:
		var merged: Dictionary = def.duplicate()
		var prog: Dictionary = objective_progress.get(def["id"], {})
		merged["progress"] = prog.get("progress", 0)
		merged["completed"] = prog.get("completed", false)
		merged["claimed"]   = prog.get("claimed", false)
		result.append(merged)
	return result


## Returns merged progress dict for a single objective id.
func get_objective_progress(obj_id: String) -> Dictionary:
	return objective_progress.get(obj_id, {"progress": 0, "completed": false, "claimed": false})


## Returns count of objectives with claimed == true for a given stage.
func count_claimed_objectives(ch: int, map_idx: int) -> int:
	var count := 0
	for def in MAP_OBJECTIVES.get(ch, {}).get(map_idx, []):
		if objective_progress.get(def["id"], {}).get("claimed", false):
			count += 1
	return count

# ---------------------------------------------------------------------------
# Progress updates (called from GameScene)
# ---------------------------------------------------------------------------

## Records progress for all objectives matching (type, chapter, map_idx).
## Call from GameScene only when GameData.selected_chapter >= 1.
func update_objective(type: String, ch: int, map_idx: int, amount: int) -> void:
	var defs: Array = MAP_OBJECTIVES.get(ch, {}).get(map_idx, [])
	var changed := false
	for def in defs:
		if def["type"] != type:
			continue
		var obj_id: String = def["id"]
		if not objective_progress.has(obj_id):
			objective_progress[obj_id] = {"progress": 0, "completed": false, "claimed": false}
		var prog: Dictionary = objective_progress[obj_id]
		if prog["claimed"]:
			continue  # Already fully done — skip
		if prog["completed"]:
			continue  # Completed but not yet claimed; don't double-count
		prog["progress"] = min(prog["progress"] + amount, def["target"])
		changed = true
		quest_updated.emit(obj_id)
		if prog["progress"] >= def["target"]:
			prog["completed"] = true
			quest_completed.emit(obj_id)
	if changed:
		save_data()


## Records that a map stage was won (unlocks the next map/chapter).
func on_map_won(ch: int, map_idx: int) -> void:
	if not map_completion.has(ch):
		map_completion[ch] = {}
	if map_completion[ch].get(map_idx, false):
		return  # Already recorded
	map_completion[ch][map_idx] = true
	map_unlocked.emit(ch, map_idx)
	save_data()

# ---------------------------------------------------------------------------
# Reward claiming
# ---------------------------------------------------------------------------

## Claims a completed objective and grants the lootbox reward.
## Returns false if the objective is not completed or already claimed.
func claim_objective(obj_id: String) -> bool:
	var prog: Dictionary = objective_progress.get(obj_id, {})
	if not prog.get("completed", false) or prog.get("claimed", false):
		return false

	# Find the reward rarity from the objective definition.
	var rarity := _find_reward_rarity(obj_id)
	if rarity.is_empty():
		push_warning("QuestManager.claim_objective: unknown objective id '%s'" % obj_id)
		return false

	prog["claimed"] = true
	LootboxManager.earn_box(rarity, 1)
	save_data()
	quest_updated.emit(obj_id)
	return true


func _find_reward_rarity(obj_id: String) -> String:
	for ch in MAP_OBJECTIVES:
		for m in MAP_OBJECTIVES[ch]:
			for def in MAP_OBJECTIVES[ch][m]:
				if def["id"] == obj_id:
					return def.get("reward_rarity", "common")
	return ""

# ---------------------------------------------------------------------------
# Persistence — local JSON
# ---------------------------------------------------------------------------

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("QuestManager: could not open quest_data.json for reading.")
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("QuestManager: quest_data.json is malformed — resetting.")
		return
	# Restore map_completion (JSON keys are strings — convert back to ints).
	if parsed.has("map_completion"):
		for ch_str in parsed["map_completion"]:
			var ch := int(ch_str)
			if not map_completion.has(ch):
				map_completion[ch] = {}
			for m_str in parsed["map_completion"][ch_str]:
				map_completion[ch][int(m_str)] = parsed["map_completion"][ch_str][m_str]
	# Restore objective_progress.
	if parsed.has("objective_progress"):
		for obj_id in parsed["objective_progress"]:
			objective_progress[obj_id] = parsed["objective_progress"][obj_id]
	# Restore prologue flag.
	if parsed.has("prologue_seen"):
		prologue_seen = parsed["prologue_seen"]


func save_data() -> void:
	# Build serialisable map_completion with string keys for JSON.
	var serial_completion: Dictionary = {}
	for ch in map_completion:
		serial_completion[str(ch)] = {}
		for m in map_completion[ch]:
			serial_completion[str(ch)][str(m)] = map_completion[ch][m]

	var payload := {
		"map_completion":    serial_completion,
		"objective_progress": objective_progress,
		"prologue_seen":      prologue_seen,
	}

	DirAccess.make_dir_recursive_absolute("user://tower_defense_data")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("QuestManager: could not open quest_data.json for writing.")
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	_save_to_firebase()

# ---------------------------------------------------------------------------
# Firebase sync (fire-and-forget, mirrors LootboxManager pattern)
# ---------------------------------------------------------------------------

func _save_to_firebase() -> void:
	if not AccountManager.is_authenticated:
		return
	var username: String = AccountManager.current_username
	if username.is_empty():
		return
	var fb := _get_firebase()
	var serial_completion: Dictionary = {}
	for ch in map_completion:
		serial_completion[str(ch)] = {}
		for m in map_completion[ch]:
			serial_completion[str(ch)][str(m)] = map_completion[ch][m]
	# Fire-and-forget (no await) — mirrors original behaviour.
	fb.put_data("/story_progress/" + username, serial_completion)
	fb.put_data("/quests/" + username, objective_progress)


func _load_from_firebase() -> void:
	if not AccountManager.is_authenticated:
		return
	var username: String = AccountManager.current_username
	if username.is_empty():
		return
	var fb := _get_firebase()
	var progress_result: Dictionary = await fb.get_data("/quests/" + username)
	var progress_data = progress_result.get("data")
	if progress_data is Dictionary and not progress_data.is_empty():
		for obj_id in progress_data:
			objective_progress[obj_id] = progress_data[obj_id]
	var completion_result: Dictionary = await fb.get_data("/story_progress/" + username)
	var completion_data = completion_result.get("data")
	if completion_data is Dictionary and not completion_data.is_empty():
		for ch_str in completion_data:
			var ch := int(ch_str)
			if not map_completion.has(ch):
				map_completion[ch] = {}
			for m_str in completion_data[ch_str]:
				map_completion[ch][int(m_str)] = completion_data[ch_str][m_str]
