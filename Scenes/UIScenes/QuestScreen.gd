extends Control
## QuestScreen — Main-menu quest browser for the story mode quest system.
##
## Layout (all built in code):
##   Root Control (full-rect)
##     Background ColorRect (dark tint)
##     HBoxContainer
##       Left panel  — chapter list (VBoxContainer of buttons)
##       Right panel — ScrollContainer with map/objective rows
##     Back Button (top-left)

var _selected_chapter: int = 1
var _chapter_buttons: Dictionary = {}   # chapter(int) → Button
var _right_panel: VBoxContainer = null

func _ready() -> void:
	_build_ui()
	_select_chapter(1)
	QuestManager.quest_updated.connect(_on_quest_updated)
	QuestManager.quest_completed.connect(_on_quest_completed)
	QuestManager.map_unlocked.connect(_on_map_unlocked)

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = UIThemeHelper.COL_PANEL_BG
	bg.color.a = 0.97
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main HBox (left sidebar + right content)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	hbox.add_child(_build_left_panel())
	hbox.add_child(_build_right_area())

	# Back button — min 60 px touch target
	var back_btn := UIThemeHelper.make_button("← Back", "secondary")
	back_btn.custom_minimum_size = Vector2(200, 60)
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.offset_left  = 24
	back_btn.offset_top   = 24
	back_btn.offset_right = 224
	back_btn.offset_bottom = 84
	back_btn.z_index = 10
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)

	# Title label
	var title_lbl := Label.new()
	title_lbl.text = "Story Mode — Quests"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_GOLD)
	title_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_lbl.offset_top    = 30
	title_lbl.offset_bottom = 72
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.z_index = 10
	add_child(title_lbl)


func _build_left_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIThemeHelper.apply_panel_style(panel, true)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",   80)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	for ch in range(1, 11):
		var unlocked := QuestManager.is_chapter_unlocked(ch) or GameData.dev_mode_enabled
		var ch_name: String = QuestManager.CHAPTER_NAMES.get(ch, "Chapter %d" % ch)
		var label: String   = "Ch.%d  %s" % [ch, ch_name]
		if not unlocked:
			label += "  🔒"
		elif GameData.dev_mode_enabled and not QuestManager.is_chapter_unlocked(ch):
			label += "  [DEV]"
		var btn := _make_button(label)
		btn.custom_minimum_size = Vector2(0, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		btn.disabled = not unlocked
		btn.pressed.connect(_select_chapter.bind(ch))
		_chapter_buttons[ch] = btn
		vbox.add_child(btn)

	return panel


func _build_right_area() -> Control:
	var area := Control.new()
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.add_theme_constant_override("margin_top", 100)
	area.add_child(scroll)

	_right_panel = VBoxContainer.new()
	_right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_panel.add_theme_constant_override("separation", 12)
	scroll.add_child(_right_panel)

	return area

# ---------------------------------------------------------------------------
# Chapter/objective rendering
# ---------------------------------------------------------------------------

func _select_chapter(ch: int) -> void:
	_selected_chapter = ch
	# Highlight selected chapter button
	for c in _chapter_buttons:
		var btn: Button = _chapter_buttons[c]
		var is_sel: bool = (c == ch)
		var sel_style := StyleBoxFlat.new()
		sel_style.bg_color     = UIThemeHelper.COL_BTN_PRIMARY_P if is_sel else UIThemeHelper.COL_PANEL_BG
		sel_style.border_color = UIThemeHelper.COL_TEXT_GOLD if is_sel else UIThemeHelper.COL_PANEL_BORDER.darkened(0.3)
		sel_style.set_border_width_all(2)
		sel_style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal",  sel_style)
		btn.add_theme_stylebox_override("pressed", sel_style)

	_rebuild_right_panel()


func _rebuild_right_panel() -> void:
	for child in _right_panel.get_children():
		child.queue_free()

	var ch: int = _selected_chapter
	var ch_name: String = QuestManager.CHAPTER_NAMES.get(ch, "Chapter %d" % ch)

	# Chapter header
	var hdr := Label.new()
	hdr.text = "Chapter %d — %s" % [ch, ch_name]
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_GOLD)
	hdr.add_theme_constant_override("margin_top", 8)
	_right_panel.add_child(hdr)

	if not QuestManager.is_chapter_unlocked(ch):
		var locked_lbl := Label.new()
		locked_lbl.text = "🔒  Complete Chapter %d to unlock this chapter." % (ch - 1)
		locked_lbl.add_theme_font_size_override("font_size", 24)
		locked_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_right_panel.add_child(locked_lbl)
		return

	# Map rows 1-5
	for m in range(1, 6):
		_right_panel.add_child(_build_map_row(ch, m))


