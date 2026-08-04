extends Control
## LoadingScreen — full-screen transition screen shown between scene changes.
## Usage: call LoadingScreen.change_scene(tree, path) as a static helper, OR
##        use the scene directly by instantiating it and calling begin(target_path).

signal transition_done

var _target_path: String = ""
var _min_display_timer: float = 0.0
var _scene_preloaded: bool = false
var _packed: PackedScene = null

const MIN_DISPLAY_SEC := 0.4   # minimum time the screen is visible before switching

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	_build_ui()

func _build_ui() -> void:
	# Dark parchment background
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.04, 0.01, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centered content
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 24)
	center.add_child(vb)

	# Loading label
	var title := Label.new()
	title.text = "Loading..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32))
	vb.add_child(title)

	# Spinner row
	var spinner_lbl := Label.new()
	spinner_lbl.name = "Spinner"
	spinner_lbl.text = "⟳"
	spinner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spinner_lbl.add_theme_font_size_override("font_size", 36)
	spinner_lbl.add_theme_color_override("font_color", Color(0.78, 0.58, 0.20))
	vb.add_child(spinner_lbl)

	# Loading dots label
	var dots := Label.new()
	dots.name = "Dots"
	dots.text = "Loading…"
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.add_theme_font_size_override("font_size", 16)
	dots.add_theme_color_override("font_color", Color(0.55, 0.42, 0.22))
	vb.add_child(dots)

	# Gold border rule at bottom
	var rule := ColorRect.new()
	rule.color = Color(0.78, 0.58, 0.20, 0.35)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rule.anchor_top = 1.0
	rule.offset_top = -2
	add_child(rule)

	# Animate the spinner
	_start_spinner_anim(spinner_lbl)
	# Fade in
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)

func _start_spinner_anim(lbl: Label) -> void:
	var frames := ["⟳", "↻", "↺", "⟲"]
	var idx := 0
	var t := create_tween().set_loops()
	t.tween_interval(0.15)
	t.tween_callback(func():
		lbl.text = frames[idx % frames.size()]
		idx += 1
	)

func _process(delta: float) -> void:
	if _target_path.is_empty():
		return
	_min_display_timer -= delta
	if _min_display_timer <= 0.0 and _scene_preloaded:
		_do_switch()

## Begin the transition: preloads the target scene in the background,
## then switches once MIN_DISPLAY_SEC has elapsed.
func begin(target_path: String) -> void:
	_target_path = target_path
	_min_display_timer = MIN_DISPLAY_SEC
	_scene_preloaded = false
	# Preload in the background using a thread-safe approach
	ResourceLoader.load_threaded_request(target_path)
	_poll_preload()

func _poll_preload() -> void:
	var status := ResourceLoader.load_threaded_get_status(_target_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_packed = ResourceLoader.load_threaded_get(_target_path)
		_scene_preloaded = true
	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		_poll_preload()
	else:
		# Fallback: synchronous load
		_packed = load(_target_path)
		_scene_preloaded = true

func _do_switch() -> void:
	if _packed == null:
		push_error("LoadingScreen: failed to load scene: %s" % _target_path)
		get_tree().change_scene_to_file(_target_path)
		return
	get_tree().change_scene_to_packed(_packed)
