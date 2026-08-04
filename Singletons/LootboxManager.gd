extends Node
## LootboxManager — Gacha/lootbox system for unlocking tower families.
##
## Box types: "common", "rare", "legendary"
## Opening a box uses WeightedChoice to pick a tower family.
## Pulling a new family immediately unlocks all 3 tower levels in that family.
## Tower ownership only comes from opening lootboxes.
##
## Data saved locally (DataPersistence) and synced to Firebase under /lootbox/{username}.

signal lootbox_data_changed
signal firebase_sync_complete(success: bool)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Set to true to show Dev Tools in the Settings menu (add boxes, reset saves).
## Flip to false before shipping a release build.
const DEV_MODE := false
const BASIC_TOWER_FAMILY := "PitikKawayan"

## How much each rarity tier is weighted when a given box type is opened.
## WeightedChoice.pick() receives a dict of { family_name: weight } built from these.
const BOX_WEIGHTS := {
	"common":    { "common": 0.70, "rare": 0.25, "legendary": 0.05 },
	"rare":      { "common": 0.30, "rare": 0.55, "legendary": 0.15 },
	"legendary": { "common": 0.10, "rare": 0.35, "legendary": 0.55 },
}

## Shards earned when a duplicate family is drawn.
const SHARD_REWARD := {
	"common":    10,
	"rare":      25,
	"legendary": 50,
}

## Display names for box types shown in the UI.
const BOX_DISPLAY_NAMES := {
	"common":    "Common Box",
	"rare":      "Rare Box",
	"legendary": "Legendary Box",
}

# ---------------------------------------------------------------------------
# Player data (in-memory, mirrors saved/loaded state)
# ---------------------------------------------------------------------------

## Set of tower family names the player has unlocked.
var unlocked_families: Array = []
## Number of unopened boxes the player owns, keyed by box type.
var pending_boxes: Dictionary = { "common": 0, "rare": 0, "legendary": 0 }
## Legacy duplicate currency retained for existing save compatibility.
var shards: int = 0

## Legacy per-family shard data retained for existing save compatibility.
var family_shards: Dictionary = {}  # { family_name: int }

var _firebase: Node = null
var _listener_path: String = ""   # tracks the currently-active SSE path

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	load_data()
	# Sync from Firebase if authenticated
	if AccountManager.is_authenticated:
		_start_firebase_sync()
	else:
		AccountManager.account_authenticated.connect(_on_account_authenticated)

func _on_account_authenticated() -> void:
	_start_firebase_sync()

func _exit_tree() -> void:
	if not _listener_path.is_empty() and is_instance_valid(_firebase):
		_firebase.stop_listener(_listener_path)

## Runs the initial one-time fetch then opens the real-time SSE stream.
func _start_firebase_sync() -> void:
	await _load_from_firebase()
	_start_realtime_listener()

func _start_realtime_listener() -> void:
	var username: String = AccountManager.current_username
	if username.is_empty():
		return
	var path: String = "/lootbox/" + username
	if _listener_path == path:
		return   # Already subscribed to this user's path.
	var fb := _get_firebase()
	# Stop any previous listener (e.g. after re-login with a different account).
	if not _listener_path.is_empty():
		fb.stop_listener(_listener_path)
	_listener_path = path
	fb.start_listener(path, _on_lootbox_sse_event)

