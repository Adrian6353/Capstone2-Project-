extends Control
## DevPanel — Developer tools for story mode and quest system.
## Accessible via the red "Dev Mode" button on the main menu.
## dev_mode_enabled persists for the session only (never saved to disk).

var _state_label: Label = null

func _ready() -> void:
	GameData.dev_mode_enabled = true   # Entering the panel enables dev mode
	_build_ui()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.10, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Red banner at the top
	var banner := ColorRect.new()
	banner.color = Color(0.45, 0.05, 0.05, 1)
	banner.custom_minimum_size = Vector2(0, 56)
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(banner)

	var banner_lbl := Label.new()
	banner_lbl.text = "⚠  DEV MODE  ⚠"
	banner_lbl.add_theme_font_size_override("font_size", 28)
	banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	banner_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner_lbl.custom_minimum_size = Vector2(0, 56)
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	add_child(banner_lbl)

	# Scroll root below banner
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.add_theme_constant_override("margin_top", 60)
	add_child(scroll)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 20)
	root_vbox.add_theme_constant_override("margin_left",   40)
	root_vbox.add_theme_constant_override("margin_right",  40)
	root_vbox.add_theme_constant_override("margin_top",    20)
	root_vbox.add_theme_constant_override("margin_bottom", 40)
	scroll.add_child(root_vbox)

	# ── Sections ─────────────────────────────────────────────────────────────
	root_vbox.add_child(_section_story_progress())
	root_vbox.add_child(_section_tower_testing())
	root_vbox.add_child(_section_objectives())
	root_vbox.add_child(_section_navigation())
	root_vbox.add_child(_section_state_viewer())


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------

func _section_story_progress() -> Control:
	var panel := _make_panel("Story Progress", Color(0.14, 0.10, 0.06, 1))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_panel_content(panel).add_child(row)

	var unlock_all := _btn("Unlock All Chapters & Maps", Color(0.2, 0.45, 0.2, 1))
	unlock_all.pressed.connect(_on_unlock_all)
	row.add_child(unlock_all)

	var reset_all := _btn("Reset All Progress", Color(0.5, 0.1, 0.1, 1))
	reset_all.pressed.connect(_on_reset_all)
	row.add_child(reset_all)

	# Per-chapter unlock buttons
	var ch_row := HBoxContainer.new()
	ch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ch_row.add_theme_constant_override("separation", 10)
	_panel_content(panel).add_child(ch_row)

	for ch in range(1, 11):
		var b := _btn("Ch.%d" % ch, Color(0.14, 0.20, 0.35, 1))
		b.custom_minimum_size = Vector2(80, 50)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_on_unlock_chapter.bind(ch))
		ch_row.add_child(b)

	return panel


func _section_tower_testing() -> Control:
	var panel := _make_panel("Lootbox Tower Testing", Color(0.16, 0.07, 0.12, 1))
	var content := _panel_content(panel)

	var explanation := Label.new()
	explanation.text = "Clear every lootbox tower unlock while keeping Pitik-Kawayan as the permanent basic tower. Unopened boxes are preserved."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 15)
	explanation.add_theme_color_override("font_color", Color(0.9, 0.75, 0.85))
	content.add_child(explanation)

	var reset_towers := _btn("Reset Tower Unlocks", Color(0.52, 0.08, 0.20, 1))
	reset_towers.pressed.connect(_on_reset_tower_unlocks)
	content.add_child(reset_towers)
	return panel


func _section_objectives() -> Control:
	var panel := _make_panel("Objectives", Color(0.06, 0.14, 0.20, 1))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_panel_content(panel).add_child(row)

	var complete_btn := _btn("Complete All Objectives", Color(0.14, 0.30, 0.40, 1))
	complete_btn.pressed.connect(_on_complete_all_objectives)
	row.add_child(complete_btn)

	var claim_btn := _btn("Claim All Objectives", Color(0.38, 0.28, 0.05, 1))
	claim_btn.pressed.connect(_on_claim_all_objectives)
	row.add_child(claim_btn)

	return panel


