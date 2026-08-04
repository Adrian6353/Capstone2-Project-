extends Control
## Lootbox/Gacha UI — opened from the main menu via the "Gacha" button.
##
## Builds all UI programmatically in _ready() so no external .tscn node
## hierarchy is required beyond the root Control this script is attached to.
## Layout:
##   - Background overlay
##   - Title & close button
##   - Tower collection status
##   - Three box panels (Common / Rare / Legendary), horizontal row
##   - Result panel (shown after opening a box, hidden otherwise)

# ---------------------------------------------------------------------------
# Box type metadata (order for display)
# ---------------------------------------------------------------------------
const BOX_TYPES: Array = ["common", "rare", "legendary"]
const BOX_COLORS: Dictionary = {
	"common":    Color(0.36, 0.73, 0.36),   # green
	"rare":      Color(0.27, 0.51, 0.93),   # blue
	"legendary": Color(1.0,  0.76, 0.13),   # gold
}

# ---------------------------------------------------------------------------
# Autoload singletons
# ---------------------------------------------------------------------------
var LootboxManager
var GameData
var RaritySystem

# ---------------------------------------------------------------------------
# Node references built in _ready()
# ---------------------------------------------------------------------------
var _open_buttons: Dictionary = {}        # box_type → Button
var _count_labels: Dictionary = {}        # box_type → Label
var _collection_count_label: Label = null
var _result_panel: PanelContainer = null
var _result_title: Label = null
var _result_body: Label = null
var _collection_list: VBoxContainer = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	LootboxManager = get_node("/root/LootboxManager")
	GameData = get_node("/root/GameData")
	RaritySystem = get_node("/root/RaritySystem")
	_build_ui()
	_refresh_all()
	LootboxManager.lootbox_data_changed.connect(_refresh_all)

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	# Root fills the viewport as a darkened overlay.
	anchor_right  = 1.0
	anchor_bottom = 1.0
	set("theme_override_colors/font_color", Color.WHITE)

	# Dimmed backdrop.
	var backdrop := ColorRect.new()
	backdrop.anchor_right  = 1.0
	backdrop.anchor_bottom = 1.0
	backdrop.color = Color(0, 0, 0, 0.72)
	add_child(backdrop)
	backdrop.gui_input.connect(_on_backdrop_input)

	# Centred panel — anchors keep it inside any viewport size (mobile-safe).
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.03
	panel.anchor_top    = 0.03
	panel.anchor_right  = 0.97
	panel.anchor_bottom = 0.97
	add_child(panel)

	UIThemeHelper.apply_panel_style(panel)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 14)
	root_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vb.add_theme_constant_override("margin_left",   18)
	root_vb.add_theme_constant_override("margin_right",  18)
	root_vb.add_theme_constant_override("margin_top",    14)
	root_vb.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(root_vb)

	# ── Header row ──────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	root_vb.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "✦ GACHA — Tower Lootboxes ✦"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕  Close"
	close_btn.custom_minimum_size = Vector2(110, 48)
	UIThemeHelper.apply_button_theme(close_btn, "secondary", 16)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# ── Shard bar ───────────────────────────────────────────────────────────
	var collection_row := HBoxContainer.new()
	collection_row.add_theme_constant_override("separation", 10)
	root_vb.add_child(collection_row)

	var collection_title := Label.new()
	collection_title.text = "Tower Families:"
	collection_title.add_theme_font_size_override("font_size", 18)
	collection_row.add_child(collection_title)

	_collection_count_label = Label.new()
	_collection_count_label.text = "0"
	_collection_count_label.add_theme_font_size_override("font_size", 18)
	_collection_count_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	collection_row.add_child(_collection_count_label)

	var collection_hint := Label.new()
	collection_hint.text = "(open lootboxes to permanently unlock towers for every game)"
	collection_hint.add_theme_font_size_override("font_size", 13)
	collection_hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	collection_row.add_child(collection_hint)

	# Separator
	root_vb.add_child(HSeparator.new())

	# ── Three box panels ────────────────────────────────────────────────────
	var boxes_row := HBoxContainer.new()
	boxes_row.add_theme_constant_override("separation", 16)
	boxes_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vb.add_child(boxes_row)

	for box_type in BOX_TYPES:
		var box_panel := _build_box_panel(box_type)
		box_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boxes_row.add_child(box_panel)

	# Separator
	root_vb.add_child(HSeparator.new())

	# ── Tower collection list ────────────────────────────────────────────────
	var unlock_header := Label.new()
	unlock_header.text = "Tower Collection:"
	unlock_header.add_theme_font_size_override("font_size", 16)
	unlock_header.add_theme_color_override("font_color", Color(0.85, 0.72, 1.0))
	root_vb.add_child(unlock_header)

	var unlock_scroll := ScrollContainer.new()
	unlock_scroll.custom_minimum_size = Vector2(0, 90)
	unlock_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vb.add_child(unlock_scroll)

	_collection_list = VBoxContainer.new()
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_scroll.add_child(_collection_list)

	# ── Result overlay (hidden by default) ──────────────────────────────────
	_result_panel = PanelContainer.new()
	_result_panel.anchor_left   = 0.5
	_result_panel.anchor_top    = 0.5
	_result_panel.anchor_right  = 0.5
	_result_panel.anchor_bottom = 0.5
	_result_panel.custom_minimum_size = Vector2(520, 340)
	_result_panel.position = Vector2(-260, -170)
	_result_panel.visible = false
	# Bring result panel above the main panel
	add_child(_result_panel)

	UIThemeHelper.apply_panel_style(_result_panel)

	var rp_vb := VBoxContainer.new()
	rp_vb.add_theme_constant_override("separation", 12)
	rp_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_panel.add_child(rp_vb)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 24)
	rp_vb.add_child(_result_title)

	_result_body = Label.new()
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body.add_theme_font_size_override("font_size", 17)
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rp_vb.add_child(_result_body)

	var rp_ok := Button.new()
	rp_ok.text = "OK"
	rp_ok.custom_minimum_size = Vector2(140, 60)
	rp_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIThemeHelper.apply_button_theme(rp_ok, "primary", 20)
	rp_ok.pressed.connect(func(): _result_panel.visible = false)
	rp_vb.add_child(rp_ok)