func _on_lootbox_sse_event(event_type: String, event_path: String, data: Variant) -> void:
	# We only react to root-level puts/patches (Firebase sends a full object
	# because LootboxManager always writes the whole document with PUT).
	if event_path != "/":
		return
	if data == null or not data is Dictionary:
		return
	var remote: Dictionary = data
	var changed := false

	# Union of unlocked families (never revoke unlocks).
	for family_name in remote.get("unlocked_families", []):
		if not unlocked_families.has(family_name):
			unlocked_families.append(family_name)
			_unlock_family(family_name)
			changed = true

	# Take the maximum of each box type.
	var remote_boxes: Dictionary = remote.get("pending_boxes", {})
	for box_type in pending_boxes:
		var remote_count: int = remote_boxes.get(box_type, 0)
		if remote_count > pending_boxes[box_type]:
			pending_boxes[box_type] = remote_count
			changed = true

	# Take the maximum shard total.
	var remote_shards: int = remote.get("shards", 0)
	if remote_shards > shards:
		shards = remote_shards
		changed = true

	# Take the maximum per-family shard amount.
	for fam in remote.get("family_shards", {}):
		var remote_amt: int = remote["family_shards"][fam]
		if remote_amt > family_shards.get(fam, 0):
			family_shards[fam] = remote_amt
			changed = true
	if _migrate_legacy_pulls():
		changed = true

	if changed:
		# Persist locally without triggering another Firebase write to avoid loops.
		DataPersistence.save_lootbox_data({
			"unlocked_families": unlocked_families,
			"pending_boxes":     pending_boxes,
			"shards":            shards,
			"family_shards":     family_shards,
		})
		lootbox_data_changed.emit()

# ---------------------------------------------------------------------------
# Box earning (called by game_over.gd)
# ---------------------------------------------------------------------------

## Award lootboxes based on game performance.
## @param waves_survived   How many waves the player survived.
## @param level_completed  True if the player cleared all selected waves.
## @param total_waves      The total waves selected for this game session.
func award_post_game_boxes(_waves_survived: int, level_completed: bool, total_waves: int) -> Dictionary:
	var earned := { "common": 0, "rare": 0, "legendary": 0 }

	# No lootboxes awarded on a loss.
	if not level_completed:
		return earned

	# Rarity weights scale with the number of waves selected.
	var weights: Dictionary
	match total_waves:
		3:
			weights = { "common": 0.70, "rare": 0.25, "legendary": 0.05 }
		5:
			weights = { "common": 0.50, "rare": 0.35, "legendary": 0.15 }
		10:
			weights = { "common": 0.30, "rare": 0.45, "legendary": 0.25 }
		_:
			weights = { "common": 0.60, "rare": 0.30, "legendary": 0.10 }

	# Pick one rarity using the weighted table.
	var roll := randf()
	var chosen_rarity := "common"
	var cumulative := 0.0
	for rarity in ["common", "rare", "legendary"]:
		cumulative += weights[rarity]
		if roll < cumulative:
			chosen_rarity = rarity
			break

	earned[chosen_rarity] += 1
	earn_box(chosen_rarity, 1)

	return earned

## Increment pending_boxes for a given type and persist.
func earn_box(box_type: String, amount: int = 1) -> void:
	if not pending_boxes.has(box_type):
		push_warning("LootboxManager.earn_box: unknown box type '%s'" % box_type)
		return
	pending_boxes[box_type] += amount
	save_data()
	lootbox_data_changed.emit()

# ---------------------------------------------------------------------------
# Box opening — uses WeightedChoice
# ---------------------------------------------------------------------------

