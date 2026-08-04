extends Node2D

signal game_finished(result)
signal money_changed(new_amount)

var map_node
var camera_node

var build_mode= false
var build_valid = false 
var build_location
var build_tile
var build_type
var tower_preview_node: Node2D = null

var current_wave = 0
var enemies_in_wave = 0
var wave_in_progress = false
var waves_completed = 0

var base_health = 100
var _returning_to_main_menu: bool = false

# Co-op networking (lockstep with host-authority for base health and game over)
var _coop_wave_rpc_active: bool = false  # prevents re-entry guard in _client_begin_wave
var _coop_wave_request_pending: bool = false  # client-side debounce: blocks double-sends before host replies

# Sell system
# Refund percentage is defined in GameData.REFUND_PERCENTAGE (0.75 = 75%)

# Upgrade panel
const UpgradePanelScript = preload("res://Scenes/UIScenes/upgrade_panel.gd")
var _upgrade_panel: Node = null

# Mutual ready-up (co-op only)
var _local_player_ready: bool = false
var _partner_player_ready: bool = false

# Map ping system (co-op only)
var _ping_mode: bool = false
var _last_ping_time: float = -999.0
const PING_COOLDOWN: float = 3.0

# Touch: track press position to distinguish a tap from a finger-drag pan
var _touch_press_pos: Vector2 = Vector2.ZERO
const TOUCH_DRAG_THRESHOLD: float = 18.0  # pixels; travel beyond this is a pan, not a tap
const EnemyDebugPanelScript  = preload("res://Scenes/UIScenes/EnemyDebugPanel.gd")
const EnemySpawnerPanelScript = preload("res://Scenes/UIScenes/EnemySpawnerPanel.gd")
var _enemy_debug_panel:   CanvasLayer = null
var _enemy_spawner_panel: CanvasLayer = null


func _ready():
	add_to_group("game_scene")  # Used by DevHUD to locate this node via the scene tree
	# Initialize tower availability for normal mode
	GameData.current_wave = 1
	
	# Co-op must be set up BEFORE reset_economy so player_gold pools are initialised.
	if CoopManager.is_coop_active:
		_setup_coop()
	
	# Scale starting money based on player count
	if GameData.selected_player_count == 2:
		GameData.starting_money = 700  # More resources for 2 players
	else:
		GameData.starting_money = 500  # Standard for 1 player
	
	# Initialize economy
	GameData.reset_economy()
	emit_signal("money_changed", GameData.current_money)
	get_node("UI").update_money_display(GameData.current_money)
	
	# Start telemetry session (after coop setup so device IDs are ready).
	TelemetryManager.start_session()
	
	# Start background music for gameplay
	AudioManager.play_music("gameplay")
	
	# Load map variant based on player count
	var map_path = GameData.selected_map
	var player_suffix = "_" + str(GameData.selected_player_count) + "P"
	# Insert player suffix before .tscn extension
	var variant_path = map_path.trim_suffix(".tscn") + player_suffix + ".tscn"

	var map_scene
	if ResourceLoader.exists(variant_path):
		map_scene = load(variant_path)
	else:
		map_scene = load(map_path)
	if not map_scene:
		return
	
	map_node = map_scene.instantiate()
	add_child(map_node)
	map_node.position = Vector2(-16, -34)
	
	if not map_node:
		return
	
	# Get the camera from the map
	camera_node = map_node.get_node_or_null("GameCamera")

	for i in get_tree().get_nodes_in_group("build_buttons"):
		i.pressed.connect(Callable(self, "initiate_build_mode").bindv([i.name]))
		if i.has_signal("pressed"):
			i.pressed.connect(func(): AudioManager.play_ui_sound("button_click"))
	
	for i in get_tree().get_nodes_in_group("wave_buttons"):
		i.pressed.connect(Callable(self, "_on_wave_button_pressed"))
		if i.has_signal("pressed"):
			i.pressed.connect(func(): AudioManager.play_ui_sound("button_click"))
	
	# Initialize wave preview for the first wave
	var ui_layer = get_node_or_null("UI")
	if ui_layer:
		ui_layer.update_wave_preview(current_wave)
	
	# Show tutorial on first play
	call_deferred("_maybe_show_tutorial")

func _maybe_show_tutorial() -> void:
	# Show the tutorial automatically on the player's first game.
	# Subsequent launches skip it; the Help (?) button always re-opens it.
	var seen: bool = DataPersistence.load_setting("seen_tutorial", false)
	if not seen:
		DataPersistence.save_setting("seen_tutorial", true)
		var tut = load("res://Scenes/UIScenes/tutorial_popup.tscn").instantiate()
		add_child(tut)
		tut.start_tutorial()

func _process(_delta):
	if build_mode:
		update_tower_preview()
	
