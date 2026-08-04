class_name FirebaseIntegration
extends Node
# Firebase REST API wrapper for Godot
# Handles HTTP requests to Firebase Realtime Database

const DATABASE_URL = "https://tower-defense-capstone-default-rtdb.asia-southeast1.firebasedatabase.app"
const TIMEOUT = 10.0

## Returns the auth query parameter for Firebase REST requests.
## Uses the current player's session token so requests are tied to a real
## account rather than being fully anonymous.  Replace the token source here
## once Firebase Authentication (ID tokens) is integrated.
func _auth_param() -> String:
	var token: String = get_node_or_null("/root/AccountManager").session_token if get_node_or_null("/root/AccountManager") else ""
	if token.is_empty():
		return "?auth=anonymous"
	return "?auth=" + token

var last_response: Array = []
var response_received: bool = false
var current_request_id: int = 0
var request_in_progress: bool = false
var pending_http_request: HTTPRequest = null
var pending_response_holder: Dictionary = {}
var put_response_data: Dictionary = {}
var put_response_received: bool = false

func _ready():
	print("[Firebase] Integration ready")
	# Create and add HTTPRequest once, keep it alive
	pending_http_request = HTTPRequest.new()
	add_child(pending_http_request)
	# Don't connect signal yet, will connect per-request

func _process(_delta):
	# Manual polling for HTTPRequest response (no longer needed with HTTPClient)
	pass

# GET request to Firebase
func get_data(path: String) -> Dictionary:
	var url = DATABASE_URL + path + ".json" + _auth_param()
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var my_request_id = current_request_id
	current_request_id += 1
	
	print("[Firebase] GET Request %d: %s" % [my_request_id, url])
	
	# Set up callback
	var response_holder = {"received": false, "data": []}
	
	var callback = func(http_result: int, http_code: int, http_headers: PackedStringArray, http_body: PackedByteArray):
		print("[Firebase] GET Response %d: Code=%d, Result=%d, Body=%d bytes" % [my_request_id, http_code, http_result, http_body.size()])
		response_holder["received"] = true
		response_holder["data"] = [http_result, http_code, http_headers, http_body]
	
	http_request.request_completed.connect(callback)
	
	var error = http_request.request(url)
	if error != OK:
		print("[Firebase] ERROR: Failed to send GET request - %d" % error)
		http_request.queue_free()
		return {"error": "Failed to send request"}
	
	# Wait for response
	var start_time = Time.get_ticks_msec()
	while not response_holder["received"] and (Time.get_ticks_msec() - start_time) < (TIMEOUT * 1000):
		await get_tree().process_frame
	
	http_request.queue_free()
	
	if not response_holder["received"]:
		print("[Firebase] ERROR: GET request timeout after %.2fs" % ((Time.get_ticks_msec() - start_time) / 1000.0))
		return {"error": "Request timeout"}
	
	var result = response_holder["data"]
	if result[0] != OK:
		print("[Firebase] ERROR: GET network error %d" % result[0])
		return {"error": "Network error"}
	
	if result[1] != 200:
		var body_str = result[3].get_string_from_utf8()
		print("[Firebase] ERROR: GET HTTP %d - %s" % [result[1], body_str])
		return {"error": "HTTP error: " + str(result[1])}
	
	var body = result[3].get_string_from_utf8()
	print("[Firebase] GET Response body: %s" % body)
	var json = JSON.new()
	var json_error = json.parse(body)
	
	if json_error:
		print("[Firebase] ERROR: JSON parse error")
		return {"error": "JSON parse error"}
	
	print("[Firebase] GET parsed data: %s" % json.data)
	return {"data": json.data}

# HTTP response callback
func _on_http_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print("[Firebase] CALLBACK FIRED! Request ID: %d, Result: %d, Code: %d, Body size: %d" % [current_request_id, result, response_code, body.size()])
	last_response = [result, response_code, headers, body]
	response_received = true