func _build_map_row(ch: int, m: int) -> PanelContainer:
	var is_boss   := (m == 5)
	var unlocked  := QuestManager.is_map_unlocked(ch, m)
	var map_label := ("  [ BOSS MAP ]" if is_boss else "  Map %d" % m)

	var panel := PanelContainer.new()
	panel.name = "MapRow_ch%d_m%d" % [ch, m]
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color     = Color(0.12, 0.16, 0.28, 0.9) if unlocked else Color(0.08, 0.09, 0.15, 0.85)
	pstyle.border_color = Color(0.5, 0.6, 0.85, 0.35)  if unlocked else Color(0.3, 0.3, 0.4, 0.2)
	pstyle.set_border_width(SIDE_LEFT, 3)
	pstyle.set_border_width(SIDE_RIGHT, 3)
	pstyle.set_border_width(SIDE_TOP, 3)
	pstyle.set_border_width(SIDE_BOTTOM, 3)
	pstyle.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", pstyle)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Map header row
	var map_hbox := HBoxContainer.new()
	var map_title := Label.new()
	map_title.text = map_label
	map_title.add_theme_font_size_override("font_size", 20)
	var title_color := UIThemeHelper.COL_TEXT_GOLD if is_boss else UIThemeHelper.COL_TEXT_CREAM
	if not unlocked:
		title_color = UIThemeHelper.COL_TEXT_MUTED
	map_title.add_theme_color_override("font_color", title_color)
	map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_hbox.add_child(map_title)

	if not unlocked:
		var lock_lbl := Label.new()
		var unlock_msg := "Complete Map %d first" % (m - 1)
		if m == 1:
			unlock_msg = "Complete Chapter %d Boss to unlock" % (ch - 1)
		lock_lbl.text = "🔒  " + unlock_msg
		lock_lbl.add_theme_font_size_override("font_size", 20)
		lock_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(map_hbox)
		vbox.add_child(lock_lbl)
		return panel

	vbox.add_child(map_hbox)

	# Objective rows
	var objectives := QuestManager.get_objectives_for_map(ch, m)
	for obj in objectives:
		vbox.add_child(_build_objective_row(obj))

	return panel


