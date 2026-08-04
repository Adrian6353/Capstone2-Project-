extends Control

# ---------------------------------------------------------------------------
# Mode: "login" | "register" | "recovery" (reset password) | "recover_username"
# ---------------------------------------------------------------------------

var _mode: String = "login"
var _security_question_fetched: bool = false
var _loading_tween: Tween = null
var _loading_base: String = ""

const SECURITY_QUESTIONS = [
	"What was the name of your first pet?",
	"What city were you born in?",
	"What is your mother's maiden name?",
	"What was the name of your elementary school?",
	"What was your childhood nickname?"
]

# Node references (set in _ready)
@onready var _subtitle_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Subtitle
@onready var _status_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var _username_field: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/UsernameField
@onready var _email_field: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/EmailField
@onready var _password_field: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/PasswordField
@onready var _confirm_container: Control = $CenterContainer/PanelContainer/VBoxContainer/ConfirmPasswordContainer
@onready var _confirm_field: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/ConfirmPasswordContainer/ConfirmPasswordField
@onready var _security_container: Control = $CenterContainer/PanelContainer/VBoxContainer/SecurityQuestionContainer
@onready var _security_question_label: Label = $CenterContainer/PanelContainer/VBoxContainer/SecurityQuestionContainer/SecurityQuestionLabel
@onready var _security_question_option: OptionButton = $CenterContainer/PanelContainer/VBoxContainer/SecurityQuestionContainer/SecurityQuestionOptionButton
@onready var _security_answer_field: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/SecurityAnswerField
@onready var _new_password_container: Control = $CenterContainer/PanelContainer/VBoxContainer/NewPasswordContainer
@onready var _new_password_field: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/NewPasswordContainer/NewPasswordField
@onready var _confirm_new_container: Control = $CenterContainer/PanelContainer/VBoxContainer/ConfirmNewPasswordContainer
@onready var _confirm_new_field: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/ConfirmNewPasswordContainer/ConfirmNewPasswordField
@onready var _main_action_button: Button = $CenterContainer/PanelContainer/VBoxContainer/MainActionButton
@onready var _switch_mode_button: Button = $CenterContainer/PanelContainer/VBoxContainer/SwitchModeButton
@onready var _forgot_password_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ForgotPasswordButton
@onready var _forgot_username_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ForgotUsernameButton

func _ready():
	_setup_background()
	_style_buttons()
	_populate_security_questions()

	# Connect AccountManager signals
	AccountManager.account_authenticated.connect(_on_account_authenticated)
	AccountManager.login_required.connect(_on_login_required)
	AccountManager.session_invalidated.connect(_on_session_invalidated)
	AccountManager.auth_failed.connect(_on_auth_failed)
	AccountManager.username_found.connect(_on_username_found)

	# Connect buttons
	_main_action_button.pressed.connect(_on_main_action_pressed)
	_switch_mode_button.pressed.connect(_on_switch_mode_pressed)
	_forgot_password_button.pressed.connect(_on_forgot_password_pressed)
	_forgot_username_button.pressed.connect(_on_forgot_username_pressed)

	# Show connecting state while validating session
	_set_status("Connecting")
	_start_loading_animation("Connecting")
	_set_inputs_enabled(false)
	_update_visibility()

	await AccountManager.validate_session()

# ---------------------------------------------------------------------------
# AccountManager signal handlers
# ---------------------------------------------------------------------------

func _on_account_authenticated():
	get_tree().change_scene_to_file("res://Scenes/UIScenes/main_menu.tscn")

func _on_login_required():
	_stop_loading_animation()
	_set_status("")
	_set_inputs_enabled(true)
	_set_mode("login")

func _on_session_invalidated(_reason: String):
	_set_status("You were logged in on another device. Please log in again.")
	_set_inputs_enabled(true)
	_set_mode("login")

func _on_auth_failed(error: String):
	_stop_loading_animation()
	_set_status("⚠  " + error)
	_set_inputs_enabled(true)

func _on_username_found(username: String):
	_set_status("Your username is: " + username)
	_set_inputs_enabled(true)

# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_main_action_pressed():
	_set_status("")
	_set_inputs_enabled(false)

	match _mode:
		"login":
			var user = _username_field.text.strip_edges()
			var pw = _password_field.text
			if user.is_empty() or pw.is_empty():
				_set_status("Please enter username and password.")
				_set_inputs_enabled(true)
				return
			await AccountManager.login(user, pw)

		"register":
			var user = _username_field.text.strip_edges()
			var email = _email_field.text.strip_edges()
			var pw = _password_field.text
			var confirm = _confirm_field.text
			var question_idx = _security_question_option.selected
			var answer = _security_answer_field.text.strip_edges()

			if user.is_empty() or email.is_empty() or pw.is_empty():
				_set_status("Please fill in all fields.")
				_set_inputs_enabled(true)
				return
			if pw != confirm:
				_set_status("Passwords do not match.")
				_set_inputs_enabled(true)
				return
			if question_idx < 0:
				_set_status("Please select a security question.")
				_set_inputs_enabled(true)
				return
			if answer.is_empty():
				_set_status("Please enter a security answer.")
				_set_inputs_enabled(true)
				return

			var question = SECURITY_QUESTIONS[question_idx]
			await AccountManager.register(user, pw, email, question, answer)

		"recovery":
			var user = _username_field.text.strip_edges()
			if user.is_empty():
				_set_status("Please enter your username.")
				_set_inputs_enabled(true)
				return

			if not _security_question_fetched:
				# Step 1: fetch the question
				var q = await AccountManager.get_security_question(user)
				if q.begins_with("error:"):
					_set_status(q.substr(6))
					_set_inputs_enabled(true)
					return
				_security_question_label.text = q
				_security_question_fetched = true
				_security_container.visible = true
				_security_answer_field.visible = true
				_new_password_container.visible = true
				_confirm_new_container.visible = true
				_main_action_button.text = "Reset Password"
				_set_status("Answer your security question, then enter a new password.")
				_set_inputs_enabled(true)
			else:
				# Step 2: submit reset
				var answer = _security_answer_field.text.strip_edges()
				var new_pass = _new_password_field.text
				var confirm_new = _confirm_new_field.text
				if answer.is_empty() or new_pass.is_empty():
					_set_status("Please fill in answer and new password.")
					_set_inputs_enabled(true)
					return
				if new_pass != confirm_new:
					_set_status("New passwords do not match.")
					_set_inputs_enabled(true)
					return
				await AccountManager.reset_password(user, answer, new_pass)

		"recover_username":
			var email = _email_field.text.strip_edges()
			if email.is_empty():
				_set_status("Please enter your email address.")
				_set_inputs_enabled(true)
				return
			await AccountManager.get_username_by_email(email)
			# Result handled in _on_username_found / _on_auth_failed
			_set_inputs_enabled(true)

func _on_switch_mode_pressed():
	match _mode:
		"login":       _set_mode("register")
		_:             _set_mode("login")

func _on_forgot_password_pressed():
	_set_mode("recovery")

func _on_forgot_username_pressed():
	_set_mode("recover_username")

# ---------------------------------------------------------------------------
# Mode management
# ---------------------------------------------------------------------------

func _set_mode(mode: String):
	_mode = mode
	_security_question_fetched = false
	_set_status("")
	_clear_fields()
	_update_visibility()

func _update_visibility():
	match _mode:
		"login":
			_subtitle_label.text = "Login"
			_main_action_button.text = "Login"
			_switch_mode_button.text = "Create Account"
			_username_field.visible = true
			_email_field.visible = false
			_password_field.visible = true
			_password_field.placeholder_text = "Password"
			_confirm_container.visible = false
			_security_container.visible = false
			_security_answer_field.visible = false
			_new_password_container.visible = false
			_confirm_new_container.visible = false
			_forgot_password_button.visible = true
			_forgot_username_button.visible = true

		"register":
			_subtitle_label.text = "Create Account"
			_main_action_button.text = "Create Account"
			_switch_mode_button.text = "Back to Login"
			_username_field.visible = true
			_email_field.visible = true
			_password_field.visible = true
			_password_field.placeholder_text = "Password"
			_confirm_container.visible = true
			_security_container.visible = true
			_security_question_option.visible = true
			_security_question_label.visible = false
			_security_answer_field.visible = true
			_new_password_container.visible = false
			_confirm_new_container.visible = false
			_forgot_password_button.visible = false
			_forgot_username_button.visible = false

		"recovery":
			_subtitle_label.text = "Reset Password"
			_main_action_button.text = "Find My Account"
			_switch_mode_button.text = "Back to Login"
			_username_field.visible = true
			_email_field.visible = false
			_password_field.visible = false
			_confirm_container.visible = false
			_security_container.visible = false
			_security_answer_field.visible = false
			_new_password_container.visible = false
			_confirm_new_container.visible = false
			_forgot_password_button.visible = false
			_forgot_username_button.visible = false

		"recover_username":
			_subtitle_label.text = "Find Username"
			_main_action_button.text = "Find My Username"
			_switch_mode_button.text = "Back to Login"
			_username_field.visible = false
			_email_field.visible = true
			_password_field.visible = false
			_confirm_container.visible = false
			_security_container.visible = false
			_security_answer_field.visible = false
			_new_password_container.visible = false
			_confirm_new_container.visible = false
			_forgot_password_button.visible = false
			_forgot_username_button.visible = false

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------