func _unhandled_input(event):
	if event.is_action_released("ui_cancel") and build_mode == true:
		cancel_build_mode()
	if event.is_action_released("ui_accept") and build_mode == true:
		verify_and_build()
		cancel_build_mode()
	# Record where the finger/click landed so we can measure travel on release
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_touch_press_pos = event.position

	# Primary tap/click release — handles both build placement and upgrade panel.
	# Travel check ensures a finger-pan doesn't accidentally trigger these actions.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		var travel: float = (event as InputEventMouseButton).position.distance_to(_touch_press_pos)
		if travel < TOUCH_DRAG_THRESHOLD:
			if build_mode:
				verify_and_build()
				cancel_build_mode()
			elif _ping_mode and not wave_in_progress:
				# Ping mode: place ping marker on tap.
				var world_pos := get_global_mouse_position()
				_place_ping(world_pos)
			else:
				var tower = get_tower_at_mouse()
				if tower:
					_open_upgrade_panel(tower)
				elif is_instance_valid(_upgrade_panel):
					_close_upgrade_panel()
	# Right-click to sell tower
	if event.is_action_released("right_click"):
		var tower = get_tower_at_mouse()
		if tower:
			_close_upgrade_panel()
			sell_tower(tower)
	# F3 – toggle enemy info panel
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		if OS.is_debug_build():
			_toggle_enemy_debug_panel()
	# F4 – toggle enemy spawner panel
	if event is InputEventKey and event.pressed and event.keycode == KEY_F4:
		if OS.is_debug_build():
			_toggle_enemy_spawner_panel()
	
## Debug Functions

func _toggle_enemy_debug_panel() -> void:
	if is_instance_valid(_enemy_debug_panel):
		_enemy_debug_panel.queue_free()
		_enemy_debug_panel = null
	else:
		_enemy_debug_panel = CanvasLayer.new()
		_enemy_debug_panel.set_script(EnemyDebugPanelScript)
		add_child(_enemy_debug_panel)

func _toggle_enemy_spawner_panel() -> void:
	if is_instance_valid(_enemy_spawner_panel):
		_enemy_spawner_panel.queue_free()
		_enemy_spawner_panel = null
	else:
		_enemy_spawner_panel = CanvasLayer.new()
		_enemy_spawner_panel.set_script(EnemySpawnerPanelScript)
		add_child(_enemy_spawner_panel)

## Wave Functions

func start_next_wave() -> void:
	if wave_in_progress:
		return
	if waves_completed >= GameData.selected_wave_count:
		return
	# Co-op: only host decides when waves start; client sends a request instead.
	if CoopManager.is_coop_active and not multiplayer.is_server() and not _coop_wave_rpc_active:
		if not _coop_wave_request_pending:
			_coop_wave_request_pending = true
			_host_request_wave.rpc_id(1)
		return
	var wave_data = GameData.retrieve_wave_data(GameData.selected_player_count, current_wave)
	wave_in_progress = true
	# Close planning phase in telemetry.
	TelemetryManager.end_planning_phase()
	# Hide wave buttons during wave
	_set_wave_buttons_visible(false)
	get_node("UI").reset_ready_button()
	# Play boss music if this is a boss wave; otherwise play normal wave music
	if GameData.is_boss_wave(current_wave):
		AudioManager.play_music("bosswave", 0.5)
	else:
		AudioManager.play_music("normal_wave", 0.5)
	# Play wave start sound
	AudioManager.play_sfx("wave_start")
	# Co-op: tell client to start the same wave (before the spawn delay so both are in sync).
	if CoopManager.is_coop_active and multiplayer.is_server():
		_client_begin_wave.rpc(current_wave)
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self):
		return
	spawn_enemies(wave_data)
	current_wave += 1
	GameData.current_wave = current_wave  # Sync with GameData for tower availability
	enemies_in_wave = wave_data.size()
	
	# Refresh the lootbox-owned tower bar.
	var ui_layer = get_node_or_null("UI")
	if ui_layer:
		ui_layer.update_tower_availability_for_wave(current_wave)
		ui_layer.stop_wave_button_pulse()
		ui_layer.show_wave_banner("⚔  WAVE %d  ⚔" % current_wave, Color(0.95, 0.78, 0.32))
		# Update wave preview to show next wave (if there is one)
		if current_wave < GameData.selected_wave_count:
			ui_layer.update_wave_preview(current_wave)

func _set_wave_buttons_visible(visible: bool):
	for btn in get_tree().get_nodes_in_group("wave_buttons"):
		btn.visible = visible

func spawn_enemies(wave_data):
	var path_node = map_node.get_node_or_null("Path")
	if not path_node:
		return
		
	for i in wave_data:
		var enemy_type = i[0]
		var enemy_scene_path = "res://Scenes/Enemies/" + enemy_type + ".tscn"
		var enemy_scene = load(enemy_scene_path)
		
		if not enemy_scene:
			continue
			
		var new_enemy = enemy_scene.instantiate()
		
		if not new_enemy:
			continue
		
		# Store enemy type on the enemy for later use
		new_enemy.enemy_type = enemy_type
		
		if new_enemy.has_signal("base_damage"):
			new_enemy.base_damage.connect(on_base_damage)
		if new_enemy.has_signal("enemy_destroyed"):
			new_enemy.enemy_destroyed.connect(on_enemy_destroyed.bindv([enemy_type]))
		path_node.add_child(new_enemy, true)

		if new_enemy.has_method("initialize"):
			new_enemy.initialize(current_wave)

		await get_tree().create_timer(i[1]).timeout
		if not is_instance_valid(self):
			return

