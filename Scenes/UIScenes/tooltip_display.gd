extends CanvasLayer

var tween
var _panel_stylebox: StyleBoxFlat

func _ready() -> void:
	# Build a unique dark panel style per instance (safe to modify per-rarity)
	_panel_stylebox = StyleBoxFlat.new()
	_panel_stylebox.bg_color = Color(0.06, 0.07, 0.11, 0.96)
	_panel_stylebox.border_color = Color.GREEN
	_panel_stylebox.set_border_width_all(2)
	_panel_stylebox.set_corner_radius_all(6)
	$PanelContainer.add_theme_stylebox_override("panel", _panel_stylebox)
	$PanelContainer.modulate.a = 0

func set_position(new_position: Vector2) -> void:
	$PanelContainer.position = new_position

func _get_rarity_color(rarity: String) -> Color:
	if has_node("/root/RaritySystem"):
		return get_node("/root/RaritySystem").get_rarity_color(rarity)
	match rarity:
		"common":    return Color.GREEN
		"rare":      return Color(0.3, 0.5, 1.0)
		"legendary": return Color.GOLD
	return Color.WHITE

func set_content(data: Dictionary) -> void:
	var vbox      = $PanelContainer/MarginContainer/VBoxContainer
	var stats_box = vbox.get_node("StatsContainer")

	# ── Rarity colour ─────────────────────────────────────────────────
	var rarity       = data.get("rarity", "")
	var has_rarity   = rarity != ""
	var rarity_color = _get_rarity_color(rarity) if has_rarity else Color.WHITE

	if _panel_stylebox:
		_panel_stylebox.border_color = rarity_color if has_rarity else Color(0.28, 0.28, 0.35)

	# ── Tower name (coloured by rarity) ───────────────────────────────
	var name_lbl = vbox.get_node("NameLabel")
	name_lbl.text = data.get("name", "Unknown")
	if has_rarity:
		name_lbl.add_theme_color_override("font_color", rarity_color)
	else:
		name_lbl.remove_theme_color_override("font_color")

	# ── Rarity badge ──────────────────────────────────────────────────
	var rarity_lbl = vbox.get_node("RarityLabel")
	if has_rarity:
		var badge: String
		match rarity:
			"common":    badge = "★  COMMON"
			"rare":      badge = "★★  RARE"
			"epic":      badge = "★★★  EPIC"
			"legendary": badge = "★★★★  LEGENDARY"
			_:           badge = rarity.to_upper()
		rarity_lbl.text = badge
		rarity_lbl.add_theme_color_override("font_color", rarity_color.lightened(0.25))
		rarity_lbl.show()
	else:
		rarity_lbl.hide()

	# ── Description ───────────────────────────────────────────────────
	vbox.get_node("DescriptionLabel").text = data.get("description", "")

	# ── Stats ─────────────────────────────────────────────────────────
	var cost_lbl     = stats_box.get_node("CostLabel")
	var cat_lbl      = stats_box.get_node("CategoryLabel")
	var dmg_lbl      = stats_box.get_node("DamageLabel")
	var rng_lbl      = stats_box.get_node("RangeLabel")
	var rate_lbl     = stats_box.get_node("FireRateLabel")

	# Cost
	if data.has("cost"):
		cost_lbl.text = "Cost:    %d Gold" % data.get("cost", 0)
		cost_lbl.show()
	else:
		cost_lbl.hide()

	# Category / attack type
	var cat = data.get("category", "")
	if cat != "":
		cat_lbl.text = "Type:    %s" % cat
		cat_lbl.show()
	else:
		cat_lbl.hide()

	# Damage
	if data.has("damage"):
		var dmg = data.get("damage", 0)
		dmg_lbl.text = "Damage:  %s" % (str(dmg) if dmg > 0 else "--")
		dmg_lbl.show()
	else:
		dmg_lbl.hide()

	# Range
	if data.has("range"):
		rng_lbl.text = "Range:   %d" % data.get("range", 0)
		rng_lbl.show()
	else:
		rng_lbl.hide()

	# Fire rate — rof is seconds between shots, convert to attacks/s
	if data.has("fire_rate"):
		rate_lbl.text = "Rate:    %s" % data.get("fire_rate", "Normal")
		rate_lbl.show()
	elif data.has("rof"):
		var rof_s  = max(data.get("rof", 1.0), 0.01)
		var aps    = 1.0 / rof_s
		var rating: String
		if   aps >= 4.0: rating = "Very Fast"
		elif aps >= 2.0: rating = "Fast"
		elif aps >= 1.0: rating = "Normal"
		elif aps >= 0.6: rating = "Slow"
		else:            rating = "Very Slow"
		rate_lbl.text = "Rate:    %s  (%.1f/s)" % [rating, aps]
		rate_lbl.show()
	else:
		rate_lbl.hide()

func show_tooltip() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property($PanelContainer, "modulate:a", 1.0, 0.15)

func hide_tooltip() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property($PanelContainer, "modulate:a", 0.0, 0.15)

func _process(_delta: float) -> void:
	var mouse_pos    = get_viewport().get_mouse_position()
	var tooltip_size = $PanelContainer.size
	var screen_size  = get_viewport().get_visible_rect().size

	# Default: float ABOVE and slightly right of the cursor
	# (good for the bottom card-bar)
	var new_pos = Vector2(mouse_pos.x + 15, mouse_pos.y - tooltip_size.y - 15)

	# Clamp to screen
	if new_pos.x + tooltip_size.x > screen_size.x:
		new_pos.x = mouse_pos.x - tooltip_size.x - 15
	if new_pos.y < 0:
		new_pos.y = mouse_pos.y + 20

	$PanelContainer.position = new_pos
