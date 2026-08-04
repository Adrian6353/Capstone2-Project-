extends Control

var selected_map_index = -1  # 1-4 within the chapter
var selected_chapter = -1
## "chapter" → "map"
var current_state = "chapter"

var chapter_buttons = {}
var map_buttons = {}      # map_idx → Button, rebuilt each chapter select
var _step_label: Label = null

@export var background_image: Texture2D = preload("res://Assets/UI/Art/rm218-bb-07.jpg")

func _ready():
	# Play dedicated new game music through AudioManager
	AudioManager.play_music("new_game", 0.5)

	$VBoxContainer.add_theme_constant_override("separation", 24)
	$VBoxContainer.add_theme_constant_override("margin_top", 12)
	$VBoxContainer.add_theme_constant_override("margin_bottom", 12)

	_setup_background()
	_add_step_indicator()
	_add_preview_label()
	_add_chapter_section()
	_add_map_section()
	_add_action_buttons()
	_update_state()
	_update_preview()

func _add_step_indicator() -> void:
	_step_label = Label.new()
	_step_label.name = "StepIndicator"
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.add_theme_font_size_override("font_size", 18)
	_step_label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_CREAM)
	$VBoxContainer.add_child(_step_label)
	_update_step_indicator()

func _update_step_indicator() -> void:
	if not _step_label:
		return
	var ch := "●" if current_state in ["chapter", "map"] else "○"
	var mp := "●" if current_state == "map" else "○"
	_step_label.text = "%s Chapter  ›  %s Map" % [ch, mp]
	match current_state:
		"chapter":
			_step_label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_GOLD)
		"map":
			_step_label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_CREAM)

func _add_preview_label():
	var preview_label = Label.new()
	preview_label.name = "SelectionPreview"
	preview_label.text = _get_preview_text()
	preview_label.add_theme_font_size_override("font_size", 18)
	preview_label.add_theme_color_override("font_color", Color(0.8, 0.85, 1))
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$VBoxContainer.add_child(preview_label)

func _add_chapter_section():
	var section = _create_option_section("Select Chapter")
	section.name = "ChapterSection"
	section.visible = false
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 110)
	var chapter_row = HBoxContainer.new()
	chapter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chapter_row.add_theme_constant_override("separation", 12)

	for i in range(1, 11):
		var button = _create_option_button("Chapter %d" % i)
		button.custom_minimum_size = Vector2(140, 70)
		button.pressed.connect(_on_chapter_selected.bind(i))
		chapter_buttons[i] = button
		chapter_row.add_child(button)

	scroll.add_child(chapter_row)
	section.get_node("Padding/Contents").add_child(scroll)
	$VBoxContainer.add_child(section)

func _add_map_section():
	var section = _create_option_section("Select Map")
	section.name = "MapSection"
	section.visible = false
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	var map_row = HBoxContainer.new()
	map_row.name = "MapRow"
	map_row.alignment = BoxContainer.ALIGNMENT_CENTER
	map_row.add_theme_constant_override("separation", 14)
	scroll.add_child(map_row)
	section.get_node("Padding/Contents").add_child(scroll)
	$VBoxContainer.add_child(section)


## Clears and repopulates the 4 story-map buttons for the given chapter.
func _rebuild_map_buttons() -> void:
	var section  = $VBoxContainer.get_node_or_null("MapSection")
	if not section:
		return
	var map_row = section.get_node("Padding/Contents/Scroll/MapRow")
	for child in map_row.get_children():
		child.queue_free()
	map_buttons.clear()

	for i in range(1, 5):
		var quest_unlocked := QuestManager.is_map_unlocked(selected_chapter, i)
		var unlocked: bool  = GameData.dev_mode_enabled or quest_unlocked
		var is_boss     := (i == 4)
		var story_waves := QuestManager.get_story_wave_count(selected_chapter, i)
		var claimed     := QuestManager.count_claimed_objectives(selected_chapter, i)
		var total_objs: int = QuestManager.MAP_OBJECTIVES.get(selected_chapter, {}).get(i, []).size()
		var stars_full  := "★".repeat(claimed)
		var stars_empty := "☆".repeat(total_objs - claimed)

		var line1 := "[ BOSS ]" if is_boss else "Map %d" % i
		var line2: String
		if not unlocked:
			line2 = "🔒 Locked"
		elif GameData.dev_mode_enabled and not quest_unlocked:
			line2 = "[DEV] " + stars_full + stars_empty
		else:
			line2 = stars_full + stars_empty
		var line3 := "%d Waves" % story_waves

		var button := _create_option_button(line1 + "\n" + line2 + "\n" + line3)
		button.custom_minimum_size = Vector2(150, 108)
		button.disabled = not unlocked
		button.pressed.connect(_on_map_selected.bind(i))
		map_buttons[i] = button
		map_row.add_child(button)

