extends Node

signal account_authenticated
signal auth_failed(error: String)
signal login_required
signal session_invalidated(reason: String)

const CONFIG_FILE_PATH = "user://tower_defense_data/player_profile.cfg"
const DEVICE_ID_KEY = "device_uuid"
const PROFILE_SECTION = "profile"
const PROFILE_DISPLAY_NAME_KEY = "display_name"

var device_uuid: String = ""
var display_name: String = ""
var is_authenticated: bool = false
var current_username: String = ""
var session_token: String = ""

var _firebase: Node = null

func _ready():
	_ensure_data_dir_exists()
	_load_or_create_device_id()
	_load_cached_display_name()
	print("[AccountManager] Device UUID: %s" % device_uuid.substr(0, 16))
	# login_screen.gd calls validate_session() on startup — do not auto-authenticate here

# ---------------------------------------------------------------------------
# Device ID (kept for backwards-compat with leaderboard/ranking system)
# ---------------------------------------------------------------------------

func _load_or_create_device_id():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILE_PATH)

	if err == OK and config.has_section_key("device", DEVICE_ID_KEY):
		device_uuid = config.get_value("device", DEVICE_ID_KEY)
	else:
		device_uuid = _generate_token(32)
		config.set_value("device", DEVICE_ID_KEY, device_uuid)
		config.set_value("device", "created_at", Time.get_ticks_msec())
		config.save(CONFIG_FILE_PATH)

# ---------------------------------------------------------------------------
# Firebase helper (lazy singleton)
# ---------------------------------------------------------------------------

func _get_firebase() -> Node:
	if _firebase == null or not is_instance_valid(_firebase):
		_firebase = FirebaseIntegration.new()
		add_child(_firebase)
	return _firebase

# ---------------------------------------------------------------------------
# Session validation (called by login_screen on startup)
# ---------------------------------------------------------------------------

func validate_session() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILE_PATH)

	if err != OK or not config.has_section_key("auth", "username") or not config.has_section_key("auth", "session_token"):
		login_required.emit()
		return

	var saved_username = config.get_value("auth", "username")
	var saved_token = config.get_value("auth", "session_token")

	# Offline: trust cached session
	if not NetworkStatus.get_is_online():
		current_username = saved_username
		session_token = saved_token
		display_name = _resolve_display_name_from_config(config, saved_username)
		is_authenticated = true
		account_authenticated.emit()
		return

	var fb = _get_firebase()
	var result = await fb.get_data("/auth/users/" + saved_username)

	if result.has("error") or result.get("data") == null:
		_clear_local_auth()
		login_required.emit()
		return

	var data = result["data"]
	if not data is Dictionary:
		_clear_local_auth()
		login_required.emit()
		return

	if data.get("session_token", "") != saved_token:
		_clear_local_auth()
		session_invalidated.emit("logged_in_elsewhere")
		return

	current_username = saved_username
	session_token = saved_token
	display_name = _normalize_display_name(data.get("display_name", saved_username), saved_username)
	is_authenticated = true
	_save_local_auth(current_username, session_token, display_name)
	account_authenticated.emit()

# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------

func login(username: String, password: String) -> void:
	if not _is_valid_username(username):
		auth_failed.emit("Username must be 3–20 characters (letters, numbers, underscore)")
		return

	if password.length() < 6:
		auth_failed.emit("Password must be at least 6 characters")
		return

	if not NetworkStatus.get_is_online():
		auth_failed.emit("Internet connection required to log in")
		return

	var fb = _get_firebase()
	var result = await fb.get_data("/auth/users/" + username)

	if result.has("error") or result.get("data") == null:
		auth_failed.emit("Username not found")
		return

	var data = result["data"]
	if not data is Dictionary:
		auth_failed.emit("Username not found")
		return

	var stored_hash = data.get("password_hash", "")
	var salt = data.get("salt", "")
	if _hash_password(salt, password) != stored_hash:
		auth_failed.emit("Incorrect password")
		return

	var new_token = _generate_token(32)
	var update = {
		"session_token": new_token,
		"last_device_id": device_uuid,
		"last_login_at": Time.get_ticks_msec()
	}
	# Merge with existing data so we don't overwrite other fields
	for key in data.keys():
		if not update.has(key):
			update[key] = data[key]

	await fb.put_data("/auth/users/" + username, update)

	current_username = username
	session_token = new_token
	display_name = _normalize_display_name(data.get("display_name", username), username)
	is_authenticated = true
	_save_local_auth(username, new_token, display_name)
	account_authenticated.emit()

# ---------------------------------------------------------------------------
# Register
# ---------------------------------------------------------------------------

