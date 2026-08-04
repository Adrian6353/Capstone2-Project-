extends CanvasLayer

var hp_bar
var _hp_max: int = 100
var _hp_numeric_label: Label = null
var _hp_bar_tween: Tween = null
var money_label
var partner_gold_label: Label = null   # co-op only: shows partner's gold
var tower_buttons = {}
var help_visible = false
var card_collection_panel = null
var card_count_labels = {}
var card_btn_progress_labels = {}

# ── Card Cooldown ──────────────────────────────────────────────────────────
const CARD_COOLDOWN_DURATION: float = 12.0
var _card_cooldowns: Dictionary = {}    # {tower_name: seconds_remaining}
var _cooldown_overlays: Dictionary = {} # {tower_name: ColorRect}
var _cooldown_labels: Dictionary = {}   # {tower_name: Label}

# ── Ready-Up ───────────────────────────────────────────────────────────────
var _ready_button_ref: Button = null    # cached wave/ready button

# ── Ping ───────────────────────────────────────────────────────────────────
var _ping_button_ref: Button = null

# ── UI Feedback ────────────────────────────────────────────────────────────
var _prev_money: int = 0                # for detecting gold gains
var _wave_pulse_tween: Tween = null     # looping pulse on wave button
var _speed_badge: Label = null          # "2×" overlay near speed button
var _build_indicator: Label = null      # "📦 Placing: X" bar
var _vignette_node: ColorRect = null    # low-HP red border
var _vignette_tween: Tween = null       # pulsing vignette tween
var _low_hp_active: bool = false        # vignette shown?

func _ready() -> void:
	call_deferred("initialize_hp_bar")
	call_deferred("initialize_money_label")
	call_deferred("initialize_control_button_tooltips")
	call_deferred("_init_towers_normal")
	if GameData.game_mode == "card_hunt":
		call_deferred("_create_card_collection_panel")
	# Story mode: attach the quest HUD overlay.
	if GameData.selected_chapter >= 1 and GameData.selected_map_index >= 1:
		call_deferred("_add_quest_hud")
	# Dev mode: attach the developer HUD overlay.
	if GameData.dev_mode_enabled:
		call_deferred("_add_dev_hud")
	# Co-op: role badge and ping button.
	if GameData.is_coop:
		call_deferred("_add_role_badge")
		call_deferred("add_ping_button")

func _process(delta: float) -> void:
	_update_cooldowns(delta)

func _add_quest_hud() -> void:
	var hud_scene := load("res://Scenes/UIScenes/QuestHUD.tscn")
	if hud_scene:
		add_child(hud_scene.instantiate())

func _add_dev_hud() -> void:
	var hud_scene := load("res://Scenes/UIScenes/DevHUD.tscn")
	if hud_scene:
		add_child(hud_scene.instantiate())

func initialize_hp_bar() -> void:
	hp_bar = get_node_or_null("HUD/InfoBar/H/PlayerHPBar")
	if hp_bar == null:
		return
	hp_bar.max_value = 100
	hp_bar.value = 100
	_hp_max = 100
	# Add numeric HP label if not already present
	var info_h = get_node_or_null("HUD/InfoBar/H")
	if info_h and not info_h.has_node("HPNumeric"):
		_hp_numeric_label = Label.new()
		_hp_numeric_label.name = "HPNumeric"
		_hp_numeric_label.text = "100/100"
		_hp_numeric_label.add_theme_font_size_override("font_size", 16)
		_hp_numeric_label.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_CREAM)
		_hp_numeric_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hp_numeric_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var hp_bar_idx: int = hp_bar.get_index()
		info_h.add_child(_hp_numeric_label)
		info_h.move_child(_hp_numeric_label, hp_bar_idx + 1)
	else:
		_hp_numeric_label = info_h.get_node_or_null("HPNumeric") if info_h else null
	update_health_bar(100)

func initialize_money_label() -> void:
	money_label = get_node_or_null("HUD/InfoBar/H/GoldAmount")
	if money_label == null:
		print("Warning: GoldAmount label not found in UI")
		return
	update_money_display(GameData.current_money)
	# Co-op: add a second label showing the partner's gold.
	if GameData.is_coop:
		var info_h = get_node_or_null("HUD/InfoBar/H")
		if info_h:
			var sep = Label.new()
			sep.text = "  |  P2: "
			sep.add_theme_font_size_override("font_size", 32)
			sep.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
			sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			info_h.add_child(sep)
			partner_gold_label = Label.new()
			partner_gold_label.text = str(GameData.partner_gold)
			partner_gold_label.add_theme_font_size_override("font_size", 32)
			partner_gold_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
			partner_gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			info_h.add_child(partner_gold_label)

# ─────────────────────────────────────────────────────────────────────────────
# NORMAL MODE — card bar setup (Lv1 towers only)
# ─────────────────────────────────────────────────────────────────────────────
func _init_towers_normal() -> void:
	var card_bar = get_node_or_null("HUD/CardBar")
	if not card_bar:
		push_warning("UI: CardBar not found — normal mode tower buttons won't load")
		return

	# The scene still contains a legacy placeholder button. Hide every existing
	# card first, then reveal only the player's lootbox-owned tower families.
	for child in card_bar.get_children():
		if child is Control:
			child.visible = false

	# In co-op, only show the local player's role-specific towers.
	var role: int = CoopManager.get_local_player_id() if CoopManager.is_coop_active else 0
	for tower_name in GameData.get_available_towers_normal_mode(role):
		var btn = _get_or_create_tower_btn(tower_name, card_bar)
		if btn:
			_connect_tower_btn(btn, tower_name)
			tower_buttons[tower_name] = btn

	update_tower_affordability(GameData.current_money)

# ─────────────────────────────────────────────────────────────────────────────
# Shared button helpers
# ─────────────────────────────────────────────────────────────────────────────
func _get_or_create_tower_btn(tower_name: String, card_bar: Node) -> Control:
	"""Return the existing card-bar button for *tower_name*, or create one."""
	var btn = card_bar.get_node_or_null(tower_name)
	if not btn:
		btn = create_dynamic_tower_button(tower_name)
		if btn:
			card_bar.add_child(btn)
	if btn:
		btn.visible = true
		update_tower_card_info(btn, tower_name)
	return btn

func _add_card_progress_to_btn(btn: Control, tower_name: String) -> void:
	"""Activate the pre-built CardProgressRow on a tower button (row always exists for layout consistency)."""
	var required = GameData.cards_required_to_build.get(tower_name, 0)
	if required == 0:
		return

	var row = btn.get_node_or_null(
		"PanelContainer/MarginContainer/MainContainer/CardProgressRow")
	if not row:
		return

	var count_lbl = row.get_node_or_null("CardCount")
	if not count_lbl:
		return

	var collected = GameData.get_collected_card_count(tower_name)
	count_lbl.text = str(collected) + "/" + str(required)
	if collected >= required:
		count_lbl.add_theme_color_override("font_color", Color.GOLD)
	else:
		count_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))

	row.modulate.a = 1.0  # make visible now that data is set
	card_btn_progress_labels[tower_name] = count_lbl

