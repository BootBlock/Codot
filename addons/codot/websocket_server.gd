@tool
extends Node
## WebSocket server for AI agent connections.
##
## This class implements a WebSocket server that runs inside the Godot editor,
## accepting connections from AI agents (via MCP or direct WebSocket).
## It handles the WebSocket handshake, message parsing, and response routing.
##
## The server uses a TCP listener and manually manages the WebSocket protocol
## to work reliably within the editor environment.
##
## @tutorial: https://github.com/your-repo/codot

## Emitted when a new client successfully connects.
## [param client_id]: Unique identifier assigned to the client.
signal client_connected(client_id: int)

## Emitted when a client disconnects.
## [param client_id]: The ID of the disconnected client.
signal client_disconnected(client_id: int)

## Emitted when a command is received from a client.
## [param client_id]: The ID of the client that sent the command.
## [param command]: The parsed command Dictionary.
signal command_received(client_id: int, command: Dictionary)

## TCP server for accepting incoming connections.
var _tcp_server: TCPServer = null

## Pending peers during WebSocket handshake. Maps tcp_peer -> WebSocketPeer.
var _pending_peers: Dictionary = {}

## Connected clients. Maps client_id -> WebSocketPeer.
var _clients: Dictionary = {}

## Counter for generating unique client IDs.
var _next_client_id: int = 1

## Whether the server is currently running.
var _is_running: bool = false

## Timer for polling connections in editor (since _process may not be reliable).
var _poll_timer: Timer = null


## Called when the node enters the scene tree.
## Sets up the polling timer for reliable operation in the editor.
func _ready() -> void:
	# Create a timer for polling since _process() doesn't work reliably in editor plugins
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.016  # ~60fps
	_poll_timer.timeout.connect(_on_poll_timer)
	add_child(_poll_timer)


## Timer callback for polling connections.
## Called at ~60fps to process pending connections and messages.
func _on_poll_timer() -> void:
	if not _is_running:
		return
	_poll_connections()
	_poll_pending()
	_poll_clients()


## Process callback (backup for timer).
## Polls connections, pending handshakes, and active clients.
func _process(_delta: float) -> void:
	if not _is_running:
		return
	_poll_connections()
	_poll_pending()
	_poll_clients()


## Start the WebSocket server on the specified port.
## [br][br]
## [param port]: TCP port to listen on (default: 6850).
## [br][br]
## Returns OK on success, or an error code on failure.
func start(port: int) -> int:
	if _is_running:
		stop()
	
	_tcp_server = TCPServer.new()
	var error: int = _tcp_server.listen(port, "127.0.0.1")
	
	if error == OK:
		_is_running = true
		# Start the poll timer
		if _poll_timer != null:
			_poll_timer.start()
			print("[Codot] Poll timer started")
	
	return error


## Stop the WebSocket server and disconnect all clients.
## Cleans up all resources and pending connections.
func stop() -> void:
	_is_running = false
	
	if _poll_timer != null:
		_poll_timer.stop()
	
	for client_id in _clients.keys():
		_disconnect_client(client_id)
	_clients.clear()
	_pending_peers.clear()
	
	if _tcp_server != null:
		_tcp_server.stop()
		_tcp_server = null


## Send a response to a specific client.
## [br][br]
## [param client_id]: The client to send to.
## [param response]: The response Dictionary to send as JSON.
## [br][br]
## Returns OK on success, ERR_DOES_NOT_EXIST if client not found.
func send_response(client_id: int, response: Dictionary) -> int:
	if not _clients.has(client_id):
		return ERR_DOES_NOT_EXIST
	
	var peer: WebSocketPeer = _clients[client_id]
	var json_string: String = JSON.stringify(response)
	return peer.send_text(json_string)


