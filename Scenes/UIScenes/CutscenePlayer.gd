extends CanvasLayer
## CutscenePlayer — Stardew/CrossCode-style cutscene and dialogue renderer.
##
## Usage:
##   var player = CutscenePlayer.new()   # or added via CutsceneManager
##   add_child(player)
##   player.play_sequence(StoryData.get_sequence("ch1_intro"))
##   await player.sequence_finished
##
## Sequence step formats:
##   ["panel",    title: String, body: String]
##   ["panel",    title: String, body: String, tint: Color]  ← optional bg tint
##   ["dialogue", speaker: String, text: String]

signal sequence_finished

const CHARS_PER_SEC: float = 45.0
const LETTERBOX_HEIGHT: float = 70.0

const PORTRAIT_MAP: Dictionary = {
	"Amaru":      "res://Assets/Portraits/Amaru_portrait.png",
	"Alon":       "res://Assets/Portraits/Alon_portrait.png",
	"Lola Mutya": "res://Assets/Portraits/ApungMutya_portrait.png",
}

## Per-speaker pitch for the typing blip — gives each character a distinct voice.
const VOICE_PITCH: Dictionary = {
	"Amaru":      1.0,
	"Alon":       1.25,
	"Lola Mutya": 0.82,
}

## Per-speaker name colour shown in the dialogue box.
const SPEAKER_COLOR: Dictionary = {
	"Amaru":      Color(1.0, 0.84, 0.38),
	"Alon":       Color(0.4, 0.85, 0.9),
	"Lola Mutya": Color(0.95, 0.7, 0.6),
}

# ---- Full-screen panel nodes ------------------------------------------------
var _fs_root: Control
var _fs_bg_art: ColorRect
var _fs_title: Label
var _fs_body: RichTextLabel
var _fs_hint: Label

# ---- Dialogue-box nodes -----------------------------------------------------
var _dlg_root: Control
var _dlg_portrait_panel: PanelContainer
var _dlg_portrait: TextureRect
var _dlg_speaker: Label
var _dlg_text: RichTextLabel
var _dlg_hint: Label

# ---- Letterbox bars ---------------------------------------------------------
var _lb_top: ColorRect
var _lb_bottom: ColorRect
var _lb_tween: Tween = null

# ---- Voice / blip audio -----------------------------------------------------
var _voice_player: AudioStreamPlayer
var _chars_since_blip: int = 0
var _current_pitch: float = 1.0
var _prev_visible: int = 0

# ---- Typewriter state -------------------------------------------------------
var _steps: Array = []
var _step_idx: int = 0
var _full_text: String = ""
var _is_typing: bool = false
var _elapsed: float = 0.0

# ---- Cached current step kind for _process ----------------------------------
var _current_kind: String = ""

# ---- Transition / animation state -------------------------------------------
var _last_speaker: String = ""
var _dlg_visible: bool = false
var _hint_tween: Tween = null

# ---------------------------------------------------------------------------
func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_build_fullscreen_panel()
	_build_dialogue_box()
	_build_letterbox()
	_build_voice_player()
	_hide_all()

# ---------------------------------------------------------------------------
# UI construction — full-screen panel
# ---------------------------------------------------------------------------

func _build_fullscreen_panel() -> void:
	_fs_root = Control.new()
	_fs_root.name = "FullscreenPanel"
	_fs_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fs_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_fs_root.gui_input.connect(_on_fs_gui_input)
	add_child(_fs_root)

	# Dark overlay background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fs_root.add_child(bg)

	# Background art placeholder — tintable per chapter; replace ColorRect with
	# TextureRect once backdrop assets are added to Assets/Cutscenes/Backdrops/.
	_fs_bg_art = ColorRect.new()
	_fs_bg_art.name = "BackgroundArt"
	_fs_bg_art.color = Color(0.10, 0.08, 0.18, 1.0)
	_fs_bg_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fs_bg_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fs_root.add_child(_fs_bg_art)

	var bg_art_lbl := Label.new()
	bg_art_lbl.text = "[background art]"
	bg_art_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg_art_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	bg_art_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_art_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_art_lbl.add_theme_font_size_override("font_size", 20)
	bg_art_lbl.add_theme_color_override("font_color", Color(0.30, 0.28, 0.42))
	_fs_root.add_child(bg_art_lbl)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fs_root.add_child(dim)

	# Centered content container — 1400 px wide for 2400×1080 landscape canvas
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fs_root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(1400, 0)
	vbox.add_theme_constant_override("separation", 28)
	center.add_child(vbox)

	# Title
	_fs_title = Label.new()
	_fs_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fs_title.add_theme_font_size_override("font_size", 42)
	_fs_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38))
	_fs_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_fs_title)

	# Decorative separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(1.0, 0.84, 0.38, 0.4))
	sep.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(sep)

	# Body text
	_fs_body = RichTextLabel.new()
	_fs_body.bbcode_enabled = true
	_fs_body.scroll_active = false
	_fs_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_fs_body.custom_minimum_size = Vector2(1400, 300)
	_fs_body.fit_content = true
	_fs_body.add_theme_font_size_override("normal_font_size", 22)
	_fs_body.add_theme_color_override("default_color", Color(0.91, 0.88, 0.82))
	vbox.add_child(_fs_body)

	# "Tap to continue" hint — hidden while typing; shown + pulsed when done.
	_fs_hint = Label.new()
	_fs_hint.text = "▶  Tap to continue"
	_fs_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fs_hint.add_theme_font_size_override("font_size", 16)
	_fs_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_fs_hint.hide()
	vbox.add_child(_fs_hint)

	# Skip button — large touch target (160 × 88 px) anchored top-right
	var skip_container := Control.new()
	skip_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	skip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fs_root.add_child(skip_container)

	var skip_btn := _make_skip_button()
	skip_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.offset_left   = -180
	skip_btn.offset_top    = 90
	skip_btn.offset_right  = -20
	skip_btn.offset_bottom = 178
	skip_container.add_child(skip_btn)