func _tower_display_name(tower_type: String) -> String:
	"""Return the human-readable display name for a tower type."""
	var display_names: Dictionary = {
		"PitikKawayan":        "Pitik-Kawayan",
		"SharpenedBamboo":     "Sharpened Bamboo",
		"TwinShooters":        "Twin Shooters",
		"KampilanDefender":    "Kampilan Defender",
		"HeatedBlade":         "Heated Blade",
		"WideSweep":           "Wide Sweep",
		"BawangBallista":      "Bawang Ballista",
		"HeavyCloves":         "Heavy Cloves",
		"SaltTreatedWood":     "Salt Treated Wood",
		"MutyaFocus":          "Mutya Focus",
		"RefractedLight":      "Refracted Light",
		"Intensify":           "Intensify",
		"AgimatMortar":        "Agimat Mortar",
		"GuidedTalismans":     "Guided Talismans",
		"ShrapnelBurst":       "Shrapnel Burst",
		"ParolNgLiwanag":      "Parol ng Liwanag",
		"BrightOil":           "Bright Oil",
		"SearingLight":        "Searing Light",
		"BaleteRootSnare":     "Balete Root-Snare",
		"DeepRoots":           "Deep Roots",
		"ThornyVines":         "Thorny Vines",
		"KidlatWeaver":        "Kidlat Weaver",
		"StaticCharge":        "Static Charge",
		"HighVoltage":         "High Voltage",
		"SibatPiercer":        "Sibat Piercer",
		"IronTipped":          "Iron Tipped",
		"WeightedShafts":      "Weighted Shafts",
		"HabingLiwanagShrine": "Habing Liwanag Shrine",
		"WovenThreads":        "Woven Threads",
		"SanghayasBlessing":   "Sanghayas' Blessing",
	}
	return display_names.get(tower_type, tower_type)

func _connect_tower_btn(btn: Control, tower_name: String) -> void:
	"""Wire all signals on a tower button (idempotent — checks before connecting)."""
	if not btn.is_in_group("build_buttons"):
		btn.add_to_group("build_buttons")
	if not btn.pressed.is_connected(Callable(get_parent(), "initiate_build_mode")):
		btn.pressed.connect(Callable(get_parent(), "initiate_build_mode").bindv([tower_name]))
	if not btn.pressed.is_connected(Callable(AudioManager, "play_ui_sound")):
		btn.pressed.connect(Callable(AudioManager, "play_ui_sound").bindv(["button_click"]))
	if not btn.mouse_entered.is_connected(Callable(self, "_on_tower_mouse_entered")):
		btn.mouse_entered.connect(Callable(self, "_on_tower_mouse_entered").bindv([tower_name]))
	if not btn.mouse_exited.is_connected(Callable(self, "_on_tower_mouse_exited")):
		btn.mouse_exited.connect(Callable(self, "_on_tower_mouse_exited"))

func update_tower_card_info(tower_button: Control, tower_name: String) -> void:
	"""Update tower card display with tower information"""
	var tower_data = GameData.tower_data.get(tower_name, {})
	
	# Update tower name
	var tower_name_label = tower_button.get_node_or_null("PanelContainer/MarginContainer/MainContainer/TowerName")
	if tower_name_label:
		tower_name_label.text = _tower_display_name(tower_name)
	
	# Stats are shown in tooltip only — no stat nodes on the card face any more.
	
	# Update cost
	var cost_amount = tower_button.get_node_or_null("PanelContainer/MarginContainer/MainContainer/CostLabel/CostAmount")
	if cost_amount:
		var cost = tower_data.get("cost", 0)
		cost_amount.text = str(cost)
		cost_amount.add_theme_color_override("font_color", Color.GOLD)
	
	# Apply rarity color to tower name for visual indicator
	var rarity = tower_data.get("rarity", "common")
	var rarity_color = RaritySystem.get_rarity_color(rarity)
	if tower_name_label:
		tower_name_label.add_theme_color_override("font_color", rarity_color)
	
	# Add rarity border styling to the card panel
	var panel_container = tower_button.get_node_or_null("PanelContainer")
	if panel_container:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color(0.07, 0.04, 0.02, 0.88)
		stylebox.border_color = rarity_color
		stylebox.set_border_width_all(2)
		stylebox.set_corner_radius_all(8)
		panel_container.add_theme_stylebox_override("panel", stylebox)

## Create a dynamic tower button for towers not in the scene
func create_dynamic_tower_button(tower_name: String) -> Control:
	"""Generate a compact tower button (icon + cost only). Stats shown on hover tooltip."""
	# Tower texture mapping
	var tower_textures = {
		"PitikKawayan": "res://Assets/Towers/PitikKawayan_Lv1.png",
		"SharpenedBamboo": "res://Assets/Towers/PitikKawayan_Lv2.png",
		"TwinShooters": "res://Assets/Towers/PitikKawayan_Lv3.png",
		"KampilanDefender": "res://Assets/Towers/Kampilan Defender Lv.1.png",
		"HeatedBlade": "res://Assets/Towers/Kampilan Defender Lv.2.png",
		"WideSweep": "res://Assets/Towers/Kampilan Defender Lv.3.png",
		"BawangBallista": "res://Assets/Towers/Lv1 Bawang Ballista.png",
		"HeavyCloves": "res://Assets/Towers/Lvl2 Bawang Ballista.png",
		"SaltTreatedWood": "res://Assets/Towers/Lvl3 Bawang Ballista.png",
		"MutyaFocus": "res://Assets/Towers/Mutya Focus Lv.1.png",
		"RefractedLight": "res://Assets/Towers/Mutya Focus Lv.2.png",
		"Intensify": "res://Assets/Towers/Mutya Focus Lv.3.png",
		"AgimatMortar": "res://Assets/Towers/Agimat Mortar Lv.1.png",
		"GuidedTalismans": "res://Assets/Towers/Agimat Mortar Lv.2.png",
		"ShrapnelBurst": "res://Assets/Towers/Agimat Mortar Lv.3.png",
		"ParolNgLiwanag": "res://Assets/Towers/Lvl1 Parol ng Liwanag.png",
		"BrightOil": "res://Assets/Towers/Lvl2 Parol ng liwanag.png",
		"SearingLight": "res://Assets/Towers/Lvl 3 Parol Ng Liwanag.png",
		"BaleteRootSnare": "res://Assets/Towers/Lv.1 Balete Root-Snare.png",
		"DeepRoots": "res://Assets/Towers/Lv.2 Balete Root-Snare.png",
		"ThornyVines": "res://Assets/Towers/Lv.3 Balete Root-Snare.png",
		"KidlatWeaver": "res://Assets/Towers/Kidlat Weaver Lv1.png",
		"StaticCharge": "res://Assets/Towers/Kidlat Weaver Lv2.png",
		"HighVoltage": "res://Assets/Towers/Kidlat Weaver Lv3.png",
		"SibatPiercer": "res://Assets/Towers/Sibat Piercer Lv.1.png",
		"IronTipped": "res://Assets/Towers/Sibat Piercer Lv.2.png",
		"WeightedShafts": "res://Assets/Towers/Sibat Piercer Lv.3.png",
		"HabingLiwanagShrine": "res://Assets/Towers/HabingLiwanagShrine Lv.1.png",
		"WovenThreads": "res://Assets/Towers/HabingLiwanagShrine Lv.2.png",
		"SanghayasBlessing": "res://Assets/Towers/HabingLiwanagShrine Lv.3.png",
	}

	var td = GameData.tower_data.get(tower_name, {})
	var tower_texture = load(tower_textures.get(tower_name, "res://Assets/Towers/Pitik_Kawayan_Lv1.png"))
	var rarity = td.get("rarity", "common")
	var rarity_color = RaritySystem.get_rarity_color(rarity)

	# Card dimensions — every card is exactly this size
	# Card: vertical layout — icon on top, name + cost centred below.
	# 96×130 gives full-width text so 12 px is legible on mobile.
	const CARD_W  := 96
	const CARD_H  := 130
	const ICON_SZ := 68

	# ── Root button ──────────────────────────────────────────
	var button = Button.new()
	button.name = tower_name
	button.custom_minimum_size = Vector2(CARD_W, CARD_H)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	button.flat = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fallback tooltip (shown by engine when TooltipManager is absent)
	button.tooltip_text = "%s\nDMG: %s  ROF: %s\nRNG: %s  Cost: %s" % [
		_tower_display_name(tower_name),
		str(td.get("damage", 0)), str(td.get("rof", 0)),
		str(td.get("range", 0)),  str(td.get("cost", 0))
	]

	# ── Rarity-bordered panel ─────────────────────────────────
	var panel = PanelContainer.new()
	panel.name = "PanelContainer"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.07, 0.04, 0.02, 0.88)
	stylebox.border_color = rarity_color
	stylebox.set_border_width_all(2)
	stylebox.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", stylebox)

	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left",   5)
	margin.add_theme_constant_override("margin_top",    5)
	margin.add_theme_constant_override("margin_right",  5)
	margin.add_theme_constant_override("margin_bottom", 5)

	# ── Vertical layout: icon → name → cost ──────────────────
	var vbox = VBoxContainer.new()
	vbox.name = "MainContainer"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)

	# Tower icon — centred at top
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.texture = tower_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_SZ, ICON_SZ)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	# Tower name — full card width, auto-wraps, 12 px = readable on phone
	var tower_name_label = Label.new()
	tower_name_label.name = "TowerName"
	tower_name_label.text = _tower_display_name(tower_name)
	tower_name_label.add_theme_font_size_override("font_size", 12)
	tower_name_label.add_theme_color_override("font_color", rarity_color)
	tower_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tower_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(tower_name_label)

	# Cost row: gold icon + amount, centred
	var cost_row = HBoxContainer.new()
	cost_row.name = "CostLabel"
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 3)

	var cost_icon = TextureRect.new()
	cost_icon.name = "GoldIcon"
	cost_icon.texture = load("res://Assets/UI/Art/Gold_1.png")
	cost_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	cost_icon.custom_minimum_size = Vector2(16, 16)
	cost_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_row.add_child(cost_icon)

	var cost_label = Label.new()
	cost_label.name = "CostAmount"
	cost_label.text = str(td.get("cost", 0))
	cost_label.add_theme_font_size_override("font_size", 15)
	cost_label.add_theme_color_override("font_color", Color.GOLD)
	cost_row.add_child(cost_label)
	vbox.add_child(cost_row)

	# Cards progress row — hidden until _add_card_progress_to_btn activates it.
	# Always built so every card has identical structure (modulate.a=0 preserves layout space).
	var cards_row = HBoxContainer.new()
	cards_row.name = "CardProgressRow"
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 2)
	cards_row.modulate.a = 0.0

	var cards_lbl = Label.new()
	cards_lbl.text = "🃏 "
	cards_lbl.add_theme_font_size_override("font_size", 11)
	cards_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	cards_row.add_child(cards_lbl)

	var count_lbl = Label.new()
	count_lbl.name = "CardCount"
	count_lbl.text = "0/0"
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	cards_row.add_child(count_lbl)
	vbox.add_child(cards_row)

	margin.add_child(vbox)
	panel.add_child(margin)
	button.add_child(panel)
	button.clip_contents = true  # visually clip any overflow without affecting button size

	return button

