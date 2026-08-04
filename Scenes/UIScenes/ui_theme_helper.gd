## UIThemeHelper — static utility class providing the Fantasy RPG design system.
## Usage (no instance needed):
##   UIThemeHelper.apply_button_theme(my_button, "primary")
##   UIThemeHelper.apply_panel_style(my_panel)
##   UIThemeHelper.animate_panel_in(my_panel)
class_name UIThemeHelper

# ─── Fantasy RPG Color Palette ────────────────────────────────────────────────

# Panels / backgrounds  — dark warm parchment
const COL_PANEL_BG         := Color(0.10, 0.06, 0.02, 0.96)
const COL_PANEL_BORDER      := Color(0.78, 0.58, 0.20, 1.0)   # aged gold
const COL_PANEL_BORDER_DIM  := Color(0.48, 0.34, 0.10, 0.60)  # subtle gold

# Primary buttons  — amber/gold  (main CTAs)
const COL_BTN_PRIMARY_N    := Color(0.30, 0.15, 0.04, 1.0)
const COL_BTN_PRIMARY_H    := Color(0.44, 0.24, 0.07, 1.0)
const COL_BTN_PRIMARY_P    := Color(0.18, 0.09, 0.02, 1.0)

# Secondary buttons  — muted dark amber  (less emphasis)
const COL_BTN_SECONDARY_N  := Color(0.18, 0.10, 0.03, 0.92)
const COL_BTN_SECONDARY_H  := Color(0.28, 0.16, 0.05, 1.0)
const COL_BTN_SECONDARY_P  := Color(0.12, 0.06, 0.02, 1.0)

# Danger buttons  — dark red  (sell / quit / destructive actions)
const COL_BTN_DANGER_N     := Color(0.30, 0.07, 0.06, 1.0)
const COL_BTN_DANGER_H     := Color(0.44, 0.12, 0.10, 1.0)
const COL_BTN_DANGER_P     := Color(0.20, 0.04, 0.04, 1.0)

# Border colors per variant
const COL_BORDER_PRIMARY   := Color(0.95, 0.75, 0.25, 1.0)   # bright gold
const COL_BORDER_SECONDARY := Color(0.62, 0.46, 0.16, 0.85)
const COL_BORDER_DANGER    := Color(0.90, 0.28, 0.18, 1.0)   # red-orange

# Text
const COL_TEXT_CREAM       := Color(1.00, 0.95, 0.85, 1.0)
const COL_TEXT_GOLD        := Color(0.95, 0.78, 0.32, 1.0)
const COL_TEXT_MUTED       := Color(0.68, 0.55, 0.36, 1.0)
const COL_TEXT_WHITE       := Color(1.00, 1.00, 1.00, 1.0)
const COL_TEXT_DISABLED    := Color(0.50, 0.43, 0.33, 0.55)

# Rarity  (mirrors existing RaritySystem constants for easy use in UI code)
const COL_RARITY_COMMON    := Color(0.35, 0.95, 0.35, 1.0)
const COL_RARITY_RARE      := Color(0.45, 0.65, 1.00, 1.0)
const COL_RARITY_LEGENDARY := Color(1.00, 0.80, 0.20, 1.0)

# Shared geometry
const CORNER_RADIUS        := 12
const BORDER_WIDTH         := 3
const BTN_MIN_H            := 60   # minimum touch target height (mobile)

# ─── Internal StyleBox factory ────────────────────────────────────────────────

static func _flat(bg: Color, border: Color,
		corner: int = CORNER_RADIUS, bw: int = BORDER_WIDTH) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(corner)
	return s

# ─── Public style factories ───────────────────────────────────────────────────

## Returns a panel StyleBoxFlat.
## subtle=true gives a lighter, inline-panel look (smaller border, less opaque).
static func make_panel_style(subtle: bool = false) -> StyleBoxFlat:
	if subtle:
		return _flat(Color(0.07, 0.04, 0.01, 0.88), COL_PANEL_BORDER_DIM, 8, 2)
	return _flat(COL_PANEL_BG, COL_PANEL_BORDER, CORNER_RADIUS, BORDER_WIDTH)

## Returns a button StyleBoxFlat for the given variant + state.
## variant: "primary" | "secondary" | "danger"
## state  : "normal"  | "hover"     | "pressed"
static func make_button_style(variant: String, state: String) -> StyleBoxFlat:
	match variant:
		"primary":
			match state:
				"hover":   return _flat(COL_BTN_PRIMARY_H, COL_BORDER_PRIMARY)
				"pressed": return _flat(COL_BTN_PRIMARY_P, COL_BORDER_PRIMARY)
				_:         return _flat(COL_BTN_PRIMARY_N, COL_BORDER_PRIMARY)
		"danger":
			match state:
				"hover":   return _flat(COL_BTN_DANGER_H, COL_BORDER_DANGER)
				"pressed": return _flat(COL_BTN_DANGER_P, COL_BORDER_DANGER)
				_:         return _flat(COL_BTN_DANGER_N, COL_BORDER_DANGER)
		_: # "secondary" + fallback
			match state:
				"hover":   return _flat(COL_BTN_SECONDARY_H, COL_BORDER_SECONDARY)
				"pressed": return _flat(COL_BTN_SECONDARY_P, COL_BORDER_SECONDARY)
				_:         return _flat(COL_BTN_SECONDARY_N, COL_BORDER_SECONDARY)

