extends Control

# Autoload singletons
var AccountManager
var RankingManager
var DataPersistence
var NetworkStatus
var AudioManager

# References to UI elements (will be auto-found or set in _ready)
var display_name_input: LineEdit
var device_id_label: Label
var sync_status_label: Label
var local_stats_label: Label
var save_name_button: Button
var leaderboard_button: Button
var back_button: Button
var logout_button: Button
var reset_progress_button: Button
var _error_label: Label = null  # transient error toast

@export var background_image: Texture2D = preload("res://Assets/UI/Art/rm218-bb-07.jpg")

func _ready():
	# Initialize autoload references
	AccountManager = get_node("/root/AccountManager")
	RankingManager = get_node("/root/RankingManager")
	DataPersistence = get_node("/root/DataPersistence")
	NetworkStatus = get_node("/root/NetworkStatus")
	AudioManager = get_node("/root/AudioManager")

	# Keep the same UI track running instead of restarting it.
	AudioManager.play_music("main_menu", 1.0)
	
	# Find UI elements in scene
	_find_ui_elements()
	
	# Connect signals
	if save_name_button:
		save_name_button.pressed.connect(_on_save_name)
	if leaderboard_button:
		leaderboard_button.pressed.connect(_on_open_leaderboard)
	if back_button:
		back_button.pressed.connect(_on_back)
	if logout_button:
		logout_button.pressed.connect(_on_logout)
	if reset_progress_button:
		reset_progress_button.pressed.connect(_on_reset_progress_pressed)

	# Redirect to login if logged out from elsewhere
	AccountManager.login_required.connect(_on_login_required)

	_setup_background()
	_style_ui()
	_refresh_display()

	# Listen for ranking updates
	RankingManager.sync_complete.connect(_on_sync_complete)
	RankingManager.offline_mode_enabled.connect(_on_offline_mode)

func _setup_background():
	var bg = get_node_or_null("Background")
	if bg:
		if background_image:
			bg.texture = background_image
			bg.expand = true
			bg.stretch_mode = TextureRect.STRETCH_SCALE
		var blur_material = ShaderMaterial.new()
		blur_material.shader = _create_blur_shader()
		bg.material = blur_material

func _style_ui():
	$VBoxContainer.add_theme_constant_override("separation", 18)
	$VBoxContainer.add_theme_constant_override("margin_top", 22)
	$VBoxContainer.add_theme_constant_override("margin_bottom", 22)

	var title_label = $VBoxContainer/Title
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$VBoxContainer.set_h_size_flags(0)
	$VBoxContainer.set_v_size_flags(0)

	var btn_variants := {
		"SaveButton":          "primary",
		"LeaderboardButton":   "secondary",
		"BackButton":          "secondary",
		"LogoutButton":        "danger",
		"ResetProgressButton": "danger",
	}
	for btn_name in btn_variants.keys():
		var btn = $VBoxContainer.get_node_or_null(btn_name)
		if btn:
			UIThemeHelper.apply_button_theme(btn, btn_variants[btn_name], 18)
			btn.custom_minimum_size = Vector2(0, 60)

	if has_node("VBoxContainer/NameInput"):
		var name_input = $VBoxContainer/NameInput
		name_input.custom_minimum_size = Vector2(0, 52)

	if local_stats_label:
		local_stats_label.add_theme_font_size_override("font_size", 15)
		local_stats_label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_CREAM)

	if sync_status_label:
		sync_status_label.add_theme_font_size_override("font_size", 14)
		sync_status_label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_MUTED)

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

func _find_ui_elements():
	# Try to find elements by common node names
	if has_node("VBoxContainer/NameInput"):
		display_name_input = $VBoxContainer/NameInput
	if has_node("VBoxContainer/DeviceIDLabel"):
		device_id_label = $VBoxContainer/DeviceIDLabel
	if has_node("VBoxContainer/SyncStatusLabel"):
		sync_status_label = $VBoxContainer/SyncStatusLabel
	if has_node("VBoxContainer/StatsLabel"):
		local_stats_label = $VBoxContainer/StatsLabel
	if has_node("VBoxContainer/SaveButton"):
		save_name_button = $VBoxContainer/SaveButton
	if has_node("VBoxContainer/LeaderboardButton"):
		leaderboard_button = $VBoxContainer/LeaderboardButton
	if has_node("VBoxContainer/BackButton"):
		back_button = $VBoxContainer/BackButton
	if has_node("VBoxContainer/LogoutButton"):
		logout_button = $VBoxContainer/LogoutButton
	if has_node("VBoxContainer/ResetProgressButton"):
		reset_progress_button = $VBoxContainer/ResetProgressButton

