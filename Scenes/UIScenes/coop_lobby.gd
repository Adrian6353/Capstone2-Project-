extends Control
## Co-op lobby screen.
## HOST path: tap "Host" → see your LAN IP → wait for partner → tap "Start".
## JOIN path: tap "Join" → enter host IP → tap "Connect" → wait for host to start.

# ---- node refs (resolved in _ready) ----
var _ip_label       : Label
var _status_label   : Label
var _start_btn      : Button
var _ip_input       : LineEdit
var _connect_btn    : Button
var _join_status    : Label
var _host_panel     : VBoxContainer
var _join_panel     : VBoxContainer

const BG_COLOR      := Color(0.07, 0.07, 0.12, 0.96)
const ACCENT_COLOR  := Color(0.5, 0.25, 0.08, 1.0)
const BORDER_COLOR  := Color(1.0, 0.8, 0.35, 1.0)

# --------------------------------------------------------------------------- #
#  Lifecycle                                                                   #
# --------------------------------------------------------------------------- #

func _ready() -> void:
	_build_ui()
	CoopManager.partner_connected.connect(_on_partner_connected)
	CoopManager.partner_disconnected.connect(_on_partner_disconnected)
	CoopManager.connection_failed.connect(_on_connection_failed)

func _exit_tree() -> void:
	if CoopManager.partner_connected.is_connected(_on_partner_connected):
		CoopManager.partner_connected.disconnect(_on_partner_connected)
	if CoopManager.partner_disconnected.is_connected(_on_partner_disconnected):
		CoopManager.partner_disconnected.disconnect(_on_partner_disconnected)
	if CoopManager.connection_failed.is_connected(_on_connection_failed):
		CoopManager.connection_failed.disconnect(_on_connection_failed)

# --------------------------------------------------------------------------- #
#  UI construction                                                             #
# --------------------------------------------------------------------------- #

func _build_ui() -> void:
	# Full-screen background
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centered card
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(700, 520)
	card.offset_left  = -350
	card.offset_top   = -260
	card.offset_right =  350
	card.offset_bottom = 260
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.10, 0.16, 1.0)
	card_style.set_border_width_all(2)
	card_style.border_color = BORDER_COLOR
	card_style.set_corner_radius_all(16)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   32)
	margin.add_theme_constant_override("margin_top",    32)
	margin.add_theme_constant_override("margin_right",  32)
	margin.add_theme_constant_override("margin_bottom", 32)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "CO-OP MODE"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", BORDER_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Both devices must be on the same WiFi or hotspot"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Host / Join toggle row
	var toggle_row := HBoxContainer.new()
	toggle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	toggle_row.add_theme_constant_override("separation", 16)
	vbox.add_child(toggle_row)

	var host_btn := _make_btn("Host Game", 200, 56)
	host_btn.pressed.connect(_on_host_pressed)
	toggle_row.add_child(host_btn)

	var join_btn := _make_btn("Join Game", 200, 56)
	join_btn.pressed.connect(_on_join_pressed)
	toggle_row.add_child(join_btn)

	# ---- HOST PANEL ----
	_host_panel = VBoxContainer.new()
	_host_panel.add_theme_constant_override("separation", 12)
	_host_panel.visible = false
	vbox.add_child(_host_panel)

	_ip_label = Label.new()
	_ip_label.add_theme_font_size_override("font_size", 22)
	_ip_label.add_theme_color_override("font_color", Color.WHITE)
	_ip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_host_panel.add_child(_ip_label)

	var port_lbl := Label.new()
	port_lbl.text = "Port: %d" % CoopManager.DEFAULT_PORT
	port_lbl.add_theme_font_size_override("font_size", 18)
	port_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	port_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_host_panel.add_child(port_lbl)

	_status_label = Label.new()
	_status_label.text = "Waiting for partner..."
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_host_panel.add_child(_status_label)

	_start_btn = _make_btn("Start Game", 260, 60)
	_start_btn.disabled = true
	_start_btn.pressed.connect(_on_start_pressed)
	_host_panel.add_child(_start_btn)
	_host_panel.alignment = BoxContainer.ALIGNMENT_CENTER

	# ---- JOIN PANEL ----
	_join_panel = VBoxContainer.new()
	_join_panel.add_theme_constant_override("separation", 12)
	_join_panel.visible = false
	vbox.add_child(_join_panel)

	var ip_row := HBoxContainer.new()
	ip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ip_row.add_theme_constant_override("separation", 10)
	_join_panel.add_child(ip_row)

	var ip_lbl := Label.new()
	ip_lbl.text = "Host IP:"
	ip_lbl.add_theme_font_size_override("font_size", 20)
	ip_lbl.add_theme_color_override("font_color", Color.WHITE)
	ip_row.add_child(ip_lbl)

	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "e.g. 192.168.1.10"
	_ip_input.custom_minimum_size = Vector2(260, 48)
	_ip_input.add_theme_font_size_override("font_size", 20)
	ip_row.add_child(_ip_input)

	_connect_btn = _make_btn("Connect", 180, 56)
	_connect_btn.pressed.connect(_on_connect_pressed)
	_join_panel.add_child(_connect_btn)

	_join_status = Label.new()
	_join_status.text = "Enter the host's IP address above"
	_join_status.add_theme_font_size_override("font_size", 18)
	_join_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_join_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_panel.add_child(_join_status)

	# Back button
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var back := _make_btn("Back", 180, 52)
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)