func register(username: String, password: String, email: String, security_question: String, security_answer: String) -> void:
	if not _is_valid_username(username):
		auth_failed.emit("Username must be 3–20 characters (letters, numbers, underscore)")
		return

	if password.length() < 6:
		auth_failed.emit("Password must be at least 6 characters")
		return

	if not _is_valid_email(email):
		auth_failed.emit("Please enter a valid email address")
		return

	if security_question.strip_edges().is_empty():
		auth_failed.emit("Please select a security question")
		return

	if security_answer.strip_edges().is_empty():
		auth_failed.emit("Please enter a security answer")
		return

	if not NetworkStatus.get_is_online():
		auth_failed.emit("Internet connection required to register")
		return

	var fb = _get_firebase()

	# Check username taken
	var user_check = await fb.get_data("/auth/users/" + username)
	if not user_check.has("error") and user_check.get("data") != null:
		auth_failed.emit("Username already taken")
		return

	# Check email taken
	var email_key = _hash_email(email)
	var email_check = await fb.get_data("/auth/email_index/" + email_key)
	if not email_check.has("error") and email_check.get("data") != null:
		auth_failed.emit("Email already registered to another account")
		return

	var salt = _generate_token(16)
	var new_token = _generate_token(32)
	var now = Time.get_ticks_msec()

	var user_data = {
		"username": username,
		"display_name": username,
		"email": email,
		"password_hash": _hash_password(salt, password),
		"salt": salt,
		"security_question": security_question,
		"security_answer_hash": _hash_answer(security_answer),
		"session_token": new_token,
		"last_device_id": device_uuid,
		"last_login_at": now,
		"created_at": now
	}

	var write_result = await fb.put_data("/auth/users/" + username, user_data)
	if write_result.has("error"):
		auth_failed.emit("Registration failed. Please try again.")
		return

	await fb.put_data("/auth/email_index/" + email_key, {"username": username})

	current_username = username
	session_token = new_token
	display_name = username
	is_authenticated = true
	_save_local_auth(username, new_token, username)
	account_authenticated.emit()

# ---------------------------------------------------------------------------
# Password reset (via security question)
# ---------------------------------------------------------------------------

func get_security_question(username: String) -> String:
	if not NetworkStatus.get_is_online():
		return "error:No internet connection"

	var fb = _get_firebase()
	var result = await fb.get_data("/auth/users/" + username)

	if result.has("error") or result.get("data") == null:
		return "error:Username not found"

	var data = result["data"]
	if not data is Dictionary:
		return "error:Username not found"

	return data.get("security_question", "error:No security question set")

func reset_password(username: String, answer: String, new_password: String) -> void:
	if new_password.length() < 6:
		auth_failed.emit("New password must be at least 6 characters")
		return

	if not NetworkStatus.get_is_online():
		auth_failed.emit("Internet connection required to reset password")
		return

	var fb = _get_firebase()
	var result = await fb.get_data("/auth/users/" + username)

	if result.has("error") or result.get("data") == null:
		auth_failed.emit("Username not found")
		return

	var data = result["data"]
	if not data is Dictionary:
		auth_failed.emit("Username not found")
		return

	if _hash_answer(answer) != data.get("security_answer_hash", ""):
		auth_failed.emit("Incorrect answer")
		return

	var salt = data.get("salt", "")
	var new_token = _generate_token(32)
	var update = {}
	for key in data.keys():
		update[key] = data[key]
	update["password_hash"] = _hash_password(salt, new_password)
	update["session_token"] = new_token
	update["last_device_id"] = device_uuid
	update["last_login_at"] = Time.get_ticks_msec()

	var write_result = await fb.put_data("/auth/users/" + username, update)
	if write_result.has("error"):
		auth_failed.emit("Reset failed. Please try again.")
		return

	current_username = username
	session_token = new_token
	display_name = _normalize_display_name(data.get("display_name", username), username)
	is_authenticated = true
	_save_local_auth(username, new_token, display_name)
	account_authenticated.emit()

# ---------------------------------------------------------------------------
# Username recovery (via email)
# ---------------------------------------------------------------------------

func get_username_by_email(email: String) -> void:
	if not NetworkStatus.get_is_online():
		auth_failed.emit("Internet connection required")
		return

	if not _is_valid_email(email):
		auth_failed.emit("Please enter a valid email address")
		return

	var email_key = _hash_email(email)
	var fb = _get_firebase()
	var result = await fb.get_data("/auth/email_index/" + email_key)

	if result.has("error") or result.get("data") == null:
		auth_failed.emit("No account found for this email")
		return

	var data = result["data"]
	if not data is Dictionary or not data.has("username"):
		auth_failed.emit("No account found for this email")
		return

	# Emit a dedicated signal carrying the found username
	username_found.emit(data["username"])

