extends Control

# Autoload singletons
var AccountManager
var RankingManager
var NetworkStatus
var AudioManager

# Leaderboard display
var leaderboard_container: VBoxContainer
var leaderboard_item_scene: PackedScene
var player_rank_label: Label
var refresh_button: Button
var back_button: Button

# Auto-refresh
var auto_refresh_timer: Timer
var auto_refresh_label: Label
var _seconds_since_refresh: float = 0.0
var _is_refreshing: bool = false

func _ready():
	# Initialize autoload references
	AccountManager = get_node("/root/AccountManager")
	RankingManager = get_node("/root/RankingManager")
	NetworkStatus = get_node("/root/NetworkStatus")
	AudioManager = get_node("/root/AudioManager")

	# Play dedicated leaderboard music through AudioManager.
	AudioManager.play_music("leaderboard", 1.0)
	
	_find_ui_elements()
	_setup_auto_refresh()

	# Connect signals
	if refresh_button:
		refresh_button.hide()
	
	# Listen for leaderboard updates
	RankingManager.leaderboard_updated.connect(_on_leaderboard_updated)
	
	# Seed the display now with cached data, then request a fresh snapshot.
	RankingManager.request_leaderboard_refresh()
	_update_leaderboard()

func _find_ui_elements():
	if has_node("VBoxContainer/ScrollContainer/LeaderboardList"):
		leaderboard_container = $VBoxContainer/ScrollContainer/LeaderboardList
	if has_node("VBoxContainer/PlayerRankLabel"):
		player_rank_label = $VBoxContainer/PlayerRankLabel
		player_rank_label.add_theme_font_size_override("font_size", 22)
		player_rank_label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_GOLD)
	if has_node("VBoxContainer/Title"):
		$VBoxContainer/Title.add_theme_font_size_override("font_size", 32)
		$VBoxContainer/Title.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_GOLD)
	if has_node("VBoxContainer/RefreshButton"):
		refresh_button = $VBoxContainer/RefreshButton
		UIThemeHelper.apply_button_theme(refresh_button, "secondary", 18)
	if has_node("VBoxContainer/BackButton"):
		back_button = $VBoxContainer/BackButton
		UIThemeHelper.apply_button_theme(back_button, "primary", 18)
	if has_node("VBoxContainer/SubtitleLabel"):
		var sub = $VBoxContainer/SubtitleLabel
		sub.add_theme_font_size_override("font_size", 13)
		sub.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_MUTED)

func _setup_auto_refresh():
	# Status label — shows live connection state instead of a countdown.
	auto_refresh_label = Label.new()
	auto_refresh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_refresh_label.add_theme_font_size_override("font_size", 12)
	auto_refresh_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.5))
	auto_refresh_label.text = "● Live"
	if has_node("VBoxContainer"):
		var vbox = $VBoxContainer
		vbox.add_child(auto_refresh_label)
		if player_rank_label:
			vbox.move_child(auto_refresh_label, player_rank_label.get_index() + 1)
	# This screen refreshes on scene open and when RankingManager publishes updates.

func _process(delta: float):
	if not auto_refresh_label:
		return
	if not NetworkStatus.get_is_online():
		auto_refresh_label.text = "⚠ Offline"
		auto_refresh_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		return
	_seconds_since_refresh += delta
	var secs := int(_seconds_since_refresh)
	auto_refresh_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.5))
	if secs <= 3:
		auto_refresh_label.text = "● Live  •  Updated just now"
	else:
		auto_refresh_label.text = "● Live  •  Last updated: %ds ago" % secs