func _refresh_display():

	# Display username
	if device_id_label:
		var username = AccountManager.get_username()
		if username != "":
			device_id_label.text = "Username: " + username
		else:
			device_id_label.text = "Device ID: " + AccountManager.get_device_id().substr(0, 16) + "..."
	
	# Display current display name
	if display_name_input:
		display_name_input.text = _resolve_profile_display_name()
	
	# Display local stats
	if local_stats_label:
		var stats = DataPersistence.get_local_stats()
		var text = "Games Played: %d\n" % stats["total_games"]
		text += "Wins: %d\n" % stats.get("wins", 0)
		text += "Total Waves Survived: %d\n" % stats.get("total_waves", 0)
		text += "Best Waves (Map1): %d\n" % stats["best_waves_map_1"]
		text += "Best Waves (Map2): %d\n" % stats["best_waves_map_2"]
		text += "Best Waves (Map3): %d" % stats["best_waves_map_3"]
		local_stats_label.text = text
	
	# Display sync status
	_update_sync_status()

func _update_sync_status():
	if sync_status_label:
		if NetworkStatus.get_is_online():
			var player_rank = RankingManager.get_player_rank()
			if player_rank > 0:
				sync_status_label.text = "✓ Online • Rank: #%d" % player_rank
			else:
				sync_status_label.text = "✓ Online • Not ranked"
		else:
			sync_status_label.text = "⚠ Offline • Changes will sync when online"

func _on_save_name():
	if display_name_input:
		var new_name = display_name_input.text.strip_edges()
		if AccountManager.set_display_name(new_name):
			AudioManager.play_ui_sound("button_click")
			_refresh_display()
		else:
			display_name_input.text = _resolve_profile_display_name()
			_show_name_error("Invalid name. Must be 3–20 characters.")

func _show_name_error(message: String) -> void:
	if is_instance_valid(_error_label):
		_error_label.queue_free()
	_error_label = Label.new()
	_error_label.text = message
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_font_size_override("font_size", 14)
	_error_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	$VBoxContainer.add_child(_error_label)
	$VBoxContainer.move_child(_error_label, save_name_button.get_index() + 1 if save_name_button else -1)
	# Auto-dismiss after 3 seconds
	var t := create_tween()
	t.tween_interval(2.5)
	t.tween_property(_error_label, "modulate:a", 0.0, 0.5)
	t.tween_callback(_error_label.queue_free)

func _on_open_leaderboard():
	AudioManager.play_ui_sound("button_click")
	get_tree().change_scene_to_file("res://Scenes/UIScenes/leaderboard.tscn")

func _on_back():
	AudioManager.play_ui_sound("button_click")
	get_tree().change_scene_to_file("res://Scenes/UIScenes/main_menu.tscn")

func _on_logout():
	AudioManager.play_ui_sound("button_click")
	ConfirmationDialogManager.show_confirmation(
		"Logout?",
		"Are you sure you want to logout? You will need to login again.",
		func():
			AccountManager.logout()
			# _on_login_required will fire from the signal and redirect
	)

func _on_login_required():
	get_tree().change_scene_to_file("res://Scenes/UIScenes/login_screen.tscn")

func _on_sync_complete():
	_update_sync_status()

func _on_offline_mode():
	_update_sync_status()

func _on_reset_progress_pressed():
	AudioManager.play_ui_sound("button_click")
	ConfirmationDialogManager.show_confirmation(
		"Reset Progress?",
		"This will clear all your local personal best records and remove your entry from the online leaderboard.\nThis cannot be undone.",
		func():
			DataPersistence.reset_local_stats()
			if NetworkStatus.get_is_online():
				await RankingManager.reset_remote_entry()
			_refresh_display()
	)

func _resolve_profile_display_name() -> String:
	var display_name = AccountManager.get_display_name().strip_edges()
	if display_name != "":
		return display_name

	var username = AccountManager.get_username().strip_edges()
	if username != "":
		return username

	return "Player"