func game_over(won: bool) -> void:
	# Co-op: only host triggers game over; client waits for the _client_game_over RPC.
	if CoopManager.is_coop_active and not multiplayer.is_server():
		return

	# Story mode: record win for quest progression.
	if won and GameData.selected_chapter >= 1 and GameData.selected_map_index >= 1:
		QuestManager.on_map_won(GameData.selected_chapter, GameData.selected_map_index)
		QuestManager.update_objective("win_map", GameData.selected_chapter, GameData.selected_map_index, 1)

	# Track best waves for ranking system
	_update_session_best_waves()

	# Finalize telemetry session (host side).
	TelemetryManager.finish_session(won, base_health, waves_completed)

	# Co-op: tell client to show game over too.
	if CoopManager.is_coop_active and multiplayer.is_server():
		_client_game_over.rpc(won)

	# Boss map win: play chapter outro before the game-over screen.
	if won and GameData.selected_map_index == 4:
		CutsceneManager.play_chapter_outro(GameData.selected_chapter, func():
			_show_game_over_ui(won)
		)
		return

	_show_game_over_ui(won)

func _update_session_best_waves() -> void:
	if current_wave > GameData.current_session_best_waves:
		GameData.current_session_best_waves = current_wave

func return_to_main_menu() -> void:
	if _returning_to_main_menu:
		return
	_returning_to_main_menu = true
	_update_session_best_waves()
	TelemetryManager.finish_session(false, base_health, waves_completed)
	get_tree().paused = false
	AudioManager.stop_music(0.5)
	if CoopManager.is_coop_active:
		CoopManager.disconnect_coop()
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/UIScenes/main_menu.tscn")

func _show_game_over_ui(won: bool) -> void:
	get_tree().paused = true

	# Play appropriate sound effect
	if won:
		AudioManager.play_sfx("game_win")
	else:
		AudioManager.play_sfx("game_over")

	var game_over_scene = load("res://Scenes/UIScenes/game_over.tscn")
	if game_over_scene:
		var game_over_ui = game_over_scene.instantiate()
		# Set the label to 'LEVEL COMPLETE!' if won, else 'GAME OVER'
		if won:
			game_over_ui.level_completed = true
		get_node("UI").add_child(game_over_ui)

	emit_signal("game_finished", won)

## Building Functions

func initiate_build_mode(tower_type):
	var role: int = CoopManager.get_local_player_id() if CoopManager.is_coop_active else 0
	if tower_type not in GameData.get_available_towers_normal_mode(role):
		print("Cannot build ", tower_type, ": its family has not been obtained from a lootbox.")
		get_node("UI").show_locked_tower_message(tower_type)
		return
	var tower_cost = GameData.tower_data[tower_type].get("cost", 0)
	if GameData.current_money < tower_cost:
		print("Cannot afford ", tower_type, "! Cost: $", tower_cost, " Available: $", GameData.current_money)
		get_node("UI").show_insufficient_funds_message(tower_type, tower_cost)
		return
	# Block if this card is still on cooldown.
	if get_node("UI").is_card_on_cooldown(tower_type):
		var player_role: int = CoopManager.get_local_player_id() if CoopManager.is_coop_active else 1
		TelemetryManager.on_cooldown_blocked(tower_type, player_role)
		get_node("UI").show_cooldown_message(tower_type)
		return
	
	if build_mode:
		cancel_build_mode()
	build_type = tower_type
	build_mode = true
	_create_tower_preview(tower_type)
	var _ui_bi := get_node_or_null("UI")
	if _ui_bi:
		_ui_bi.show_build_indicator(tower_type)

func _create_tower_preview(tower_type: String) -> void:
	if tower_preview_node:
		tower_preview_node.queue_free()
		tower_preview_node = null

	var scene_file = GameData.get_tower_scene_path(tower_type)
	var scene_path = "res://Scenes/Towers/" + scene_file
	var tower_scene = load(scene_path)
	if tower_scene == null:
		print("ERROR: Could not load tower preview scene: ", scene_path)
		return

	tower_preview_node = Node2D.new()
	tower_preview_node.name = "TowerPreview"
	tower_preview_node.z_index = 10

	# Range circle behind the tower sprite
	var range_overlay = Sprite2D.new()
	range_overlay.name = "RangeOverlay"
	range_overlay.texture = load("res://Assets/UI/range_overlay.png")
	range_overlay.centered = true
	range_overlay.position = Vector2.ZERO
	range_overlay.modulate = Color(1.0, 1.0, 1.0, 0.5)
	tower_preview_node.add_child(range_overlay)

	# Tower sprite on top
	var drag_tower = tower_scene.instantiate()
	drag_tower.name = "DragTower"
	drag_tower.set("type", tower_type)
	drag_tower.set("category", GameData.tower_data[tower_type].get("category", null))
	drag_tower.modulate = Color(1.0, 1.0, 1.0, 0.7)
	drag_tower.position = Vector2.ZERO
	tower_preview_node.add_child(drag_tower)
	_configure_preview_range(range_overlay, drag_tower, tower_type)

	add_child(tower_preview_node)
	tower_preview_node.global_position = get_global_mouse_position()