# ---------------------------------------------------------------------------
# UI construction — dialogue box
# ---------------------------------------------------------------------------

func _build_dialogue_box() -> void:
	_dlg_root = Control.new()
	_dlg_root.name = "DialogueBox"
	_dlg_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dlg_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_dlg_root.gui_input.connect(_on_dlg_gui_input)
	add_child(_dlg_root)

	# Semi-transparent overlay dims the game scene underneath
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.45)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg_root.add_child(overlay)

	# Bottom panel — 380 px tall for comfortable reading on a 1080-px canvas
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top    = -380
	panel.offset_left   = 50
	panel.offset_right  = -50
	panel.offset_bottom = -90

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color     = Color(0.05, 0.04, 0.10, 0.94)
	panel_style.border_color = Color(1.0, 0.84, 0.38, 0.65)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	_dlg_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   32)
	margin.add_theme_constant_override("margin_right",  32)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 28)
	margin.add_child(hbox)

	# Portrait panel — 240×316 px for clear visibility on 2400-px wide canvas
	_dlg_portrait_panel = PanelContainer.new()
	_dlg_portrait_panel.custom_minimum_size = Vector2(240, 316)
	# Centre pivot so the pop-in scale animation grows from the middle
	_dlg_portrait_panel.pivot_offset = Vector2(120.0, 158.0)

	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color     = Color(0.12, 0.11, 0.18)
	portrait_style.border_color = Color(1.0, 0.84, 0.38, 0.45)
	portrait_style.set_border_width_all(2)
	portrait_style.set_corner_radius_all(10)
	_dlg_portrait_panel.add_theme_stylebox_override("panel", portrait_style)

	_dlg_portrait = TextureRect.new()
	_dlg_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dlg_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dlg_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dlg_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dlg_portrait.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_dlg_portrait_panel.add_child(_dlg_portrait)
	hbox.add_child(_dlg_portrait_panel)

	# Right side: speaker name + dialogue text + hint
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(text_vbox)

	_dlg_speaker = Label.new()
	_dlg_speaker.add_theme_font_size_override("font_size", 24)
	_dlg_speaker.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38))
	text_vbox.add_child(_dlg_speaker)

	_dlg_text = RichTextLabel.new()
	_dlg_text.bbcode_enabled  = true
	_dlg_text.scroll_active   = false
	_dlg_text.autowrap_mode   = TextServer.AUTOWRAP_WORD
	_dlg_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dlg_text.add_theme_font_size_override("normal_font_size", 20)
	_dlg_text.add_theme_color_override("default_color", Color(0.92, 0.90, 0.85))
	text_vbox.add_child(_dlg_text)

	# Hint — hidden while typing; shown + pulsed when done.
	_dlg_hint = Label.new()
	_dlg_hint.text = "▶  Tap to continue"
	_dlg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dlg_hint.add_theme_font_size_override("font_size", 15)
	_dlg_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_dlg_hint.hide()
	text_vbox.add_child(_dlg_hint)

	# Skip button — large touch target (160 × 88 px) anchored top-right
	var skip_container := Control.new()
	skip_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	skip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg_root.add_child(skip_container)

	var skip_btn := _make_skip_button()
	skip_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.offset_left   = -180
	skip_btn.offset_top    = 90
	skip_btn.offset_right  = -20
	skip_btn.offset_bottom = 178
	skip_container.add_child(skip_btn)

# ---------------------------------------------------------------------------
# UI construction — cinematic letterbox bars
# ---------------------------------------------------------------------------