func _build_objective_row(obj: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ObjRow_" + obj["id"]
	row.add_theme_constant_override("separation", 14)

	var claimed    : bool = obj.get("claimed", false)
	var completed  : bool = obj.get("completed", false)
	var progress   : int  = obj.get("progress", 0)
	var target     : int  = obj.get("target", 1)
	var rarity     : String = obj.get("reward_rarity", "common")

	# Status icon
	var icon_lbl := Label.new()
	icon_lbl.text = "✔" if claimed else ("!" if completed else "○")
	icon_lbl.add_theme_font_size_override("font_size", 26)
	var icon_color := Color(0.3, 0.9, 0.4) if claimed else (Color(1.0, 0.9, 0.2) if completed else Color(0.6, 0.6, 0.7))
	icon_lbl.add_theme_color_override("font_color", icon_color)
	icon_lbl.custom_minimum_size = Vector2(32, 0)
	row.add_child(icon_lbl)

	# Title + progress
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_lbl := Label.new()
	title_lbl.text = obj.get("title", "")
	title_lbl.add_theme_font_size_override("font_size", 22)
	var txt_color := Color(0.6, 0.7, 0.6) if claimed else Color(1.0, 1.0, 1.0)
	title_lbl.add_theme_color_override("font_color", txt_color)
	info.add_child(title_lbl)

	var prog_lbl := Label.new()
	prog_lbl.name = "ProgLabel_" + obj["id"]
	prog_lbl.text = ("%d / %d" % [progress, target]) if not claimed else "Completed"
	prog_lbl.add_theme_font_size_override("font_size", 18)
	prog_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9) if not claimed else Color(0.5, 0.8, 0.5))
	info.add_child(prog_lbl)

	row.add_child(info)

	# Reward label
	var rarity_colors := {"common": Color(0.5, 0.85, 0.5), "rare": Color(0.4, 0.6, 1.0), "legendary": Color(1.0, 0.75, 0.2)}
	var reward_lbl := Label.new()
	reward_lbl.text = rarity.capitalize() + " Box"
	reward_lbl.add_theme_font_size_override("font_size", 18)
	reward_lbl.add_theme_color_override("font_color", rarity_colors.get(rarity, Color.WHITE))
	reward_lbl.custom_minimum_size = Vector2(140, 0)
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(reward_lbl)

	# Claim button
	var claim_btn := _make_button("Claim")
	claim_btn.name   = "ClaimBtn_" + obj["id"]
	claim_btn.custom_minimum_size = Vector2(110, 44)
	claim_btn.disabled = (not completed) or claimed
	if claimed:
		claim_btn.text = "Claimed"
	claim_btn.pressed.connect(_on_claim_pressed.bind(obj["id"]))
	row.add_child(claim_btn)

	return row

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_claim_pressed(obj_id: String) -> void:
	AudioManager.play_ui_sound("button_click")
	QuestManager.claim_objective(obj_id)
	# Refresh the entire right panel to reflect the new state.
	_rebuild_right_panel()
	# Refresh chapter lock states in the sidebar.
	_refresh_chapter_sidebar()


func _on_quest_updated(_obj_id: String) -> void:
	_rebuild_right_panel()


func _on_quest_completed(_obj_id: String) -> void:
	_rebuild_right_panel()


func _on_map_unlocked(_ch: int, _m: int) -> void:
	_rebuild_right_panel()
	_refresh_chapter_sidebar()


func _refresh_chapter_sidebar() -> void:
	for ch in _chapter_buttons:
		var btn: Button = _chapter_buttons[ch]
		var quest_unlocked := QuestManager.is_chapter_unlocked(ch)
		var unlocked := quest_unlocked or GameData.dev_mode_enabled
		btn.disabled = not unlocked
		var ch_name: String = QuestManager.CHAPTER_NAMES.get(ch, "Chapter %d" % ch)
		var label: String   = "Ch.%d  %s" % [ch, ch_name]
		if not unlocked:
			label += "  🔒"
		elif GameData.dev_mode_enabled and not quest_unlocked:
			label += "  [DEV]"
		btn.text = label


func _on_back_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	get_tree().change_scene_to_file("res://Scenes/UIScenes/main_menu.tscn")

# ---------------------------------------------------------------------------
# Style helpers
# ---------------------------------------------------------------------------

func _make_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_stylebox_override("normal",  _button_style(Color(0.14, 0.18, 0.30, 1), Color(0.4, 0.5, 0.7, 0.35)))
	btn.add_theme_stylebox_override("hover",   _button_style(Color(0.22, 0.30, 0.50, 1), Color(0.6, 0.7, 1.0, 0.5)))
	btn.add_theme_stylebox_override("pressed", _button_style(Color(0.24, 0.44, 0.70, 1), Color(0.7, 0.85, 1.0, 0.8)))
	btn.add_theme_stylebox_override("focus",   _button_style(Color(0.14, 0.18, 0.30, 1), Color(0.4, 0.5, 0.7, 0.35)))
	btn.mouse_entered.connect(func(): AudioManager.play_ui_sound("button_hover"))
	return btn


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width(SIDE_LEFT, 2)
	s.set_border_width(SIDE_RIGHT, 2)
	s.set_border_width(SIDE_TOP, 2)
	s.set_border_width(SIDE_BOTTOM, 2)
	s.set_corner_radius_all(12)
	return s
