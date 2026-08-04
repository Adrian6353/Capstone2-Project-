extends PanelContainer
## UpgradePanel — shows stats for a selected placed tower and offers
## Upgrade / Sell actions.  Built entirely in code (no .tscn needed).

signal upgrade_requested(tower)
signal sell_requested(tower)

var tower_ref: Node2D = null

# Node refs populated in _build_ui()
var _name_label: Label
var _rarity_label: Label
var _level_label: Label
var _curr_dmg: Label
var _curr_rof: Label
var _curr_rng: Label
var _next_dmg: Label
var _next_rof: Label
var _next_rng: Label
var _next_name_label: Label
var _cost_label: Label
var _upgrade_btn: Button
var _sell_btn: Button

const RARITY_COLORS := {
	"common":    Color(0.35, 0.95, 0.35),
	"rare":      Color(0.45, 0.65, 1.0),
	"legendary": Color(1.0,  0.80, 0.2),
}

const PANEL_WIDTH  := 300.0
const MARGIN       := 14.0  # pixels from screen right/top edge

func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	# Apply Fantasy RPG panel style
	UIThemeHelper.apply_panel_style(self)
	_build_ui()
	call_deferred("_anchor_panel")

func _anchor_panel() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x < 600:
		# Mobile portrait: dock to bottom center
		position = Vector2((vp_size.x - PANEL_WIDTH) / 2.0, vp_size.y - size.y - MARGIN)
	else:
		# Landscape: right side at 25 % from top
		position = Vector2(vp_size.x - PANEL_WIDTH - MARGIN, vp_size.y * 0.22)
	UIThemeHelper.animate_panel_in(self)

# ────────────────────────────────────────────────────────────────────────────
#  UI construction
# ────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		root_margin.add_theme_constant_override("margin_" + side, 10)
	add_child(root_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	root_margin.add_child(vbox)

	# ── Title row ──────────────────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_col)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.clip_text = true
	name_col.add_child(_name_label)

	_rarity_label = Label.new()
	_rarity_label.add_theme_font_size_override("font_size", 10)
	name_col.add_child(_rarity_label)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 13)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_level_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(52, 52)
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# ── Stats columns ───────────────────────────────────────────────────────
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 4)
	vbox.add_child(stats_row)

	# Current column
	var curr_col := VBoxContainer.new()
	curr_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(curr_col)

	var curr_header := Label.new()
	curr_header.text    = "CURRENT"
	curr_header.add_theme_font_size_override("font_size", 10)
	curr_header.modulate = Color(0.7, 0.7, 0.7)
	curr_col.add_child(curr_header)

	_curr_dmg = _make_stat_label()
	curr_col.add_child(_curr_dmg)
	_curr_rof = _make_stat_label()
	curr_col.add_child(_curr_rof)
	_curr_rng = _make_stat_label()
	curr_col.add_child(_curr_rng)

	# Arrow column
	var arr_col := VBoxContainer.new()
	stats_row.add_child(arr_col)

	var spacer := Label.new()          # aligns arrows with stat rows, not header
	spacer.text = " "
	spacer.add_theme_font_size_override("font_size", 10)
	arr_col.add_child(spacer)

	for _i in 3:
		var arr := Label.new()
		arr.text    = "→"
		arr.add_theme_font_size_override("font_size", 11)
		arr.modulate = Color(0.55, 0.55, 0.55)
		arr_col.add_child(arr)

	# Next column
	var next_col := VBoxContainer.new()
	next_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(next_col)

	var next_header := Label.new()
	next_header.text    = "NEXT LVL"
	next_header.add_theme_font_size_override("font_size", 10)
	next_header.modulate = Color(0.7, 0.7, 0.7)
	next_col.add_child(next_header)

	_next_dmg = _make_stat_label()
	next_col.add_child(_next_dmg)
	_next_rof = _make_stat_label()
	next_col.add_child(_next_rof)
	_next_rng = _make_stat_label()
	next_col.add_child(_next_rng)

	vbox.add_child(HSeparator.new())

	# ── Next tower name + cost ──────────────────────────────────────────────
	_next_name_label = Label.new()
	_next_name_label.add_theme_font_size_override("font_size", 12)
	_next_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_next_name_label)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 11)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_cost_label)

	# ── Action buttons ──────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_row)

	_upgrade_btn = Button.new()
	_upgrade_btn.text = "UPGRADE"
	_upgrade_btn.custom_minimum_size = Vector2(0, 52)
	_upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	btn_row.add_child(_upgrade_btn)

	_sell_btn = Button.new()
	_sell_btn.text = "SELL"
	_sell_btn.custom_minimum_size = Vector2(0, 52)
	_sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_btn.pressed.connect(_on_sell_pressed)
	btn_row.add_child(_sell_btn)

