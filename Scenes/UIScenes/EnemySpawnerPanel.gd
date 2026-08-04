extends CanvasLayer
## EnemySpawnerPanel  (F4 to open/close)
## Side-panel spawner — the game field stays visible so you can watch each enemy walk the path.
##
## CONTROLS
##   Manual spawn  – click any enemy button to drop one on the path immediately
##   Auto-Preview  – select a chapter (or "All"), set a delay, press ▶ to spawn each
##                   enemy type from that pool one at a time so you can observe each one
##   Clear          – removes every enemy currently on the path

const PANEL_WIDTH = 380

var _game_scene: Node2D       # parent GameScene
var _active_label: Label      # shows "On path: N"
var _preview_btn: Button      # ▶ / ■ toggle
var _delay_label: Label       # shows current delay value
var _delay_value: float = 2.0 # seconds between auto-preview spawns

var _is_previewing   = false
var _preview_queue: Array = []
var _selected_chapter_filter: int = 0  # 0 = All

# All enemy names that have a .tscn on disk
var ALL_ENEMIES: Array = []

func _ready() -> void:
	layer = 199  # just below the info panel (200)
	_game_scene = get_parent()
	_collect_all_enemies()
	_build_ui()

func _collect_all_enemies() -> void:
	# Use GameData.enemy_data as canonical list – same order every run
	ALL_ENEMIES = GameData.enemy_data.keys()
	ALL_ENEMIES.sort()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F4:
		queue_free()