func _section_navigation() -> Control:
	var panel := _make_panel("Navigation", Color(0.10, 0.10, 0.16, 1))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_panel_content(panel).add_child(row)

	var story_btn := _btn("Open Story Mode", Color(0.22, 0.18, 0.06, 1))
	story_btn.pressed.connect(func():
		AudioManager.play_ui_sound("button_click")
		get_tree().change_scene_to_file("res://Scenes/UIScenes/map_selection.tscn"))
	row.add_child(story_btn)

	var debug_btn := _btn("Open Debug Maps", Color(0.14, 0.24, 0.14, 1))
	debug_btn.pressed.connect(func():
		AudioManager.play_ui_sound("button_click")
		get_tree().change_scene_to_file("res://Scenes/UIScenes/DebugMapSelect.tscn"))
	row.add_child(debug_btn)

	var quest_btn := _btn("Quest Browser", Color(0.14, 0.14, 0.30, 1))
	quest_btn.pressed.connect(func():
		AudioManager.play_ui_sound("button_click")
		get_tree().change_scene_to_file("res://Scenes/UIScenes/QuestScreen.tscn"))
	row.add_child(quest_btn)

	var disable_btn := _btn("Disable Dev Mode & Back", Color(0.30, 0.08, 0.08, 1))
	disable_btn.pressed.connect(_on_disable_and_back)
	row.add_child(disable_btn)

	var back_btn := _btn("Back (Keep Dev Mode)", Color(0.16, 0.16, 0.22, 1))
	back_btn.pressed.connect(_on_back)
	row.add_child(back_btn)

	return panel


func _section_state_viewer() -> Control:
	var panel := _make_panel("Current Quest State", Color(0.06, 0.08, 0.12, 1))
	var content := _panel_content(panel)

	var refresh_btn := _btn("Refresh", Color(0.14, 0.20, 0.35, 1))
	refresh_btn.custom_minimum_size = Vector2(140, 44)
	refresh_btn.pressed.connect(_refresh_state)
	content.add_child(refresh_btn)

	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 14)
	_state_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_state_label)

	_refresh_state()
	return panel

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_unlock_all() -> void:
	AudioManager.play_ui_sound("button_click")
	for ch in range(1, 11):
		if not QuestManager.map_completion.has(ch):
			QuestManager.map_completion[ch] = {}
		for m in range(1, 5):
			QuestManager.map_completion[ch][m] = true
	QuestManager.save_data()
	_refresh_state()


func _on_reset_all() -> void:
	AudioManager.play_ui_sound("button_click")
	ConfirmationDialogManager.show_confirmation(
		"Reset All Progress?",
		"This will reset all map completion and objective progress. This cannot be undone.",
		func():
			QuestManager.map_completion    = {}
			QuestManager.objective_progress = {}
			QuestManager.save_data()
			_refresh_state()
	)


func _on_reset_tower_unlocks() -> void:
	AudioManager.play_ui_sound("button_click")
	ConfirmationDialogManager.show_confirmation(
		"Reset Tower Unlocks?",
		"This removes every lootbox tower unlock except Pitik-Kawayan. Your unopened boxes remain available for testing.",
		func():
			LootboxManager.reset_tower_unlocks_to_basic()
			_refresh_state()
	)


func _on_unlock_chapter(ch: int) -> void:
	AudioManager.play_ui_sound("button_click")
	# Mark all maps of this chapter (and the boss of the previous one) as complete
	# so the chapter becomes accessible via normal unlock logic.
	if ch > 1:
		if not QuestManager.map_completion.has(ch - 1):
			QuestManager.map_completion[ch - 1] = {}
		QuestManager.map_completion[ch - 1][4] = true
	if not QuestManager.map_completion.has(ch):
		QuestManager.map_completion[ch] = {}
	for m in range(1, 5):
		QuestManager.map_completion[ch][m] = true
	QuestManager.save_data()
	_refresh_state()


func _on_complete_all_objectives() -> void:
	AudioManager.play_ui_sound("button_click")
	for ch in range(1, 11):
		var maps: Dictionary = QuestManager.MAP_OBJECTIVES.get(ch, {})
		for m in maps:
			for obj in maps[m]:
				var id: String = obj["id"]
				var target: int = obj.get("target", 1)
				if not QuestManager.objective_progress.has(id):
					QuestManager.objective_progress[id] = {}
				QuestManager.objective_progress[id]["progress"]  = target
				QuestManager.objective_progress[id]["completed"] = true
				QuestManager.objective_progress[id]["claimed"]   = QuestManager.objective_progress[id].get("claimed", false)
	QuestManager.save_data()
	_refresh_state()