func _update_state():
	var chapter_section = $VBoxContainer.get_node("ChapterSection")
	var map_section     = $VBoxContainer.get_node_or_null("MapSection")
	chapter_section.visible = current_state in ["chapter", "map"]
	if map_section:
		map_section.visible = current_state == "map"
	_update_step_indicator()
	var start_btn = $VBoxContainer.get_node_or_null("ActionButtons/StartButton")
	if start_btn:
		match current_state:
			"chapter": start_btn.text = "← Select a Chapter"
			"map":     start_btn.text = "Start Story" if selected_map_index >= 1 else "← Select a Map"

func _add_action_buttons():
	var action_hbox = HBoxContainer.new()
	action_hbox.name = "ActionButtons"
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 20)

	var start_button = _create_action_button("Next  →")
	start_button.name = "StartButton"
	start_button.pressed.connect(_on_start_game_pressed)
	action_hbox.add_child(start_button)

	var back_button = _create_action_button("Back to Menu")
	back_button.pressed.connect(_on_back_pressed)
	action_hbox.add_child(back_button)

	$VBoxContainer.add_child(action_hbox)

func _create_option_section(title: String) -> PanelContainer:
	var section = PanelContainer.new()
	section.custom_minimum_size = Vector2(0, 120)
	UIThemeHelper.apply_panel_style(section, true)

	var margin = MarginContainer.new()
	margin.name = "Padding"
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)
	section.add_child(margin)

	var section_vbox = VBoxContainer.new()
	section_vbox.name = "Contents"
	section_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(section_vbox)

	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_GOLD)
	section_vbox.add_child(label)

	return section

func _create_button_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	return row

func _create_option_button(text: String) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 70)
	button.toggle_mode = true
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_CREAM)
	button.add_theme_color_override("font_color_pressed", UIThemeHelper.COL_TEXT_GOLD)
	button.add_theme_stylebox_override("normal",  _button_style(UIThemeHelper.COL_PANEL_BG,        UIThemeHelper.COL_PANEL_BORDER.darkened(0.4)))
	button.add_theme_stylebox_override("hover",   _button_style(UIThemeHelper.COL_BTN_PRIMARY_H,   UIThemeHelper.COL_PANEL_BORDER))
	button.add_theme_stylebox_override("pressed", _button_style(UIThemeHelper.COL_BTN_PRIMARY_P,   UIThemeHelper.COL_TEXT_GOLD))
	button.mouse_entered.connect(func(): AudioManager.play_ui_sound("button_hover"))
	return button

func _create_action_button(text: String) -> Button:
	var button = _create_option_button(text)
	button.custom_minimum_size = Vector2(220, 76)
	return button

func _setup_background():
	var bg = get_node_or_null("Background")
	if bg:
		if background_image:
			bg.texture = background_image
		var blur_material = ShaderMaterial.new()
		blur_material.shader = _create_blur_shader()
		bg.material = blur_material

func _create_blur_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float blur_uv : hint_range(0.0, 0.05) = 0.015;