func _create_card_collection_panel() -> void:
	"""Create a scrollable, mobile-friendly card collection panel for card hunt mode."""
	# ── Toggle button (always visible at top-right) ──
	var toggle_btn = Button.new()
	toggle_btn.name = "CardPanelToggle"
	toggle_btn.text = "Cards ▶"
	toggle_btn.custom_minimum_size = Vector2(110, 44)
	toggle_btn.anchor_left   = 1.0
	toggle_btn.anchor_top    = 0.0
	toggle_btn.anchor_right  = 1.0
	toggle_btn.anchor_bottom = 0.0
	toggle_btn.offset_left   = -115
	toggle_btn.offset_top    = 120  # below the InfoBar
	toggle_btn.offset_right  = -5
	toggle_btn.offset_bottom = 168
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.08, 0.08, 0.18, 0.92)
	btn_style.border_color = Color.GOLD
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	toggle_btn.add_theme_stylebox_override("normal", btn_style)
	toggle_btn.add_theme_stylebox_override("hover", btn_style)
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.22, 0.16, 0.04, 0.92)
	pressed_style.border_color = Color.GOLD
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(6)
	toggle_btn.add_theme_stylebox_override("pressed", pressed_style)
	toggle_btn.add_theme_color_override("font_color", Color.GOLD)
	add_child(toggle_btn)

	# ── Scrollable panel (hidden by default, opened by toggle) ──
	var panel = PanelContainer.new()
	panel.name = "CardCollectionPanel"
	panel.visible = false
	panel.anchor_left   = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_right  = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = -320
	panel.offset_top    = 174  # below the toggle button
	panel.offset_right  = -5
	panel.offset_bottom = -125  # stop above the card bar
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.12, 0.93)
	panel_style.border_color = Color(0.7, 0.55, 0.1, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)

	# Margin
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_top",    6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	# Outer VBox: title + separator + scroll
	var outer_vbox = VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(outer_vbox)

	var title = Label.new()
	title.text = "CARDS COLLECTED"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)
	outer_vbox.add_child(HSeparator.new())

	# ScrollContainer fills remaining space
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(vbox)

	# Rarity colours shared across the loop
	var rarity_colors_map = {
		"common":    Color(0.3,  1.0,  0.3),
		"rare":      Color(0.4,  0.7,  1.0),
		"legendary": Color(1.0,  0.65, 0.0)
	}
	var rarity_headers = {
		"common":    "── COMMON ──",
		"rare":      "── RARE ──",
		"legendary": "── LEGENDARY ──"
	}

	# Build entries grouped by rarity then by family
	for rarity in ["common", "rare", "legendary"]:
		# Spacer before section
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(spacer)

		var rarity_lbl = Label.new()
		rarity_lbl.text = rarity_headers[rarity]
		rarity_lbl.add_theme_font_size_override("font_size", 13)
		rarity_lbl.add_theme_color_override("font_color", rarity_colors_map[rarity])
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rarity_lbl)

		for fam_name in GameData.tower_families.keys():
			var fam = GameData.tower_families[fam_name]
			if fam["rarity"] != rarity:
				continue

			vbox.add_child(HSeparator.new())

			var fam_lbl = Label.new()
			fam_lbl.text = _tower_display_name(fam_name)
			fam_lbl.add_theme_font_size_override("font_size", 11)
			fam_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
			vbox.add_child(fam_lbl)

			for tower_type in fam["towers"]:
				if not GameData.tower_data.has(tower_type):
					continue

				var row = HBoxContainer.new()
				row.add_theme_constant_override("separation", 4)

				var tower_lbl = Label.new()
				tower_lbl.text = "  " + _tower_display_name(tower_type)
				tower_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				tower_lbl.add_theme_font_size_override("font_size", 11)
				tower_lbl.add_theme_color_override("font_color", rarity_colors_map[rarity])
				row.add_child(tower_lbl)

				var count_lbl = Label.new()
				count_lbl.custom_minimum_size.x = 52
				count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				count_lbl.add_theme_font_size_override("font_size", 11)
				var required = GameData.cards_required_to_build.get(tower_type, 0)
				var collected = GameData.get_collected_card_count(tower_type)
				if required == 0:
					count_lbl.text = "FREE"
					count_lbl.add_theme_color_override("font_color", Color.GOLD)
				else:
					count_lbl.text = str(collected) + "/" + str(required)
					if collected >= required:
						count_lbl.add_theme_color_override("font_color", Color.GOLD)
				row.add_child(count_lbl)
				vbox.add_child(row)
				card_count_labels[tower_type] = count_lbl

	add_child(panel)
	card_collection_panel = panel
