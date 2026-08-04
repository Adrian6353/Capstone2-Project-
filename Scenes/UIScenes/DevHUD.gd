extends PanelContainer
## DevHUD — In-game developer overlay (bottom-left corner).
## Only instantiated when GameData.dev_mode_enabled is true.
## Toggle visibility with F12 at any time during gameplay.

func _ready() -> void:
	# Style the panel
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color     = Color(0.08, 0.04, 0.04, 0.90)
	pstyle.border_color = Color(1.0, 0.35, 0.35, 0.6)
	pstyle.set_border_width(SIDE_LEFT, 2)
	pstyle.set_border_width(SIDE_RIGHT, 2)
	pstyle.set_border_width(SIDE_TOP, 2)
	pstyle.set_border_width(SIDE_BOTTOM, 2)
	pstyle.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", pstyle)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "⚠ DEV HUD  (F12 toggle)"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	vbox.add_child(header)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.5, 0.2, 0.2, 0.5))
	vbox.add_child(sep)

	# Buttons
	var buttons := [
		["+ 1000 Gold",           "_dev_add_gold"],
		["Restore HP",            "_dev_restore_hp"],
		["Force Win",             "_dev_force_win"],
		["Complete Objectives",   "_dev_complete_objectives"],
	]
	for pair in buttons:
		var btn := _make_btn(pair[0], pair[1])
		vbox.add_child(btn)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		visible = not visible
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Dev actions — operate on the GameScene via the scene tree
# ---------------------------------------------------------------------------

func _get_game_scene() -> Node:
	return get_tree().get_first_node_in_group("game_scene")


func _dev_add_gold() -> void:
	var gs := _get_game_scene()
	if not gs:
		return
	GameData.current_money += 1000
	gs.emit_signal("money_changed", GameData.current_money)
	gs.get_node("UI").update_money_display(GameData.current_money)


func _dev_restore_hp() -> void:
	var gs := _get_game_scene()
	if not gs:
		return
	gs.base_health = 20
	gs.get_node("UI").update_health_bar(gs.base_health)


func _dev_force_win() -> void:
	var gs := _get_game_scene()
	if gs:
		gs.game_over(true)


func _dev_complete_objectives() -> void:
	var ch: int = GameData.selected_chapter
	var m: int  = GameData.selected_map_index
	if ch < 1 or m < 1:
		return
	QuestManager.update_objective("kill_enemies",   ch, m, 99999)
	QuestManager.update_objective("survive_waves",  ch, m, 99999)
	QuestManager.update_objective("win_map",        ch, m, 1)


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

func _make_btn(label: String, method: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.30, 0.06, 0.06, 1)
	s.border_color = Color(0.8, 0.3, 0.3, 0.4)
	s.set_border_width(SIDE_LEFT, 1)
	s.set_border_width(SIDE_RIGHT, 1)
	s.set_border_width(SIDE_TOP, 1)
	s.set_border_width(SIDE_BOTTOM, 1)
	s.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.50, 0.10, 0.10, 1)
	btn.add_theme_stylebox_override("hover", sh)
	btn.pressed.connect(Callable(self, method))
	return btn
