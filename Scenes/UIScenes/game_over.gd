extends Control

# Autoload singletons
var RankingManager
var DataPersistence
var NetworkStatus
var AudioManager
var GameData
var LootboxManager

var level_completed := false
var waves_survived := 0
var sync_status_label: Label
var personal_best_label: Label
var rewards_label: Label

func _ready():
	# Initialize autoload references
	RankingManager = get_node("/root/RankingManager")
	DataPersistence = get_node("/root/DataPersistence")
	NetworkStatus = get_node("/root/NetworkStatus")
	AudioManager = get_node("/root/AudioManager")
	GameData = get_node("/root/GameData")
	LootboxManager = get_node("/root/LootboxManager")
	
	process_mode = PROCESS_MODE_ALWAYS
	
	# Apply Fantasy RPG panel style
	var panel := get_node_or_null("M/Panel")
	if panel:
		UIThemeHelper.apply_panel_style(panel)
	
	# Get waves survived from game session
	waves_survived = GameData.current_session_best_waves
	var map_name = GameData.selected_map

	var title_node := get_node_or_null("M/Panel/VB/Title")
	if title_node:
		if level_completed:
			title_node.text = "✦ VICTORY! ✦"
			title_node.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_GOLD)
		else:
			title_node.text = "GAME OVER"
			title_node.add_theme_color_override("font_color", Color(1.0, 0.30, 0.25))

	# Display waves survived
	var waves_label = get_node_or_null("M/Panel/VB/WavesLabel")
	if waves_label:
		waves_label.text = "Waves Survived: %d" % waves_survived
		waves_label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_CREAM)
	
	# Check if personal best
	_check_personal_best(map_name)
	
	# Submit game result
	_submit_game_result(map_name)

	# Award lootboxes based on performance and display them.
	_award_and_display_boxes()

	# Style buttons
	var retry_button = get_node_or_null("M/Panel/VB/ButtonRow/Retry")
	if retry_button:
		UIThemeHelper.apply_button_theme(retry_button, "primary", 24)
		retry_button.pressed.connect(_on_retry_pressed)

	var main_menu_button = get_node_or_null("M/Panel/VB/ButtonRow/MainMenu")
	if main_menu_button:
		UIThemeHelper.apply_button_theme(main_menu_button, "secondary", 24)
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	# Entry animation
	var m_panel := get_node_or_null("M")
	if m_panel:
		if level_completed:
			UIThemeHelper.animate_scale_punch(m_panel, 1.10, 0.40)
		else:
			await get_tree().process_frame
			UIThemeHelper.animate_shake(m_panel, 6.0, 0.30)
	
	# Listen for sync completion
	if RankingManager:
		RankingManager.sync_complete.connect(_on_sync_complete)
		RankingManager.offline_mode_enabled.connect(_on_offline_mode)

func _check_personal_best(map_name: String):
	# Compare with local best for this map
	var stats = DataPersistence.get_local_stats()
	var best_key = ""
	
	if map_name.contains("Map1"):
		best_key = "best_waves_map_1"
	elif map_name.contains("Map2"):
		best_key = "best_waves_map_2"
	else:
		best_key = "best_waves_map_3"
	
	var previous_best = stats.get(best_key, 0)
	
	# Show personal best indicator
	personal_best_label = get_node_or_null("M/Panel/VB/PersonalBestLabel")
	if personal_best_label:
		if waves_survived > previous_best:
			personal_best_label.text = "🎉 NEW PERSONAL BEST!"
			personal_best_label.add_theme_color_override("font_color", Color.GOLD)
		else:
			personal_best_label.text = "Previous Best: %d waves" % previous_best
			personal_best_label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_MUTED)

func _submit_game_result(map_name: String):
	# Submit to ranking manager
	if RankingManager:
		RankingManager.submit_game_result(map_name, waves_survived, level_completed)
	
	# Show syncing status
	sync_status_label = get_node_or_null("M/Panel/VB/SyncStatusLabel")
	if sync_status_label:
		sync_status_label.text = "Syncing..."
		sync_status_label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_MUTED)

func _on_sync_complete():
	if sync_status_label:
		if NetworkStatus and NetworkStatus.get_is_online():
			sync_status_label.text = "✓ Results synced to leaderboard"
			sync_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			sync_status_label.text = "✓ Synced"

func _on_offline_mode():
	if sync_status_label:
		sync_status_label.text = "⚠ Offline — will sync when online"
		sync_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

# Award lootboxes for this game session and show the reward summary.
func _award_and_display_boxes():
	if not LootboxManager:
		return

	var earned: Dictionary = LootboxManager.award_post_game_boxes(
		waves_survived,
		level_completed,
		GameData.selected_wave_count
	)

	# Build reward summary text.
	var parts: PackedStringArray = PackedStringArray()
	for box_type in ["legendary", "rare", "common"]:
		var count: int = earned.get(box_type, 0)
		if count > 0:
			parts.append("+%d %s" % [count, LootboxManager.get_box_display_name(box_type)])

	rewards_label = get_node_or_null("M/Panel/VB/RewardsLabel")
	if rewards_label:
		if parts.size() > 0:
			rewards_label.text = "📦 Rewards: " + "  ".join(parts)
			rewards_label.add_theme_color_override("font_color", Color.GOLD)
		else:
			rewards_label.text = ""

func _on_retry_pressed():
	if AudioManager:
		AudioManager.stop_music(0.3)
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	ConfirmationDialogManager.show_confirmation(
		"Return to Main Menu?",
		"Are you sure you want to return to the main menu?",
		func():
			var current_scene := get_tree().current_scene
			if current_scene and current_scene.has_method("return_to_main_menu"):
				current_scene.return_to_main_menu()
			else:
				if AudioManager:
					AudioManager.stop_music(0.5)
				get_tree().paused = false
				get_tree().call_deferred("change_scene_to_file", "res://Scenes/UIScenes/main_menu.tscn")
	)