func _set_status(text: String):
	_status_label.text = text
	_status_label.visible = not text.is_empty()

func _set_inputs_enabled(enabled: bool):
	_main_action_button.disabled = not enabled
	_switch_mode_button.disabled = not enabled
	_forgot_password_button.disabled = not enabled
	_forgot_username_button.disabled = not enabled
	_username_field.editable = enabled
	_email_field.editable = enabled
	_password_field.editable = enabled
	_confirm_field.editable = enabled
	_security_answer_field.editable = enabled
	_new_password_field.editable = enabled
	_confirm_new_field.editable = enabled

func _clear_fields():
	_username_field.text = ""
	_email_field.text = ""
	_password_field.text = ""
	_confirm_field.text = ""
	_security_answer_field.text = ""
	_new_password_field.text = ""
	_confirm_new_field.text = ""
	_security_question_label.text = ""

func _populate_security_questions():
	_security_question_option.clear()
	for q in SECURITY_QUESTIONS:
		_security_question_option.add_item(q)

# ---------------------------------------------------------------------------
# Visual styling
# ---------------------------------------------------------------------------

func _setup_background():
	var bg = get_node_or_null("Background")
	if bg:
		var blur_material = ShaderMaterial.new()
		blur_material.shader = _create_blur_shader()
		bg.material = blur_material

func _create_blur_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float blur_uv : hint_range(0.0, 0.05) = 0.015;

void fragment() {
	vec2 uv = UV;
	vec4 sum = vec4(0.0);
	sum += texture(TEXTURE, uv + vec2(-blur_uv, -blur_uv));
	sum += texture(TEXTURE, uv + vec2(0.0, -blur_uv));
	sum += texture(TEXTURE, uv + vec2(blur_uv, -blur_uv));
	sum += texture(TEXTURE, uv + vec2(-blur_uv, 0.0));
	sum += texture(TEXTURE, uv);
	sum += texture(TEXTURE, uv + vec2(blur_uv, 0.0));
	sum += texture(TEXTURE, uv + vec2(-blur_uv, blur_uv));
	sum += texture(TEXTURE, uv + vec2(0.0, blur_uv));
	sum += texture(TEXTURE, uv + vec2(blur_uv, blur_uv));
	COLOR = sum / 9.0;
}
"""
	return shader

func _style_buttons():
	UIThemeHelper.apply_button_theme(_main_action_button, "primary", 18)
	UIThemeHelper.apply_button_theme(_switch_mode_button, "secondary", 16)
	UIThemeHelper.apply_button_theme(_forgot_password_button, "secondary", 15)
	UIThemeHelper.apply_button_theme(_forgot_username_button, "secondary", 15)
	for btn in [_main_action_button, _switch_mode_button, _forgot_password_button, _forgot_username_button]:
		if btn:
			btn.custom_minimum_size = Vector2(0, 60)

# Animated ellipsis during async operations (Connecting. / Connecting.. / Connecting...)
func _start_loading_animation(base_text: String) -> void:
	_stop_loading_animation()
	_loading_base = base_text
	_loading_tween = create_tween().set_loops()
	var dots := ["", ".", "..", "..."]
	var idx := 0
	_loading_tween.tween_callback(func():
		if _status_label and is_instance_valid(_status_label):
			_status_label.text = _loading_base + dots[idx % dots.size()]
		idx += 1
	).set_delay(0.45)

func _stop_loading_animation() -> void:
	if _loading_tween and _loading_tween.is_valid():
		_loading_tween.kill()
	_loading_tween = null
	_loading_base = ""
