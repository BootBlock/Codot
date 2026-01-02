@tool
## Event Subscription Module
## Handles event subscriptions for push notifications.
##
## Allows AI agents to subscribe to real-time events like:
## - Scene changes (node added/removed/modified)
## - Errors and warnings
## - Game events (play/pause/stop)
## - File system changes
extends "command_base.gd"


## Active subscriptions by client
## Format: { client_id: { event_type: { options } } }
var _subscriptions: Dictionary = {}

## Event queue for pending notifications
var _event_queue: Array = []

## Maximum events to queue per subscription
const MAX_QUEUE_SIZE := 100


## Get list of available event types.
func cmd_list_event_types(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var event_types := [
		{
			"type": "scene_changed",
			"description": "Triggered when current scene changes",
			"data": ["old_scene", "new_scene"]
		},
		{
			"type": "node_added",
			"description": "Triggered when a node is added to the scene",
			"data": ["path", "type", "parent"]
		},
		{
			"type": "node_removed",
			"description": "Triggered when a node is removed from the scene",
			"data": ["path", "type"]
		},
		{
			"type": "node_renamed",
			"description": "Triggered when a node is renamed",
			"data": ["old_path", "new_path", "old_name", "new_name"]
		},
		{
			"type": "property_changed",
			"description": "Triggered when a node property changes",
			"data": ["path", "property", "old_value", "new_value"]
		},
		{
			"type": "script_error",
			"description": "Triggered on script errors",
			"data": ["file", "line", "message", "severity"]
		},
		{
			"type": "game_started",
			"description": "Triggered when game starts playing",
			"data": ["scene", "timestamp"]
		},
		{
			"type": "game_stopped",
			"description": "Triggered when game stops",
			"data": ["reason", "timestamp"]
		},
		{
			"type": "game_paused",
			"description": "Triggered when game is paused",
			"data": ["timestamp"]
		},
		{
			"type": "file_changed",
			"description": "Triggered when a file is modified",
			"data": ["path", "action"]  # action: created, modified, deleted
		},
		{
			"type": "selection_changed",
			"description": "Triggered when editor selection changes",
			"data": ["selected_nodes"]
		},
		{
			"type": "debug_output",
			"description": "Triggered on debug output (print, warning, error)",
			"data": ["type", "message", "file", "line"]
		}
	]
	
	return _success(cmd_id, {
		"event_types": event_types,
		"count": event_types.size()
	})


## Subscribe to an event type.
## [br][br]
## [param params]:
## - 'event_type' (String, required): Type of event to subscribe to.
## - 'client_id' (String, required): Unique client identifier.
## - 'filter' (Dictionary, optional): Filter conditions for the event.
func cmd_subscribe(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var event_type: String = params.get("event_type", "")
	var client_id: String = params.get("client_id", "")
	
	if event_type.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'event_type' parameter")
	if client_id.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'client_id' parameter")
	
	var valid_types := ["scene_changed", "node_added", "node_removed", "node_renamed",
						"property_changed", "script_error", "game_started", "game_stopped",
						"game_paused", "file_changed", "selection_changed", "debug_output"]
	
	if event_type not in valid_types:
		return _error(cmd_id, "INVALID_EVENT_TYPE", 
			"Invalid event type: %s. Valid types: %s" % [event_type, ", ".join(valid_types)])
	
	var filter: Dictionary = params.get("filter", {})
	
	# Initialize client subscriptions if needed
	if not _subscriptions.has(client_id):
		_subscriptions[client_id] = {}
	
	_subscriptions[client_id][event_type] = {
		"subscribed_at": Time.get_unix_time_from_system(),
		"filter": filter,
		"event_count": 0
	}
	
	return _success(cmd_id, {
		"subscribed": true,
		"event_type": event_type,
		"client_id": client_id,
		"filter": filter
	})


## Unsubscribe from an event type.
## [br][br]
## [param params]:
## - 'event_type' (String, required): Type of event to unsubscribe from.
## - 'client_id' (String, required): Unique client identifier.
func cmd_unsubscribe(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var event_type: String = params.get("event_type", "")
	var client_id: String = params.get("client_id", "")
	
	if event_type.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'event_type' parameter")
	if client_id.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'client_id' parameter")
	
	if not _subscriptions.has(client_id):
		return _error(cmd_id, "NOT_SUBSCRIBED", "Client has no subscriptions")
	
	if not _subscriptions[client_id].has(event_type):
		return _error(cmd_id, "NOT_SUBSCRIBED", 
			"Client not subscribed to event type: " + event_type)
	
	_subscriptions[client_id].erase(event_type)
	
	# Clean up empty client entries
	if _subscriptions[client_id].is_empty():
		_subscriptions.erase(client_id)
	
	return _success(cmd_id, {
		"unsubscribed": true,
		"event_type": event_type,
		"client_id": client_id
	})


## Get all active subscriptions for a client.
## [br][br]
## [param params]:
## - 'client_id' (String, required): Unique client identifier.
func cmd_get_subscriptions(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var client_id: String = params.get("client_id", "")
	
	if client_id.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'client_id' parameter")
	
	if not _subscriptions.has(client_id):
		return _success(cmd_id, {
			"client_id": client_id,
			"subscriptions": [],
			"count": 0
		})
	
	var subs: Array = []
	for event_type in _subscriptions[client_id]:
		var sub_info: Dictionary = _subscriptions[client_id][event_type].duplicate()
		sub_info["event_type"] = event_type
		subs.append(sub_info)
	
	return _success(cmd_id, {
		"client_id": client_id,
		"subscriptions": subs,
		"count": subs.size()
	})


## Get queued events for a client (poll-based fallback).
## [br][br]
## [param params]:
## - 'client_id' (String, required): Unique client identifier.
## - 'max_events' (int, default 50): Maximum events to return.
## - 'clear' (bool, default true): Clear returned events from queue.
func cmd_poll_events(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var client_id: String = params.get("client_id", "")
	var max_events: int = params.get("max_events", 50)
	var clear: bool = params.get("clear", true)
	
	if client_id.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'client_id' parameter")
	
	# Filter events for this client
	var client_events: Array = []
	var events_to_remove: Array = []
	
	for i in range(_event_queue.size()):
		var event: Dictionary = _event_queue[i]
		if _should_deliver_event(client_id, event):
			client_events.append(event)
			if clear:
				events_to_remove.append(i)
		
		if client_events.size() >= max_events:
			break
	
	# Remove delivered events (in reverse order to maintain indices)
	if clear:
		events_to_remove.reverse()
		for idx in events_to_remove:
			_event_queue.remove_at(idx)
	
	return _success(cmd_id, {
		"client_id": client_id,
		"events": client_events,
		"count": client_events.size(),
		"remaining_in_queue": _event_queue.size()
	})


## Clear all subscriptions for a client.
## [br][br]
## [param params]:
## - 'client_id' (String, required): Unique client identifier.
func cmd_unsubscribe_all(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var client_id: String = params.get("client_id", "")
	
	if client_id.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'client_id' parameter")
	
	var count := 0
	if _subscriptions.has(client_id):
		count = _subscriptions[client_id].size()
		_subscriptions.erase(client_id)
	
	return _success(cmd_id, {
		"client_id": client_id,
		"unsubscribed_count": count
	})


# =============================================================================
# Internal Event Handling
# =============================================================================

## Queue an event for delivery to subscribers.
func queue_event(event_type: String, data: Dictionary) -> void:
	var event := {
		"type": event_type,
		"timestamp": Time.get_unix_time_from_system(),
		"data": data
	}
	
	_event_queue.append(event)
	
	# Trim queue if too large
	while _event_queue.size() > MAX_QUEUE_SIZE:
		_event_queue.pop_front()


## Check if an event should be delivered to a client.
func _should_deliver_event(client_id: String, event: Dictionary) -> bool:
	if not _subscriptions.has(client_id):
		return false
	
	var event_type: String = event.get("type", "")
	if not _subscriptions[client_id].has(event_type):
		return false
	
	var subscription: Dictionary = _subscriptions[client_id][event_type]
	var filter: Dictionary = subscription.get("filter", {})
	
	# Apply filters
	if filter.is_empty():
		return true
	
	var event_data: Dictionary = event.get("data", {})
	
	# Check path filter
	if filter.has("path_prefix"):
		var path: String = event_data.get("path", "")
		if not path.begins_with(filter["path_prefix"]):
			return false
	
	# Check type filter
	if filter.has("node_type"):
		var node_type: String = event_data.get("type", "")
		if node_type != filter["node_type"]:
			return false
	
	# Check severity filter (for errors)
	if filter.has("min_severity"):
		var severity: String = event_data.get("severity", "info")
		var min_sev: String = filter["min_severity"]
		if not _severity_meets_minimum(severity, min_sev):
			return false
	
	return true


## Check if severity meets minimum threshold.
func _severity_meets_minimum(severity: String, minimum: String) -> bool:
	var levels := {"info": 0, "warning": 1, "error": 2, "critical": 3}
	var sev_level: int = levels.get(severity, 0)
	var min_level: int = levels.get(minimum, 0)
	return sev_level >= min_level


## Get subscription statistics.
func cmd_get_subscription_stats(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var total_clients := _subscriptions.size()
	var total_subscriptions := 0
	var subscriptions_by_type: Dictionary = {}
	
	for client_id in _subscriptions:
		for event_type in _subscriptions[client_id]:
			total_subscriptions += 1
			if not subscriptions_by_type.has(event_type):
				subscriptions_by_type[event_type] = 0
			subscriptions_by_type[event_type] += 1
	
	return _success(cmd_id, {
		"total_clients": total_clients,
		"total_subscriptions": total_subscriptions,
		"subscriptions_by_type": subscriptions_by_type,
		"queue_size": _event_queue.size()
	})