# ---------------------------------------------------------------------------
# Build a single box panel
# ---------------------------------------------------------------------------
func _build_box_panel(box_type: String) -> PanelContainer:
	var color: Color = BOX_COLORS[box_type]

	var pc := PanelContainer.new()
	var pc_style := StyleBoxFlat.new()
	pc_style.bg_color     = color.darkened(0.72)
	pc_style.border_color = color
	pc_style.set_border_width_all(2)
	pc_style.set_corner_radius_all(10)
	pc.add_theme_stylebox_override("panel", pc_style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pc.add_child(vb)

	# Box type title
	var name_lbl := Label.new()
	name_lbl.text = LootboxManager.get_box_display_name(box_type).to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", color)
	vb.add_child(name_lbl)

	# Big colored box emoji / icon area
	var icon_lbl := Label.new()
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 48)
	match box_type:
		"common":    icon_lbl.text = "📦"
		"rare":      icon_lbl.text = "🎁"
		"legendary": icon_lbl.text = "✨"
	vb.add_child(icon_lbl)

	# Count label
	var count_lbl := Label.new()
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 20)
	count_lbl.add_theme_color_override("font_color", Color.WHITE)
	_count_labels[box_type] = count_lbl
	vb.add_child(count_lbl)

	# Drop-rate hint
	var weights: Dictionary = LootboxManager.BOX_WEIGHTS[box_type]
	var hint_lbl := Label.new()
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	hint_lbl.text = "🟢 %.0f%%  🔵 %.0f%%  ⭐ %.0f%%" % [
		weights["common"]    * 100.0,
		weights["rare"]      * 100.0,
		weights["legendary"] * 100.0,
	]
	vb.add_child(hint_lbl)

	# Open button
	var open_btn := Button.new()
	open_btn.text = "Open Box"
	open_btn.custom_minimum_size = Vector2(0, 60)
	open_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIThemeHelper.apply_button_theme(open_btn, "primary", 18)
	open_btn.pressed.connect(func(): _on_open_box(box_type))
	_open_buttons[box_type] = open_btn
	vb.add_child(open_btn)

	return pc

