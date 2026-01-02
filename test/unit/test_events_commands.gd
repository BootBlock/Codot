extends GutTest
## Unit tests for event subscription commands.
##
## Tests event subscriptions, polling, and filtering.


var _handler: Node = null


func before_each() -> void:
	var handler_script = load("res://addons/codot/command_handler.gd")
	_handler = handler_script.new()
	add_child_autofree(_handler)


func after_each() -> void:
	_handler = null


# =============================================================================
# List Event Types Tests
# =============================================================================

func test_list_event_types_returns_array() -> void:
	var command = {
		"id": 1,
		"command": "list_event_types",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_has(response["result"], "event_types", "Should have event_types array")
	assert_has(response["result"], "count", "Should have count")
	assert_gt(response["result"]["count"], 0, "Should have at least one event type")


func test_list_event_types_has_expected_types() -> void:
	var command = {
		"id": 1,
		"command": "list_event_types",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	
	var types: Array = []
	for event_type in response["result"]["event_types"]:
		types.append(event_type["type"])
	
	assert_has(types, "scene_changed", "Should have scene_changed")
	assert_has(types, "node_added", "Should have node_added")
	assert_has(types, "script_error", "Should have script_error")
	assert_has(types, "game_started", "Should have game_started")


# =============================================================================
# Subscribe Tests
# =============================================================================

func test_subscribe_requires_event_type() -> void:
	var command = {
		"id": 1,
		"command": "subscribe",
		"params": {"client_id": "test_client"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without event_type")
	assert_eq(response["error"]["code"], "MISSING_PARAM", "Should return MISSING_PARAM")


func test_subscribe_requires_client_id() -> void:
	var command = {
		"id": 1,
		"command": "subscribe",
		"params": {"event_type": "scene_changed"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without client_id")
	assert_eq(response["error"]["code"], "MISSING_PARAM", "Should return MISSING_PARAM")


func test_subscribe_validates_event_type() -> void:
	var command = {
		"id": 1,
		"command": "subscribe",
		"params": {"event_type": "invalid_event", "client_id": "test_client"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail for invalid event type")
	assert_eq(response["error"]["code"], "INVALID_EVENT_TYPE", "Should return INVALID_EVENT_TYPE")


func test_subscribe_success() -> void:
	var command = {
		"id": 1,
		"command": "subscribe",
		"params": {"event_type": "scene_changed", "client_id": "test_client"}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_true(response["result"]["subscribed"], "Should indicate subscribed")
	assert_eq(response["result"]["event_type"], "scene_changed", "Should return event type")
	assert_eq(response["result"]["client_id"], "test_client", "Should return client id")


# =============================================================================
# Unsubscribe Tests
# =============================================================================

func test_unsubscribe_requires_event_type() -> void:
	var command = {
		"id": 1,
		"command": "unsubscribe",
		"params": {"client_id": "test_client"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without event_type")


func test_unsubscribe_requires_client_id() -> void:
	var command = {
		"id": 1,
		"command": "unsubscribe",
		"params": {"event_type": "scene_changed"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without client_id")


func test_unsubscribe_nonexistent_subscription() -> void:
	var command = {
		"id": 1,
		"command": "unsubscribe",
		"params": {"event_type": "scene_changed", "client_id": "nonexistent_client"}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail for nonexistent client")
	assert_eq(response["error"]["code"], "NOT_SUBSCRIBED", "Should return NOT_SUBSCRIBED")


# =============================================================================
# Get Subscriptions Tests
# =============================================================================

func test_get_subscriptions_requires_client_id() -> void:
	var command = {
		"id": 1,
		"command": "get_subscriptions",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without client_id")


func test_get_subscriptions_empty_for_new_client() -> void:
	var command = {
		"id": 1,
		"command": "get_subscriptions",
		"params": {"client_id": "new_client"}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_eq(response["result"]["count"], 0, "Should have no subscriptions")


# =============================================================================
# Poll Events Tests
# =============================================================================

func test_poll_events_requires_client_id() -> void:
	var command = {
		"id": 1,
		"command": "poll_events",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without client_id")


func test_poll_events_empty_for_new_client() -> void:
	var command = {
		"id": 1,
		"command": "poll_events",
		"params": {"client_id": "new_client"}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_eq(response["result"]["count"], 0, "Should have no events")


# =============================================================================
# Unsubscribe All Tests
# =============================================================================

func test_unsubscribe_all_requires_client_id() -> void:
	var command = {
		"id": 1,
		"command": "unsubscribe_all",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_false(response["success"], "Should fail without client_id")


func test_unsubscribe_all_success() -> void:
	var command = {
		"id": 1,
		"command": "unsubscribe_all",
		"params": {"client_id": "test_client"}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_has(response["result"], "unsubscribed_count", "Should have count")


# =============================================================================
# Subscription Stats Tests
# =============================================================================

func test_get_subscription_stats_returns_structure() -> void:
	var command = {
		"id": 1,
		"command": "get_subscription_stats",
		"params": {}
	}
	var response = await _handler.handle_command(command)
	
	assert_true(response["success"], "Should succeed")
	assert_has(response["result"], "total_clients", "Should have total_clients")
	assert_has(response["result"], "total_subscriptions", "Should have total_subscriptions")
	assert_has(response["result"], "queue_size", "Should have queue_size")


# =============================================================================
# Full Subscription Workflow Test
# =============================================================================

func test_subscribe_and_unsubscribe_workflow() -> void:
	# Subscribe
	var subscribe_cmd = {
		"id": 1,
		"command": "subscribe",
		"params": {"event_type": "node_added", "client_id": "workflow_client"}
	}
	var sub_response = await _handler.handle_command(subscribe_cmd)
	assert_true(sub_response["success"], "Should subscribe successfully")
	
	# Get subscriptions
	var get_cmd = {
		"id": 2,
		"command": "get_subscriptions",
		"params": {"client_id": "workflow_client"}
	}
	var get_response = await _handler.handle_command(get_cmd)
	assert_true(get_response["success"], "Should get subscriptions")
	assert_eq(get_response["result"]["count"], 1, "Should have one subscription")
	
	# Unsubscribe
	var unsub_cmd = {
		"id": 3,
		"command": "unsubscribe",
		"params": {"event_type": "node_added", "client_id": "workflow_client"}
	}
	var unsub_response = await _handler.handle_command(unsub_cmd)
	assert_true(unsub_response["success"], "Should unsubscribe successfully")
	
	# Verify unsubscribed
	var verify_cmd = {
		"id": 4,
		"command": "get_subscriptions",
		"params": {"client_id": "workflow_client"}
	}
	var verify_response = await _handler.handle_command(verify_cmd)
	assert_true(verify_response["success"], "Should get subscriptions")
	assert_eq(verify_response["result"]["count"], 0, "Should have no subscriptions")
