extends CanvasLayer

signal tutorial_finished

const ARROW_SIZE := 20.0
const POPUP_MARGIN := 16.0

var current_step: int = 0
var steps: Array[Dictionary] = []
var _was_paused: bool = false

# UI references
var dimmer: ColorRect
var popup_panel: PanelContainer
var title_label: Label
var desc_label: Label
var step_label: Label
var next_button: Button
var skip_button: Button
var arrow_node: Control

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	layer = 100
	_define_steps()
	_build_ui()

func _define_steps() -> void:
	steps = [
		{
			"target": "UI/HUD/InfoBar/H/GoldIcon",
			"title": "Gold",
			"description": "This is your Gold. Earn it by defeating enemies and spend it to build towers. Manage it wisely!",
			"arrow_dir": "down",
		},
		{
			"target": "UI/HUD/InfoBar/H/PlayerHPBar",
			"title": "Base Health",
			"description": "This is your Base Health. Enemies that reach the end of the path deal damage here. If it hits zero, you lose!",
			"arrow_dir": "down",
		},
		{
			"target": "UI/HUD/StartWaveButton",
			"title": "Start Wave",
			"description": "Tap this button to send the next wave of enemies. Prepare your defenses before starting!",
			"arrow_dir": "down",
		},
		{
			"target": "UI/HUD/WavePreviewPanel",
			"title": "Wave Preview",
			"description": "Check here to see what enemies are coming in the next wave so you can plan your tower placement.",
			"arrow_dir": "down",
		},
		{
			"target": "UI/HUD/CardBar",
			"title": "Tower Cards",
			"description": "Select a tower from here, then tap anywhere on a valid tile to place it. Each tower costs Gold. Right-click a placed tower to sell it.",
			"arrow_dir": "up",
		},
		{
			"target": "UI/HUD/GameControls/MarginContainer/PausePlay",
			"title": "Pause / Play",
			"description": "Tap to pause or resume the game. Use this when you need time to plan your next move.",
			"arrow_dir": "left",
		},
		{
			"target": "UI/HUD/GameControls/MarginContainer2/SpeedUp",
			"title": "Speed Up",
			"description": "Toggle 2x game speed to fast-forward through waves. Tap again to return to normal speed.",
			"arrow_dir": "left",
		},
	]