func initialize_control_button_tooltips() -> void:
	# Connect hover events for game control buttons
	var pause_button = get_node_or_null("HUD/GameControls/MarginContainer/PausePlay")
	var speed_button = get_node_or_null("HUD/GameControls/MarginContainer2/SpeedUp")
	var help_button = get_node_or_null("HUD/GameControls/MarginContainer3/HelpButton")
	var menu_button = get_node_or_null("HUD/GameControls/MarginContainer4/PauseMenu")

	# Force ALWAYS process mode so buttons work while game is paused
	for btn in [pause_button, speed_button, help_button, menu_button]:
		if btn:
			btn.process_mode = Node.PROCESS_MODE_ALWAYS

	if pause_button:
		if not pause_button.pressed.is_connected(_on_pause_play_pressed):
			pause_button.pressed.connect(_on_pause_play_pressed)
		if not pause_button.mouse_entered.is_connected(_on_pause_button_entered):
			pause_button.mouse_entered.connect(_on_pause_button_entered)
		if not pause_button.mouse_exited.is_connected(_on_button_exited):
			pause_button.mouse_exited.connect(_on_button_exited)

	if speed_button:
		if not speed_button.pressed.is_connected(_on_speed_up_pressed):
			speed_button.pressed.connect(_on_speed_up_pressed)
		if not speed_button.mouse_entered.is_connected(_on_speed_button_entered):
			speed_button.mouse_entered.connect(_on_speed_button_entered)
		if not speed_button.mouse_exited.is_connected(_on_button_exited):
			speed_button.mouse_exited.connect(_on_button_exited)

	if help_button:
		if not help_button.pressed.is_connected(_on_help_button_pressed):
			help_button.pressed.connect(_on_help_button_pressed)
		if not help_button.mouse_entered.is_connected(_on_help_button_entered):
			help_button.mouse_entered.connect(_on_help_button_entered)
		if not help_button.mouse_exited.is_connected(_on_button_exited):
			help_button.mouse_exited.connect(_on_button_exited)
		_style_help_button(help_button)

	if menu_button:
		if not menu_button.pressed.is_connected(_on_menu_button_pressed):
			menu_button.pressed.connect(_on_menu_button_pressed)
		if not menu_button.mouse_entered.is_connected(_on_menu_button_entered):
			menu_button.mouse_entered.connect(_on_menu_button_entered)
		if not menu_button.mouse_exited.is_connected(_on_button_exited):
			menu_button.mouse_exited.connect(_on_button_exited)
	
	# Connect hover tooltips for HUD info elements
	var gold_icon = get_node_or_null("HUD/InfoBar/H/GoldIcon")
	var gold_label = get_node_or_null("HUD/InfoBar/H/GoldAmount")
	var health_bar = get_node_or_null("HUD/InfoBar/H/PlayerHPBar")
	var health_icon = get_node_or_null("HUD/InfoBar/H/Health")
	var wave_preview = get_node_or_null("HUD/WavePreviewPanel")
	var start_wave_btn = get_node_or_null("HUD/WaveBar/StartWaveButton")
	
	for node in [gold_icon, gold_label]:
		if node:
			node.mouse_entered.connect(_on_gold_display_entered)
			node.mouse_exited.connect(_on_button_exited)
			if node is TextureRect:
				node.mouse_filter = Control.MOUSE_FILTER_STOP
	
	for node in [health_bar, health_icon]:
		if node:
			node.mouse_entered.connect(_on_health_bar_entered)
			node.mouse_exited.connect(_on_button_exited)
			if node is TextureRect:
				node.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if wave_preview:
		wave_preview.mouse_entered.connect(_on_wave_preview_entered)
		wave_preview.mouse_exited.connect(_on_button_exited)
	
	if start_wave_btn:
		start_wave_btn.mouse_entered.connect(_on_start_wave_entered)
		start_wave_btn.mouse_exited.connect(_on_button_exited)

func set_tower_preview(_tower_type, _mouse_position):
	pass  # Preview handled in GameScene.gd world space

func update_tower_preview(_new_position, _color):
	pass  # Preview handled in GameScene.gd world space

func _on_pause_play_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	if get_parent().build_mode:
		get_parent().cancel_build_mode()

	if get_tree().paused:
		get_tree().paused = false
	else:
		get_tree().paused = true

func _on_speed_up_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	if get_parent().build_mode:
		get_parent().cancel_build_mode()

	if Engine.time_scale == 2.0:
		Engine.time_scale = 1.0
		if is_instance_valid(_speed_badge):
			_speed_badge.visible = false
	else:
		Engine.time_scale = 2.0
		_show_speed_badge()

func update_health_bar(base_health):
	if hp_bar == null:
		hp_bar = get_node_or_null("HUD/InfoBar/H/PlayerHPBar")
		if hp_bar == null:
			return
	
	if _hp_bar_tween:
		_hp_bar_tween.kill()
	_hp_bar_tween = hp_bar.create_tween()
	_hp_bar_tween.tween_property(hp_bar, "value", base_health, 0.1)

	if base_health >= 60:
		hp_bar.tint_progress = Color("3cc510")
	elif base_health <= 60 and base_health >= 25:
		hp_bar.tint_progress = Color("e1be32")
	else:
		hp_bar.tint_progress = Color("e11e1e")
	
	# Update numeric HP label
	if _hp_numeric_label:
		_hp_numeric_label.text = "%d/%d" % [int(base_health), _hp_max]
		if base_health >= 60:
			_hp_numeric_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.35))
		elif base_health >= 25:
			_hp_numeric_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			_hp_numeric_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.22))
	
	# Low-HP vignette
	if base_health < 25 and not _low_hp_active:
		_show_low_hp_vignette()
	elif base_health >= 25 and _low_hp_active:
		_hide_low_hp_vignette()

func update_money_display(amount: int) -> void:
	if money_label == null:
		money_label = get_node_or_null("HUD/InfoBar/H/GoldAmount")
		if money_label == null:
			return
	
	# Float a +N label when gold is gained.
	if amount > _prev_money and _prev_money > 0:
		_float_gold_gain(amount - _prev_money)
	elif amount < _prev_money:
		# Flash label red briefly on spend.
		var t: Tween = money_label.create_tween()
		t.tween_property(money_label, "modulate", Color(1.0, 0.35, 0.35), 0.08)
		t.tween_property(money_label, "modulate", Color.WHITE, 0.22)
	_prev_money = amount
	
	money_label.text = str(amount)
	update_tower_affordability(amount)

func update_partner_gold_display(amount: int) -> void:
	if partner_gold_label == null:
		return
	partner_gold_label.text = str(amount)

func update_tower_affordability(current_money: int) -> void:
	_update_affordability_normal(current_money)

# ─────────────────────────────────────────────────────────────────────────────
# NORMAL MODE — affordability (gold only, no card check)
# ─────────────────────────────────────────────────────────────────────────────
func _update_affordability_normal(current_money: int) -> void:
	for tower_name in tower_buttons.keys():
		var btn = tower_buttons[tower_name]
		if not is_instance_valid(btn):
			continue
		var cost = GameData.tower_data[tower_name].get("cost", 0)
		var has_cost_label = btn.get_node_or_null(
			"PanelContainer/MarginContainer/MainContainer/CostLabel") != null
		var can_afford = current_money >= cost
		var on_cd = is_card_on_cooldown(tower_name)
		if has_cost_label:
			if can_afford and not on_cd:
				btn.modulate = Color.WHITE
				btn.disabled = false
			else:
				btn.modulate = Color(0.5, 0.5, 0.5, 1)
				btn.disabled = true

