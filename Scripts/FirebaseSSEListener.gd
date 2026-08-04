class_name FirebaseSSEListener
extends Node
## Maintains a persistent Server-Sent Events (SSE) connection to a Firebase
## Realtime Database path and emits data_received whenever Firebase pushes a change.
##
## Firebase RTDB SSE protocol:
##   - Immediately on connect: event: put  /  full current snapshot
##   - On remote write to /path/key:  event: put  /key  new value
##   - On remote PATCH to /path:      event: patch /     partial fields
##   - Heartbeat:                     event: keep-alive
##
## Usage:
##   var listener = FirebaseSSEListener.new()
##   parent_firebase.add_child(listener)          # parent must be FirebaseIntegration
##   listener.data_received.connect(_on_data)
##   listener.start("/leaderboards/waves_survived", parent_firebase)

signal data_received(event_type: String, event_path: String, data: Variant)
signal connection_established()
signal connection_lost()

const RECONNECT_DELAY: float = 5.0
const _HOST: String = "tower-defense-capstone-default-rtdb.asia-southeast1.firebasedatabase.app"
const _PORT: int = 443

var listen_path: String = ""

var _parent_firebase: Node = null
var _http_client: HTTPClient = null
var _buffer: String = ""
## idle | connecting | awaiting_response | reading | reconnecting | stopped
var _state: String = "idle"
var _reconnect_timer: float = 0.0

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Begin streaming changes from [param path] under the Firebase RTDB root.
## [param parent_firebase] is the owning FirebaseIntegration node (provides auth token).
func start(path: String, parent_firebase: Node) -> void:
	listen_path = path
	_parent_firebase = parent_firebase
	_do_connect()

## Stop the SSE stream and release the HTTP connection.
func stop() -> void:
	_state = "stopped"
	if _http_client:
		_http_client.close()
		_http_client = null

# ---------------------------------------------------------------------------
# Main process loop — state machine
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	match _state:
		"connecting":
			_poll_connecting()
		"awaiting_response":
			_poll_awaiting_response()
		"reading":
			_poll_reading()
		"reconnecting":
			_reconnect_timer -= delta
			if _reconnect_timer <= 0.0:
				_do_connect()

# ---------------------------------------------------------------------------
# Connection states
# ---------------------------------------------------------------------------

func _do_connect() -> void:
	_buffer = ""
	_state = "connecting"
	_http_client = HTTPClient.new()
	var err: int = _http_client.connect_to_host(_HOST, _PORT, TLSOptions.client())
	if err != OK:
		push_warning("[Firebase SSE] connect_to_host failed (%d) for: %s" % [err, listen_path])
		_schedule_reconnect()

func _poll_connecting() -> void:
	_http_client.poll()
	var status: int = _http_client.get_status()
	if status == HTTPClient.STATUS_CONNECTED:
		# Fetch a fresh auth token each reconnect attempt.
		var auth: String = ""
		if is_instance_valid(_parent_firebase) and _parent_firebase.has_method("_auth_param"):
			auth = _parent_firebase._auth_param()
		var request_path: String = listen_path + ".json" + auth
		var headers: PackedStringArray = ["Accept: text/event-stream", "Cache-Control: no-cache"]
		var err: int = _http_client.request(HTTPClient.METHOD_GET, request_path, headers)
		if err != OK:
			push_warning("[Firebase SSE] Failed to send GET (%d) for: %s" % [err, listen_path])
			_schedule_reconnect()
		else:
			_state = "awaiting_response"
	elif status == HTTPClient.STATUS_CANT_CONNECT \
			or status == HTTPClient.STATUS_CANT_RESOLVE \
			or status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR \
			or status == HTTPClient.STATUS_CONNECTION_ERROR:
		push_warning("[Firebase SSE] Cannot connect (status=%d) for: %s" % [status, listen_path])
		_schedule_reconnect()
	# STATUS_RESOLVING / STATUS_CONNECTING: still in progress — keep polling

func _poll_awaiting_response() -> void:
	_http_client.poll()
	var status: int = _http_client.get_status()
	if status == HTTPClient.STATUS_BODY:
		var code: int = _http_client.get_response_code()
		if code != 200:
			push_warning("[Firebase SSE] HTTP %d for: %s" % [code, listen_path])
			_schedule_reconnect()
			return
		print("[Firebase SSE] Streaming: %s" % listen_path)
		connection_established.emit()
		_state = "reading"
	elif status == HTTPClient.STATUS_CONNECTION_ERROR or status == HTTPClient.STATUS_DISCONNECTED:
		push_warning("[Firebase SSE] Lost connection while awaiting response for: %s" % listen_path)
		_schedule_reconnect()
	# STATUS_REQUESTING: still sending — keep polling

func _poll_reading() -> void:
	_http_client.poll()
	var status: int = _http_client.get_status()
	if status == HTTPClient.STATUS_BODY:
		var chunk: PackedByteArray = _http_client.read_response_body_chunk()
		if chunk.size() > 0:
			_buffer += chunk.get_string_from_utf8()
			_parse_buffer()
	elif status == HTTPClient.STATUS_DISCONNECTED or status == HTTPClient.STATUS_CONNECTION_ERROR:
		print("[Firebase SSE] Disconnected from: %s — scheduling reconnect" % listen_path)
		connection_lost.emit()
		_schedule_reconnect()

func _schedule_reconnect() -> void:
	if _state == "stopped":
		return
	_state = "reconnecting"
	_reconnect_timer = RECONNECT_DELAY
	if _http_client:
		_http_client.close()
	print("[Firebase SSE] Will reconnect in %.0fs for: %s" % [RECONNECT_DELAY, listen_path])

# ---------------------------------------------------------------------------
# SSE parsing
# ---------------------------------------------------------------------------

## Drains all complete SSE events from the buffer (events are delimited by "\n\n").
func _parse_buffer() -> void:
	while true:
		var sep: int = _buffer.find("\n\n")
		if sep == -1:
			break
		var block: String = _buffer.substr(0, sep)
		_buffer = _buffer.substr(sep + 2)
		if not block.is_empty():
			_handle_event_block(block)

## Parses one SSE event block (a group of "field: value" lines) and emits data_received.
func _handle_event_block(block: String) -> void:
	var event_type: String = ""
	var data_str: String = ""
	for line in block.split("\n"):
		if line.begins_with("event:"):
			event_type = line.substr(6).strip_edges()
		elif line.begins_with("data:"):
			data_str = line.substr(5).strip_edges()

	match event_type:
		"keep-alive", "cancel", "":
			return
		"auth_revoked":
			push_warning("[Firebase SSE] Auth revoked for: %s — reconnecting" % listen_path)
			_schedule_reconnect()
			return
		"put", "patch":
			pass  # Processed below.
		_:
			return

	if data_str.is_empty() or data_str == "null":
		return

	var json := JSON.new()
	if json.parse(data_str) != OK:
		push_warning("[Firebase SSE] JSON parse error for: %s" % listen_path)
		return
	if not json.data is Dictionary:
		return

	var event_path: String = str(json.data.get("path", "/"))
	var event_data: Variant = json.data.get("data")
	data_received.emit(event_type, event_path, event_data)
