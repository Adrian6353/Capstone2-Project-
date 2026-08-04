extends Control

# Autoload singletons
var AccountManager
var AudioManager
var GameData

var background_video_path: String = "res://Assets/UI/Art/main_menu_video.ogv"
var _is_transitioning: bool = false

var button_method_map = {
	"NewGame":    "_on_new_game_pressed",
	"CoOp":       "_on_coop_pressed",
	"StoryMode":  "_on_story_mode_pressed",
	"Quests":     "_on_quests_pressed",
	"Gacha":      "_on_gacha_pressed",
	"Codex":      "_on_codex_pressed",
	"Leaderboard": "_on_leaderboard_pressed",
	"Settings":   "_on_settings_pressed",
	"About":      "_on_about_pressed",
	"Quit":       "_on_quit_pressed"
}

func _ready():
	# Initialize autoload references
	AccountManager = get_node("/root/AccountManager")
	AudioManager = get_node("/root/AudioManager")
	GameData = get_node("/root/GameData")

	# Keep menu music continuous when navigating between UI screens.
	AudioManager.play_music("main_menu", 1.0)
	_setup_background_video()
	_build_profile_header()
	_setup_menu_layout()
	_inject_story_mode_button()
	_style_existing_menu_buttons()
	_connect_menu_buttons()
	_add_version_label()
	_animate_title()

	# If auth completes later, refresh the profile header label with latest display name.
	if AccountManager and not AccountManager.account_authenticated.is_connected(_on_account_authenticated):
		AccountManager.account_authenticated.connect(_on_account_authenticated)

func _animate_title() -> void:
	# Gentle scale-in on the entire menu panel for a polished entry.
	var menu_root = get_node_or_null("M")
	if not menu_root:
		return
	menu_root.modulate.a = 0.0
	menu_root.scale = Vector2(0.96, 0.96)
	menu_root.pivot_offset = menu_root.size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(menu_root, "modulate:a", 1.0, 0.30).set_ease(Tween.EASE_OUT)
	tw.tween_property(menu_root, "scale", Vector2.ONE, 0.30).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _add_version_label() -> void:
	var ver := Label.new()
	ver.text = "v1.0"
	ver.anchor_left  = 1.0
	ver.anchor_top   = 1.0
	ver.anchor_right = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left  = -220
	ver.offset_top   = -28
	ver.offset_right = -8
	ver.offset_bottom = -4
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.55, 0.42, 0.22, 0.70))
	add_child(ver)

func _connect_menu_buttons():
	var menu_box = $M/VB
	
	for child in menu_box.get_children():
		if child is Button and not (child is CheckBox or child is CheckButton or child is OptionButton):
			var method_name = button_method_map.get(child.name, "")
			
			if method_name:
				if not child.pressed.is_connected(Callable(self, method_name)):
					child.pressed.connect(Callable(self, method_name))
			
			if not child.mouse_entered.is_connected(Callable(self, "_on_button_hover")):
				child.mouse_entered.connect(Callable(self, "_on_button_hover"))

func _setup_background_video():
	var bg = get_node_or_null("B")
	if not bg:
		bg = get_node_or_null("VideoStreamPlayer")
	if not bg:
		bg = get_node_or_null("VideoPlayer")
	if not bg:
		return

	var stream = load(background_video_path)
	if not stream:
		push_error("Unable to load main menu video: %s" % background_video_path)
		return

	bg.visible = true
	bg.stream = stream
	bg.autoplay = true
	bg.loop = true
	bg.paused = false
	bg.play()

func _setup_menu_layout():
	var menu_box = $M/VB
	menu_box.anchor_left = 0.5
	menu_box.anchor_top = 0.2
	menu_box.anchor_right = 0.5
	menu_box.anchor_bottom = 0.8
	menu_box.offset_left = -215
	menu_box.offset_top = 0
	menu_box.offset_right = 215
	menu_box.offset_bottom = 0
	menu_box.add_theme_constant_override("separation", 10)
	menu_box.alignment = 1
	menu_box.custom_minimum_size = Vector2(430, 0)

# _apply_menu_theme kept for reference but styling is now done via UIThemeHelper.