func update_tower_availability_for_wave(new_wave: int) -> void:
	"""Refresh lootbox-owned tower visibility when the wave changes."""
	GameData.current_wave = new_wave

	# Filter by role in co-op, show all in solo.
	var role: int = CoopManager.get_local_player_id() if CoopManager.is_coop_active else 0
	var available_towers = GameData.get_available_towers_normal_mode(role)

	for tower_name in GameData.tower_data.keys():
		var tower_button = get_node_or_null("HUD/CardBar/" + tower_name)
		if tower_button:
			var is_available = tower_name in available_towers
			tower_button.visible = is_available

	# Update affordability display for current money
	update_tower_affordability(GameData.current_money)

func show_locked_tower_message(tower_type: String) -> void:
	var msg := Label.new()
	msg.text = "%s is locked. Obtain it from a lootbox first." % _tower_display_name(tower_type)
	msg.add_theme_font_size_override("font_size", 19)
	msg.add_theme_color_override("font_color", Color(0.75, 0.65, 1.0))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vr := get_viewport().get_visible_rect()
	msg.position = Vector2(vr.size.x * 0.5 - 220, vr.size.y - 230)
	add_child(msg)
	var tween := msg.create_tween()
	tween.tween_property(msg, "position:y", msg.position.y - 36, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.1)
	tween.tween_property(msg, "modulate:a", 0.0, 0.35)
	tween.tween_callback(msg.queue_free)

func show_insufficient_funds_message(tower_type: String, cost: int) -> void:
	var shortfall: int = cost - GameData.current_money
	var msg := Label.new()
	msg.text = "Not enough gold!  (Need %d more)" % shortfall
	msg.add_theme_font_size_override("font_size", 19)
	msg.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	msg.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	msg.add_theme_constant_override("shadow_offset_x", 1)
	msg.add_theme_constant_override("shadow_offset_y", 1)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vr := get_viewport().get_visible_rect()
	msg.position = Vector2(vr.size.x * 0.5 - 160, vr.size.y - 230)
	add_child(msg)
	var t := msg.create_tween()
	t.tween_property(msg, "position:y", msg.position.y - 36, 0.25).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.9)
	t.tween_property(msg, "modulate:a", 0.0, 0.35)
	t.tween_callback(msg.queue_free)

func update_wave_preview(wave_number: int) -> void:
	"""Update the wave preview panel to show next wave info"""
	var wave_label = get_node_or_null("HUD/WavePreviewPanel/MarginContainer/VBoxContainer/WaveLabel")
	var enemy_label = get_node_or_null("HUD/WavePreviewPanel/MarginContainer/VBoxContainer/EnemyPreview")
	
	if not wave_label or not enemy_label:
		print("[WavePreview] ERROR: Could not find wave preview labels!")
		return
	
	# Get the wave data for this wave
	var wave_data = GameData.retrieve_wave_data(GameData.selected_player_count, wave_number)
	
	# Determine if this is a boss wave
	var is_boss = GameData.is_boss_wave(wave_number)
	var boss_indicator = " (BOSS)" if is_boss else ""
	
	# Update wave label with current wave number
	wave_label.text = "Wave: %d%s" % [wave_number + 1, boss_indicator]
	
	# Count enemies and group them by type
	var enemy_counts: Dictionary = {}
	for enemy_entry in wave_data:
		var enemy_type = enemy_entry[0]
		if enemy_type in enemy_counts:
			enemy_counts[enemy_type] += 1
		else:
			enemy_counts[enemy_type] = 1
	
	# Build a readable display of enemies (max 3 lines to fit in the preview)
	var enemy_display = ""
	var line_count = 0
	for enemy_type in enemy_counts.keys():
		if line_count > 0:
			enemy_display += "\n"
		var count = enemy_counts[enemy_type]
		if count > 1:
			enemy_display += "%dx %s" % [count, enemy_type]
		else:
			enemy_display += "%s" % [enemy_type]
		line_count += 1
		if line_count >= 3:
			break
	
	enemy_label.text = enemy_display

# Tooltip handlers
func _on_tower_mouse_entered(tower_name: String) -> void:
	if not GameData.tower_data.has(tower_name):
		return
	# Show tooltip if TooltipManager is available
	if get_tree().root.has_node("TooltipManager"):
		var tooltip_manager = get_tree().root.get_node("TooltipManager")
		tooltip_manager.show_tooltip(tower_name, get_viewport().get_mouse_position())

func _on_tower_mouse_exited() -> void:
	# Hide tooltip if TooltipManager is available
	if get_tree().root.has_node("TooltipManager"):
		var tooltip_manager = get_tree().root.get_node("TooltipManager")
		tooltip_manager.hide_tooltip()

func _on_pause_button_entered() -> void:
	if get_tree().root.has_node("TooltipManager"):
		var tooltip_manager = get_tree().root.get_node("TooltipManager")
		var pause_button = get_node_or_null("HUD/GameControls/MarginContainer/PausePlay")
		if pause_button:
			tooltip_manager.show_tooltip("PauseButton", pause_button.global_position)

func _on_speed_button_entered() -> void:
	if get_tree().root.has_node("TooltipManager"):
		var tooltip_manager = get_tree().root.get_node("TooltipManager")
		var speed_button = get_node_or_null("HUD/GameControls/MarginContainer2/SpeedUp")
		if speed_button:
			tooltip_manager.show_tooltip("SpeedUpButton", speed_button.global_position)

func _on_help_button_entered() -> void:
	if get_tree().root.has_node("TooltipManager"):
		var tooltip_manager = get_tree().root.get_node("TooltipManager")
		var help_button = get_node_or_null("HUD/GameControls/MarginContainer3/HelpButton")
		if help_button:
			tooltip_manager.show_tooltip("HelpButton", help_button.global_position)

func _on_button_exited() -> void:
	# Hide tooltip if TooltipManager is available
	if get_tree().root.has_node("TooltipManager"):
		var tooltip_manager = get_tree().root.get_node("TooltipManager")
		tooltip_manager.hide_tooltip()

func _on_menu_button_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_click")
	show_pause_menu()

func _on_menu_button_entered() -> void:
	if AudioManager:
		AudioManager.play_ui_sound("button_hover")
	if get_tree().root.has_node("TooltipManager"):
		var tooltip_manager = get_tree().root.get_node("TooltipManager")
		var menu_button = get_node_or_null("HUD/GameControls/MarginContainer4/PauseMenu")
		if menu_button:
			tooltip_manager.show_tooltip("MenuButton", menu_button.global_position)

func _on_gold_display_entered() -> void:
	if get_tree().root.has_node("TooltipManager"):
		var tooltip_manager = get_tree().root.get_node("TooltipManager")
		tooltip_manager.show_tooltip("GoldDisplay", get_viewport().get_mouse_position())

func _on_health_bar_entered() -> void:
	if get_tree().root.has_node("TooltipManager"):
		var tooltip_manager = get_tree().root.get_node("TooltipManager")
		tooltip_manager.show_tooltip("HealthBar", get_viewport().get_mouse_position())

func _on_wave_preview_entered() -> void:
	if get_tree().root.has_node("TooltipManager"):
		var tooltip_manager = get_tree().root.get_node("TooltipManager")
		tooltip_manager.show_tooltip("WavePreview", get_viewport().get_mouse_position())

func _on_start_wave_entered() -> void:
	if get_tree().root.has_node("TooltipManager"):
		var tooltip_manager = get_tree().root.get_node("TooltipManager")
		tooltip_manager.show_tooltip("StartWaveButton", get_viewport().get_mouse_position())