func _configure_preview_range(range_overlay: Sprite2D, drag_tower: Node2D, tower_type: String) -> void:
	if not range_overlay or not range_overlay.texture:
		return

	var preview_radius = _get_preview_world_range_radius(drag_tower, tower_type)
	if preview_radius <= 0.0:
		return

	var texture_size = range_overlay.texture.get_size().x
	if texture_size <= 0.0:
		return

	var preview_diameter = preview_radius * 2.0
	var scale_factor = preview_diameter / texture_size
	range_overlay.scale = Vector2.ONE * scale_factor

func _get_preview_world_range_radius(drag_tower: Node2D, tower_type: String) -> float:
	var collision_shape := drag_tower.get_node_or_null("Range/CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return float(GameData.tower_data.get(tower_type, {}).get("range", 0.0))

	var local_radius = 10.0 * (0.5 * float(GameData.tower_data.get(tower_type, {}).get("range", 0.0)))
	if drag_tower.has_method("get_configured_range_radius"):
		local_radius = float(drag_tower.call("get_configured_range_radius"))

	return local_radius * collision_shape.global_scale.x

func update_tower_preview():
	if not map_node:
		return

	var exclusion = map_node.get_node_or_null("TowerExclusion")
	if exclusion == null:
		return

	var mouse_position = get_global_mouse_position()
	var local_mouse = exclusion.to_local(mouse_position)
	var current_tile = exclusion.local_to_map(local_mouse)
	var tile_position = exclusion.map_to_local(current_tile)

	var world_position = exclusion.to_global(tile_position)
	if tower_preview_node:
		tower_preview_node.global_position = world_position

	if exclusion.get_cell_source_id(current_tile) == -1:
		if is_tower_overlapping(tile_position):
			_set_preview_color(Color("ff3651ff"))
			build_valid = false
		else:
			_set_preview_color(Color("50a920ff"))
			build_valid = true
			build_location = tile_position
			build_tile = current_tile
	else:
		_set_preview_color(Color("ff3651ff"))
		build_valid = false

func _set_preview_color(color: Color) -> void:
	if not tower_preview_node:
		return
	var drag_tower = tower_preview_node.get_node_or_null("DragTower")
	if drag_tower:
		drag_tower.modulate = color
	var range_overlay = tower_preview_node.get_node_or_null("RangeOverlay")
	if range_overlay:
		range_overlay.modulate = color.lerp(Color.WHITE, 0.5)
		

func cancel_build_mode():
	build_mode = false
	build_valid = false
	if tower_preview_node:
		tower_preview_node.queue_free()
		tower_preview_node = null
	var _ui_hbi := get_node_or_null("UI")
	if _ui_hbi:
		_ui_hbi.hide_build_indicator()

func is_tower_overlapping(position: Vector2) -> bool:
	"""Check if a tower already exists too close to the given position"""
	if not map_node:
		return false
	
	var towers_node = map_node.get_node_or_null("Towers")
	if not towers_node:
		return false
	
	# Collision radius based on tower scale (0.15 scale = ~30-40px at default resolution)
	var collision_radius = 35.0
	
	for tower in towers_node.get_children():
		if tower.position.distance_to(position) < collision_radius:
			return true
	
	return false
func verify_and_build():
	if build_valid:
		# In normal mode, only allow Level 1 towers to be built (and role-appropriate ones in co-op).
		if GameData.game_mode == "normal":
			var role: int = CoopManager.get_local_player_id() if CoopManager.is_coop_active else 0
			var available_towers = GameData.get_available_towers_normal_mode(role)
			if build_type not in available_towers:
				print("Cannot build tower: ", build_type, " has not been obtained from a lootbox.")
				get_node("UI").show_locked_tower_message(build_type)
				cancel_build_mode()
				return
		
		var tower_cost = GameData.tower_data[build_type].get("cost", 0)
		
		# Check money requirement
		if not GameData.spend_money(tower_cost):
			print("Not enough money! Cost: ", tower_cost, " Available: ", GameData.current_money)
			get_node("UI").show_insufficient_funds_message(build_type, tower_cost)
			return
		
		# Build the tower
		var tower_scene_path = GameData.get_tower_scene_path(build_type)
		var tower_scene = load("res://Scenes/Towers/" + tower_scene_path)
		if not tower_scene:
			push_error("GameScene: could not load tower scene for '%s' at path '%s'" % [build_type, tower_scene_path])
			GameData.add_money(tower_cost)
			cancel_build_mode()
			return
		var new_tower = tower_scene.instantiate()
		new_tower.position = build_location
		new_tower.built = true
		new_tower.type = build_type
		new_tower.category = GameData.tower_data[build_type]["category"]	
		
		# Final overlap check before placing
		if is_tower_overlapping(build_location):
			print("Cannot place tower: overlaps with existing tower")
			new_tower.queue_free()
			GameData.add_money(tower_cost)
			cancel_build_mode()
			return
		
		var towers_container = map_node.get_node("Towers")
		towers_container.add_child(new_tower, true)
		
		print("Tower built: ", build_type)
		# Play tower place sound
		AudioManager.play_sfx("tower_place")
		# Start card cooldown and record placement in telemetry.
		get_node("UI").start_card_cooldown(build_type)
		var _place_role: int = CoopManager.get_local_player_id() if CoopManager.is_coop_active else 1
		TelemetryManager.on_tower_placed(wave_in_progress, _place_role, build_type, build_location)
		
		# Co-op: sync tower to partner and notify them of our new gold total.
		if CoopManager.is_coop_active:
			_coop_sync_tower.rpc(build_type, build_location.x, build_location.y)
			_coop_notify_partner_gold.rpc(GameData.current_money)
		
		# Update UI with new money amount and tower affordability
		emit_signal("money_changed", GameData.current_money)
		get_node("UI").update_money_display(GameData.current_money)
		
func on_enemy_destroyed(reward: int, enemy_type: String = "") -> void:
	GameData.add_money(reward)
	# Play coin collection sound
	AudioManager.play_sfx("coin_collect")
	emit_signal("money_changed", GameData.current_money)
	get_node("UI").update_money_display(GameData.current_money)
	print("Enemy destroyed! +", reward, " money. Total: ", GameData.current_money)
	# Co-op: tell partner our updated gold so their HUD stays current.
	if CoopManager.is_coop_active:
		_coop_notify_partner_gold.rpc(GameData.current_money)

	# Story mode: track kill objective.
	if GameData.selected_chapter >= 1 and GameData.selected_map_index >= 1:
		QuestManager.update_objective("kill_enemies", GameData.selected_chapter, GameData.selected_map_index, 1)

	enemies_in_wave -= 1
	_finalize_wave_if_cleared()
		
func on_base_damage(damage):
	# Co-op: base health is host-authoritative.  Client only counts the enemy.
	if CoopManager.is_coop_active and not multiplayer.is_server():
		enemies_in_wave -= 1
		_finalize_wave_if_cleared()
		return
	base_health -= damage
	get_node("UI").update_health_bar(base_health)
	enemies_in_wave -= 1
	# Co-op: broadcast new health to client.
	if CoopManager.is_coop_active and multiplayer.is_server():
		_client_sync_base_health.rpc(base_health)
	if base_health <= 0:
		game_over(false)
		return
	_finalize_wave_if_cleared()

func _finalize_wave_if_cleared() -> void:
	if enemies_in_wave <= 0 and enemies_in_wave > -1:
		wave_in_progress = false
		waves_completed = current_wave
		# Reset ready-up flags for next inter-wave phase.
		_local_player_ready = false
		_partner_player_ready = false
		# Start planning phase in telemetry.
		TelemetryManager.start_planning_phase(waves_completed)
		# Story mode: track wave survival objective.
		if GameData.selected_chapter >= 1 and GameData.selected_map_index >= 1:
			QuestManager.update_objective("survive_waves", GameData.selected_chapter, GameData.selected_map_index, 1)
		# Resume gameplay music after wave ends
		AudioManager.play_music("gameplay", 0.5)
		_set_wave_buttons_visible(true)
		# Update wave preview to show the next wave
		var ui_layer = get_node_or_null("UI")
		if ui_layer:
			ui_layer.reset_card_cooldowns()
			if waves_completed < GameData.selected_wave_count:
				ui_layer.update_wave_preview(waves_completed)
				ui_layer.show_wave_banner("✓  WAVE CLEARED", Color(0.35, 1.0, 0.45))
				ui_layer.start_wave_button_pulse()
		# If all waves have been completed, trigger win.
		# In co-op: only host calls game_over (client waits for the RPC).
		if waves_completed >= GameData.selected_wave_count:
			if not CoopManager.is_coop_active or multiplayer.is_server():
				game_over(true)
		enemies_in_wave = -1

func handle_card_drops(enemy_type: String = "Dwende") -> void:
	"""Drop a random tower card based on enemy-specific drop rates"""
	# Fallback to Dwende if empty
	if enemy_type.is_empty():
		enemy_type = "Dwende"
	
	# Get drop rates for this enemy type
	var drop_rates = GameData.enemy_drop_rates.get(enemy_type, {})
	if drop_rates.is_empty():
		print("Warning: No drop rates found for enemy type: ", enemy_type)
		return
	
	var random_value = randf()
	var cumulative_chance = 0.0
	
	for tower_type in drop_rates.keys():
		cumulative_chance += drop_rates[tower_type]
		if random_value <= cumulative_chance:
			GameData.collect_card(tower_type)
			var rarity = GameData.get_card_rarity(tower_type)
			# Log card collection in telemetry.
			var player_role: int = CoopManager.get_local_player_id() if CoopManager.is_coop_active else 1
			TelemetryManager.on_card_collected(tower_type, player_role)
			# Show visual card drop animation
			spawn_card_drop_effect(tower_type, rarity)
			
			get_node("UI").show_card_collected(tower_type, rarity)
			print("Card dropped from ", enemy_type, ": ", tower_type, " (", rarity, ")! Total collected: ", 
				GameData.get_collected_card_count(tower_type))
			return
	
	# Fallback: no card was dropped
	print("No card drop from ", enemy_type)

func spawn_card_drop_effect(tower_type: String, rarity: String) -> void:
	"""Create a visual card drop effect"""
	# Create card visual
	var card = Control.new()
	card.custom_minimum_size = Vector2(60, 80)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Card background
	var card_bg = ColorRect.new()
	card_bg.anchor_right = 1.0
	card_bg.anchor_bottom = 1.0
	var color = GameData.get_rarity_color(rarity)
	card_bg.color = color
	card_bg.color.a = 0.7
	card.add_child(card_bg)
	
	# Card label
	var card_label = Label.new()
	card_label.text = tower_type
	card_label.add_theme_font_size_override("font_size", 10)
	card_label.anchor_right = 1.0
	card_label.anchor_bottom = 1.0
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(card_label)
	
	# Position at a random location on screen
	var viewport_rect = get_viewport().get_visible_rect()
	var random_x = randf_range(100, viewport_rect.size.x - 100)
	var random_y = randf_range(100, viewport_rect.size.y / 2)
	card.position = Vector2(random_x, random_y)
	
	# Add to scene
	get_tree().root.add_child(card)
	
	# Animate the card: float up and fade then disappear
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "position:y", random_y - 100, 1.5)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(card, "modulate:a", 0.0, 1.5)
	
	await fade_tween.finished
	if is_instance_valid(card):
		card.queue_free()