func _style_existing_menu_buttons() -> void:
	var menu_box = $M/VB
	for child in menu_box.get_children():
		if child is Button and not (child is CheckBox or child is CheckButton or child is OptionButton):
			UIThemeHelper.apply_button_theme(child, "primary", 36)
			child.custom_minimum_size = Vector2(430, 64)

# Button styling is now delegated to UIThemeHelper.apply_button_theme().

func _build_profile_header():
	var header = PanelContainer.new()
	header.name = "ProfileHeader"
	header.anchor_left = 0.0
	header.anchor_top = 0.0
	header.anchor_right = 0.0
	header.anchor_bottom = 0.0
	header.offset_left = 24
	header.offset_top = 24
	header.offset_right = 390
	header.offset_bottom = 148
	UIThemeHelper.apply_panel_style(header)

	var content = HBoxContainer.new()
	content.name = "HeaderContent"
	content.anchor_left = 0.0
	content.anchor_top = 0.0
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.offset_left = 16
	content.offset_top = 16
	content.offset_right = -16
	content.offset_bottom = -16
	content.add_theme_constant_override("separation", 14)

	var avatar = PanelContainer.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = Vector2(88, 88)
	avatar.add_theme_stylebox_override("panel", _create_avatar_style())

	var profile_vbox = VBoxContainer.new()
	profile_vbox.name = "ProfileText"
	profile_vbox.add_theme_constant_override("separation", 6)

	var profile_label = Label.new()
	profile_label.text = "Player Profile"
	profile_label.add_theme_font_size_override("font_size", 18)
	profile_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))

	var subtitle_label = Label.new()
	subtitle_label.text = "Welcome back"
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.35, 0.8))

	var username_label = Label.new()
	username_label.name = "ProfileUsername"
	username_label.text = AccountManager.get_display_name() if AccountManager else "Player"
	username_label.add_theme_font_size_override("font_size", 22)
	username_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))

	var profile_button = Button.new()
	profile_button.name = "ProfileButton"
	profile_button.text = "Open Profile"
	profile_button.custom_minimum_size = Vector2(0, 44)
	UIThemeHelper.apply_button_theme(profile_button, "secondary", 14)
	profile_button.pressed.connect(_on_profile_pressed)

	profile_vbox.add_child(profile_label)
	profile_vbox.add_child(subtitle_label)
	profile_vbox.add_child(username_label)
	profile_vbox.add_child(profile_button)

	content.add_child(avatar)
	content.add_child(profile_vbox)
	header.add_child(content)
	add_child(header)

func _create_avatar_style() -> StyleBoxFlat:
	return UIThemeHelper.make_panel_style(true)

func _on_account_authenticated():
	var username_label = get_node_or_null("ProfileHeader/HeaderContent/ProfileText/ProfileUsername")
	if username_label and AccountManager:
		username_label.text = AccountManager.get_display_name()

func _on_button_hover():
	# Play button hover sound
	AudioManager.play_ui_sound("button_hover")

func _inject_story_mode_button() -> void:
	## Adds section labels and the Story Mode / Quests buttons dynamically.
	var menu_box := $M/VB

	# ── PLAY section ──────────────────────────────────────────────────────────
	# Insert a section label before NewGame
	if not menu_box.get_node_or_null("_LblPlay"):
		var lbl := UIThemeHelper.make_section_label("─── PLAY ───")
		lbl.name = "_LblPlay"
		menu_box.add_child(lbl)
		var new_game_btn := menu_box.get_node_or_null("NewGame")
		var target_idx := new_game_btn.get_index() if new_game_btn else 0
		menu_box.move_child(lbl, target_idx)

	var new_game_btn := menu_box.get_node_or_null("NewGame")
	var insert_idx := new_game_btn.get_index() + 1 if new_game_btn else menu_box.get_child_count()

	if not menu_box.get_node_or_null("StoryMode"):
		var btn := Button.new()
		btn.name = "StoryMode"
		btn.text = "Story Mode"
		menu_box.add_child(btn)
		menu_box.move_child(btn, insert_idx)
		insert_idx += 1

	if not menu_box.get_node_or_null("Quests"):
		var btn := Button.new()
		btn.name = "Quests"
		btn.text = "Quests"
		menu_box.add_child(btn)
		menu_box.move_child(btn, insert_idx)
		insert_idx += 1

	# ── COLLECTION section ────────────────────────────────────────────────────
	if not menu_box.get_node_or_null("_LblCollection"):
		var sep_lbl := UIThemeHelper.make_section_label("─── COLLECTION ───")
		sep_lbl.name = "_LblCollection"
		menu_box.add_child(sep_lbl)
		# Place before Gacha button
		var gacha_btn := menu_box.get_node_or_null("Gacha")
		if gacha_btn:
			menu_box.move_child(sep_lbl, gacha_btn.get_index())

	# ── OTHER section ─────────────────────────────────────────────────────────
	if not menu_box.get_node_or_null("_LblOther"):
		var sep_lbl2 := UIThemeHelper.make_section_label("─── OTHER ───")
		sep_lbl2.name = "_LblOther"
		menu_box.add_child(sep_lbl2)
		var lb_btn := menu_box.get_node_or_null("Leaderboard")
		if lb_btn:
			menu_box.move_child(sep_lbl2, lb_btn.get_index())