# ---------------------------------------------------------------------------
# Data refresh
# ---------------------------------------------------------------------------
func _refresh_all() -> void:
	# Update box counts and button states.
	for box_type in BOX_TYPES:
		var count: int = LootboxManager.get_box_count(box_type)
		_count_labels[box_type].text = "x%d" % count
		_open_buttons[box_type].disabled = count <= 0

	# Update collection count.
	if _collection_count_label:
		_collection_count_label.text = "%d / %d" % [
			LootboxManager.unlocked_families.size(),
			GameData.tower_families.size(),
		]

	# Rebuild tower collection list.
	_rebuild_collection_list()

func _rebuild_collection_list() -> void:
	for child in _collection_list.get_children():
		child.queue_free()

	for family_name in GameData.tower_families:
		var rarity: String = GameData.tower_families.get(family_name, {}).get("rarity", "common")
		var rarity_symbol: String = RaritySystem.get_rarity_symbol(rarity)
		var rarity_color: Color = RaritySystem.get_rarity_color(rarity)
		var is_unlocked: bool = LootboxManager.is_family_unlocked(family_name)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_collection_list.add_child(row)

		var fam_towers: Array = GameData.tower_families.get(family_name, {}).get("towers", [])
		var fam_display: String = TooltipManager.TOWER_DISPLAY_NAMES.get(
			fam_towers[0] if fam_towers.size() > 0 else family_name, family_name)
		var fam_lbl := Label.new()
		fam_lbl.text = "%s %s" % [rarity_symbol if is_unlocked else "🔒", fam_display if is_unlocked else "Undiscovered Tower"]
		fam_lbl.add_theme_color_override("font_color", rarity_color if is_unlocked else Color(0.55, 0.55, 0.6))
		fam_lbl.add_theme_font_size_override("font_size", 14)
		fam_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(fam_lbl)

		var status_lbl := Label.new()
		status_lbl.text = "UNLOCKED" if is_unlocked else "Open a lootbox"
		status_lbl.add_theme_font_size_override("font_size", 13)
		status_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7) if is_unlocked else Color(0.6, 0.6, 0.65))
		row.add_child(status_lbl)

# ---------------------------------------------------------------------------
# Chest animation helpers  (uses addon spritesheet: Chests.png)
# ---------------------------------------------------------------------------

## Builds a SpriteFrames from the addon's Chests.png atlas.
## Frames are 48×32 px each.
##   idle  – closed chest      (x=0)
##   shake – chest bouncing    (x=0,48,96,144,192) looped @10 fps
##   open  – chest popping open(x=240,288,384,432,336) once @9 fps
func _build_chest_sprite_frames() -> SpriteFrames:
	var sheet: Texture2D = load("res://addons/weighted_choice/demo/sprites/Chests.png")
	if sheet == null:
		return null
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	# idle
	sf.add_animation("idle")
	sf.set_animation_loop("idle", false)
	sf.set_animation_speed("idle", 0.0)
	sf.add_frame("idle", _make_chest_atlas(sheet, 0))

	# shake (chest rocking before burst)
	sf.add_animation("shake")
	sf.set_animation_loop("shake", true)
	sf.set_animation_speed("shake", 10.0)
	for x in [0, 48, 96, 144, 192]:
		sf.add_frame("shake", _make_chest_atlas(sheet, x))

	# open (chest lid flying off)
	sf.add_animation("open")
	sf.set_animation_loop("open", false)
	sf.set_animation_speed("open", 9.0)
	for x in [240, 288, 384, 432, 336]:
		sf.add_frame("open", _make_chest_atlas(sheet, x))

	return sf