## Sell System Functions

func get_tower_at_mouse() -> Node2D:
	"""Find a tower at the current mouse position"""
	if not map_node:
		return null
	
	var towers_node = map_node.get_node_or_null("Towers")
	if not towers_node:
		return null
	
	var mouse_pos = get_global_mouse_position()
	var towers = towers_node.get_children()
	
	# Check each tower to see if mouse is within its bounds
	for tower in towers:
		if not "type" in tower or not GameData.tower_data.has(tower.type):
			continue
		var distance = tower.global_position.distance_to(mouse_pos)
		# Use tower's range as click area (minimum 50 pixels for easier clicking)
		var click_radius = max(80, GameData.tower_data[tower.type]["range"] * 0.15)  # 80 px min for finger taps
		if distance <= click_radius:
			return tower
	
	return null

func sell_tower(tower: Node2D) -> void:
	"""Sell a tower and refund a percentage of its cost"""
	if not tower or not map_node:
		return
	
	var tower_type = tower.type
	var tower_cost = GameData.tower_data[tower_type].get("cost", 0)
	var refund_amount = int(tower_cost * GameData.REFUND_PERCENTAGE)
	
	# Get the tower's tile position from the exclusion layer
	var exclusion = map_node.get_node_or_null("TowerExclusion")
	if exclusion:
		var local_pos = exclusion.to_local(tower.global_position)
		var tile_pos = exclusion.local_to_map(local_pos)
		# Clear the tile so it can be built on again
		exclusion.erase_cell(tile_pos)
	
	# Refund the money
	GameData.add_money(refund_amount)
	
	# Remove the tower
	tower.queue_free()
	
	# Update UI
	emit_signal("money_changed", GameData.current_money)
	get_node("UI").update_money_display(GameData.current_money)
	
	print("Tower sold: ", tower_type, " for $", refund_amount, " (75% refund)")
	# Play tower sell sound
	AudioManager.play_sfx("tower_sell")
	
	# Co-op: sync sell to partner (use position as identifier) and notify gold change.
	if CoopManager.is_coop_active:
		_coop_sync_sell.rpc(tower.position.x, tower.position.y)
		_coop_notify_partner_gold.rpc(GameData.current_money)
	
	# Show feedback message
	get_node("UI").show_tower_sold_message(tower_type, refund_amount)