## Broadcast a message to all connected clients.
## [br][br]
## [param message]: The message Dictionary to send to all clients.
func broadcast(message: Dictionary) -> void:
	var json_string: String = JSON.stringify(message)
	for client_id in _clients.keys():
		var peer: WebSocketPeer = _clients[client_id]
		if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			peer.send_text(json_string)


## Poll for new TCP connections.
## Accepts incoming TCP connections and initializes WebSocket handshake.
func _poll_connections() -> void:
	if _tcp_server == null:
		return
	if not _tcp_server.is_listening():
		return
	
	while _tcp_server.is_connection_available():
		var tcp_peer: StreamPeerTCP = _tcp_server.take_connection()
		if tcp_peer != null:
			print("[Codot] New TCP connection received")
			var ws_peer: WebSocketPeer = WebSocketPeer.new()
			# Increase buffer sizes to handle large responses
			ws_peer.outbound_buffer_size = 1024 * 1024  # 1MB outbound buffer
			ws_peer.inbound_buffer_size = 1024 * 1024   # 1MB inbound buffer
			var err: int = ws_peer.accept_stream(tcp_peer)
			print("[Codot] accept_stream result: ", err)
			_pending_peers[tcp_peer] = ws_peer


## Poll pending connections for WebSocket handshake completion.
## Moves completed handshakes to active clients.
func _poll_pending() -> void:
	var to_remove: Array = []
	
	for tcp_peer in _pending_peers.keys():
		var ws_peer: WebSocketPeer = _pending_peers[tcp_peer]
		ws_peer.poll()
		
		var state: int = ws_peer.get_ready_state()
		# Debug: print state periodically
		if state == WebSocketPeer.STATE_CONNECTING:
			pass  # Still handshaking
		elif state == WebSocketPeer.STATE_OPEN:
			# Handshake complete, move to clients
			var client_id: int = _next_client_id
			_next_client_id += 1
			_clients[client_id] = ws_peer
			to_remove.append(tcp_peer)
			client_connected.emit(client_id)
			print("[Codot] Client connected: ", client_id)
		elif state == WebSocketPeer.STATE_CLOSED:
			var code: int = ws_peer.get_close_code()
			var reason: String = ws_peer.get_close_reason()
			print("[Codot] Pending peer closed. Code: ", code, " Reason: ", reason)
			to_remove.append(tcp_peer)
	
	for tcp_peer in to_remove:
		_pending_peers.erase(tcp_peer)


func _poll_clients() -> void:
	var to_remove: Array = []
	
	for client_id in _clients.keys():
		var peer: WebSocketPeer = _clients[client_id]
		peer.poll()
		
		var state: int = peer.get_ready_state()
		
		if state == WebSocketPeer.STATE_OPEN:
			while peer.get_available_packet_count() > 0:
				var packet: PackedByteArray = peer.get_packet()
				_handle_packet(client_id, packet)
		
		elif state == WebSocketPeer.STATE_CLOSED:
			to_remove.append(client_id)
	
	for client_id in to_remove:
		_disconnect_client(client_id)


func _disconnect_client(client_id: int) -> void:
	if _clients.has(client_id):
		client_disconnected.emit(client_id)
		print("[Codot] Client disconnected: ", client_id)
		_clients.erase(client_id)


func _handle_packet(client_id: int, packet: PackedByteArray) -> void:
	var text: String = packet.get_string_from_utf8()
	
	var json: JSON = JSON.new()
	var parse_error: int = json.parse(text)
	
	if parse_error != OK:
		var err_response: Dictionary = {
			"id": null,
			"success": false,
			"error": {"code": "PARSE_ERROR", "message": json.get_error_message()}
		}
		send_response(client_id, err_response)
		return
	
	var command = json.data
	if command is Dictionary:
		command_received.emit(client_id, command)
	else:
		var err_response: Dictionary = {
			"id": null,
			"success": false,
			"error": {"code": "INVALID_COMMAND", "message": "Command must be a JSON object"}
		}
		send_response(client_id, err_response)
