extends CanvasLayer
## EnemyDebugPanel
## Press F3 in-game to open/close this overlay.
## Shows every enemy grouped by chapter, displaying HP, speed, reward, and role.

# Which chapter numbers each enemy appears in as regular / boss
const CHAPTER_NAMES = {
	1:  "Ch.1 – Embers at the Outskirts",
	2:  "Ch.2 – The Balete Giant",
	3:  "Ch.3 – Wings Over Dapithapon",
	4:  "Ch.4 – The Crooked Pass",
	5:  "Ch.5 – The Black Swarm",
	6:  "Ch.6 – Hunt Beneath Noonday",
	7:  "Ch.7 – The Red-Moon Siege",
	8:  "Ch.8 – Gate of the Wild Realm",
	9:  "Ch.9 – Court of Hollow Roots",
	10: "Ch.10 – The Last Weave"
}

func _ready() -> void:
	layer = 200   # Always on top
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	# F3 closes the panel
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		queue_free()

# ---------- UI construction ----------

func _build_ui() -> void:
	# Dim overlay
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Outer margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# Header row
	var header_row = HBoxContainer.new()
	root_vbox.add_child(header_row)

	var title_lbl = Label.new()
	title_lbl.text = "Enemy Debug Panel  (F3 to close)"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(90, 36)
	close_btn.pressed.connect(queue_free)
	header_row.add_child(close_btn)

	# Separator
	var sep = HSeparator.new()
	root_vbox.add_child(sep)

	# Column headers
	var col_header = _make_row_container()
	root_vbox.add_child(col_header)
	for header_text in ["Enemy", "HP", "Speed", "Reward", "Chapter(s)", "Role"]:
		var lbl = Label.new()
		lbl.text = header_text
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_header.add_child(lbl)

	var sep2 = HSeparator.new()
	root_vbox.add_child(sep2)

	# Scroll area for enemy rows
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(list_vbox)

	# Build a lookup: enemy_name -> [chapters], [roles]
	var chapter_lookup: Dictionary = {}  # enemy_name -> {chapters: [], roles: {}}
	for ch_num in GameData.chapter_enemy_pools:
		var pool = GameData.chapter_enemy_pools[ch_num]
		for enemy_name in pool["regular"]:
			if not chapter_lookup.has(enemy_name):
				chapter_lookup[enemy_name] = {"chapters": [], "roles": {}}
			if ch_num not in chapter_lookup[enemy_name]["chapters"]:
				chapter_lookup[enemy_name]["chapters"].append(ch_num)
			chapter_lookup[enemy_name]["roles"][ch_num] = "Regular"
		for enemy_name in pool["boss"]:
			if not chapter_lookup.has(enemy_name):
				chapter_lookup[enemy_name] = {"chapters": [], "roles": {}}
			if ch_num not in chapter_lookup[enemy_name]["chapters"]:
				chapter_lookup[enemy_name]["chapters"].append(ch_num)
			# Boss overrides if the enemy also appears as regular in the same chapter
			chapter_lookup[enemy_name]["roles"][ch_num] = "BOSS"

	# Sort enemy names alphabetically
	var sorted_enemies = GameData.enemy_data.keys()
	sorted_enemies.sort()

	var row_alt = false
	for enemy_name in sorted_enemies:
		var stats = GameData.enemy_data[enemy_name]
		var lookup = chapter_lookup.get(enemy_name, {"chapters": [], "roles": {}})

		var row_bg = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.14, 0.2, 0.9) if row_alt else Color(0.08, 0.1, 0.16, 0.9)
		style.set_corner_radius_all(4)
		row_bg.add_theme_stylebox_override("panel", style)
		list_vbox.add_child(row_bg)
		row_alt = not row_alt

		var row = _make_row_container()
		row_bg.add_child(row)

		# Name
		_add_cell(row, enemy_name, Color(1, 1, 1))

		# HP
		_add_cell(row, str(stats.get("hp", "?")), Color(0.4, 1, 0.5))

		# Speed
		_add_cell(row, str(stats.get("speed", "?")), Color(1, 0.85, 0.3))

		# Reward
		_add_cell(row, "$" + str(stats.get("reward", "?")), Color(0.9, 0.75, 0.2))

		# Chapters
		var ch_list = ""
		if lookup["chapters"].is_empty():
			ch_list = "—"
		else:
			var sorted_ch = lookup["chapters"].duplicate()
			sorted_ch.sort()
			ch_list = ", ".join(sorted_ch.map(func(n): return str(n)))
		_add_cell(row, ch_list, Color(0.7, 0.9, 1))

		# Role (Boss / Regular / Both / —)
		var roles_set = {}
		for r in lookup["roles"].values():
			roles_set[r] = true
		var role_text = ""
		var role_color = Color(0.8, 0.8, 0.8)
		if roles_set.has("BOSS") and roles_set.has("Regular"):
			role_text = "Both"
			role_color = Color(1, 0.6, 0.2)
		elif roles_set.has("BOSS"):
			role_text = "BOSS"
			role_color = Color(1, 0.3, 0.3)
		elif roles_set.has("Regular"):
			role_text = "Regular"
			role_color = Color(0.5, 1, 0.5)
		else:
			role_text = "—"
		_add_cell(row, role_text, role_color)

	# Footer note
	var footer = Label.new()
	footer.text = "Tip: chapter pools are used only when a chapter is selected in Map Selection. Otherwise, the tier-based fallback runs."
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(footer)


func _make_row_container() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	return row


func _add_cell(parent: HBoxContainer, text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	parent.add_child(lbl)