# ─── High-level appliers ──────────────────────────────────────────────────────

## Apply the Fantasy RPG panel style to any PanelContainer.
static func apply_panel_style(panel: PanelContainer, subtle: bool = false) -> void:
	panel.add_theme_stylebox_override("panel", make_panel_style(subtle))

## Apply all button theme overrides for the given variant.
## variant : "primary" | "secondary" | "danger"
## font_size: default 32 (scales down for small buttons)
static func apply_button_theme(btn: Button, variant: String = "primary",
		font_size: int = 32) -> void:
	btn.add_theme_stylebox_override("normal",   make_button_style(variant, "normal"))
	btn.add_theme_stylebox_override("hover",    make_button_style(variant, "hover"))
	btn.add_theme_stylebox_override("pressed",  make_button_style(variant, "pressed"))
	btn.add_theme_stylebox_override("focus",    make_button_style(variant, "normal"))
	btn.add_theme_stylebox_override("disabled",
		_flat(Color(0.12, 0.07, 0.03, 0.50), Color(0.38, 0.28, 0.10, 0.40)))
	btn.add_theme_color_override("font_color",          COL_TEXT_CREAM)
	btn.add_theme_color_override("font_hover_color",    COL_TEXT_WHITE)
	btn.add_theme_color_override("font_pressed_color",  COL_TEXT_CREAM)
	btn.add_theme_color_override("font_disabled_color", COL_TEXT_DISABLED)
	btn.add_theme_font_size_override("font_size", font_size)
	if btn.custom_minimum_size.y < BTN_MIN_H:
		btn.custom_minimum_size.y = BTN_MIN_H

## Style a Label as a heading.
## color defaults to COL_TEXT_GOLD; pass a custom Color to override.
static func apply_heading(lbl: Label, font_size: int = 28,
		color: Color = COL_TEXT_GOLD) -> void:
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)

## Apply body-text styling (cream, readable size).
static func apply_body(lbl: Label, font_size: int = 18) -> void:
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", COL_TEXT_CREAM)

## Apply muted/sub-text styling.
static func apply_muted(lbl: Label, font_size: int = 14) -> void:
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", COL_TEXT_MUTED)

# ─── Widget factories ─────────────────────────────────────────────────────────

## Create a decorative section separator line with gold tint.
static func make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = COL_PANEL_BORDER_DIM
	s.set_corner_radius_all(1)
	sep.add_theme_stylebox_override("separator", s)
	sep.add_theme_constant_override("separation", 10)
	return sep

## Create a small section-label used as a visual divider between button groups.
## e.g. UIThemeHelper.make_section_label("─── PLAY ───")
static func make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COL_TEXT_MUTED)
	return lbl

## Create a fully styled Button in one call.
static func make_button(text: String, variant: String = "primary",
		font_size: int = 32, min_width: float = 0.0) -> Button:
	var btn := Button.new()
	btn.text = text
	if min_width > 0.0:
		btn.custom_minimum_size = Vector2(min_width, BTN_MIN_H)
	apply_button_theme(btn, variant, font_size)
	return btn

# ─── Animation helpers ────────────────────────────────────────────────────────

## Slide-in + fade-in tween for modals/panels.
## Call after the node is added to the scene tree.
static func animate_panel_in(panel: Control, duration: float = 0.22) -> void:
	var orig_y: float = panel.position.y
	panel.position.y = orig_y + 20.0
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "position:y", orig_y, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(panel, "modulate:a", 1.0, duration) \
		.set_ease(Tween.EASE_OUT)

## Scale-punch tween (emphasise a win/unlock moment).
static func animate_scale_punch(node: Control, peak: float = 1.15,
		duration: float = 0.30) -> void:
	node.pivot_offset = node.size / 2.0
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(peak, peak), duration * 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(node, "scale", Vector2.ONE, duration * 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

## Simple screen-shake: displaces a node's position briefly.
static func animate_shake(node: Control, intensity: float = 8.0,
		duration: float = 0.35) -> void:
	var origin: Vector2 = node.position
	var tw := node.create_tween()
	tw.set_loops(6)
	tw.tween_property(node, "position",
		origin + Vector2(randf_range(-intensity, intensity),
						 randf_range(-intensity, intensity)), duration / 12.0)
	tw.tween_callback(func(): node.position = origin)