func _build_ui() -> void:
	# Full-screen dimmer
	dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.55)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	# Arrow indicator (drawn via code)
	arrow_node = Control.new()
	arrow_node.name = "Arrow"
	arrow_node.z_index = 10
	arrow_node.custom_minimum_size = Vector2(ARROW_SIZE * 2, ARROW_SIZE * 2)
	arrow_node.size = Vector2(ARROW_SIZE * 2, ARROW_SIZE * 2)
	arrow_node.draw.connect(_draw_arrow)
	add_child(arrow_node)

	# Popup panel
	popup_panel = PanelContainer.new()
	popup_panel.name = "PopupPanel"
	popup_panel.custom_minimum_size = Vector2(340, 0)
	popup_panel.z_index = 10

	var panel_style := UIThemeHelper.make_panel_style()
	popup_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(popup_panel)

	# Content inside the popup
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	popup_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Step counter
	step_label = Label.new()
	step_label.add_theme_font_size_override("font_size", 13)
	UIThemeHelper.apply_muted(step_label, 13)
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(step_label)

	# Title
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	UIThemeHelper.apply_heading(title_label, 24, UIThemeHelper.COL_TEXT_GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	# Description
	desc_label = Label.new()
	UIThemeHelper.apply_body(desc_label, 16)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(300, 0)
	vbox.add_child(desc_label)

	# Button row
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	skip_button = Button.new()
	skip_button.text = "Skip Tutorial"
	skip_button.custom_minimum_size = Vector2(150, 60)
	UIThemeHelper.apply_button_theme(skip_button, "danger", 16)
	skip_button.pressed.connect(_on_skip_pressed)
	btn_row.add_child(skip_button)

	next_button = Button.new()
	next_button.text = "Next  ▶"
	next_button.custom_minimum_size = Vector2(150, 60)
	UIThemeHelper.apply_button_theme(next_button, "primary", 16)
	next_button.pressed.connect(_on_next_pressed)
	btn_row.add_child(next_button)

func _style_button(_btn: Button, _bg_color: Color, _border_color: Color) -> void:
	pass  # Replaced by UIThemeHelper.apply_button_theme

func start_tutorial() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	current_step = 0
	_show_step(current_step)

func _show_step(index: int) -> void:
	if index < 0 or index >= steps.size():
		_finish_tutorial()
		return

	var step = steps[index]
	step_label.text = "Step %d / %d" % [index + 1, steps.size()]
	title_label.text = step["title"]
	desc_label.text = step["description"]

	# Update button text on last step
	if index == steps.size() - 1:
		next_button.text = "Got it!"
	else:
		next_button.text = "Next"

	# Find the target node and position the popup next to it
	var game_scene = get_parent()
	var target = game_scene.get_node_or_null(step["target"])
	if target == null:
		# Try alternate path for CardHuntBar in card hunt mode
		if step["target"] == "UI/HUD/CardBar":
			target = game_scene.get_node_or_null("UI/HUD/CardHuntBar")
		if target == null:
			push_warning("Tutorial: target node not found: " + step["target"])
			# Position in center as fallback
			_position_popup_center()
			return

	# Wait one frame for layout to settle
	await get_tree().process_frame
	_position_popup_near_target(target, step["arrow_dir"])

	# Animate popup in
	popup_panel.modulate = Color(1, 1, 1, 0)
	popup_panel.scale = Vector2(0.9, 0.9)
	arrow_node.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(popup_panel, "modulate", Color(1, 1, 1, 1), 0.2)
	tween.tween_property(popup_panel, "scale", Vector2(1, 1), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(arrow_node, "modulate", Color(1, 1, 1, 1), 0.2)

func _position_popup_near_target(target: Control, arrow_dir: String) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var target_rect = target.get_global_rect()
	var target_center = target_rect.get_center()

	# Ensure popup_panel has valid size
	popup_panel.reset_size()
	await get_tree().process_frame
	var popup_size = popup_panel.size

	var popup_pos := Vector2.ZERO
	var arrow_pos := Vector2.ZERO

	match arrow_dir:
		"down":
			# Popup above target, arrow points down
			popup_pos.x = target_center.x - popup_size.x / 2
			popup_pos.y = target_rect.position.y - popup_size.y - ARROW_SIZE - POPUP_MARGIN
			arrow_pos.x = target_center.x - ARROW_SIZE
			arrow_pos.y = target_rect.position.y - ARROW_SIZE * 2 - 4
		"up":
			# Popup below target, arrow points up
			popup_pos.x = target_center.x - popup_size.x / 2
			popup_pos.y = target_rect.end.y + ARROW_SIZE + POPUP_MARGIN
			arrow_pos.x = target_center.x - ARROW_SIZE
			arrow_pos.y = target_rect.end.y + 4
		"left":
			# Popup to the left of target, arrow points right
			popup_pos.x = target_rect.position.x - popup_size.x - ARROW_SIZE - POPUP_MARGIN
			popup_pos.y = target_center.y - popup_size.y / 2
			arrow_pos.x = target_rect.position.x - ARROW_SIZE * 2 - 4
			arrow_pos.y = target_center.y - ARROW_SIZE
		"right":
			# Popup to the right of target, arrow points left
			popup_pos.x = target_rect.end.x + ARROW_SIZE + POPUP_MARGIN
			popup_pos.y = target_center.y - popup_size.y / 2
			arrow_pos.x = target_rect.end.x + 4
			arrow_pos.y = target_center.y - ARROW_SIZE

	# Clamp popup position to stay on-screen
	popup_pos.x = clamp(popup_pos.x, POPUP_MARGIN, viewport_size.x - popup_size.x - POPUP_MARGIN)
	popup_pos.y = clamp(popup_pos.y, POPUP_MARGIN, viewport_size.y - popup_size.y - POPUP_MARGIN)

	popup_panel.position = popup_pos
	arrow_node.position = arrow_pos

	# Store arrow direction for drawing
	arrow_node.set_meta("arrow_dir", arrow_dir)
	arrow_node.queue_redraw()

func _position_popup_center() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	popup_panel.reset_size()
	await get_tree().process_frame
	var popup_size = popup_panel.size
	popup_panel.position = (viewport_size - popup_size) / 2.0
	arrow_node.visible = false

func _draw_arrow() -> void:
	var dir = arrow_node.get_meta("arrow_dir", "down")
	var color = Color(0.85, 0.7, 0.2, 0.9)
	var s = ARROW_SIZE
	var points: PackedVector2Array

	match dir:
		"down":
			points = PackedVector2Array([Vector2(0, 0), Vector2(s * 2, 0), Vector2(s, s * 1.5)])
		"up":
			points = PackedVector2Array([Vector2(0, s * 1.5), Vector2(s * 2, s * 1.5), Vector2(s, 0)])
		"left":
			# Arrow points right (toward target which is to the right)
			points = PackedVector2Array([Vector2(0, s), Vector2(s * 1.5, 0), Vector2(s * 1.5, s * 2)])
		"right":
			# Arrow points left (toward target which is to the left)
			points = PackedVector2Array([Vector2(s * 1.5, s), Vector2(0, 0), Vector2(0, s * 2)])
		_:
			points = PackedVector2Array([Vector2(0, 0), Vector2(s * 2, 0), Vector2(s, s * 1.5)])

	arrow_node.draw_colored_polygon(points, color)

func _on_next_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	current_step += 1
	if current_step >= steps.size():
		_finish_tutorial()
	else:
		_show_step(current_step)

func _on_skip_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	_finish_tutorial()

func _finish_tutorial() -> void:
	# Restore pause state FIRST so buttons are never stuck paused
	get_tree().paused = _was_paused

	# Save completion
	var persistence = get_node_or_null("/root/DataPersistence")
	if persistence:
		persistence.save_setting("tutorial_completed", true)

	emit_signal("tutorial_finished")
	queue_free()