# PUT request to Firebase (write data)
# Uses PUT (not POST) to write directly to specified path
func put_data(path: String, data: Dictionary) -> Dictionary:
	var url = DATABASE_URL + path + ".json" + _auth_param()
	var json_data = JSON.stringify(data)
	var req_headers = ["Content-Type: application/json"]
	
	print("[Firebase] ===== PUT REQUEST START =====")
	print("[Firebase] URL: %s" % url)
	print("[Firebase] Data: %s" % json_data)
	
	# Create a fresh HTTPRequest for this specific request
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	# Store response in custom properties on the request object
	http_request.set_meta("response_received", false)
	http_request.set_meta("response_code", 0)
	http_request.set_meta("response_body", PackedByteArray())
	
	var callback = func(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		print("[Firebase] PUT Callback fired! Code=%d, Body=%d bytes" % [code, body.size()])
		http_request.set_meta("response_code", code)
		http_request.set_meta("response_body", body)
		http_request.set_meta("response_received", true)
	
	http_request.request_completed.connect(callback)
	
	# Send request using PUT (not POST) to write to specific path
	print("[Firebase] Sending PUT request...")
	var error = http_request.request(url, req_headers, HTTPClient.METHOD_PUT, json_data)
	print("[Firebase] Request error code: %d" % error)
	
	if error != OK:
		print("[Firebase] ERROR: Failed to send request - %d" % error)
		http_request.queue_free()
		return {"error": "Failed to send request: " + str(error)}
	
	# Wait for response
	var start_time = Time.get_ticks_msec()
	while not http_request.get_meta("response_received", false) and (Time.get_ticks_msec() - start_time) < (TIMEOUT * 1000):
		await get_tree().process_frame
	
	var post_response_ok = http_request.get_meta("response_received", false)
	var post_response_code = http_request.get_meta("response_code", 0)
	var post_response_body = http_request.get_meta("response_body", PackedByteArray())
	
	http_request.queue_free()
	
	if not post_response_ok:
		print("[Firebase] ERROR: PUT timeout after %.2fs" % ((Time.get_ticks_msec() - start_time) / 1000.0))
		return {"error": "Request timeout"}
	
	print("[Firebase] PUT Got response in %.2fs" % ((Time.get_ticks_msec() - start_time) / 1000.0))
	print("[Firebase] Response code: %d" % post_response_code)
	
	if post_response_code != 200 and post_response_code != 201:
		var post_response_str = post_response_body.get_string_from_utf8() if post_response_body.size() > 0 else ""
		print("[Firebase] ERROR: HTTP %d - %s" % [post_response_code, post_response_str])
		return {"error": "HTTP error: " + str(post_response_code)}
	
	var post_body_str = post_response_body.get_string_from_utf8()
	print("[Firebase] Response body: %s" % post_body_str)
	print("[Firebase] ===== PUT SUCCESS =====")
	return {"success": true}

# DELETE request
func delete_data(path: String) -> Dictionary:
	var url = DATABASE_URL + path + ".json" + _auth_param()
	var my_request_id = current_request_id
	current_request_id += 1
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var response_holder = {"received": false, "data": []}
	
	var callback = func(http_result: int, http_code: int, http_headers: PackedStringArray, http_body: PackedByteArray):
		print("[Firebase] DELETE Response %d: Code=%d, Result=%d" % [my_request_id, http_code, http_result])
		response_holder["received"] = true
		response_holder["data"] = [http_result, http_code, http_headers, http_body]
	
	http_request.request_completed.connect(callback)
	
	var error = http_request.request(url, [], HTTPClient.METHOD_DELETE)
	if error != OK:
		http_request.queue_free()
		return {"error": "Failed to send request"}
	
	var start_time = Time.get_ticks_msec()
	while not response_holder["received"] and (Time.get_ticks_msec() - start_time) < (TIMEOUT * 1000):
		await get_tree().process_frame
	
	http_request.queue_free()
	
	if not response_holder["received"]:
		return {"error": "Request timeout"}
	
	var result = response_holder["data"]
	if result.is_empty():
		return {"error": "Request failed"}
	
	if result[0] != OK:
		return {"error": "Network error"}
	
	if result[1] != 200:
		return {"error": "HTTP error: " + str(result[1])}
	
	return {"success": true}