func _update_leaderboard():
	var leaderboard = RankingManager.get_leaderboard()
	var current_device_id = AccountManager.get_device_id()
	
	print("[Leaderboard] Updating leaderboard with %d entries" % leaderboard.size())
	print("[Leaderboard] Current device: %s" % current_device_id.substr(0, 8))
	
	# Clear existing items
	if leaderboard_container:
		for child in leaderboard_container.get_children():
			child.queue_free()
	
	# Add header
	if leaderboard_container:
		var header = _create_leaderboard_row("Rank", "Player", "Total Waves", "Best Run", "Wins", true)
		leaderboard_container.add_child(header)
	
	# Add leaderboard entries
	var player_found = false
	for i in range(leaderboard.size()):
		var entry = leaderboard[i]
		var player_name = _resolve_leaderboard_name(entry)
		print("[Leaderboard] Entry %d: %s - total %d, best %d, %d wins" % [i+1, player_name, entry.get("total_waves", 0), entry["best_waves"], entry.get("wins", 0)])
		var is_player = entry["device_uuid"] == current_device_id
		
		if is_player:
			player_found = true
			if player_rank_label:
				player_rank_label.text = "Your Rank: #%d" % (i + 1)
		
		var row = _create_leaderboard_row(
			str(i + 1),
			player_name,
			str(int(entry.get("total_waves", 0))),
			str(int(entry["best_waves"])),
			str(int(entry.get("wins", 0))),
			false,
			is_player
		)
		if leaderboard_container:
			leaderboard_container.add_child(row)
	
	if not player_found and player_rank_label:
		player_rank_label.text = "Your Rank: Unranked"
	
	print("[Leaderboard] Leaderboard display complete")

func _create_leaderboard_row(rank: String, player: String, total: String, best: String, wins: String, is_header: bool = false, highlight: bool = false) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row_style := StyleBoxFlat.new()
	row_style.set_border_width_all(0)
	row_style.border_width_left = 4
	row_style.border_color = Color(0, 0, 0, 0)
	row_style.bg_color = Color(0, 0, 0, 0)
	if highlight:
		row_style.bg_color = Color(0.30, 0.22, 0.04, 0.55)
		row_style.border_color = UIThemeHelper.COL_BORDER_PRIMARY
	row_panel.add_theme_stylebox_override("panel", row_style)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.add_child(row)

	# Rank — prepend medal for top 3
	var rank_text := rank
	if not is_header:
		match rank:
			"1": rank_text = "🥇"
			"2": rank_text = "🥈"
			"3": rank_text = "🥉"
			_: rank_text = "#" + rank
	var rank_label = Label.new()
	rank_label.text = rank_text
	rank_label.custom_minimum_size = Vector2(60, 60)
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(rank_label)

	# Player name
	var player_label = Label.new()
	player_label.text = player
	player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(player_label)

	# Total Waves
	var total_label = Label.new()
	total_label.text = total
	total_label.custom_minimum_size = Vector2(110, 60)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(total_label)

	# Best Wave
	var best_label = Label.new()
	best_label.text = best
	best_label.custom_minimum_size = Vector2(90, 60)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(best_label)

	# Wins
	var wins_label = Label.new()
	wins_label.text = wins
	wins_label.custom_minimum_size = Vector2(65, 60)
	wins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(wins_label)

	# Styling
	if is_header:
		for label in [rank_label, player_label, total_label, best_label, wins_label]:
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_GOLD)
	elif highlight:
		for label in [rank_label, player_label, total_label, best_label, wins_label]:
			label.add_theme_font_size_override("font_size", 17)
			label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_CREAM)
	else:
		for label in [rank_label, player_label, total_label, best_label, wins_label]:
			label.add_theme_font_size_override("font_size", 17)
			label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_MUTED)

	return row_panel

func _on_back():
	AudioManager.play_ui_sound("button_click")
	get_tree().change_scene_to_file("res://Scenes/UIScenes/main_menu.tscn")

func _on_refresh():
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	_is_refreshing = true
	RankingManager.request_leaderboard_refresh()

func _on_leaderboard_updated(_leaderboard: Array):
	_seconds_since_refresh = 0.0
	_is_refreshing = false
	_update_leaderboard()

func _resolve_leaderboard_name(entry: Dictionary) -> String:
	# Always prefer the locally-known name for our own device
	if str(entry.get("device_uuid", "")) == AccountManager.get_device_id():
		var local_name = AccountManager.get_display_name().strip_edges()
		if local_name != "":
			return local_name
		var local_username = AccountManager.get_username().strip_edges()
		if local_username != "":
			return local_username

	var candidate = str(entry.get("display_name", "")).strip_edges()
	if candidate != "":
		return candidate

	return "Unknown"