# --------------------------------------------------------------------------- #
#  Button event handlers                                                       #
# --------------------------------------------------------------------------- #

func _on_host_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	_join_panel.visible  = false
	_host_panel.visible  = true
	_status_label.text   = "Starting server..."
	_start_btn.disabled  = true

	var err := CoopManager.start_host()
	if err != OK:
		_status_label.text = "Failed to start server. Try again."
		return

	_ip_label.text     = "Your IP:  %s" % CoopManager.get_local_ip()
	_status_label.text = "Waiting for partner to connect..."

func _on_join_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	_host_panel.visible = false
	_join_panel.visible = true

func _on_connect_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	var ip := _ip_input.text.strip_edges()
	if ip.is_empty():
		_join_status.text = "Please enter the host IP address."
		return
	_connect_btn.disabled = true
	_join_status.text     = "Connecting to %s..." % ip
	var err := CoopManager.join_host(ip)
	if err != OK:
		_join_status.text     = "Failed to initiate connection."
		_connect_btn.disabled = false

func _on_start_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	# Tell all peers to load the game
	_load_game_scene.rpc()

func _on_back_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	CoopManager.disconnect_coop()
	get_tree().change_scene_to_file("res://Scenes/UIScenes/main_menu.tscn")

# --------------------------------------------------------------------------- #
#  CoopManager signal handlers                                                 #
# --------------------------------------------------------------------------- #

func _on_partner_connected() -> void:
	if CoopManager.is_host:
		_status_label.text              = "Partner connected!  Ready to start."
		_status_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		_start_btn.disabled             = false
	else:
		_join_status.text = "Connected!  Waiting for host to start..."
		_join_status.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		_connect_btn.disabled = true

func _on_partner_disconnected() -> void:
	if CoopManager.is_host:
		_status_label.text = "Partner disconnected."
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		_start_btn.disabled = true
	else:
		_join_status.text = "Disconnected from host."
		_join_status.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		_connect_btn.disabled = false

func _on_connection_failed() -> void:
	_join_status.text = "Connection failed.  Check the IP and try again."
	_join_status.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_connect_btn.disabled = false

# --------------------------------------------------------------------------- #
#  RPC — called on ALL peers (host triggers via _on_start_pressed)            #
# --------------------------------------------------------------------------- #

@rpc("authority", "call_local", "reliable")
func _load_game_scene() -> void:
	GameData.is_coop          = true
	GameData.selected_player_count = 2
	GameData.game_mode        = "normal"
	get_tree().change_scene_to_file("res://Scenes/MainScenes/GameScene.tscn")

# --------------------------------------------------------------------------- #
#  Helpers                                                                     #
# --------------------------------------------------------------------------- #

func _make_btn(text: String, min_w: float, min_h: float) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, min_h)

	var normal := StyleBoxFlat.new()
	normal.bg_color     = ACCENT_COLOR
	normal.border_color = BORDER_COLOR
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)

	var hover := StyleBoxFlat.new()
	hover.bg_color     = Color(0.65, 0.40, 0.15, 1.0)
	hover.border_color = BORDER_COLOR
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(10)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color     = Color(0.3, 0.15, 0.05, 1.0)
	pressed.border_color = BORDER_COLOR
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(10)

	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("pressed",  pressed)
	btn.add_theme_stylebox_override("focus",    normal)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_color_override("font_color",         Color(1.0, 0.98, 0.9))
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.80, 0.70))
	btn.add_theme_font_size_override("font_size", 22)
	return btn