func _make_chest_atlas(sheet: Texture2D, x: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(x, 0, 48, 32)
	return at

## Play the shake→open chest animation, then call _show_result when done.
func _show_chest_animation(box_type: String, result: Dictionary) -> void:
	var box_color: Color    = BOX_COLORS.get(box_type, Color.WHITE)
	var reveal_color: Color = RaritySystem.get_rarity_color(result.get("rarity", "common"))
	var vp: Vector2         = get_viewport_rect().size

	# ── Full-screen dim (blocks clicks during animation) ──────────────────────
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color        = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# ── Centered popup card ───────────────────────────────────────────────────
	const CARD_W := 360.0
	const CARD_H := 340.0
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.position            = vp * 0.5 - Vector2(CARD_W * 0.5, CARD_H * 0.5)
	card.pivot_offset        = Vector2(CARD_W * 0.5, CARD_H * 0.5)
	card.scale               = Vector2(0.4, 0.4)
	card.modulate            = Color(1, 1, 1, 0.0)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color                   = Color(0.09, 0.07, 0.14)
	card_style.border_width_left          = 3
	card_style.border_width_right         = 3
	card_style.border_width_top           = 3
	card_style.border_width_bottom        = 3
	card_style.border_color               = box_color
	card_style.corner_radius_top_left     = 14
	card_style.corner_radius_top_right    = 14
	card_style.corner_radius_bottom_left  = 14
	card_style.corner_radius_bottom_right = 14
	card_style.shadow_color               = Color(box_color.r, box_color.g, box_color.b, 0.40)
	card_style.shadow_size                = 16
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	# Inner layout: margin → vbox
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Box-type title
	var title_lbl := Label.new()
	title_lbl.text                 = "%s Box" % box_type.capitalize()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 19)
	title_lbl.add_theme_color_override("font_color", box_color)
	vbox.add_child(title_lbl)

	# Coloured divider
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(box_color.r, box_color.g, box_color.b, 0.35))
	vbox.add_child(sep)

	# Fixed-height area that holds the AnimatedSprite2D (Node2D, not Control)
	# Content width = CARD_W - margins = 320.  Chest at scale 5 = 240×160 px.
	var sprite_area := Control.new()
	sprite_area.custom_minimum_size = Vector2(0, 174)
	vbox.add_child(sprite_area)

	# Build sprite frames — fall back to immediate reveal if asset missing
	var sf := _build_chest_sprite_frames()
	if sf == null:
		dim.queue_free()
		card.queue_free()
		_show_result(result)
		return

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.scale         = Vector2(5.0, 5.0)   # 240×160 px — clearly visible, not overwhelming
	sprite.position      = Vector2(160, 87)     # centred in 320×174 content area
	sprite.modulate      = box_color
	sprite.play("idle")
	sprite_area.add_child(sprite)

	# Rarity label — revealed after the open burst
	var rarity_lbl := Label.new()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 21)
	rarity_lbl.add_theme_color_override("font_color", Color.WHITE)
	rarity_lbl.modulate = Color(1, 1, 1, 0.0)
	vbox.add_child(rarity_lbl)

	# Subtle hint text
	var hint_lbl := Label.new()
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.70))
	hint_lbl.modulate = Color(1, 1, 1, 0.0)
	vbox.add_child(hint_lbl)

	# ── Tween sequence ─────────────────────────────────────────────────────────
	var tween := create_tween()

	# Phase 1 – popup card bounces in while dim fades (0.3 s)
	tween.tween_property(dim, "color", Color(0, 0, 0, 0.80), 0.30)
	tween.parallel().tween_property(card, "modulate", Color(1, 1, 1, 1.0), 0.25)
	tween.parallel().tween_property(card, "scale", Vector2(1.06, 1.06), 0.28) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Settle to 1.0
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.10) \
		.set_ease(Tween.EASE_IN_OUT)
	# Hint text fades in
	tween.tween_callback(func(): hint_lbl.text = "Something is inside…")
	tween.tween_property(hint_lbl, "modulate", Color(1, 1, 1, 1.0), 0.20)

	# Phase 2 – shake for 1.8 s
	tween.tween_callback(func(): sprite.play("shake"))
	tween.tween_interval(1.8)

	# Phase 3 – open burst; hint fades out
	tween.tween_callback(func():
		sprite.play("open")
		hint_lbl.text = ""
	)
	tween.tween_property(hint_lbl, "modulate", Color(1, 1, 1, 0.0), 0.15)
	tween.tween_interval(0.50)

	# Phase 4 – rarity colour sweep + label reveal
	tween.tween_callback(func():
		var sym: String   = RaritySystem.get_rarity_symbol(result.get("rarity", "common"))
		var rname: String = RaritySystem.get_rarity_name(result.get("rarity", "common"))
		rarity_lbl.text   = "%s  %s  %s" % [sym, rname.to_upper(), sym]
		rarity_lbl.add_theme_color_override("font_color", reveal_color)
		sprite.modulate                = reveal_color
		card_style.border_color        = reveal_color
		card_style.shadow_color        = Color(reveal_color.r, reveal_color.g, reveal_color.b, 0.55)
		card.add_theme_stylebox_override("panel", card_style)
		sep.add_theme_color_override("color", Color(reveal_color.r, reveal_color.g, reveal_color.b, 0.45))
		title_lbl.add_theme_color_override("font_color", reveal_color)
	)
	# Rarity label fades in; card pulses with drama
	tween.tween_property(rarity_lbl, "modulate", Color(1, 1, 1, 1.0), 0.28)
	tween.parallel().tween_property(card, "scale", Vector2(1.05, 1.05), 0.14) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.14) \
		.set_ease(Tween.EASE_IN_OUT)
	# Hold on reveal
	tween.tween_interval(0.65)

	# Phase 5 – card shrinks and fades out; dismiss
	tween.tween_property(card, "modulate", Color(1, 1, 1, 0.0), 0.22) \
		.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(dim,  "color", Color(0, 0, 0, 0.0), 0.22)
	tween.parallel().tween_property(card, "scale", Vector2(0.85, 0.85), 0.22)
	tween.tween_callback(func():
		dim.queue_free()
		card.queue_free()
		_show_result(result)
	)