## Open one box of the given type. Returns a result dictionary:
## {
##   "success":       bool,       # False if no boxes of that type remain
##   "family":        String,     # Tower family name that was picked
##   "rarity":        String,     # Rarity of the picked family
##   "is_new":        bool,       # True if the family was not yet unlocked
##   "shards_earned": int,        # Shards earned (>0 only when is_new == false)
##   "towers":        Array[String] # The 3 tower names in this family
## }
func open_box(box_type: String) -> Dictionary:
	var failure := { "success": false, "family": "", "rarity": "", "is_new": false, "shards_earned": 0, "towers": [] }

	if not pending_boxes.has(box_type) or pending_boxes[box_type] <= 0:
		return failure

	# Prefer unowned families so every progression box grants a tower until the
	# collection is complete. After that, boxes can roll duplicates.
	var rarity_weights: Dictionary = BOX_WEIGHTS[box_type]
	var pick_dict: Dictionary = {}
	var locked_families := get_locked_families()
	var candidate_families: Array = locked_families if not locked_families.is_empty() else GameData.tower_families.keys()

	for family_name in candidate_families:
		var family_data: Dictionary = GameData.tower_families[family_name]
		var family_rarity: String = family_data.get("rarity", "common")
		pick_dict[family_name] = rarity_weights.get(family_rarity, 0.0)

	# Use WeightedChoice addon to pick a family.
	var picked_family: String = WeightedChoice.pick(pick_dict)
	var picked_rarity: String = GameData.tower_families[picked_family].get("rarity", "common")
	var picked_towers: Array = GameData.tower_families[picked_family].get("towers", [])

	var already_unlocked: bool = unlocked_families.has(picked_family)
	var shards_earned: int = 0
	var just_unlocked: bool = false

	if already_unlocked:
		# Collection complete: duplicates grant legacy shards.
		shards_earned = SHARD_REWARD.get(picked_rarity, 10)
		shards += shards_earned
	else:
		_unlock_family(picked_family)
		just_unlocked = true

	pending_boxes[box_type] -= 1
	save_data()
	lootbox_data_changed.emit()

	return {
		"success":                 true,
		"family":                  picked_family,
		"rarity":                  picked_rarity,
		"is_new":                  just_unlocked,
		"just_unlocked":           just_unlocked,
		"shards_earned":           shards_earned,
		"towers":                  picked_towers,
	}

# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Returns true if the given tower family is fully unlocked.
func is_family_unlocked(family_name: String) -> bool:
	return family_name == BASIC_TOWER_FAMILY or unlocked_families.has(family_name)

## Returns how many boxes of the given type the player has.
func get_box_count(box_type: String) -> int:
	return pending_boxes.get(box_type, 0)

## Returns a list of all families the player has NOT yet unlocked.
func get_locked_families() -> Array:
	var locked: Array = []
	for family_name in GameData.tower_families:
		if not is_family_unlocked(family_name):
			locked.append(family_name)
	return locked

## Remove every lootbox unlock except the permanent basic tower family.
## Pending boxes are preserved so the lootbox flow can be tested repeatedly.
func reset_tower_unlocks_to_basic() -> void:
	unlocked_families = [BASIC_TOWER_FAMILY]
	family_shards.clear()
	GameData.collected_cards.clear()
	_unlock_family(BASIC_TOWER_FAMILY)
	save_data()
	lootbox_data_changed.emit()

## Returns a human-readable name for a box type.
func get_box_display_name(box_type: String) -> String:
	return BOX_DISPLAY_NAMES.get(box_type, box_type.capitalize() + " Box")

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _unlock_family(family_name: String) -> void:
	if not unlocked_families.has(family_name):
		unlocked_families.append(family_name)
	# Also mark individual towers as collected in GameData.collected_cards
	# so the card_hunt mode and CardBar are aware of the unlock.
	var towers: Array = GameData.tower_families.get(family_name, {}).get("towers", [])
	for tower_name in towers:
		if not GameData.collected_cards.has(tower_name):
			GameData.collected_cards[tower_name] = 1

## Before lootboxes became direct unlocks, a pull added family-specific shards.
## Treat any historical pull as ownership so existing players keep their rewards.
func _migrate_legacy_pulls() -> bool:
	var changed := false
	for family_key in family_shards:
		var family_name := str(family_key)
		if (
			int(family_shards[family_key]) > 0
			and GameData.tower_families.has(family_name)
			and not unlocked_families.has(family_name)
		):
			_unlock_family(family_name)
			changed = true
	return changed

# ---------------------------------------------------------------------------
# Persistence — local (DataPersistence)
# ---------------------------------------------------------------------------

func save_data() -> void:
	var data := {
		"unlocked_families": unlocked_families,
		"pending_boxes":     pending_boxes,
		"shards":            shards,
		"family_shards":     family_shards,
	}
	DataPersistence.save_lootbox_data(data)
	_sync_to_firebase()

