extends PanelContainer
## QuestHUD — Small in-game overlay showing the current map's quest objectives.
## Only visible during story mode runs (GameData.selected_chapter >= 1).
## Anchored to the top-right corner of the UI CanvasLayer.

var _objective_labels: Dictionary = {}  # obj_id → Label
var _content_container: VBoxContainer = null
var _is_collapsed: bool = false
var _toggle_btn: Button = null

func _ready() -> void:
	var ch: int = GameData.selected_chapter
	var m: int  = GameData.selected_map_index

	# Hide entirely when not in story mode.
	if ch < 1 or m < 1:
		hide()
		return

	_build_panel(ch, m)
	QuestManager.quest_updated.connect(_on_quest_updated)
	QuestManager.quest_completed.connect(_on_quest_completed)

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_panel(ch: int, m: int) -> void:
	# Panel background style
	UIThemeHelper.apply_panel_style(self, true)  # subtle=true for compact HUD look

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 4)
	margin.add_child(root_vb)

	# Header row with collapse toggle
	var header_row := HBoxContainer.new()
	root_vb.add_child(header_row)

	# Header — "Chapter N · Map M"
	var is_boss  := (m == 5)
	var map_text := ("Boss" if is_boss else "Map %d" % m)
	var header := Label.new()
	header.text = "Ch.%d  %s  — Quests" % [ch, map_text]
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_GOLD)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)

	_toggle_btn = Button.new()
	_toggle_btn.text = "▴"
	_toggle_btn.custom_minimum_size = Vector2(36, 36)
	_toggle_btn.flat = true
	_toggle_btn.add_theme_font_size_override("font_size", 16)
	_toggle_btn.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_MUTED)
	_toggle_btn.pressed.connect(_on_toggle_collapsed)
	header_row.add_child(_toggle_btn)

	var separator := HSeparator.new()
	root_vb.add_child(separator)

	# Content container (can be hidden for collapse)
	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 4)
	root_vb.add_child(_content_container)

	# One label per objective (skip already-claimed ones)
	var objectives := QuestManager.get_objectives_for_map(ch, m)
	for obj in objectives:
		if obj.get("claimed", false):
			continue
		var lbl := Label.new()
		lbl.name = "Obj_" + obj["id"]
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_CREAM)
		_objective_labels[obj["id"]] = lbl
		_content_container.add_child(lbl)
		_refresh_label(obj["id"])

	# If everything is already claimed, show a completion message.
	if _objective_labels.is_empty():
		var done_lbl := Label.new()
		done_lbl.text = "✔  All objectives complete!"
		done_lbl.add_theme_font_size_override("font_size", 16)
		done_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_RARITY_COMMON)
		_content_container.add_child(done_lbl)

func _on_toggle_collapsed() -> void:
	_is_collapsed = not _is_collapsed
	if _content_container:
		_content_container.visible = not _is_collapsed
	if _toggle_btn:
		_toggle_btn.text = "▾" if _is_collapsed else "▴"

# ---------------------------------------------------------------------------
# Refresh helpers
# ---------------------------------------------------------------------------

func _refresh_label(obj_id: String) -> void:
	var lbl: Label = _objective_labels.get(obj_id)
	if lbl == null:
		return
	var ch: int = GameData.selected_chapter
	var m: int  = GameData.selected_map_index
	var objectives := QuestManager.get_objectives_for_map(ch, m)
	for obj in objectives:
		if obj["id"] != obj_id:
			continue
		var completed : bool = obj.get("completed", false)
		var progress  : int  = obj.get("progress", 0)
		var target    : int  = obj.get("target", 1)
		if completed:
			lbl.text = "✔  " + obj.get("title", "")
			lbl.add_theme_color_override("font_color", UIThemeHelper.COL_RARITY_COMMON)
		else:
			lbl.text = "○  %s  (%d / %d)" % [obj.get("title", ""), progress, target]
			lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT_CREAM)
		return

# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------

func _on_quest_updated(obj_id: String) -> void:
	if _objective_labels.has(obj_id):
		_refresh_label(obj_id)


func _on_quest_completed(obj_id: String) -> void:
	if _objective_labels.has(obj_id):
		_refresh_label(obj_id)
