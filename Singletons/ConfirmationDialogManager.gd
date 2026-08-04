extends CanvasLayer
## ConfirmationDialogManager — Reusable confirmation dialog system.
## Displays styled confirmation dialogs using the fantasy RPG design system.
##
## Usage:
##   ConfirmationDialogManager.show_confirmation(
##       "Confirm Action",
##       "Are you sure you want to do this?",
##       func(): print("Confirmed!"),
##       func(): print("Cancelled!")
##   )

var _audio_manager: Node
var _current_dialog: Node = null
var _current_dimmer: Node = null
var _confirmed_callback: Callable
var _cancelled_callback: Callable

func _ready() -> void:
	_audio_manager = get_node_or_null("/root/AudioManager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000  # Ensure dialogs appear on top of game content


func show_confirmation(
	title: String,
	message: String,
	confirmed_callback: Callable,
	cancelled_callback: Callable = func(): pass
) -> void:
	# Close any existing dialog before showing a new one
	_cleanup()
	_confirmed_callback = confirmed_callback
	_cancelled_callback = cancelled_callback
	_create_dialog_ui(title, message)


func _create_dialog_ui(title: String, message: String) -> void:
	# Full-screen dimmer — clicking it cancels the dialog
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.55)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_on_cancel()
	)
	add_child(dimmer)
	_current_dimmer = dimmer

	# Main dialog panel
	var dialog_panel := PanelContainer.new()
	dialog_panel.name = "ConfirmationDialog"
	dialog_panel.custom_minimum_size = Vector2(400, 0)
	UIThemeHelper.apply_panel_style(dialog_panel)
	add_child(dialog_panel)
	_current_dialog = dialog_panel

	# MarginContainer provides inner padding (VBoxContainer does not support margin constants)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	dialog_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title_label := Label.new()
	title_label.text = title
	UIThemeHelper.apply_heading(title_label, 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(title_label)

	var message_label := Label.new()
	message_label.text = message
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIThemeHelper.apply_body(message_label, 16)
	message_label.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(message_label)

	vbox.add_child(UIThemeHelper.make_separator())

	var button_hbox := HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 12)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_hbox)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 0)
	UIThemeHelper.apply_button_theme(cancel_btn, "secondary", 18)
	cancel_btn.pressed.connect(_on_cancel)
	cancel_btn.mouse_entered.connect(_on_button_hover)
	button_hbox.add_child(cancel_btn)

	var ok_btn := Button.new()
	ok_btn.text = "Confirm"
	ok_btn.custom_minimum_size = Vector2(120, 0)
	UIThemeHelper.apply_button_theme(ok_btn, "danger", 18)
	ok_btn.pressed.connect(_on_confirm)
	ok_btn.mouse_entered.connect(_on_button_hover)
	button_hbox.add_child(ok_btn)

	# Wait one frame so the panel's size is calculated before centering/animating
	await get_tree().process_frame
	if is_instance_valid(_current_dialog):
		var viewport_size := get_viewport().get_visible_rect().size
		_current_dialog.position = (viewport_size - _current_dialog.size) / 2.0
		UIThemeHelper.animate_panel_in(_current_dialog)


func _on_confirm() -> void:
	if _audio_manager:
		_audio_manager.play_ui_sound("button_click")
	var callback := _confirmed_callback
	_cleanup()
	callback.call()


func _on_cancel() -> void:
	if _audio_manager:
		_audio_manager.play_ui_sound("button_click")
	var callback := _cancelled_callback
	_cleanup()
	callback.call()


func _on_button_hover() -> void:
	if _audio_manager:
		_audio_manager.play_ui_sound("button_hover")


func _cleanup() -> void:
	# Free dialog and dimmer individually.
	# Never call get_parent().queue_free() — get_parent() is this CanvasLayer singleton.
	if is_instance_valid(_current_dialog):
		_current_dialog.queue_free()
	_current_dialog = null
	if is_instance_valid(_current_dimmer):
		_current_dimmer.queue_free()
	_current_dimmer = null
	_confirmed_callback = func(): pass
	_cancelled_callback = func(): pass
