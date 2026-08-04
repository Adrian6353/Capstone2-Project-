extends Node

signal connection_changed(is_online: bool)

var is_online: bool = true
var http_checker: HTTPRequest
var check_interval: float = 10.0
var time_since_last_check: float = 0.0

func _ready():
	http_checker = HTTPRequest.new()
	add_child(http_checker)
	
	print("[NetworkStatus] Initialized, checking internet...")
	# Initial check
	_check_internet()

func _process(delta):
	time_since_last_check += delta
	if time_since_last_check >= check_interval:
		_check_internet()
		time_since_last_check = 0.0

# Simple HTTP ping to check internet connectivity
func _check_internet():
	var was_online = is_online
	http_checker.request("https://www.google.com")
	var result = await http_checker.request_completed
	is_online = (result[0] == OK and result[1] > 0)
	
	print("[NetworkStatus] Check result - Status: %s, Online: %s" % [result[1], is_online])
	
	if was_online != is_online:
		print("[NetworkStatus] Connection changed to: %s" % ("ONLINE" if is_online else "OFFLINE"))
		connection_changed.emit(is_online)

func get_is_online() -> bool:
	return is_online