# ---------------------------------------------------------------------------
# Interaction handlers
# ---------------------------------------------------------------------------
func _on_open_box(box_type: String) -> void:
	var result: Dictionary = LootboxManager.open_box(box_type)
	if not result.get("success", false):
		return
	# Disable all open buttons while the animation plays
	for bt in _open_buttons:
		_open_buttons[bt].disabled = true
	_show_chest_animation(box_type, result)

## Shows the result panel after the chest animation completes.
func _show_result(result: Dictionary) -> void:
	# Refresh counts / re-enable buttons with updated state
	_refresh_all()

	var family: String      = result["family"]
	var rarity: String      = result["rarity"]
	var just_unlocked: bool = result.get("just_unlocked", result.get("is_new", false))
	var towers: Array       = result["towers"]
	var shards_earned: int  = result["shards_earned"]
	var already_unlocked: bool = (shards_earned > 0)  # generic shards only come from duplicates

	var rarity_name: String   = RaritySystem.get_rarity_name(rarity)
	var rarity_symbol: String = RaritySystem.get_rarity_symbol(rarity)
	var rarity_color: Color   = RaritySystem.get_rarity_color(rarity)

	# Family display name = Lv1 tower's human-readable name (the family is named after it)
	var family_display: String = TooltipManager.TOWER_DISPLAY_NAMES.get(
		towers[0] if towers.size() > 0 else family, family)

	var body_parts: PackedStringArray = PackedStringArray()
	body_parts.append("%s %s Family  [%s]" % [rarity_symbol, family_display, rarity_name])
	body_parts.append("")

	if just_unlocked:
		_result_title.text = "🎉 UNLOCKED!"
		_result_title.add_theme_color_override("font_color", Color.GOLD)
		body_parts.append("Tower family unlocked!")
		body_parts.append("")
		var level_labels: Array = ["Lv1", "Lv2", "Lv3"]
		for i in range(towers.size()):
			var t: String = towers[i]
			var td: Dictionary = GameData.tower_data.get(t, {})
			var dmg: int  = td.get("damage", 0)
			var rng: int  = td.get("range", 0)
			var cost: int = td.get("cost", 0)
			var lv_label: String = level_labels[i] if i < level_labels.size() else ("Lv%d" % (i + 1))
			# All levels use the family name — only the level number differs
			var display_name: String = "%s %s" % [family_display, lv_label]
			if dmg > 0:
				body_parts.append("  • %s" % display_name)
				body_parts.append("       DMG %d  •  RNG %d  •  Cost %d" % [dmg, rng, cost])
			else:
				body_parts.append("  • %s" % display_name)
				body_parts.append("       RNG %d  •  Cost %d  (Support)" % [rng, cost])
	elif already_unlocked:
		_result_title.text = "Duplicate — Shards Earned!"
		_result_title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		body_parts.append("💎 +%d shards  (total: %d)" % [shards_earned, LootboxManager.shards])
		body_parts.append("")
		body_parts.append("Your tower collection is already complete.")

	_result_body.text = "\n".join(body_parts)
	_result_body.add_theme_color_override("font_color", rarity_color if just_unlocked else Color.WHITE)
	_result_panel.visible = true

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _result_panel or not _result_panel.visible:
			_on_close()

func _on_close() -> void:
	queue_free()