signal username_found(username: String)

# ---------------------------------------------------------------------------
# Logout
# ---------------------------------------------------------------------------

func logout() -> void:
	_clear_local_auth()
	login_required.emit()

# ---------------------------------------------------------------------------
# Display name (profile menu can still update it)
# ---------------------------------------------------------------------------

func set_display_name(player_name: String) -> bool:
	var cleaned_name = player_name.strip_edges()
	if cleaned_name.length() == 0 or cleaned_name.length() > 50:
		return false

	display_name = cleaned_name
	var config = ConfigFile.new()
	config.load(CONFIG_FILE_PATH)
	config.set_value(PROFILE_SECTION, PROFILE_DISPLAY_NAME_KEY, display_name)
	config.set_value("auth", "display_name", display_name)
	config.save(CONFIG_FILE_PATH)

	# Update Firebase if online
	if is_authenticated and NetworkStatus.get_is_online() and current_username != "":
		var fb = _get_firebase()
		var result = await fb.get_data("/auth/users/" + current_username)
		if not result.has("error") and result.get("data") is Dictionary:
			var update = result["data"]
			update["display_name"] = display_name
			fb.put_data("/auth/users/" + current_username, update)

	return true

func get_device_id() -> String:
	return device_uuid

func get_display_name() -> String:
	return _normalize_display_name(display_name, current_username)

func get_username() -> String:
	return current_username

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _save_local_auth(username: String, token: String, dname: String) -> void:
	var config = ConfigFile.new()
	config.load(CONFIG_FILE_PATH)
	config.set_value("auth", "username", username)
	config.set_value("auth", "session_token", token)
	var normalized_name = _normalize_display_name(dname, username)
	config.set_value("auth", "display_name", normalized_name)
	config.set_value(PROFILE_SECTION, PROFILE_DISPLAY_NAME_KEY, normalized_name)
	config.save(CONFIG_FILE_PATH)

func _clear_local_auth() -> void:
	current_username = ""
	session_token = ""
	is_authenticated = false
	var config = ConfigFile.new()
	config.load(CONFIG_FILE_PATH)
	if config.has_section("auth"):
		config.erase_section("auth")
	config.save(CONFIG_FILE_PATH)
	_load_cached_display_name()

func _hash_password(salt: String, password: String) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((salt + ":" + password).to_utf8_buffer())
	return ctx.finish().hex_encode()

func _hash_answer(answer: String) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(answer.strip_edges().to_lower().to_utf8_buffer())
	return ctx.finish().hex_encode()

func _hash_email(email: String) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(email.strip_edges().to_lower().to_utf8_buffer())
	return ctx.finish().hex_encode()

func _generate_token(length: int = 32) -> String:
	var chars = "0123456789abcdef"
	var token = ""
	for i in range(length):
		token += chars[randi() % chars.length()]
	return token

func _is_valid_username(username: String) -> bool:
	if username.length() < 3 or username.length() > 20:
		return false
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	return regex.search(username) != null

func _is_valid_email(email: String) -> bool:
	var e = email.strip_edges()
	var at_pos = e.find("@")
	if at_pos < 1:
		return false
	var dot_pos = e.find(".", at_pos)
	return dot_pos > at_pos + 1 and dot_pos < e.length() - 1

func _ensure_data_dir_exists():
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("tower_defense_data"):
		dir.make_dir("tower_defense_data")

func _load_cached_display_name() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILE_PATH)
	if err != OK:
		display_name = _normalize_display_name("", "")
		return

	var username_hint = str(config.get_value("auth", "username", "")).strip_edges()
	display_name = _resolve_display_name_from_config(config, username_hint)

func _resolve_display_name_from_config(config: ConfigFile, fallback_username: String) -> String:
	if config.has_section_key(PROFILE_SECTION, PROFILE_DISPLAY_NAME_KEY):
		return _normalize_display_name(config.get_value(PROFILE_SECTION, PROFILE_DISPLAY_NAME_KEY, ""), fallback_username)

	if config.has_section_key("auth", "display_name"):
		return _normalize_display_name(config.get_value("auth", "display_name", ""), fallback_username)

	return _normalize_display_name("", fallback_username)

func _normalize_display_name(raw_name: Variant, fallback_name: String) -> String:
	var fallback = fallback_name.strip_edges()
	if fallback == "":
		fallback = "Player"

	if raw_name == null:
		return fallback

	var candidate = str(raw_name).strip_edges()
	if candidate == "":
		return fallback

	if candidate.length() > 50:
		return candidate.substr(0, 50)

	return candidate