func _on_pause_menu_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	get_node("UI").show_pause_menu()


# =========================================================================== #
#  UPGRADE SYSTEM                                                               #
# =========================================================================== #

func _open_upgrade_panel(tower: Node2D) -> void:
	_close_upgrade_panel()
	_upgrade_panel = UpgradePanelScript.new()
	get_node("UI").add_child(_upgrade_panel)
	_upgrade_panel.populate(tower)
	_upgrade_panel.upgrade_requested.connect(_on_upgrade_requested)
	_upgrade_panel.sell_requested.connect(_on_sell_requested)
	AudioManager.play_sfx("upgrade_panel_open")

func _close_upgrade_panel() -> void:
	if is_instance_valid(_upgrade_panel):
		_upgrade_panel.queue_free()
	_upgrade_panel = null

func _on_upgrade_requested(tower: Node2D) -> void:
	upgrade_tower(tower)

func _on_sell_requested(tower: Node2D) -> void:
	_close_upgrade_panel()
	sell_tower(tower)

func upgrade_tower(tower: Node2D) -> void:
	if not is_instance_valid(tower):
		return
	var next_type: String = GameData.get_next_tower_type(tower.type)
	if next_type == "":
		return
	var cost: int = GameData.get_upgrade_cost(tower.type)
	if not GameData.spend_money(cost):
		get_node("UI").show_insufficient_funds_message(tower.type, cost)
		return
	var old_pos: Vector2 = tower.position
	tower.queue_free()
	var scene_path: String = GameData.get_tower_scene_path(next_type)
	var new_tower = load("res://Scenes/Towers/" + scene_path).instantiate()
	new_tower.position = old_pos
	new_tower.built    = true
	new_tower.type     = next_type
	new_tower.category = GameData.tower_data[next_type]["category"]
	map_node.get_node("Towers").add_child(new_tower, true)
	AudioManager.play_sfx("tower_upgrade")
	emit_signal("money_changed", GameData.current_money)
	get_node("UI").update_money_display(GameData.current_money)
	if CoopManager.is_coop_active:
		_coop_sync_upgrade.rpc(old_pos.x, old_pos.y, next_type)
		_coop_notify_partner_gold.rpc(GameData.current_money)
	_close_upgrade_panel()