func show_pause_menu() -> void:
	"""Display the pause menu and pause the game"""
	# Prevent creating a second pause menu if one already exists
	if get_tree().root.has_node("PauseMenu"):
		return
	# Load and instantiate the pause menu
	var pause_menu_scene = load("res://Scenes/UIScenes/pause_menu.tscn")
	if pause_menu_scene:
		var pause_menu = pause_menu_scene.instantiate()
		# Add to root so it covers the entire screen
		get_tree().root.add_child(pause_menu)
		# Pause the game after adding the menu
		get_tree().paused = true
	else:
		print("ERROR: Failed to load pause_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	"""Handle ESC key to open pause menu"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Don't open menu if already paused, if menu is already open, or if in build mode
			if not get_tree().paused and not get_parent().build_mode:
				if AudioManager:
					AudioManager.play_ui_sound("button_click")
				show_pause_menu()
				get_tree().root.set_input_as_handled()

# Help button handler
func _on_help_button_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	_show_tutorial()

func _show_tutorial() -> void:
	var tut = load("res://Scenes/UIScenes/tutorial_popup.tscn").instantiate()
	get_parent().add_child(tut)
	tut.start_tutorial()

func _style_help_button(btn: Button) -> void:
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.2, 0.35, 0.9)
	normal_style.border_color = Color(0.85, 0.7, 0.2, 0.7)
	normal_style.set_border_width(SIDE_LEFT, 2)
	normal_style.set_border_width(SIDE_RIGHT, 2)
	normal_style.set_border_width(SIDE_TOP, 2)
	normal_style.set_border_width(SIDE_BOTTOM, 2)
	normal_style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.22, 0.3, 0.5, 0.95)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.3, 0.4, 0.6, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.5))

func get_help_text() -> String:
	return """
TOWER DEFENSE - IN-GAME HELP

CONTROLS:
• SPACE - Pause/Resume game
• T/FastForward Button - Speed up (2x)
• ESC - Cancel tower placement
• ENTER - Confirm tower placement

BUILDING TOWERS:
1. Click a tower from the card bar (left)
2. Green range = valid, Red = invalid
3. Press ENTER to build, ESC to cancel

STRATEGY TIPS:
• Spread towers for better coverage
• Build in high-traffic areas
• Save gold for later waves
• All towers auto-fire at enemies

GAME INFO:
• Base Health: 100
• Enemy reaches base = damage taken
• Gold earned from defeating enemies
• %d waves total to complete game

Press [?] again to close
""" % GameData.selected_wave_count

func show_card_collected(tower_type: String, rarity: String = "common") -> void:
	"""Display an animated notification when a card is collected"""
	# Create animated card drop notification
	var card_notification = Control.new()
	card_notification.name = "CardDropNotification"
	card_notification.custom_minimum_size = Vector2(200, 80)
	
	# Background panel
	var bg = PanelContainer.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	card_notification.add_child(bg)
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	bg.add_child(vbox)
	
	# Rarity label
	var rarity_label = Label.new()
	rarity_label.text = rarity.to_upper()
	var color = GameData.get_rarity_color(rarity)
	rarity_label.add_theme_color_override("font_color", color)
	rarity_label.add_theme_font_size_override("font_size", 16)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rarity_label)
	
	# Tower type label
	var tower_label = Label.new()
	tower_label.text = "Card: " + tower_type
	tower_label.add_theme_color_override("font_color", Color.WHITE)
	tower_label.add_theme_font_size_override("font_size", 20)
	tower_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tower_label)
	
	# Position: top right area
	var start_pos = Vector2(get_viewport().get_visible_rect().size.x - 220, 120)
	card_notification.position = start_pos
	
	add_child(card_notification)
	
	# Animate the notification: pop in, stay, then fade out
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale animation (pop in)
	var scale_tween = create_tween()
	scale_tween.set_trans(Tween.TRANS_BACK)
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(card_notification, "scale", Vector2(1.0, 1.0), 0.3)
	card_notification.scale = Vector2(0.5, 0.5)
	
	# Hold for 2 seconds, then fade and move up
	await get_tree().create_timer(2.0).timeout
	
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(card_notification, "modulate:a", 0.0, 0.5)
	fade_tween.tween_property(card_notification, "position:y", start_pos.y - 50, 0.5)
	
	await fade_tween.finished
	if is_instance_valid(card_notification):
		card_notification.queue_free()
	
	# Update the card collection panel
	update_card_collection_display(tower_type)

func update_card_collection_display(tower_type: String) -> void:
	"""Update the card collection count label for the given tower."""
	if not card_count_labels.has(tower_type):
		return
	var count_lbl = card_count_labels[tower_type]
	if not is_instance_valid(count_lbl):
		return

	var new_count = GameData.get_collected_card_count(tower_type)
	var required  = GameData.cards_required_to_build.get(tower_type, 0)
	if required == 0:
		count_lbl.text = "FREE"
		count_lbl.add_theme_color_override("font_color", Color.GOLD)
	else:
		count_lbl.text = str(new_count) + "/" + str(required)
		if new_count >= required:
			count_lbl.add_theme_color_override("font_color", Color.GOLD)

	# Small bounce on the row
	var row = count_lbl.get_parent()
	if is_instance_valid(row):
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BOUNCE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(row, "scale", Vector2(1.05, 1.05), 0.1)
		tween.tween_property(row, "scale", Vector2(1.0, 1.0), 0.1)

	update_tower_affordability(GameData.current_money)

	# Also refresh the inline card progress label on the tower button
	if card_btn_progress_labels.has(tower_type):
		var btn_lbl = card_btn_progress_labels[tower_type]
		if is_instance_valid(btn_lbl):
			var btn_count = GameData.get_collected_card_count(tower_type)
			var btn_req   = GameData.cards_required_to_build.get(tower_type, 0)
			btn_lbl.text = str(btn_count) + "/" + str(btn_req)
			if btn_count >= btn_req:
				btn_lbl.add_theme_color_override("font_color", Color.GOLD)

func show_tower_sold_message(_tower_type: String, refund_amount: int) -> void:
	"""Display an animated notification when a tower is sold"""
	# Create animated sell notification
	var sell_notification = Control.new()
	sell_notification.name = "TowerSoldNotification"
	sell_notification.custom_minimum_size = Vector2(220, 80)
	
	# Background panel
	var bg = PanelContainer.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	sell_notification.add_child(bg)
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	bg.add_child(vbox)
	
	# Title label
	var title_label = Label.new()
	title_label.text = "TOWER SOLD"
	title_label.add_theme_color_override("font_color", Color.GOLD)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# Refund amount label
	var refund_label = Label.new()
	refund_label.text = "+" + str(refund_amount) + " Gold"
	refund_label.add_theme_color_override("font_color", Color.YELLOW)
	refund_label.add_theme_font_size_override("font_size", 18)
	refund_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(refund_label)
	
	# Position: center bottom area
	var viewport_rect = get_viewport().get_visible_rect()
	var start_pos = Vector2(viewport_rect.size.x / 2 - 110, viewport_rect.size.y - 120)
	sell_notification.position = start_pos
	
	add_child(sell_notification)
	
	# Animate the notification: pop in, stay, then fade out
	var scale_tween = create_tween()
	scale_tween.set_trans(Tween.TRANS_BACK)
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(sell_notification, "scale", Vector2(1.0, 1.0), 0.3)
	sell_notification.scale = Vector2(0.5, 0.5)
	
	# Hold for 2 seconds, then fade and move up
	await get_tree().create_timer(2.0).timeout
	
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(sell_notification, "modulate:a", 0.0, 0.5)
	fade_tween.tween_property(sell_notification, "position:y", start_pos.y - 50, 0.5)
	
	await fade_tween.finished
	if is_instance_valid(sell_notification):
		sell_notification.queue_free()

