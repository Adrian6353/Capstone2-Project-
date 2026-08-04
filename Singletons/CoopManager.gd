extends Node
## CoopManager — manages 2-player co-op over local WiFi / WiFi hotspot.
## Uses Godot 4's built-in ENetMultiplayerPeer (UDP).
## Architecture: Host-authority.
##   - Host runs all enemy simulation and base-health logic.
##   - Enemies exist only on the host; positions are broadcast every 0.1 s.
##   - Towers are synced to both peers so both screens look identical.
##   - Kill rewards are split 50/50; base health is host-authoritative.

signal partner_connected
signal partner_disconnected
signal connection_failed

const DEFAULT_PORT  : int = 7777
const MAX_CLIENTS   : int = 1   # one host + one client only

var is_coop_active  : bool = false
var is_host         : bool = false
var local_peer_id   : int  = 0
var partner_peer_id : int  = 0

# --------------------------------------------------------------------------- #
#  Lifecycle                                                                   #
# --------------------------------------------------------------------------- #

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# --------------------------------------------------------------------------- #
#  Public API                                                                  #
# --------------------------------------------------------------------------- #

## Start an ENet server on DEFAULT_PORT.  Call on the hosting device.
func start_host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if err != OK:
		push_error("CoopManager: create_server failed (%s)" % err)
		return err
	multiplayer.multiplayer_peer = peer
	is_coop_active  = true
	is_host         = true
	local_peer_id   = 1   # host is always peer 1 in Godot ENet
	return OK

## Connect to a host.  `ip` is the host's LAN address (e.g. "192.168.1.5").
func join_host(ip: String) -> Error:
	if ip.is_empty():
		push_error("CoopManager: join_host called with empty IP")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err  := peer.create_client(ip, DEFAULT_PORT)
	if err != OK:
		push_error("CoopManager: create_client failed (%s)" % err)
		return err
	multiplayer.multiplayer_peer = peer
	is_coop_active = true
	is_host        = false
	return OK

## Tear down the connection and reset all state.
func disconnect_coop() -> void:
	multiplayer.multiplayer_peer = null   # null peer disconnects cleanly
	is_coop_active  = false
	is_host         = false
	local_peer_id   = 0
	partner_peer_id = 0
	GameData.is_coop = false

## Returns this device's local-network IPv4 address.
## Prefers 192.168.x.x (common hotspot / LAN range), then 10.x.x.x / 172.x.x.x.
func get_local_ip() -> String:
	var addresses := IP.get_local_addresses()
	# Prefer common private ranges (no IPv6 colons)
	for addr in addresses:
		if ":" in addr:
			continue   # skip IPv6
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	# Fallback: any non-loopback IPv4
	for addr in addresses:
		if ":" in addr:
			continue
		if addr != "127.0.0.1":
			return addr
	return "127.0.0.1"

## 1 for host (P1), 2 for client (P2).  Only valid while is_coop_active.
func get_local_player_id() -> int:
	if not is_coop_active:
		return 1
	return 1 if is_host else 2

# --------------------------------------------------------------------------- #
#  Multiplayer signal handlers                                                 #
# --------------------------------------------------------------------------- #

func _on_peer_connected(id: int) -> void:
	print("CoopManager: peer connected id=%d" % id)
	partner_peer_id = id
	if is_host:
		local_peer_id = 1
	partner_connected.emit()

func _on_peer_disconnected(id: int) -> void:
	print("CoopManager: peer disconnected id=%d" % id)
	partner_peer_id = 0
	partner_disconnected.emit()

func _on_connected_to_server() -> void:
	local_peer_id   = multiplayer.get_unique_id()
	partner_peer_id = 1   # host is always peer 1
	print("CoopManager: connected to server as peer %d" % local_peer_id)
	partner_connected.emit()

func _on_connection_failed() -> void:
	push_warning("CoopManager: connection failed")
	disconnect_coop()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	push_warning("CoopManager: server disconnected")
	disconnect_coop()
	partner_disconnected.emit()