void fragment() {
	vec2 uv = UV;
	vec4 sum = vec4(0.0);
	sum += texture(TEXTURE, uv + vec2(-blur_uv, -blur_uv));
	sum += texture(TEXTURE, uv + vec2(0.0, -blur_uv));
	sum += texture(TEXTURE, uv + vec2(blur_uv, -blur_uv));
	sum += texture(TEXTURE, uv + vec2(-blur_uv, 0.0));
	sum += texture(TEXTURE, uv);
	sum += texture(TEXTURE, uv + vec2(blur_uv, 0.0));
	sum += texture(TEXTURE, uv + vec2(-blur_uv, blur_uv));
	sum += texture(TEXTURE, uv + vec2(0.0, blur_uv));
	sum += texture(TEXTURE, uv + vec2(blur_uv, blur_uv));
	COLOR = sum / 9.0;
}
"""
	return shader

func _button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width(SIDE_LEFT, 2)
	style.set_border_width(SIDE_RIGHT, 2)
	style.set_border_width(SIDE_TOP, 2)
	style.set_border_width(SIDE_BOTTOM, 2)
	style.set_corner_radius_all(14)
	return style

func _on_chapter_selected(chapter: int):
	AudioManager.play_ui_sound("button_click")
	for i in chapter_buttons.keys():
		chapter_buttons[i].set_pressed(i == chapter)
	selected_chapter = chapter
	selected_map_index = -1
	current_state = "map"
	_rebuild_map_buttons()
	_update_state()
	_update_preview()

func _on_map_selected(map_idx: int):
	AudioManager.play_ui_sound("button_click")
	for i in map_buttons.keys():
		map_buttons[i].set_pressed(i == map_idx)
	selected_map_index = map_idx
	current_state = "map"
	_update_state()
	_update_preview()

func _on_start_game_pressed():
	AudioManager.play_ui_sound("button_click")
	match current_state:
		"chapter":
			pass
		"map":
			if selected_chapter < 1 or selected_map_index < 1:
				return
			var story_wave_count := QuestManager.get_story_wave_count(selected_chapter, selected_map_index)
			GameData.selected_chapter      = selected_chapter
			GameData.selected_map_index    = selected_map_index
			GameData.selected_map          = GameData.STORY_MAP_SCENES.get(selected_chapter, {}).get(
					selected_map_index,
					"res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn")
			GameData.selected_player_count = 1
			GameData.selected_wave_count   = story_wave_count
			_play_intro_then_launch()

## Plays the appropriate intro cutscene(s) then switches to GameScene.
## Map 1 of any chapter also plays the chapter intro first.
func _play_intro_then_launch() -> void:
	var ch: int  = GameData.selected_chapter
	var map: int = GameData.selected_map_index
	if map == 1:
		if ch == 1 and not QuestManager.prologue_seen:
			# First ever run: prologue → chapter intro → map intro → game
			QuestManager.prologue_seen = true
			QuestManager.save_data()
			CutsceneManager.play_prologue(func():
				CutsceneManager.play_chapter_intro(ch, func():
					CutsceneManager.play_map_intro(ch, map, func():
						get_tree().change_scene_to_file("res://Scenes/MainScenes/GameScene.tscn")
					)
				)
			)
		else:
			# Chapter intro → map intro → game
			CutsceneManager.play_chapter_intro(ch, func():
				CutsceneManager.play_map_intro(ch, map, func():
					get_tree().change_scene_to_file("res://Scenes/MainScenes/GameScene.tscn")
				)
			)
	elif map == 4:
		# Boss intro → map intro → game
		CutsceneManager.play_boss_intro(ch, func():
			CutsceneManager.play_map_intro(ch, map, func():
				get_tree().change_scene_to_file("res://Scenes/MainScenes/GameScene.tscn")
			)
		)
	else:
		# Map intro → game
		CutsceneManager.play_map_intro(ch, map, func():
			get_tree().change_scene_to_file("res://Scenes/MainScenes/GameScene.tscn")
		)

func _on_back_pressed():
	AudioManager.play_ui_sound("button_click")
	get_tree().change_scene_to_file("res://Scenes/UIScenes/main_menu.tscn")

func _update_preview():
	if has_node("VBoxContainer/SelectionPreview"):
		$VBoxContainer/SelectionPreview.text = _get_preview_text()

func _get_preview_text() -> String:
	var map_label := ""
	if selected_map_index >= 1:
		map_label = "Boss" if selected_map_index == 4 else "Map %d" % selected_map_index
	var ch_label := "Chapter %d" % selected_chapter if selected_chapter > 0 else "Select a chapter"
	match current_state:
		"chapter":
			return "Select a chapter"
		"map":
			if selected_map_index >= 1:
				var story_wave_count := QuestManager.get_story_wave_count(selected_chapter, selected_map_index)
				return "%s  •  %s  •  Story Length: %d Waves" % [ch_label, map_label, story_wave_count]
			return "%s  •  Select a map" % ch_label
		_:
			return ""