func _build_letterbox() -> void:
	_lb_top = ColorRect.new()
	_lb_top.name = "LetterboxTop"
	_lb_top.color = Color.BLACK
	_lb_top.anchor_left   = 0.0
	_lb_top.anchor_top    = 0.0
	_lb_top.anchor_right  = 1.0
	_lb_top.anchor_bottom = 0.0
	_lb_top.offset_bottom = 0.0   # zero height = invisible at start
	_lb_top.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_lb_top)

	_lb_bottom = ColorRect.new()
	_lb_bottom.name = "LetterboxBottom"
	_lb_bottom.color = Color.BLACK
	_lb_bottom.anchor_left   = 0.0
	_lb_bottom.anchor_top    = 1.0
	_lb_bottom.anchor_right  = 1.0
	_lb_bottom.anchor_bottom = 1.0
	_lb_bottom.offset_top    = 0.0   # zero height = invisible at start
	_lb_bottom.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_lb_bottom)

# ---------------------------------------------------------------------------
# UI construction — voice / blip audio player
# ---------------------------------------------------------------------------

func _build_voice_player() -> void:
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "UI"
	var stream = load("res://Assets/Audio/SFX/OGG/Click_Lock_Beep_1.ogg")
	if stream:
		_voice_player.stream = stream
	add_child(_voice_player)

