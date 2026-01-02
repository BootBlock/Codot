extends GutTest
## Unit tests for the Codot WebSocket server.
##
## These tests verify the WebSocket server functionality including
## connection management, message handling, and client tracking.


var _server: Node = null


func before_each() -> void:
	# Create a fresh server for each test
	var server_script = load("res://addons/codot/websocket_server.gd")
	_server = server_script.new()
	add_child_autofree(_server)


func after_each() -> void:
	if _server != null and _server._is_running:
		_server.stop()
	_server = null


# =============================================================================
# Server Initialization Tests
# =============================================================================

func test_server_starts_on_valid_port() -> void:
	var result = _server.start(16850)  # Use high port to avoid conflicts
	assert_eq(result, OK, "Server should start successfully on valid port")
	assert_true(_server._is_running, "Server should be marked as running")


func test_server_stops_cleanly() -> void:
	_server.start(16851)
	assert_true(_server._is_running, "Server should be running after start")
	
	_server.stop()
	assert_false(_server._is_running, "Server should stop running after stop()")


func test_server_clears_clients_on_stop() -> void:
	_server.start(16852)
	# Simulate having a client (internal state manipulation for testing)
	_server._clients[1] = null  # Fake client
	
	_server.stop()
	assert_eq(_server._clients.size(), 0, "Clients should be cleared on stop")


func test_server_clears_pending_on_stop() -> void:
	_server.start(16853)
	# Simulate pending peer
	_server._pending_peers["fake"] = null
	
	_server.stop()
	assert_eq(_server._pending_peers.size(), 0, "Pending peers should be cleared on stop")


func test_server_restart() -> void:
	var result1 = _server.start(16854)
	assert_eq(result1, OK, "First start should succeed")
	
	var result2 = _server.start(16855)  # Start again (should stop first)
	assert_eq(result2, OK, "Restart should succeed")
	assert_true(_server._is_running, "Server should be running after restart")


# =============================================================================
# Signal Tests
# =============================================================================

func test_signals_exist() -> void:
	assert_true(_server.has_signal("client_connected"),
		"Server should have client_connected signal")
	assert_true(_server.has_signal("client_disconnected"),
		"Server should have client_disconnected signal")
	assert_true(_server.has_signal("command_received"),
		"Server should have command_received signal")


# =============================================================================
# Response Sending Tests
# =============================================================================

func test_send_response_to_invalid_client() -> void:
	_server.start(16856)
	var result = _server.send_response(99999, {"test": true})
	assert_eq(result, ERR_DOES_NOT_EXIST, 
		"Sending to non-existent client should return ERR_DOES_NOT_EXIST")


# =============================================================================
# Client ID Generation Tests
# =============================================================================

func test_client_id_starts_at_one() -> void:
	assert_eq(_server._next_client_id, 1, "Client IDs should start at 1")


func test_initial_state_is_empty() -> void:
	assert_eq(_server._clients.size(), 0, "Should start with no clients")
	assert_eq(_server._pending_peers.size(), 0, "Should start with no pending peers")
	assert_false(_server._is_running, "Should start not running")