func _make_stat_label(is_next: bool = false) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	if is_next:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return lbl

# ────────────────────────────────────────────────────────────────────────────
#  Data population
# ────────────────────────────────────────────────────────────────────────────

func populate(tower: Node2D) -> void:
	tower_ref = tower
	var t_type: String = tower.type
	var t_data: Dictionary = GameData.tower_data[t_type]

	# Tower name & rarity
	_name_label.text = TooltipManager.TOWER_DISPLAY_NAMES.get(t_type, t_type)
	var rarity: String = t_data.get("rarity", "common")
	_rarity_label.text    = rarity.capitalize()
	_rarity_label.modulate = RARITY_COLORS.get(rarity, Color.WHITE)

	# Level indicator
	var family_key: String = GameData.get_tower_family_name(t_type)
	var level: int = GameData.get_tower_level(t_type)
	var max_lvl: int = GameData.tower_families[family_key]["towers"].size() if family_key != "" else 3
	_level_label.text = "Lv %d/%d" % [level, max_lvl]

	# Current stats
	_curr_dmg.text = "⚔ %d"   % t_data.get("damage", 0)
	_curr_rof.text = "⏱ %.2f" % t_data.get("rof", 0.0)
	_curr_rng.text = "◎ %d"   % t_data.get("range", 0)

	# Next level stats
	var next_type: String = GameData.get_next_tower_type(t_type)
	if next_type == "":
		_show_max_level()
	else:
		_show_upgrade_info(t_data, next_type)

	# Sell button: always shows refund of current tower's cost
	var refund: int = int(t_data.get("cost", 0) * GameData.REFUND_PERCENTAGE)
	_sell_btn.text = "SELL\n🪙 %dg" % refund

func _show_max_level() -> void:
	_next_name_label.text    = "✦  MAX LEVEL  ✦"
	_next_name_label.modulate = UIThemeHelper.COL_RARITY_LEGENDARY
	_cost_label.text         = ""
	for lbl in [_next_dmg, _next_rof, _next_rng]:
		lbl.text = "—"
		lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_MUTED)
	_upgrade_btn.text     = "★ MAX LEVEL"
	_upgrade_btn.disabled = true

func _show_upgrade_info(t_data: Dictionary, next_type: String) -> void:
	var next_data: Dictionary = GameData.tower_data[next_type]
	var next_display: String  = TooltipManager.TOWER_DISPLAY_NAMES.get(next_type, next_type)
	_next_name_label.text    = "▲  " + next_display
	_next_name_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))

	var cost: int = GameData.get_upgrade_cost(tower_ref.type)
	_cost_label.text = "🪙 %d gold" % cost

	var curr_dmg: int   = t_data.get("damage", 0)
	var curr_rof: float = t_data.get("rof",    0.0)
	var curr_rng: int   = t_data.get("range",  0)
	var next_dmg: int   = next_data.get("damage", 0)
	var next_rof: float = next_data.get("rof",    0.0)
	var next_rng: int   = next_data.get("range",  0)

	_next_dmg.text = _diff_str_int(next_dmg,   next_dmg - curr_dmg)
	_next_rof.text = _diff_str_flt(next_rof,   next_rof - curr_rof)
	_next_rng.text = _diff_str_int(next_rng,   next_rng - curr_rng)
	var green := Color(0.45, 1.0, 0.60)
	_next_dmg.add_theme_color_override("font_color", green)
	_next_rof.add_theme_color_override("font_color", green)
	_next_rng.add_theme_color_override("font_color", green)

	_upgrade_btn.text     = "▲ UPGRADE"
	if GameData.current_money < cost:
		_upgrade_btn.text = "▲ UPGRADE\n🪙 Need %dg more" % (cost - GameData.current_money)
		_upgrade_btn.disabled = true
	else:
		_upgrade_btn.disabled = false

func _diff_str_int(val: int, diff: int) -> String:
	if diff >= 0:
		return "%d (+%d)" % [val, diff]
	return "%d (%d)" % [val, diff]

func _diff_str_flt(val: float, diff: float) -> String:
	if diff >= 0.0:
		return "%.2f (+%.2f)" % [val, diff]
	return "%.2f (%.2f)" % [val, diff]

# ────────────────────────────────────────────────────────────────────────────
#  Button handlers
# ────────────────────────────────────────────────────────────────────────────

func _on_upgrade_pressed() -> void:
	if is_instance_valid(tower_ref):
		emit_signal("upgrade_requested", tower_ref)

func _on_sell_pressed() -> void:
	if is_instance_valid(tower_ref):
		emit_signal("sell_requested", tower_ref)

func _on_close_pressed() -> void:
	AudioManager.play_sfx("upgrade_panel_close")
	queue_free()