# ──────────────────────────────────────────────────────────────────────────────
# UI construction
# ──────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Right-side opaque panel – game is visible on the left
	var outer = PanelContainer.new()
	outer.set_anchor(SIDE_TOP, 0.0)
	outer.set_anchor(SIDE_BOTTOM, 1.0)
	outer.set_anchor(SIDE_LEFT, 1.0)
	outer.set_anchor(SIDE_RIGHT, 1.0)
	outer.set_offset(SIDE_LEFT,  -PANEL_WIDTH)
	outer.set_offset(SIDE_RIGHT,  0)
	outer.set_offset(SIDE_TOP,    0)
	outer.set_offset(SIDE_BOTTOM, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.12, 0.97)
	style.border_color = Color(0.3, 0.35, 0.5, 0.6)
	style.set_border_width(SIDE_LEFT, 2)
	outer.add_theme_stylebox_override("panel", style)
	add_child(outer)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	outer.add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# ── Header ──
	var header = HBoxContainer.new()
	root.add_child(header)

	var title = Label.new()
	title.text = "Enemy Spawner"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close = Button.new()
	close.text = "F4"
	close.custom_minimum_size = Vector2(44, 30)
	close.pressed.connect(queue_free)
	header.add_child(close)

	root.add_child(HSeparator.new())

	# ── Status & Clear ──
	var status_row = HBoxContainer.new()
	root.add_child(status_row)

	_active_label = Label.new()
	_active_label.text = "On path: 0"
	_active_label.add_theme_font_size_override("font_size", 13)
	_active_label.add_theme_color_override("font_color", Color(0.7, 1, 0.7))
	_active_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_active_label)

	var clear_btn = Button.new()
	clear_btn.text = "Clear All"
	clear_btn.custom_minimum_size = Vector2(90, 28)
	clear_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	clear_btn.pressed.connect(_clear_all_enemies)
	status_row.add_child(clear_btn)

	root.add_child(HSeparator.new())

	# ── Auto-Preview Controls ──
	var auto_label = Label.new()
	auto_label.text = "Auto-Preview"
	auto_label.add_theme_font_size_override("font_size", 14)
	auto_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
	root.add_child(auto_label)

	# Chapter filter row
	var filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	root.add_child(filter_row)

	var filter_lbl = Label.new()
	filter_lbl.text = "Chapter:"
	filter_lbl.add_theme_font_size_override("font_size", 12)
	filter_row.add_child(filter_lbl)

	var option = OptionButton.new()
	option.add_item("All enemies", 0)
	for ch in range(1, 11):
		var pool = GameData.chapter_enemy_pools.get(ch, {})
		var ch_name = pool.get("name", "Chapter %d" % ch)
		option.add_item("Ch.%d – %s" % [ch, ch_name.split("–")[0].strip_edges()], ch)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.item_selected.connect(_on_chapter_filter_changed)
	filter_row.add_child(option)

	# Delay row
	var delay_row = HBoxContainer.new()
	delay_row.add_theme_constant_override("separation", 6)
	root.add_child(delay_row)

	var delay_lbl = Label.new()
	delay_lbl.text = "Delay:"
	delay_lbl.add_theme_font_size_override("font_size", 12)
	delay_row.add_child(delay_lbl)

	var slider = HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 5.0
	slider.step = 0.5
	slider.value = _delay_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_delay_changed)
	delay_row.add_child(slider)

	_delay_label = Label.new()
	_delay_label.text = "%.1fs" % _delay_value
	_delay_label.add_theme_font_size_override("font_size", 12)
	_delay_label.custom_minimum_size = Vector2(40, 0)
	delay_row.add_child(_delay_label)

	# Play / Stop button
	_preview_btn = Button.new()
	_preview_btn.text = "▶ Start"
	_preview_btn.custom_minimum_size = Vector2(0, 32)
	_preview_btn.pressed.connect(_toggle_auto_preview)
	root.add_child(_preview_btn)

	root.add_child(HSeparator.new())

	# ── Manual Spawn — scrollable list grouped by chapter ──
	var manual_label = Label.new()
	manual_label.text = "Manual Spawn"
	manual_label.add_theme_font_size_override("font_size", 14)
	manual_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
	root.add_child(manual_label)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# Build role lookup so we can label boss enemies
	var role_lookup: Dictionary = {}  # enemy -> "Regular" | "BOSS" | "Both"
	for ch_num in GameData.chapter_enemy_pools:
		var pool = GameData.chapter_enemy_pools[ch_num]
		for e in pool["regular"]:
			if not role_lookup.has(e): role_lookup[e] = "Regular"
		for e in pool["boss"]:
			if role_lookup.get(e, "") == "Regular":
				role_lookup[e] = "Both"
			else:
				role_lookup[e] = "BOSS"

	# Group enemies by their first chapter appearance
	var chapter_groups: Dictionary = {}  # ch_num -> Array of unique enemy names
	for ch_num in range(1, 11):
		chapter_groups[ch_num] = []
	var unassigned: Array = []

	for enemy_name in ALL_ENEMIES:
		var found = false
		for ch_num in range(1, 11):
			var pool = GameData.chapter_enemy_pools.get(ch_num, {})
			if enemy_name in pool.get("regular", []) or enemy_name in pool.get("boss", []):
				chapter_groups[ch_num].append(enemy_name)
				found = true
				break
		if not found:
			unassigned.append(enemy_name)

	# Render each chapter group
	for ch_num in range(1, 11):
		if chapter_groups[ch_num].is_empty():
			continue

		var ch_pool = GameData.chapter_enemy_pools.get(ch_num, {})
		var ch_name = ch_pool.get("name", "Chapter %d" % ch_num)

		var ch_lbl = Label.new()
		ch_lbl.text = "■ Ch.%d – %s" % [ch_num, ch_name]
		ch_lbl.add_theme_font_size_override("font_size", 12)
		ch_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
		ch_lbl.clip_text = true
		list.add_child(ch_lbl)

		for enemy_name in chapter_groups[ch_num]:
			list.add_child(_make_enemy_row(enemy_name, role_lookup.get(enemy_name, "")))

	# Unassigned (not in any chapter pool) — still spawnable
	if not unassigned.is_empty():
		var other_lbl = Label.new()
		other_lbl.text = "■ (no chapter)"
		other_lbl.add_theme_font_size_override("font_size", 12)
		other_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		list.add_child(other_lbl)
		for enemy_name in unassigned:
			list.add_child(_make_enemy_row(enemy_name, ""))


func _make_enemy_row(enemy_name: String, role: String) -> HBoxContainer:
	var stats = GameData.enemy_data.get(enemy_name, {})
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	# Colored boss badge
	var role_color = Color(0.5, 1, 0.5)
	var role_badge = ""
	if role == "BOSS":
		role_badge = "[B]"
		role_color = Color(1, 0.35, 0.35)
	elif role == "Both":
		role_badge = "[R/B]"
		role_color = Color(1, 0.7, 0.2)

	var spawn_btn = Button.new()
	spawn_btn.text = "Spawn"
	spawn_btn.custom_minimum_size = Vector2(64, 26)
	spawn_btn.add_theme_font_size_override("font_size", 12)
	spawn_btn.pressed.connect(_spawn_one_enemy.bind(enemy_name))
	row.add_child(spawn_btn)

	var name_lbl = Label.new()
	name_lbl.text = (role_badge + " " if role_badge else "") + enemy_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", role_color)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	var stat_lbl = Label.new()
	stat_lbl.text = "HP:%s  Spd:%s" % [stats.get("hp","?"), stats.get("speed","?")]
	stat_lbl.add_theme_font_size_override("font_size", 11)
	stat_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	row.add_child(stat_lbl)

	return row