# =========================================================================== #
#  CO-OP NETWORKING                                                             #
# =========================================================================== #

func _setup_coop() -> void:
	GameData.is_coop = true
	if CoopManager.is_host:
		print("GameScene [COOP]: Running as HOST (P1)")
	else:
		print("GameScene [COOP]: Running as CLIENT (P2)")
	if not CoopManager.partner_disconnected.is_connected(_on_coop_partner_disconnected):
		CoopManager.partner_disconnected.connect(_on_coop_partner_disconnected)
	# Exchange device UUIDs with partner for telemetry.
	call_deferred("_exchange_device_ids")

# --- Wave synchronisation -------------------------------------------------- #

## Client → Host: client pressed "Start Wave"; host actually starts it.
@rpc("any_peer", "call_remote", "reliable")
func _host_request_wave() -> void:
	start_next_wave()

## Host → Client: tells client which wave is starting so it can run the same
## spawn sequence (lockstep).  The client reconstructs wave_data from wave_num
## deterministically using the same GameData settings.
@rpc("authority", "call_remote", "reliable")
func _client_begin_wave(wave_num: int) -> void:
	_coop_wave_request_pending = false  # clear client-side debounce
	current_wave   = wave_num
	waves_completed = max(0, wave_num - 1)
	_coop_wave_rpc_active = true
	await start_next_wave()
	_coop_wave_rpc_active = false

# --- Tower synchronisation ------------------------------------------------- #

## Syncs a freshly placed tower to the remote peer.
## Called via `rpc()` so it runs on the REMOTE peer only (the local peer
## already placed the tower through verify_and_build).
@rpc("any_peer", "call_remote", "reliable")
func _coop_sync_tower(tower_type: String, pos_x: float, pos_y: float) -> void:
	if not map_node:
		return
	var towers_container = map_node.get_node_or_null("Towers")
	if not towers_container:
		return
	var tower_scene_path = GameData.get_tower_scene_path(tower_type)
	var tower_res = load("res://Scenes/Towers/" + tower_scene_path)
	if not tower_res:
		push_error("CoopSync: cannot load tower scene for " + tower_type)
		return
	var tower_instance            = tower_res.instantiate()
	tower_instance.position       = Vector2(pos_x, pos_y)
	tower_instance.built          = true
	tower_instance.type           = tower_type
	tower_instance.category       = GameData.tower_data[tower_type]["category"]
	towers_container.add_child(tower_instance, true)
	AudioManager.play_sfx("tower_place")
	# Count partner's tower placement in telemetry.
	TelemetryManager.on_partner_tower_placed(tower_type, wave_in_progress)

# --- Gold display synchronisation ------------------------------------------ #

## Sender notifies partner of their current gold total so the partner's HUD
## can display it.  Uses `rpc()` → runs on REMOTE peer only.
@rpc("any_peer", "call_remote", "reliable")
func _coop_notify_partner_gold(amount: int) -> void:
	GameData.partner_gold = amount
	var ui_layer = get_node_or_null("UI")
	if ui_layer and ui_layer.has_method("update_partner_gold_display"):
		ui_layer.update_partner_gold_display(amount)

## Syncs a tower sell to the remote peer so they remove the same tower.
@rpc("any_peer", "call_remote", "reliable")
func _coop_sync_sell(pos_x: float, pos_y: float) -> void:
	if not map_node:
		return
	var towers_container = map_node.get_node_or_null("Towers")
	if not towers_container:
		return
	var sell_pos := Vector2(pos_x, pos_y)
	for tower in towers_container.get_children():
		if tower.position.distance_to(sell_pos) < 5.0:
			tower.queue_free()
			break

## Syncs a tower upgrade to the remote peer: removes the old tower and places
## the next-level tower at the same position.
@rpc("any_peer", "call_remote", "reliable")
func _coop_sync_upgrade(pos_x: float, pos_y: float, next_type: String) -> void:
	if not map_node:
		return
	var towers_container = map_node.get_node_or_null("Towers")
	if not towers_container:
		return
	var upgrade_pos := Vector2(pos_x, pos_y)
	for tower in towers_container.get_children():
		if tower.position.distance_to(upgrade_pos) < 5.0:
			tower.queue_free()
			break
	var scene_path: String = GameData.get_tower_scene_path(next_type)
	var tower_res = load("res://Scenes/Towers/" + scene_path)
	if not tower_res:
		return
	var new_tower = tower_res.instantiate()
	new_tower.position = upgrade_pos
	new_tower.built    = true
	new_tower.type     = next_type
	new_tower.category = GameData.tower_data[next_type]["category"]
	towers_container.add_child(new_tower, true)

# --- Base health synchronisation ------------------------------------------- #