func _on_quests_pressed():
	if _is_transitioning:
		return
	AudioManager.play_ui_sound("button_click")
	_change_scene_smooth("res://Scenes/UIScenes/QuestScreen.tscn")

func _on_story_mode_pressed():
	if _is_transitioning:
		return
	AudioManager.play_ui_sound("button_click")
	AudioManager.play_music("new_game", 0.4)
	GameData.game_mode = "normal"
	_change_scene_smooth("res://Scenes/UIScenes/map_selection.tscn")

func _on_new_game_pressed():
	if _is_transitioning:
		return
	# Play button click sound
	AudioManager.play_ui_sound("button_click")
	AudioManager.play_music("new_game", 0.4)
	# Load the debug map select scene
	GameData.game_mode = "normal"
	_change_scene_smooth("res://Scenes/UIScenes/DebugMapSelect.tscn")

func _on_coop_pressed():
	if _is_transitioning:
		return
	AudioManager.play_ui_sound("button_click")
	AudioManager.play_music("new_game", 0.4)
	GameData.is_coop = false   # reset; lobby will set it when both players connect
	_change_scene_smooth("res://Scenes/UIScenes/coop_lobby.tscn")

func _on_profile_pressed():
	if _is_transitioning:
		return
	# Play button click sound
	AudioManager.play_ui_sound("button_click")
	# Open profile menu
	_change_scene_smooth("res://Scenes/UIScenes/profile_menu.tscn")

func _on_codex_pressed():
	if _is_transitioning:
		return
	AudioManager.play_ui_sound("button_click")
	_change_scene_smooth("res://Scenes/UIScenes/codex.tscn")

func _on_leaderboard_pressed():
	if _is_transitioning:
		return
	# Play button click sound
	AudioManager.play_ui_sound("button_click")
	# Open leaderboard
	_change_scene_smooth("res://Scenes/UIScenes/leaderboard.tscn")

func _on_settings_pressed():
	AudioManager.play_ui_sound("button_click")
	var settings_scene = load("res://Scenes/UIScenes/settings_menu.tscn")
	if settings_scene:
		var settings_ui = settings_scene.instantiate()
		add_child(settings_ui)

func _on_about_pressed():
	# Play button click sound
	AudioManager.play_ui_sound("button_click")
	# TODO: Implement about screen
	print("About not yet implemented")

func _on_quit_pressed():
	AudioManager.play_ui_sound("button_click")
	get_tree().quit()

func _on_gacha_pressed():
	AudioManager.play_ui_sound("button_click")
	var lootbox_scene = load("res://Scenes/UIScenes/lootbox_ui.tscn")
	if lootbox_scene:
		var lootbox_ui = lootbox_scene.instantiate()
		add_child(lootbox_ui)
	else:
		push_error("LootboxManager: Could not load lootbox_ui.tscn")

func _change_scene_smooth(scene_path: String, _fade_duration: float = 0.2) -> void:
	_is_transitioning = true
	# Show LoadingScreen as an overlay, let it handle the scene switch.
	var ls_scene = load("res://Scenes/UIScenes/LoadingScreen.tscn")
	if ls_scene:
		var ls = ls_scene.instantiate()
		ls.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
		ls.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(ls)
		ls.begin(scene_path)
	else:
		# Fallback: plain scene switch
		get_tree().change_scene_to_file(scene_path)