# ──────────────────────────────────────────────────────────────────────────────
# Spawning helpers
# ──────────────────────────────────────────────────────────────────────────────

func _get_path_node() -> Node:
	if not is_instance_valid(_game_scene):
		return null
	var map = _game_scene.get("map_node")
	if not map:
		return null
	return map.get_node_or_null("Path")


func _spawn_one_enemy(enemy_type: String) -> void:
	var path_node = _get_path_node()
	if not path_node:
		push_warning("EnemySpawnerPanel: No Path node found in map")
		return

	var scene_path = "res://Scenes/Enemies/" + enemy_type + ".tscn"
	var scene = load(scene_path)
	if not scene:
		push_warning("EnemySpawnerPanel: Scene not found – " + scene_path)
		return

	var enemy = scene.instantiate()
	if not enemy:
		return

	enemy.enemy_type = enemy_type

	# Silence reward/damage signals so the debug spawn doesn't affect the economy
	# (connect them to no-op lambdas keeps the enemy functional but harmless)
	if enemy.has_signal("base_damage"):
		enemy.base_damage.connect(func(_d): pass)
	if enemy.has_signal("enemy_destroyed"):
		enemy.enemy_destroyed.connect(func(_r): pass)

	path_node.add_child(enemy, true)

	if enemy.has_method("initialize"):
		enemy.initialize(1)


func _clear_all_enemies() -> void:
	var path_node = _get_path_node()
	if not path_node:
		return
	for child in path_node.get_children():
		# Only free PathFollow2D nodes (enemies), not the Path2D itself
		if child is PathFollow2D:
			child.queue_free()


# ──────────────────────────────────────────────────────────────────────────────
# Auto-Preview coroutine
# ──────────────────────────────────────────────────────────────────────────────

func _build_preview_queue() -> Array:
	if _selected_chapter_filter == 0:
		# All enemies, alphabetically
		return ALL_ENEMIES.duplicate()
	else:
		# Chapter pool: regular first, then boss (deduplicated)
		var pool = GameData.chapter_enemy_pools.get(_selected_chapter_filter, {})
		var seen: Dictionary = {}
		var queue: Array = []
		for e in pool.get("regular", []):
			if not seen.has(e):
				queue.append(e)
				seen[e] = true
		for e in pool.get("boss", []):
			if not seen.has(e):
				queue.append(e)
				seen[e] = true
		return queue


func _toggle_auto_preview() -> void:
	if _is_previewing:
		_is_previewing = false
		_preview_btn.text = "▶ Start"
	else:
		_clear_all_enemies()
		_preview_queue = _build_preview_queue()
		if _preview_queue.is_empty():
			return
		_is_previewing = true
		_preview_btn.text = "■ Stop"
		_run_preview()


func _run_preview() -> void:
	while _is_previewing and not _preview_queue.is_empty():
		var enemy_type = _preview_queue.pop_front()
		_spawn_one_enemy(enemy_type)
		await get_tree().create_timer(_delay_value).timeout

	_is_previewing = false
	_preview_btn.text = "▶ Start"


# ──────────────────────────────────────────────────────────────────────────────
# Event handlers
# ──────────────────────────────────────────────────────────────────────────────

func _on_chapter_filter_changed(index: int) -> void:
	# OptionButton item IDs mirror chapter numbers (0 = All)
	var btn = get_node_or_null("../..") # not needed, use item metadata
	# index 0 -> All, index 1..10 -> chapter 1..10
	_selected_chapter_filter = index  # item index matches chapter number because we added ch 1-10


func _on_delay_changed(value: float) -> void:
	_delay_value = value
	_delay_label.text = "%.1fs" % value


# ──────────────────────────────────────────────────────────────────────────────
# Process – keep active count updated
# ──────────────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	var path_node = _get_path_node()
	if path_node:
		var count = 0
		for child in path_node.get_children():
			if child is PathFollow2D:
				count += 1
		_active_label.text = "On path: %d" % count
