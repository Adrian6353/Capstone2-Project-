extends Control

var LootboxManager: Node = null
var AudioManager: Node = null

func _ready() -> void:
	LootboxManager = get_node("/root/LootboxManager")
	AudioManager = get_node("/root/AudioManager")
	_build_ui()

func _build_ui() -> void:
	# Dim overlay
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.68)
	dim.anchors_preset = Control.PRESET_FULL_RECT
	add_child(dim)

	# Card panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	UIThemeHelper.apply_panel_style(panel)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	# Header row
	var header := HBoxContainer.new()
	vb.add_child(header)

	var title := Label.new()
	title.text = "⚙  Settings"
	UIThemeHelper.apply_heading(title, 24, UIThemeHelper.COL_TEXT_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(60, 60)
	UIThemeHelper.apply_button_theme(close_btn, "secondary", 20)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	vb.add_child(UIThemeHelper.make_separator())

	# ── Audio Section ────────────────────────────────────────────────────────
	vb.add_child(UIThemeHelper.make_section_label("🔊  Audio"))
	_add_volume_slider(vb, "Master Volume",   _get_node_prop(AudioManager, "master_volume", 1.0),   _on_master_volume_changed)
	_add_volume_slider(vb, "Music Volume",    _get_node_prop(AudioManager, "music_volume", 0.8),    _on_music_volume_changed)
	_add_volume_slider(vb, "SFX Volume",      _get_node_prop(AudioManager, "sfx_volume", 1.0),      _on_sfx_volume_changed)

	vb.add_child(UIThemeHelper.make_separator())

	# ── Visual Section ───────────────────────────────────────────────────────
	vb.add_child(UIThemeHelper.make_section_label("🖥  Visual"))
	_add_toggle_row(vb, "Fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, _on_fullscreen_toggled)

	vb.add_child(UIThemeHelper.make_separator())

	# Dev Panel button — always available in settings
	var dev_panel_btn := UIThemeHelper.make_button("⚠  Dev Panel", "danger", 16)
	dev_panel_btn.pressed.connect(func():
		if AudioManager:
			AudioManager.play_ui_sound("button_click")
		get_tree().change_scene_to_file("res://Scenes/UIScenes/DevPanel.tscn")
	)
	vb.add_child(dev_panel_btn)

	var dev_sep := HSeparator.new()
	vb.add_child(dev_sep)

	# Dev Tools section — only visible when DEV_MODE is on
	if LootboxManager and LootboxManager.DEV_MODE:
		vb.add_child(UIThemeHelper.make_section_label("🛠  Dev Tools"))

		# Add boxes row
		var box_row := HBoxContainer.new()
		box_row.add_theme_constant_override("separation", 8)
		vb.add_child(box_row)

		for box_type in ["common", "rare", "legendary"]:
			var btn := UIThemeHelper.make_button("+5 %s" % box_type.capitalize(), "secondary", 14)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.pressed.connect(_on_add_boxes.bind(box_type))
			box_row.add_child(btn)

		# Reset button
		var reset_btn := UIThemeHelper.make_button("⚠  Reset All Unlocks & Boxes", "danger", 14)
		reset_btn.pressed.connect(_on_reset_all)
		vb.add_child(reset_btn)

	UIThemeHelper.animate_panel_in(panel)

# ── Helper builders ─────────────────────────────────────────────────────────

func _add_volume_slider(parent: VBoxContainer, label_text: String, initial_value: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 48)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIThemeHelper.apply_body(lbl, 16)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 48)
	slider.value_changed.connect(callback)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(initial_value * 100)
	val_lbl.custom_minimum_size = Vector2(44, 48)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIThemeHelper.apply_muted(val_lbl, 14)
	row.add_child(val_lbl)
	slider.value_changed.connect(func(v): val_lbl.text = "%d%%" % int(v * 100))

func _add_toggle_row(parent: VBoxContainer, label_text: String, initial: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(0, 60)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIThemeHelper.apply_body(lbl, 16)
	row.add_child(lbl)

	var chk := CheckButton.new()
	chk.button_pressed = initial
	chk.custom_minimum_size = Vector2(60, 60)
	chk.toggled.connect(callback)
	row.add_child(chk)

# ── Volume callbacks ─────────────────────────────────────────────────────────

func _on_master_volume_changed(value: float) -> void:
	if AudioManager and AudioManager.has_method("set_master_volume"):
		AudioManager.set_master_volume(value)

func _on_music_volume_changed(value: float) -> void:
	if AudioManager and AudioManager.has_method("set_music_volume"):
		AudioManager.set_music_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	if AudioManager and AudioManager.has_method("set_sfx_volume"):
		AudioManager.set_sfx_volume(value)

func _get_node_prop(node: Node, prop: String, default_val: float) -> float:
	if node == null:
		return default_val
	var val = node.get(prop)
	return float(val) if val != null else default_val

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_close() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	queue_free()

func _on_add_boxes(box_type: String) -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	if LootboxManager:
		LootboxManager.earn_box(box_type, 5)

func _on_reset_all() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	ConfirmationDialogManager.show_confirmation(
		"Reset All Unlocks?",
		"This will reset all tower families and lootboxes to their initial state. This cannot be undone.",
		func():
			if LootboxManager:
				LootboxManager.pending_boxes = { "common": 1, "rare": 0, "legendary": 0 }
				LootboxManager.shards = 0
				LootboxManager.reset_tower_unlocks_to_basic()
	)
