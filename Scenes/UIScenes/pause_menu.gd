extends Control

# Autoload singletons
var NetworkStatus
var RankingManager
var AudioManager
var GameData

func _ready() -> void:
	# Initialize autoload references
	NetworkStatus = get_node("/root/NetworkStatus")
	RankingManager = get_node("/root/RankingManager")
	AudioManager = get_node("/root/AudioManager")
	GameData = get_node_or_null("/root/GameData")
	
	process_mode = PROCESS_MODE_WHEN_PAUSED
	
	var resume_btn = $CanvasLayer/CenterContainer/PanelContainer/VBoxContainer/MarginContainer/ButtonContainer/ResumeButton
	var restart_btn = $CanvasLayer/CenterContainer/PanelContainer/VBoxContainer/MarginContainer/ButtonContainer/RestartButton
	var main_menu_btn = $CanvasLayer/CenterContainer/PanelContainer/VBoxContainer/MarginContainer/ButtonContainer/MainMenuButton
	
	if resume_btn:
		UIThemeHelper.apply_button_theme(resume_btn, "primary", 24)
		if not resume_btn.pressed.is_connected(_on_resume_pressed):
			resume_btn.pressed.connect(_on_resume_pressed)
	if restart_btn:
		UIThemeHelper.apply_button_theme(restart_btn, "secondary", 24)
		if not restart_btn.pressed.is_connected(_on_restart_pressed):
			restart_btn.pressed.connect(_on_restart_pressed)
	if main_menu_btn:
		UIThemeHelper.apply_button_theme(main_menu_btn, "secondary", 24)
		if not main_menu_btn.pressed.is_connected(_on_main_menu_pressed):
			main_menu_btn.pressed.connect(_on_main_menu_pressed)
	
	for button in [resume_btn, restart_btn, main_menu_btn]:
		if button and not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover)
	
	# Populate live game stats
	_update_stats_row()
	
	# Show online/offline indicator
	_update_online_status()
	if NetworkStatus:
		NetworkStatus.connection_changed.connect(_on_connection_changed)
	
	# Entry animation on the panel
	var panel := get_node_or_null("CanvasLayer/CenterContainer/PanelContainer")
	if panel:
		UIThemeHelper.animate_panel_in(panel)

func _exit_tree() -> void:
	if NetworkStatus and NetworkStatus.connection_changed.is_connected(_on_connection_changed):
		NetworkStatus.connection_changed.disconnect(_on_connection_changed)

func _update_stats_row() -> void:
	if not GameData:
		return
	var wave_lbl := get_node_or_null(
		"CanvasLayer/CenterContainer/PanelContainer/VBoxContainer/StatsRow/WaveStatLabel")
	var gold_lbl := get_node_or_null(
		"CanvasLayer/CenterContainer/PanelContainer/VBoxContainer/StatsRow/GoldStatLabel")
	var hp_lbl := get_node_or_null(
		"CanvasLayer/CenterContainer/PanelContainer/VBoxContainer/StatsRow/HPStatLabel")
	if wave_lbl:
		wave_lbl.text = "Wave %d" % GameData.current_wave
	if gold_lbl:
		gold_lbl.text = "🪙 %d" % GameData.current_money
	if hp_lbl:
		var hp_val = GameData.get("current_health")
		if hp_val == null:
			hp_val = GameData.get("player_health")
		if hp_val == null:
			hp_val = 100
		hp_lbl.text = "❤ %d" % hp_val

func _on_button_hover() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_hover")

func _on_resume_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	get_tree().paused = false
	queue_free()

func _on_restart_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	ConfirmationDialogManager.show_confirmation(
		"Restart Level?",
		"Are you sure you want to restart this level? Your progress will be lost.",
		func():
			get_tree().paused = false
			queue_free()
			get_tree().call_deferred("reload_current_scene")
	)

func _on_main_menu_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	ConfirmationDialogManager.show_confirmation(
		"Return to Main Menu?",
		"Are you sure you want to return to the main menu? Your progress will be lost.",
		func():
			queue_free()
			var current_scene := get_tree().current_scene
			if current_scene and current_scene.has_method("return_to_main_menu"):
				current_scene.return_to_main_menu()
			else:
				if AudioManager:
					AudioManager.stop_music(0.5)
				get_tree().paused = false
				get_tree().call_deferred("change_scene_to_file", "res://Scenes/UIScenes/main_menu.tscn")
	)



func _update_online_status() -> void:
	var status_label = get_node_or_null("CanvasLayer/CenterContainer/PanelContainer/VBoxContainer/OnlineStatusLabel")
	if status_label:
		if NetworkStatus and NetworkStatus.get_is_online():
			status_label.text = "● Online"
			status_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
		else:
			status_label.text = "● Offline"
			status_label.add_theme_color_override("font_color", Color(0.85, 0.45, 0.25))

func _on_connection_changed(_online: bool) -> void:
	_update_online_status()
