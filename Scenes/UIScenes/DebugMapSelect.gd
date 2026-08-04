extends Control
## DebugMapSelect — quick map picker for development/testing.
## Accessible via the "New Game" button on the main menu.
## Always runs as 1 player; no story-mode quest tracking.

const DEBUG_MAPS: Array = [
	{"label": "Map 1",  "path": "res://Scenes/Maps/Map1_v2.tscn"},
	{"label": "Map 2",  "path": "res://Scenes/Maps/Map2_1P.tscn"},
	{"label": "Map 3",  "path": "res://Scenes/Maps/Map3.tscn"},
]
const WAVE_OPTIONS: Array = [3, 5, 10]

var _selected_map: String  = ""
var _selected_waves: int   = 3
var _map_buttons: Dictionary   = {}
var _wave_buttons: Dictionary  = {}

func _ready() -> void:
	AudioManager.play_music("new_game", 0.5)
	_build_ui()

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.14, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 28)
	vbox.add_theme_constant_override("margin_left",   60)
	vbox.add_theme_constant_override("margin_right",  60)
	vbox.add_theme_constant_override("margin_top",    40)
	vbox.add_theme_constant_override("margin_bottom", 40)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Debug Map Select"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Map section
	vbox.add_child(_build_section("Select Map", _build_map_row()))

	# Wave section
	vbox.add_child(_build_section("Select Waves", _build_wave_row()))

	# Action buttons
	var action_hbox := HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(action_hbox)

	var start_btn := _make_button("Start Game", Color(0.14, 0.34, 0.14, 1), Color(0.4, 0.85, 0.4, 0.7))
	start_btn.custom_minimum_size = Vector2(240, 80)
	start_btn.pressed.connect(_on_start_pressed)
	action_hbox.add_child(start_btn)

	var back_btn := _make_button("Back to Menu", Color(0.1, 0.14, 0.22, 1), Color(0.4, 0.45, 0.6, 0.35))
	back_btn.custom_minimum_size = Vector2(240, 80)
	back_btn.pressed.connect(_on_back_pressed)
	action_hbox.add_child(back_btn)


func _build_section(heading: String, content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color     = Color(0.12, 0.14, 0.22, 0.92)
	pstyle.border_color = Color(0.4, 0.45, 0.65, 0.35)
	pstyle.set_border_width(SIDE_LEFT, 2)
	pstyle.set_border_width(SIDE_RIGHT, 2)
	pstyle.set_border_width(SIDE_TOP, 2)
	pstyle.set_border_width(SIDE_BOTTOM, 2)
	pstyle.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", pstyle)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var lbl := Label.new()
	lbl.text = heading
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	vbox.add_child(content)
	return panel


func _build_map_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	for entry in DEBUG_MAPS:
		var btn := _make_button(entry["label"], Color(0.1, 0.14, 0.22, 1), Color(0.4, 0.45, 0.6, 0.35))
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(200, 80)
		btn.pressed.connect(_on_map_selected.bind(entry["path"], btn))
		_map_buttons[entry["path"]] = btn
		row.add_child(btn)
	return row


func _build_wave_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	for w in WAVE_OPTIONS:
		var btn := _make_button("%d Waves" % w, Color(0.1, 0.14, 0.22, 1), Color(0.4, 0.45, 0.6, 0.35))
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(160, 70)
		if w == _selected_waves:
			btn.set_pressed(true)
		btn.pressed.connect(_on_wave_selected.bind(w, btn))
		_wave_buttons[w] = btn
		row.add_child(btn)
	return row


func _make_button(label: String, bg: Color, border: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 1))
	btn.add_theme_color_override("font_color_pressed", Color(1, 1, 1))
	var normal_style := _box(bg, border)
	var pressed_style := _box(Color(0.24, 0.44, 0.7, 1), Color(0.7, 0.85, 1, 0.8))
	var hover_style   := _box(Color(0.16, 0.24, 0.34, 1), Color(0.5, 0.6, 0.8, 0.4))
	btn.add_theme_stylebox_override("normal",  normal_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("hover",   hover_style)
	btn.mouse_entered.connect(func(): AudioManager.play_ui_sound("button_hover"))
	return btn


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width(SIDE_LEFT, 2)
	s.set_border_width(SIDE_RIGHT, 2)
	s.set_border_width(SIDE_TOP, 2)
	s.set_border_width(SIDE_BOTTOM, 2)
	s.set_corner_radius_all(14)
	return s

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_map_selected(path: String, pressed_btn: Button) -> void:
	AudioManager.play_ui_sound("button_click")
	_selected_map = path
	for p in _map_buttons:
		_map_buttons[p].set_pressed(_map_buttons[p] == pressed_btn)


func _on_wave_selected(count: int, pressed_btn: Button) -> void:
	AudioManager.play_ui_sound("button_click")
	_selected_waves = count
	for w in _wave_buttons:
		_wave_buttons[w].set_pressed(_wave_buttons[w] == pressed_btn)


func _on_start_pressed() -> void:
	if _selected_map.is_empty():
		return
	AudioManager.play_ui_sound("button_click")
	GameData.selected_map          = _selected_map
	GameData.selected_player_count = 1
	GameData.selected_wave_count   = _selected_waves
	GameData.selected_chapter      = -1
	GameData.selected_map_index    = -1
	GameData.game_mode             = "normal"
	get_tree().change_scene_to_file("res://Scenes/MainScenes/GameScene.tscn")


func _on_back_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	get_tree().change_scene_to_file("res://Scenes/UIScenes/main_menu.tscn")