func _make_skip_button() -> Button:
	var btn := Button.new()
	btn.text = "Skip"
	btn.add_theme_font_size_override("font_size", 22)
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.1, 0.1, 0.15, 0.9)
	style.border_color = Color(0.7, 0.7, 0.7, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	var style_h := style.duplicate()
	style_h.bg_color = Color(0.2, 0.2, 0.3, 0.95)
	btn.add_theme_stylebox_override("hover", style_h)
	btn.pressed.connect(_on_skip_all)
	return btn

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Plays a sequence of step arrays. Emits sequence_finished when done.
func play_sequence(steps: Array) -> void:
	_steps    = steps
	_step_idx = 0
	_show_letterbox()
	_play_step()

# ---------------------------------------------------------------------------
# Letterbox helpers
# ---------------------------------------------------------------------------

func _show_letterbox() -> void:
	if _lb_tween:
		_lb_tween.kill()
	_lb_tween = create_tween().set_parallel(true) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_lb_tween.tween_property(_lb_top,    "offset_bottom", LETTERBOX_HEIGHT,  0.3)
	_lb_tween.tween_property(_lb_bottom, "offset_top",   -LETTERBOX_HEIGHT,  0.3)

func _hide_letterbox() -> void:
	if _lb_tween:
		_lb_tween.kill()
	_lb_tween = create_tween().set_parallel(true) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_lb_tween.tween_property(_lb_top,    "offset_bottom", 0.0, 0.3)
	_lb_tween.tween_property(_lb_bottom, "offset_top",    0.0, 0.3)

# ---------------------------------------------------------------------------
# Hint pulse helpers
# ---------------------------------------------------------------------------

func _start_hint_pulse(hint: Label) -> void:
	hint.modulate.a = 1.0
	hint.show()
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(hint, "modulate:a", 0.35, 0.45)
	_hint_tween.tween_property(hint, "modulate:a", 1.0,  0.45)

func _stop_hint_pulse(hint: Label) -> void:
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	hint.modulate.a = 1.0
	hint.hide()

# ---------------------------------------------------------------------------
# Blip helper
# ---------------------------------------------------------------------------

func _play_blip() -> void:
	if not _voice_player or not _voice_player.stream:
		return
	_voice_player.pitch_scale = _current_pitch + randf_range(-0.04, 0.04)
	_voice_player.play()

# ---------------------------------------------------------------------------
# Step playback internals
# ---------------------------------------------------------------------------

func _play_step() -> void:
	if _step_idx >= _steps.size():
		_hide_all()
		sequence_finished.emit()
		return

	var step: Array = _steps[_step_idx]
	_current_kind = step[0] if step.size() > 0 else ""

	if step.size() < 3:
		_step_idx += 1
		_play_step()
		return

	match _current_kind:
		"panel":
			var tint := Color(0.10, 0.08, 0.18, 1.0)
			if step.size() >= 4 and step[3] is Color:
				tint = step[3]
			_show_panel(str(step[1]), str(step[2]), tint)
		"dialogue":
			_show_dialogue(str(step[1]), str(step[2]))
		_:
			# Unknown step kind — skip it.
			_step_idx += 1
			_play_step()

func _show_panel(title: String, body: String, tint: Color = Color(0.10, 0.08, 0.18, 1.0)) -> void:
	_fs_bg_art.color = tint
	_fs_title.text   = title
	_full_text       = body
	_fs_body.text    = body
	_fs_body.visible_characters = 0
	_elapsed      = 0.0
	_is_typing    = true
	_prev_visible = 0
	_fs_hint.hide()
	_dlg_root.hide()
	_dlg_visible = false
	# Fade the panel in from transparent
	_fs_root.modulate.a = 0.0
	_fs_root.show()
	var fade := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	fade.tween_property(_fs_root, "modulate:a", 1.0, 0.35)
	set_process(true)

func _show_dialogue(speaker: String, text: String) -> void:
	# Speaker name + colour
	_dlg_speaker.text = speaker
	_dlg_speaker.add_theme_color_override(
		"font_color", SPEAKER_COLOR.get(speaker, Color(1.0, 0.84, 0.38)))

	# Portrait
	var portrait_path: String = PORTRAIT_MAP.get(speaker, "")
	_dlg_portrait.texture = load(portrait_path) if portrait_path else null

	# Portrait pop-in when the speaker changes (Stardew-style)
	if speaker != _last_speaker:
		_last_speaker = speaker
		_dlg_portrait_panel.scale = Vector2(0.88, 0.88)
		var pop := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		pop.tween_property(_dlg_portrait_panel, "scale", Vector2.ONE, 0.14)

	# Text + typing state
	_full_text = text
	_dlg_text.text = text
	_dlg_text.visible_characters = 0
	_elapsed          = 0.0
	_is_typing        = true
	_prev_visible     = 0
	_chars_since_blip = 0
	_current_pitch    = VOICE_PITCH.get(speaker, 1.0)
	_dlg_hint.hide()
	_fs_root.hide()

	# Slide-in + fade-in from bottom the first time the dialogue box appears
	if not _dlg_visible:
		_dlg_visible        = true
		_dlg_root.modulate.a = 0.0
		_dlg_root.position.y = 80.0
		_dlg_root.show()
		var slide := create_tween().set_parallel(true) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		slide.tween_property(_dlg_root, "position:y", 0.0, 0.25)
		slide.tween_property(_dlg_root, "modulate:a", 1.0, 0.20)
	else:
		_dlg_root.show()

	set_process(true)

func _process(delta: float) -> void:
	if not _is_typing:
		return
	_elapsed += delta
	var target := int(_elapsed * CHARS_PER_SEC)
	match _current_kind:
		"panel":
			_fs_body.visible_characters = target
			if target >= _fs_body.get_total_character_count():
				_is_typing = false
				_fs_body.visible_characters = -1
				set_process(false)
				_start_hint_pulse(_fs_hint)
		"dialogue":
			# Fire a blip every 2 newly-revealed characters
			var revealed := target - _prev_visible
			_prev_visible = target
			if revealed > 0:
				_chars_since_blip += revealed
				if _chars_since_blip >= 2:
					_chars_since_blip = _chars_since_blip % 2
					_play_blip()
			_dlg_text.visible_characters = target
			if target >= _dlg_text.get_total_character_count():
				_is_typing = false
				_dlg_text.visible_characters = -1
				set_process(false)
				_start_hint_pulse(_dlg_hint)

## Advances or instant-reveals, depending on typing state.
func _advance() -> void:
	if _is_typing:
		# First tap: instant-reveal current step.
		_is_typing = false
		set_process(false)
		match _current_kind:
			"panel":
				_fs_body.visible_characters = -1
				_start_hint_pulse(_fs_hint)
			"dialogue":
				_dlg_text.visible_characters = -1
				_start_hint_pulse(_dlg_hint)
	else:
		# Second tap: stop pulsing and move to next step.
		match _current_kind:
			"panel":    _stop_hint_pulse(_fs_hint)
			"dialogue": _stop_hint_pulse(_dlg_hint)
		_step_idx += 1
		_play_step()

# ---------------------------------------------------------------------------
# Input handlers — mouse + touchscreen
# ---------------------------------------------------------------------------

func _on_fs_gui_input(event: InputEvent) -> void:
	var is_tap: bool = (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if is_tap:
		_advance()
		get_viewport().set_input_as_handled()

func _on_dlg_gui_input(event: InputEvent) -> void:
	var is_tap: bool = (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if is_tap:
		_advance()
		get_viewport().set_input_as_handled()

func _on_skip_all() -> void:
	_hide_all()
	sequence_finished.emit()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _hide_all() -> void:
	_fs_root.hide()
	_dlg_root.hide()
	_dlg_root.position  = Vector2.ZERO
	_dlg_root.modulate.a = 1.0
	_dlg_visible  = false
	_last_speaker = ""
	_is_typing    = false
	set_process(false)
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	_fs_hint.hide()
	_dlg_hint.hide()
	_hide_letterbox()