# =============================================================================
# CARD COOLDOWN SYSTEM
# =============================================================================

func start_card_cooldown(tower_name: String) -> void:
	"""Begin a cooldown on the named tower card after it is placed."""
	_card_cooldowns[tower_name] = CARD_COOLDOWN_DURATION
	var btn = tower_buttons.get(tower_name)
	if is_instance_valid(btn):
		_ensure_cooldown_overlay(tower_name, btn)
		if _cooldown_overlays.has(tower_name):
			_cooldown_overlays[tower_name].visible = true
		if _cooldown_labels.has(tower_name):
			_cooldown_labels[tower_name].text = str(int(ceil(CARD_COOLDOWN_DURATION))) + "s"
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 1)

func is_card_on_cooldown(tower_name: String) -> bool:
	return _card_cooldowns.has(tower_name) and _card_cooldowns[tower_name] > 0.0

func reset_card_cooldowns() -> void:
	"""Clear all active cooldowns at wave end so cards are ready for the next wave."""
	for tower_name in _card_cooldowns.keys():
		if _cooldown_overlays.has(tower_name) and is_instance_valid(_cooldown_overlays[tower_name]):
			_cooldown_overlays[tower_name].visible = false
		var btn = tower_buttons.get(tower_name)
		if is_instance_valid(btn):
			btn.disabled = false
			var cost: int = GameData.tower_data[tower_name].get("cost", 0)
			btn.modulate = Color.WHITE if GameData.current_money >= cost else Color(0.5, 0.5, 0.5, 1)
	_card_cooldowns.clear()

func show_cooldown_message(tower_name: String) -> void:
	"""Flash a brief 'Recharging!' notice near the card bar."""
	var remaining: float = _card_cooldowns.get(tower_name, 0.0)
	var msg := Label.new()
	msg.text = "⏳ Recharging! (%ds)" % int(ceil(remaining))
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vr := get_viewport().get_visible_rect()
	msg.position = Vector2(vr.size.x * 0.5 - 120, vr.size.y - 200)
	add_child(msg)
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(msg, "modulate:a", 0.0, 0.4)
	await t.finished
	if is_instance_valid(msg):
		msg.queue_free()

func _ensure_cooldown_overlay(tower_name: String, btn: Button) -> void:
	"""Lazily create the full-card dark overlay + countdown label on a card button."""
	if _cooldown_overlays.has(tower_name) and is_instance_valid(_cooldown_overlays[tower_name]):
		return
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	btn.add_child(overlay)
	_cooldown_overlays[tower_name] = overlay

	var cd_label := Label.new()
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.anchor_right = 1.0
	cd_label.anchor_bottom = 1.0
	cd_label.add_theme_font_size_override("font_size", 22)
	cd_label.add_theme_color_override("font_color", Color.WHITE)
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cd_label)
	_cooldown_labels[tower_name] = cd_label

func _update_cooldowns(delta: float) -> void:
	"""Decrement all active cooldowns each frame and refresh card overlays."""
	var expired: Array = []
	for tower_name in _card_cooldowns.keys():
		_card_cooldowns[tower_name] -= delta
		if _card_cooldowns[tower_name] <= 0.0:
			expired.append(tower_name)
		else:
			# Update countdown display
			if _cooldown_labels.has(tower_name) and is_instance_valid(_cooldown_labels[tower_name]):
				_cooldown_labels[tower_name].text = str(int(ceil(_card_cooldowns[tower_name]))) + "s"
	for tower_name in expired:
		_card_cooldowns.erase(tower_name)
		if _cooldown_overlays.has(tower_name) and is_instance_valid(_cooldown_overlays[tower_name]):
			_cooldown_overlays[tower_name].visible = false
		var btn = tower_buttons.get(tower_name)
		if is_instance_valid(btn):
			btn.disabled = false
			var cost: int = GameData.tower_data[tower_name].get("cost", 0)
			btn.modulate = Color.WHITE if GameData.current_money >= cost else Color(0.5, 0.5, 0.5, 1)
			_flash_card_ready(tower_name, btn)

# =============================================================================
# READY-UP SYSTEM (Co-op only)
# =============================================================================

func update_ready_status(local_ready: bool, partner_ready: bool) -> void:
	"""Update the wave/ready button text to reflect current ready state."""
	# Cache the first wave button we find in the group.
	if not is_instance_valid(_ready_button_ref):
		for btn in get_tree().get_nodes_in_group("wave_buttons"):
			if btn is Button:
				_ready_button_ref = btn
				break
	if not is_instance_valid(_ready_button_ref):
		return
	var count: int = (1 if local_ready else 0) + (1 if partner_ready else 0)
	match count:
		0:
			_ready_button_ref.text = "READY?"
			_ready_button_ref.modulate = Color.WHITE
		1:
			_ready_button_ref.text = "✓ Ready (1/2)\nWaiting…"
			_ready_button_ref.modulate = Color.YELLOW
		2:
			_ready_button_ref.text = "Starting!"
			_ready_button_ref.modulate = Color.GREEN

func reset_ready_button() -> void:
	"""Restore wave button to its default label after wave starts."""
	if is_instance_valid(_ready_button_ref):
		_ready_button_ref.text = "READY?"
		_ready_button_ref.modulate = Color.WHITE

# =============================================================================
# MAP PING SYSTEM (Co-op only)
# =============================================================================

func add_ping_button() -> void:
	"""Create and add the 📍 Ping button to the HUD (co-op only)."""
	if is_instance_valid(_ping_button_ref):
		return
	var btn := Button.new()
	btn.name = "PingButton"
	btn.text = "📍 Ping"
	btn.custom_minimum_size = Vector2(90, 48)
	btn.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.25, 0.45, 0.9)
	style.border_color = Color(0.4, 0.7, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.15, 0.35, 0.6, 0.95)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	# Anchor to bottom-left of HUD
	var hud := get_node_or_null("HUD")
	if hud:
		btn.anchor_left = 0.0
		btn.anchor_top = 1.0
		btn.anchor_right = 0.0
		btn.anchor_bottom = 1.0
		btn.offset_left = 12
		btn.offset_top = -60
		btn.offset_right = 104
		btn.offset_bottom = -12
		hud.add_child(btn)
	_ping_button_ref = btn
	btn.pressed.connect(Callable(get_parent(), "_on_ping_button_pressed"))

func set_ping_button_active(active: bool) -> void:
	"""Highlight ping button while ping mode is on."""
	if not is_instance_valid(_ping_button_ref):
		return
	if active:
		_ping_button_ref.modulate = Color(0.4, 0.8, 1.0)
	else:
		_ping_button_ref.modulate = Color.WHITE

# =============================================================================
# ROLE BADGE (Co-op only)
# =============================================================================

func _add_role_badge() -> void:
	"""Show the local player's role name in the HUD."""
	var hud := get_node_or_null("HUD")
	if not hud:
		return
	var is_host: bool = CoopManager.is_host
	var role_name: String = "⚔ Mandirigma" if is_host else "✨ Babaylan"
	var role_color: Color = Color(1.0, 0.75, 0.2) if is_host else Color(0.55, 0.85, 1.0)
	var badge := Label.new()
	badge.name = "RoleBadge"
	badge.text = role_name
	badge.add_theme_font_size_override("font_size", 18)
	badge.add_theme_color_override("font_color", role_color)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.anchor_left = 1.0
	badge.anchor_top = 0.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 0.0
	badge.offset_left = -180
	badge.offset_top = 8
	badge.offset_right = -8
	badge.offset_bottom = 36
	hud.add_child(badge)