## Host → Client: pushes authoritative base_health after an enemy reaches base.
@rpc("authority", "call_remote", "reliable")
func _client_sync_base_health(hp: int) -> void:
	base_health = hp
	get_node("UI").update_health_bar(base_health)

# --- Game-over synchronisation --------------------------------------------- #

## Host → Client: triggers the game-over screen on the client side.
@rpc("authority", "call_remote", "reliable")
func _client_game_over(won: bool) -> void:
	# Finalize telemetry on client side too.
	TelemetryManager.finish_session(won, base_health, waves_completed)
	get_tree().paused = true
	if won:
		AudioManager.play_sfx("game_win")
	else:
		AudioManager.play_sfx("game_over")
	var game_over_scene = load("res://Scenes/UIScenes/game_over.tscn")
	if game_over_scene:
		var game_over_ui = game_over_scene.instantiate()
		if won:
			game_over_ui.level_completed = true
		get_node("UI").add_child(game_over_ui)
	emit_signal("game_finished", won)

# --- Disconnect handling --------------------------------------------------- #

func _on_coop_partner_disconnected() -> void:
	if CoopManager.is_host:
		# Host: show a short warning then continue solo.
		var popup := Label.new()
		popup.text = "Partner disconnected  —  continuing solo"
		popup.add_theme_font_size_override("font_size", 26)
		popup.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		popup.set_anchors_preset(Control.PRESET_CENTER)
		popup.offset_left  = -300
		popup.offset_right =  300
		popup.offset_top   = -20
		popup.offset_bottom = 20
		get_node("UI").add_child(popup)
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(popup):
			popup.queue_free()
		CoopManager.disconnect_coop()
	else:
		# Client: host left — return to main menu.
		get_tree().paused = false
		CoopManager.disconnect_coop()
		get_tree().change_scene_to_file("res://Scenes/UIScenes/main_menu.tscn")

# =============================================================================
# TELEMETRY — Device ID exchange
# =============================================================================

func _exchange_device_ids() -> void:
	"""Broadcast our device UUID to the partner so TelemetryManager can record it."""
	_receive_partner_device_id.rpc(AccountManager.device_uuid)

@rpc("any_peer", "call_remote", "reliable")
func _receive_partner_device_id(partner_uuid: String) -> void:
	TelemetryManager.set_partner_device_id(partner_uuid)

# =============================================================================
# WAVE BUTTON / READY-UP SYSTEM (Co-op only)
# =============================================================================

func _on_wave_button_pressed() -> void:
	"""Route wave-button presses through the ready-up system in co-op."""
	if CoopManager.is_coop_active:
		_handle_ready_up()
	else:
		start_next_wave()

func _handle_ready_up() -> void:
	if wave_in_progress or _local_player_ready:
		return
	_local_player_ready = true
	_notify_partner_ready.rpc()
	get_node("UI").update_ready_status(true, _partner_player_ready)
	TelemetryManager.log_coop_event("planning_ready_clicked", {
		"player": "PlayerA" if CoopManager.is_host else "PlayerB"
	})
	_check_both_ready()

@rpc("any_peer", "call_remote", "reliable")
func _notify_partner_ready() -> void:
	_partner_player_ready = true
	get_node("UI").update_ready_status(_local_player_ready, true)
	_check_both_ready()

func _check_both_ready() -> void:
	if not (_local_player_ready and _partner_player_ready):
		return
	# Only host actually triggers the wave start.
	if CoopManager.is_coop_active and not multiplayer.is_server():
		return
	_local_player_ready = false
	_partner_player_ready = false
	get_node("UI").update_ready_status(false, false)
	start_next_wave()

# =============================================================================
# MAP PING SYSTEM (Co-op only)
# =============================================================================

func _on_ping_button_pressed() -> void:
	_ping_mode = not _ping_mode
	get_node("UI").set_ping_button_active(_ping_mode)

func _place_ping(world_pos: Vector2) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_ping_time < PING_COOLDOWN:
		return
	_last_ping_time = now
	_ping_mode = false
	get_node("UI").set_ping_button_active(false)
	_spawn_ping_effect(world_pos, true)
	if CoopManager.is_coop_active:
		_coop_sync_ping.rpc(world_pos.x, world_pos.y)
	TelemetryManager.log_coop_event("ping_sent", {
		"position": str(world_pos),
		"player": "PlayerA" if CoopManager.is_host else "PlayerB"
	})

func _spawn_ping_effect(world_pos: Vector2, is_own: bool) -> void:
	"""Create a brief expanding ring at world_pos.  Blue = own, Yellow = partner's."""
	var ring := ColorRect.new()
	ring.color = Color(0.2, 0.6, 1.0, 0.85) if is_own else Color(1.0, 0.85, 0.1, 0.85)
	ring.custom_minimum_size = Vector2(40, 40)
	ring.pivot_offset = Vector2(20, 20)
	ring.position = world_pos - Vector2(20, 20)
	# Add to root so it renders on top of the game world.
	get_tree().root.add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(3.5, 3.5), 1.2)
	tween.tween_property(ring, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(ring.queue_free)

@rpc("any_peer", "call_remote", "reliable")
func _coop_sync_ping(pos_x: float, pos_y: float) -> void:
	_spawn_ping_effect(Vector2(pos_x, pos_y), false)