func _on_claim_all_objectives() -> void:
	AudioManager.play_ui_sound("button_click")
	for ch in range(1, 11):
		var maps: Dictionary = QuestManager.MAP_OBJECTIVES.get(ch, {})
		for m in maps:
			for obj in maps[m]:
				var id: String = obj["id"]
				if not QuestManager.objective_progress.has(id):
					QuestManager.objective_progress[id] = {}
				var prog: Dictionary = QuestManager.objective_progress[id]
				if not prog.get("claimed", false):
					QuestManager.claim_objective(id)
	_refresh_state()


func _refresh_state() -> void:
	if not _state_label:
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== Map Completion ===")
	for ch in range(1, 11):
		var ch_data: Dictionary = QuestManager.map_completion.get(ch, {})
		var row := "Ch.%d:" % ch
		for m in range(1, 6):
			row += "  M%d:%s" % [m, ("✓" if ch_data.get(m, false) else "✗")]
		lines.append(row)
	lines.append("")
	lines.append("=== Objective Progress (non-zero only) ===")
	var count := 0
	for obj_id in QuestManager.objective_progress:
		var p: Dictionary = QuestManager.objective_progress[obj_id]
		if p.get("progress", 0) > 0 or p.get("completed", false):
			lines.append("%s  prog=%d  done=%s  claimed=%s" % [
				obj_id, p.get("progress", 0),
				str(p.get("completed", false)),
				str(p.get("claimed", false))])
			count += 1
	if count == 0:
		lines.append("(none)")
	lines.append("")
	lines.append("=== Lootbox Tower Unlocks ===")
	var unlocked_names := PackedStringArray()
	for family_name in LootboxManager.unlocked_families:
		unlocked_names.append(str(family_name))
	lines.append(", ".join(unlocked_names))
	lines.append("Boxes: Common=%d  Rare=%d  Legendary=%d" % [
		LootboxManager.get_box_count("common"),
		LootboxManager.get_box_count("rare"),
		LootboxManager.get_box_count("legendary"),
	])
	_state_label.text = "\n".join(lines)


func _on_disable_and_back() -> void:
	AudioManager.play_ui_sound("button_click")
	GameData.dev_mode_enabled = false
	get_tree().change_scene_to_file("res://Scenes/UIScenes/main_menu.tscn")


func _on_back() -> void:
	AudioManager.play_ui_sound("button_click")
	get_tree().change_scene_to_file("res://Scenes/UIScenes/main_menu.tscn")

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------

func _make_panel(heading: String, bg: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color     = bg
	pstyle.border_color = Color(0.5, 0.5, 0.7, 0.3)
	pstyle.set_border_width(SIDE_LEFT, 2)
	pstyle.set_border_width(SIDE_RIGHT, 2)
	pstyle.set_border_width(SIDE_TOP, 2)
	pstyle.set_border_width(SIDE_BOTTOM, 2)
	pstyle.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", pstyle)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var lbl := Label.new()
	lbl.text = heading
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	vbox.add_child(lbl)

	return panel


func _panel_content(panel: PanelContainer) -> VBoxContainer:
	return panel.get_node("MarginContainer/Content") as VBoxContainer


func _btn(label: String, bg: Color) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(200, 52)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 1))
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(0.6, 0.6, 0.8, 0.4)
	s.set_border_width(SIDE_LEFT, 2)
	s.set_border_width(SIDE_RIGHT, 2)
	s.set_border_width(SIDE_TOP, 2)
	s.set_border_width(SIDE_BOTTOM, 2)
	s.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal",  s)
	var s2 := s.duplicate() as StyleBoxFlat
	s2.bg_color = bg.lightened(0.15)
	b.add_theme_stylebox_override("hover",   s2)
	b.mouse_entered.connect(func(): AudioManager.play_ui_sound("button_hover"))
	return b