# =============================================================================
# UI FEEDBACK — Juice & Polish
# =============================================================================

func show_wave_banner(text: String, color: Color = Color.GOLD) -> void:
	"""Slide a full-width wave announcement label in from the top, hold, then fade."""
	var hud := get_node_or_null("HUD")
	if not hud:
		return
	var banner := Label.new()
	banner.text = text
	banner.add_theme_font_size_override("font_size", 32)
	banner.add_theme_color_override("font_color", color)
	banner.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	banner.add_theme_constant_override("shadow_offset_x", 2)
	banner.add_theme_constant_override("shadow_offset_y", 2)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 0.0
	banner.anchor_bottom = 0.0
	banner.offset_top = -48.0
	banner.offset_bottom = 48.0
	hud.add_child(banner)
	var t := banner.create_tween()
	t.tween_property(banner, "offset_top", 60.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(banner, "offset_bottom", 100.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_interval(1.5)
	t.tween_property(banner, "modulate:a", 0.0, 0.4)
	t.tween_callback(banner.queue_free)

func start_wave_button_pulse() -> void:
	"""Looping scale + alpha pulse on the Start Wave button during planning phase."""
	var wave_btn := get_node_or_null("HUD/WaveBar/StartWaveButton")
	if not is_instance_valid(wave_btn):
		return
	stop_wave_button_pulse()
	_wave_pulse_tween = wave_btn.create_tween().set_loops()
	_wave_pulse_tween.set_parallel(true)
	_wave_pulse_tween.tween_property(wave_btn, "scale", Vector2(1.06, 1.06), 0.6).set_ease(Tween.EASE_IN_OUT)
	_wave_pulse_tween.tween_property(wave_btn, "modulate:a", 0.78, 0.6).set_ease(Tween.EASE_IN_OUT)
	_wave_pulse_tween.chain().set_parallel(true)
	_wave_pulse_tween.tween_property(wave_btn, "scale", Vector2.ONE, 0.6).set_ease(Tween.EASE_IN_OUT)
	_wave_pulse_tween.tween_property(wave_btn, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_IN_OUT)

func stop_wave_button_pulse() -> void:
	"""Stop the pulse and restore the button to its default appearance."""
	if _wave_pulse_tween and _wave_pulse_tween.is_running():
		_wave_pulse_tween.kill()
		_wave_pulse_tween = null
	var wave_btn := get_node_or_null("HUD/WaveBar/StartWaveButton")
	if is_instance_valid(wave_btn):
		wave_btn.scale = Vector2.ONE
		wave_btn.modulate = Color.WHITE

func show_build_indicator(tower_name: String) -> void:
	"""Show a bottom-center label while the player is in build/placement mode."""
	if not is_instance_valid(_build_indicator):
		_build_indicator = Label.new()
		_build_indicator.name = "BuildIndicator"
		_build_indicator.add_theme_font_size_override("font_size", 18)
		_build_indicator.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		_build_indicator.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
		_build_indicator.add_theme_constant_override("shadow_offset_x", 1)
		_build_indicator.add_theme_constant_override("shadow_offset_y", 1)
		_build_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_build_indicator.anchor_left = 0.0
		_build_indicator.anchor_right = 1.0
		_build_indicator.anchor_top = 1.0
		_build_indicator.anchor_bottom = 1.0
		_build_indicator.offset_top = -100.0
		_build_indicator.offset_bottom = -68.0
		_build_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_node("HUD").add_child(_build_indicator)
	_build_indicator.text = "Placing: %s   |   ENTER to place  •  ESC to cancel" % _tower_display_name(tower_name)
	_build_indicator.modulate = Color.WHITE
	_build_indicator.visible = true

func hide_build_indicator() -> void:
	if is_instance_valid(_build_indicator):
		_build_indicator.visible = false

func _show_speed_badge() -> void:
	"""Create or show the 2× speed badge near the speed-up button."""
	var speed_btn := get_node_or_null("HUD/GameControls/MarginContainer2/SpeedUp")
	if not is_instance_valid(speed_btn):
		return
	if not is_instance_valid(_speed_badge):
		_speed_badge = Label.new()
		_speed_badge.name = "SpeedBadge"
		_speed_badge.text = "2×"
		_speed_badge.add_theme_font_size_override("font_size", 15)
		_speed_badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		_speed_badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		_speed_badge.add_theme_constant_override("shadow_offset_x", 1)
		_speed_badge.add_theme_constant_override("shadow_offset_y", 1)
		_speed_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_speed_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_speed_badge.anchor_right = 1.0
		_speed_badge.anchor_bottom = 0.25
		_speed_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		speed_btn.add_child(_speed_badge)
	_speed_badge.visible = true

func _float_gold_gain(gained: int) -> void:
	"""Float a green '+N' label upward from the gold icon area."""
	if gained <= 0:
		return
	var lbl := Label.new()
	lbl.text = "+%d" % gained
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	# Place near top-left (gold icon area).
	lbl.position = Vector2(56, 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("HUD").add_child(lbl)
	var t := lbl.create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 48, 0.9).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(lbl.queue_free)

func _flash_card_ready(tower_name: String, btn: Button) -> void:
	"""Brief green flash + 'Ready!' label when a card cooldown expires."""
	if not is_instance_valid(btn):
		return
	# Green flash on the button itself.
	var t := btn.create_tween()
	t.tween_property(btn, "modulate", Color(0.4, 1.0, 0.5), 0.15)
	t.tween_property(btn, "modulate", Color.WHITE, 0.30)
	# Tiny 'Ready!' label above the card.
	var lbl := Label.new()
	lbl.text = "Ready!"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lbl.offset_top = -22.0
	lbl.offset_bottom = 0.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	var t2 := lbl.create_tween()
	t2.tween_property(lbl, "modulate:a", 0.0, 0.7)
	t2.tween_callback(lbl.queue_free)

func _show_low_hp_vignette() -> void:
	"""Pulsing red border at screen edges when base HP < 25."""
	_low_hp_active = true
	if not is_instance_valid(_vignette_node):
		_vignette_node = ColorRect.new()
		_vignette_node.name = "LowHPVignette"
		_vignette_node.color = Color(0.82, 0.05, 0.05, 0.0)
		_vignette_node.anchor_right = 1.0
		_vignette_node.anchor_bottom = 1.0
		_vignette_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette_node.z_index = 10
		# Use a StyleBoxFlat with empty fill to only show the border.
		get_node("HUD").add_child(_vignette_node)
	_vignette_node.visible = true
	if _vignette_tween and _vignette_tween.is_running():
		_vignette_tween.kill()
	_vignette_tween = _vignette_node.create_tween().set_loops()
	_vignette_tween.tween_property(_vignette_node, "color:a", 0.22, 0.75).set_ease(Tween.EASE_IN_OUT)
	_vignette_tween.tween_property(_vignette_node, "color:a", 0.04, 0.75).set_ease(Tween.EASE_IN_OUT)

func _hide_low_hp_vignette() -> void:
	"""Remove the low-HP vignette when HP recovers."""
	_low_hp_active = false
	if _vignette_tween and _vignette_tween.is_running():
		_vignette_tween.kill()
		_vignette_tween = null
	if is_instance_valid(_vignette_node):
		var t := _vignette_node.create_tween()
		t.tween_property(_vignette_node, "color:a", 0.0, 0.4)
		t.tween_callback(_vignette_node.queue_free)
		_vignette_node = null
