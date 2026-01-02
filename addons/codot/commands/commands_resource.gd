## Resource Operations Module
## Handles resources, animations, and audio operations.
extends "command_base.gd"


# =============================================================================
# Resource Operations
# =============================================================================

## Load a resource and return basic info.
## [br][br]
## [param params]: Must contain 'path' (String) - resource path.
func cmd_load_resource(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not ResourceLoader.exists(path):
		return _error(cmd_id, "RESOURCE_NOT_FOUND", "Resource not found: " + path)
	
	var resource = load(path)
	if resource == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load resource: " + path)
	
	return _success(cmd_id, {
		"loaded": true,
		"path": path,
		"type": resource.get_class(),
		"resource_name": resource.resource_name if resource.resource_name else ""
	})


## Get detailed information about a resource.
## [br][br]
## [param params]: Must contain 'path' (String) - resource path.
func cmd_get_resource_info(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not ResourceLoader.exists(path):
		return _error(cmd_id, "RESOURCE_NOT_FOUND", "Resource not found: " + path)
	
	var resource = load(path)
	if resource == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load resource: " + path)
	
	var properties: Dictionary = {}
	for prop in resource.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_EDITOR:
			var value = resource.get(prop["name"])
			properties[prop["name"]] = _safe_value(value)
	
	return _success(cmd_id, {
		"path": path,
		"type": resource.get_class(),
		"resource_name": resource.resource_name if resource.resource_name else "",
		"properties": properties
	})


# =============================================================================
# Animation Operations
# =============================================================================

## List all animations in an AnimationPlayer.
## [br][br]
## [param params]: Must contain 'path' (String) - AnimationPlayer node path.
func cmd_list_animations(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter (AnimationPlayer node)")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node is AnimationPlayer:
		return _error(cmd_id, "INVALID_NODE", "Node is not an AnimationPlayer")
	
	var anim_player: AnimationPlayer = node
	var animations: Array = []
	
	for anim_name in anim_player.get_animation_list():
		var anim = anim_player.get_animation(anim_name)
		animations.append({
			"name": anim_name,
			"length": anim.length,
			"loop_mode": anim.loop_mode,
			"track_count": anim.get_track_count()
		})
	
	return _success(cmd_id, {
		"path": node_path,
		"animations": animations,
		"current": anim_player.current_animation,
		"is_playing": anim_player.is_playing()
	})


## Play an animation.
## [br][br]
## [param params]:
## - 'path' (String, required): AnimationPlayer node path.
## - 'animation' (String, required): Animation name to play.
## - 'blend' (float, default -1): Custom blend time.
## - 'speed' (float, default 1.0): Playback speed.
## - 'from_end' (bool, default false): Play from end.
func cmd_play_animation(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var animation_name: String = params.get("animation", "")
	var custom_blend: float = params.get("blend", -1.0)
	var custom_speed: float = params.get("speed", 1.0)
	var from_end: bool = params.get("from_end", false)
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if animation_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'animation' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node is AnimationPlayer:
		return _error(cmd_id, "INVALID_NODE", "Node is not an AnimationPlayer")
	
	var anim_player: AnimationPlayer = node
	
	if not anim_player.has_animation(animation_name):
		return _error(cmd_id, "ANIMATION_NOT_FOUND", "Animation not found: " + animation_name)
	
	anim_player.play(animation_name, custom_blend, custom_speed, from_end)
	
	return _success(cmd_id, {
		"playing": true,
		"path": node_path,
		"animation": animation_name
	})


## Stop animation on an AnimationPlayer.
## [br][br]
## [param params]:
## - 'path' (String, required): AnimationPlayer node path.
## - 'keep_state' (bool, default true): Keep current animation pose.
func cmd_stop_animation(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var keep_state: bool = params.get("keep_state", true)
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node is AnimationPlayer:
		return _error(cmd_id, "INVALID_NODE", "Node is not an AnimationPlayer")
	
	var anim_player: AnimationPlayer = node
	anim_player.stop(keep_state)
	
	return _success(cmd_id, {
		"stopped": true,
		"path": node_path
	})


# =============================================================================
# Audio Operations
# =============================================================================

## List all audio buses.
func cmd_list_audio_buses(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var buses: Array = []
	
	for i in range(AudioServer.bus_count):
		buses.append({
			"index": i,
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"mute": AudioServer.is_bus_mute(i),
			"solo": AudioServer.is_bus_solo(i),
			"bypass_effects": AudioServer.is_bus_bypassing_effects(i),
			"effect_count": AudioServer.get_bus_effect_count(i)
		})
	
	return _success(cmd_id, {
		"buses": buses,
		"count": buses.size()
	})


## Set volume of an audio bus.
## [br][br]
## [param params]:
## - 'bus' (String, default "Master"): Audio bus name.
## - 'volume_db' (float, default 0.0): Volume in decibels.
func cmd_set_audio_bus_volume(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var bus_name: String = params.get("bus", "Master")
	var volume_db: float = params.get("volume_db", 0.0)
	
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return _error(cmd_id, "BUS_NOT_FOUND", "Audio bus not found: " + bus_name)
	
	AudioServer.set_bus_volume_db(bus_idx, volume_db)
	
	return _success(cmd_id, {
		"set": true,
		"bus": bus_name,
		"volume_db": volume_db
	})


## Set mute status of an audio bus.
## [br][br]
## [param params]:
## - 'bus' (String, default "Master"): Audio bus name.
## - 'mute' (bool, default true): Whether to mute the bus.
func cmd_set_audio_bus_mute(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var bus_name: String = params.get("bus", "Master")
	var mute: bool = params.get("mute", true)
	
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return _error(cmd_id, "BUS_NOT_FOUND", "Audio bus not found: " + bus_name)
	
	AudioServer.set_bus_mute(bus_idx, mute)
	
	return _success(cmd_id, {
		"set": true,
		"bus": bus_name,
		"mute": mute
	})


# =============================================================================
# Resource Creation & Management
# =============================================================================

## Create a new resource of a specified type.
## [br][br]
## [param params]:
## - 'type' (String, required): Resource type (e.g., "Resource", "ShaderMaterial", "Theme").
## - 'path' (String, required): Path to save the resource.
## - 'properties' (Dictionary, optional): Initial properties to set.
func cmd_create_resource(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var type: String = params.get("type", "")
	var path: String = params.get("path", "")
	var properties: Dictionary = params.get("properties", {})
	
	if type.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'type' parameter")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	# Check if type exists and is a resource
	if not ClassDB.class_exists(type):
		return _error(cmd_id, "INVALID_TYPE", "Class does not exist: " + type)
	if not ClassDB.is_parent_class(type, "Resource"):
		return _error(cmd_id, "INVALID_TYPE", "Type is not a Resource: " + type)
	
	# Create the resource
	var resource := ClassDB.instantiate(type) as Resource
	if resource == null:
		return _error(cmd_id, "CREATE_FAILED", "Failed to create resource of type: " + type)
	
	# Set properties
	var set_props: Array = []
	for key in properties:
		if resource.has_property(key):
			resource.set(key, properties[key])
			set_props.append(key)
	
	# Ensure directory exists
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Save the resource
	var result := ResourceSaver.save(resource, path)
	if result != OK:
		return _error(cmd_id, "SAVE_FAILED", "Failed to save resource to: " + path)
	
	return _success(cmd_id, {
		"created": true,
		"type": type,
		"path": path,
		"properties_set": set_props
	})


## Save an existing resource (reload and save to update).
## [br][br]
## [param params]:
## - 'path' (String, required): Resource path to save.
func cmd_save_resource(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not ResourceLoader.exists(path):
		return _error(cmd_id, "RESOURCE_NOT_FOUND", "Resource not found: " + path)
	
	var resource := load(path)
	if resource == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load resource: " + path)
	
	var result := ResourceSaver.save(resource, path)
	if result != OK:
		return _error(cmd_id, "SAVE_FAILED", "Failed to save resource: " + path)
	
	return _success(cmd_id, {
		"saved": true,
		"path": path,
		"type": resource.get_class()
	})


## Duplicate a resource to a new path.
## [br][br]
## [param params]:
## - 'source_path' (String, required): Source resource path.
## - 'dest_path' (String, required): Destination path.
## - 'subresources' (bool, default false): Duplicate embedded subresources.
func cmd_duplicate_resource(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var source_path: String = params.get("source_path", "")
	var dest_path: String = params.get("dest_path", "")
	var subresources: bool = params.get("subresources", false)
	
	if source_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'source_path' parameter")
	if dest_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'dest_path' parameter")
	
	if not ResourceLoader.exists(source_path):
		return _error(cmd_id, "RESOURCE_NOT_FOUND", "Source resource not found: " + source_path)
	
	var resource := load(source_path)
	if resource == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load source resource")
	
	var duplicate := resource.duplicate(subresources)
	if duplicate == null:
		return _error(cmd_id, "DUPLICATE_FAILED", "Failed to duplicate resource")
	
	# Ensure directory exists
	var dir_path := dest_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	var result := ResourceSaver.save(duplicate, dest_path)
	if result != OK:
		return _error(cmd_id, "SAVE_FAILED", "Failed to save duplicate to: " + dest_path)
	
	return _success(cmd_id, {
		"duplicated": true,
		"source_path": source_path,
		"dest_path": dest_path,
		"type": resource.get_class()
	})


## Set properties on an existing resource.
## [br][br]
## [param params]:
## - 'path' (String, required): Resource path.
## - 'properties' (Dictionary, required): Properties to set.
## - 'save' (bool, default true): Save after setting properties.
func cmd_set_resource_properties(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	var properties: Dictionary = params.get("properties", {})
	var save: bool = params.get("save", true)
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if properties.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'properties' parameter")
	
	if not ResourceLoader.exists(path):
		return _error(cmd_id, "RESOURCE_NOT_FOUND", "Resource not found: " + path)
	
	var resource := load(path)
	if resource == null:
		return _error(cmd_id, "LOAD_FAILED", "Failed to load resource")
	
	# Set properties
	var set_props: Array = []
	var failed_props: Array = []
	
	for key in properties:
		if resource.has_property(key):
			resource.set(key, properties[key])
			set_props.append(key)
		else:
			failed_props.append(key)
	
	# Save if requested
	if save:
		var result := ResourceSaver.save(resource, path)
		if result != OK:
			return _error(cmd_id, "SAVE_FAILED", "Set properties but failed to save")
	
	return _success(cmd_id, {
		"path": path,
		"properties_set": set_props,
		"properties_failed": failed_props,
		"saved": save
	})


## List available resource types that can be created.
func cmd_list_resource_types(cmd_id: Variant, _params: Dictionary) -> Dictionary:
	var resource_types: Array = []
	
	# Get all classes that inherit from Resource
	var classes := ClassDB.get_class_list()
	for cls in classes:
		if ClassDB.is_parent_class(cls, "Resource") and ClassDB.can_instantiate(cls):
			resource_types.append(cls)
	
	resource_types.sort()
	
	return _success(cmd_id, {
		"types": resource_types,
		"count": resource_types.size()
	})


# =============================================================================
# Helper Functions
# =============================================================================

## Safely convert values to JSON-compatible format.
func _safe_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_OBJECT:
			if value is Resource:
				return {"_type": "Resource", "path": value.resource_path}
			return {"_type": value.get_class() if value else "null"}
		TYPE_CALLABLE, TYPE_SIGNAL:
			return {"_type": type_string(typeof(value))}
		_:
			return value