func load_data() -> void:
	var data: Dictionary = DataPersistence.load_lootbox_data()
	unlocked_families = data.get("unlocked_families", [])
	pending_boxes = {
		"common":    data.get("pending_boxes", {}).get("common",    0),
		"rare":      data.get("pending_boxes", {}).get("rare",      0),
		"legendary": data.get("pending_boxes", {}).get("legendary", 0),
	}
	shards = data.get("shards", 0)
	family_shards = data.get("family_shards", {})
	var basic_was_missing := not unlocked_families.has(BASIC_TOWER_FAMILY)
	_unlock_family(BASIC_TOWER_FAMILY)
	var migrated_legacy_pulls := _migrate_legacy_pulls()
	# Pitik-Kawayan is always available. A new player also receives one box to
	# begin expanding their collection.
	var is_new_player := data.is_empty()
	if is_new_player:
		pending_boxes["common"] = 1
	if is_new_player or basic_was_missing or migrated_legacy_pulls:
		DataPersistence.save_lootbox_data({
			"unlocked_families": unlocked_families,
			"pending_boxes": pending_boxes,
			"shards": shards,
			"family_shards": family_shards,
		})
	# Re-apply unlocks to GameData.collected_cards so the game mode is consistent.
	for family_name in unlocked_families:
		_unlock_family(family_name)

# ---------------------------------------------------------------------------
# Persistence — Firebase
# ---------------------------------------------------------------------------

func _get_firebase() -> Node:
	if _firebase == null or not is_instance_valid(_firebase):
		_firebase = FirebaseIntegration.new()
		add_child(_firebase)
	return _firebase

func _sync_to_firebase() -> void:
	if not AccountManager.is_authenticated:
		return
	if not NetworkStatus.get_is_online():
		return

	var fb := _get_firebase()
	var path := "/lootbox/" + AccountManager.current_username
	var payload := {
		"unlocked_families": unlocked_families,
		"pending_boxes":     pending_boxes,
		"shards":            shards,
		"family_shards":     family_shards,
		"last_updated":      int(Time.get_unix_time_from_system()),
	}
	fb.put_data(path, payload)

func _load_from_firebase() -> void:
	if not AccountManager.is_authenticated:
		return
	if not NetworkStatus.get_is_online():
		return

	var fb := _get_firebase()
	var path := "/lootbox/" + AccountManager.current_username
	var result: Dictionary = await fb.get_data(path)

	if result.has("error") or result.get("data") == null:
		# No remote data yet — push local data up.
		_sync_to_firebase()
		firebase_sync_complete.emit(true)
		return

	var remote: Dictionary = result["data"]
	if not remote is Dictionary:
		firebase_sync_complete.emit(false)
		return

	# Merge: take the union of unlocked families (never revoke unlocks).
	var remote_families: Array = remote.get("unlocked_families", [])
	for family_name in remote_families:
		if not unlocked_families.has(family_name):
			unlocked_families.append(family_name)
			_unlock_family(family_name)

	# For pending boxes: take the maximum of local vs remote (prevents loss on multi-device).
	var remote_boxes: Dictionary = remote.get("pending_boxes", {})
	for box_type in pending_boxes:
		var remote_count: int = remote_boxes.get(box_type, 0)
		if remote_count > pending_boxes[box_type]:
			pending_boxes[box_type] = remote_count

	# For shards: take the maximum.
	var remote_shards: int = remote.get("shards", 0)
	if remote_shards > shards:
		shards = remote_shards

	# For family_shards: take the maximum per family (never lose progress).
	var remote_family_shards: Dictionary = remote.get("family_shards", {})
	for fam in remote_family_shards:
		var remote_amt: int = remote_family_shards[fam]
		if remote_amt > family_shards.get(fam, 0):
			family_shards[fam] = remote_amt
	_migrate_legacy_pulls()

	save_data()
	lootbox_data_changed.emit()
	firebase_sync_complete.emit(true)
