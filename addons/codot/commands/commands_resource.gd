## Resource Operations Module
## Handles resources, animations, and audio operations.
extends "command_base.gd"


## Check if an object has a property by name.
func _object_has_property(obj: Object, property_name: String) -> bool:
	for prop in obj.get_property_list():
		if prop["name"] == property_name:
			return true
	return false


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


## Create a new animation in an AnimationPlayer.
## [br][br]
## [param params]:
## - 'path' (String, required): AnimationPlayer node path.
## - 'name' (String, required): Name for the new animation.
## - 'length' (float, default 1.0): Animation length in seconds.
## - 'loop_mode' (int, default 0): 0=none, 1=linear, 2=pingpong.
## - 'step' (float, default 0.1): Animation step/keyframe interval.
func cmd_create_animation(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var anim_name: String = params.get("name", "")
	var length: float = params.get("length", 1.0)
	var loop_mode: int = params.get("loop_mode", 0)
	var step: float = params.get("step", 0.1)
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if anim_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'name' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node is AnimationPlayer:
		return _error(cmd_id, "INVALID_NODE", "Node is not an AnimationPlayer")
	
	var anim_player: AnimationPlayer = node
	
	if anim_player.has_animation(anim_name):
		return _error(cmd_id, "ANIMATION_EXISTS", "Animation already exists: " + anim_name)
	
	# Create the animation
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = loop_mode
	animation.step = step
	
	# Add to animation library
	var library: AnimationLibrary = null
	if anim_player.has_animation_library(""):
		library = anim_player.get_animation_library("")
	else:
		library = AnimationLibrary.new()
		anim_player.add_animation_library("", library)
	
	library.add_animation(anim_name, animation)
	
	return _success(cmd_id, {
		"created": true,
		"path": node_path,
		"name": anim_name,
		"length": length,
		"loop_mode": loop_mode
	})


## Add a track to an animation.
## [br][br]
## [param params]:
## - 'path' (String, required): AnimationPlayer node path.
## - 'animation' (String, required): Animation name.
## - 'track_type' (String, required): "value", "position_3d", "rotation_3d", "scale_3d", "method", "bezier".
## - 'track_path' (String, required): Node path and property (e.g., "Sprite2D:modulate").
func cmd_add_animation_track(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var anim_name: String = params.get("animation", "")
	var track_type: String = params.get("track_type", "value")
	var track_path: String = params.get("track_path", "")
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if anim_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'animation' parameter")
	if track_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'track_path' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node is AnimationPlayer:
		return _error(cmd_id, "INVALID_NODE", "Node is not an AnimationPlayer")
	
	var anim_player: AnimationPlayer = node
	
	if not anim_player.has_animation(anim_name):
		return _error(cmd_id, "ANIMATION_NOT_FOUND", "Animation not found: " + anim_name)
	
	var animation: Animation = anim_player.get_animation(anim_name)
	
	# Map track type string to enum
	var type_map := {
		"value": Animation.TYPE_VALUE,
		"position_3d": Animation.TYPE_POSITION_3D,
		"rotation_3d": Animation.TYPE_ROTATION_3D,
		"scale_3d": Animation.TYPE_SCALE_3D,
		"blend_shape": Animation.TYPE_BLEND_SHAPE,
		"method": Animation.TYPE_METHOD,
		"bezier": Animation.TYPE_BEZIER,
		"audio": Animation.TYPE_AUDIO,
		"animation": Animation.TYPE_ANIMATION
	}
	
	if not type_map.has(track_type):
		return _error(cmd_id, "INVALID_TRACK_TYPE", 
			"Invalid track type: %s. Valid types: %s" % [track_type, ", ".join(type_map.keys())])
	
	var track_idx := animation.add_track(type_map[track_type])
	animation.track_set_path(track_idx, NodePath(track_path))
	
	return _success(cmd_id, {
		"added": true,
		"path": node_path,
		"animation": anim_name,
		"track_index": track_idx,
		"track_type": track_type,
		"track_path": track_path
	})


## Add a keyframe to an animation track.
## [br][br]
## [param params]:
## - 'path' (String, required): AnimationPlayer node path.
## - 'animation' (String, required): Animation name.
## - 'track_index' (int, required): Track index to add keyframe to.
## - 'time' (float, required): Time in seconds for the keyframe.
## - 'value' (Variant, required): Value for the keyframe.
## - 'transition' (float, default 1.0): Transition type (-1 to 1).
func cmd_add_animation_keyframe(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var anim_name: String = params.get("animation", "")
	var track_index: int = params.get("track_index", -1)
	var time: float = params.get("time", 0.0)
	var value = params.get("value")
	var transition: float = params.get("transition", 1.0)
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if anim_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'animation' parameter")
	if track_index < 0:
		return _error(cmd_id, "MISSING_PARAM", "Missing or invalid 'track_index' parameter")
	if value == null:
		return _error(cmd_id, "MISSING_PARAM", "Missing 'value' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node is AnimationPlayer:
		return _error(cmd_id, "INVALID_NODE", "Node is not an AnimationPlayer")
	
	var anim_player: AnimationPlayer = node
	
	if not anim_player.has_animation(anim_name):
		return _error(cmd_id, "ANIMATION_NOT_FOUND", "Animation not found: " + anim_name)
	
	var animation: Animation = anim_player.get_animation(anim_name)
	
	if track_index >= animation.get_track_count():
		return _error(cmd_id, "INVALID_TRACK", "Track index out of range: %d" % track_index)
	
	# Convert value if it's a dictionary representing a type
	var converted_value = _convert_animation_value(value)
	
	var key_idx := animation.track_insert_key(track_index, time, converted_value, transition)
	
	return _success(cmd_id, {
		"added": true,
		"path": node_path,
		"animation": anim_name,
		"track_index": track_index,
		"key_index": key_idx,
		"time": time
	})


## Helper: Convert animation value from JSON-friendly format.
func _convert_animation_value(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("_type"):
			match value["_type"]:
				"Vector2":
					return Vector2(value.get("x", 0), value.get("y", 0))
				"Vector3":
					return Vector3(value.get("x", 0), value.get("y", 0), value.get("z", 0))
				"Color":
					return Color(value.get("r", 1), value.get("g", 1), value.get("b", 1), value.get("a", 1))
	return value


## Preview an animation (play in editor).
## [br][br]
## [param params]:
## - 'path' (String, required): AnimationPlayer node path.
## - 'animation' (String, required): Animation name to preview.
## - 'seek' (float, optional): Seek to specific time.
func cmd_preview_animation(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_scene(cmd_id)
	if result.has("error"):
		return result
	
	var node_path: String = params.get("path", "")
	var anim_name: String = params.get("animation", "")
	var seek_time: float = params.get("seek", -1.0)
	
	if node_path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if anim_name.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'animation' parameter")
	
	var root = _get_scene_root()
	var node = root.get_node_or_null(node_path)
	if node == null:
		return _error(cmd_id, "NODE_NOT_FOUND", "Node not found: " + node_path)
	
	if not node is AnimationPlayer:
		return _error(cmd_id, "INVALID_NODE", "Node is not an AnimationPlayer")
	
	var anim_player: AnimationPlayer = node
	
	if not anim_player.has_animation(anim_name):
		return _error(cmd_id, "ANIMATION_NOT_FOUND", "Animation not found: " + anim_name)
	
	# Play the animation
	anim_player.play(anim_name)
	
	# Seek if requested
	if seek_time >= 0:
		anim_player.seek(seek_time, true)
	
	return _success(cmd_id, {
		"previewing": true,
		"path": node_path,
		"animation": anim_name,
		"seeked_to": seek_time if seek_time >= 0 else 0.0
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
		if self._object_has_property(resource, key):
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
		if self._object_has_property(resource, key):
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
# Asset Management
# =============================================================================

## Get import settings for a resource.
## [br][br]
## [param params]:
## - 'path' (String, required): Path to the resource file.
func cmd_get_import_settings(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var path: String = params.get("path", "")
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return _success(cmd_id, {
			"path": path,
			"has_import_file": false,
			"settings": {},
			"note": "Resource does not have an import file (may not be imported)"
		})
	
	var file := FileAccess.open(import_path, FileAccess.READ)
	if file == null:
		return _error(cmd_id, "FILE_ERROR", "Could not open import file")
	
	var content := file.get_as_text()
	file.close()
	
	# Parse the import file (ConfigFile format)
	var config := ConfigFile.new()
	var err := config.load(import_path)
	if err != OK:
		return _error(cmd_id, "PARSE_ERROR", "Could not parse import file")
	
	var settings: Dictionary = {}
	var sections: PackedStringArray = config.get_sections()
	
	for section in sections:
		var section_dict: Dictionary = {}
		for key in config.get_section_keys(section):
			section_dict[key] = config.get_value(section, key)
		settings[section] = section_dict
	
	return _success(cmd_id, {
		"path": path,
		"has_import_file": true,
		"import_path": import_path,
		"settings": settings
	})


## Set import settings for a resource.
## [br][br]
## [param params]:
## - 'path' (String, required): Path to the resource file.
## - 'settings' (Dictionary, required): Settings to apply (section -> key -> value).
## - 'reimport' (bool, default true): Whether to reimport after setting.
func cmd_set_import_settings(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var path: String = params.get("path", "")
	var settings: Dictionary = params.get("settings", {})
	var reimport: bool = params.get("reimport", true)
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	if settings.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'settings' parameter")
	
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return _error(cmd_id, "NO_IMPORT_FILE", 
			"Resource does not have an import file: " + path)
	
	var config := ConfigFile.new()
	var err := config.load(import_path)
	if err != OK:
		return _error(cmd_id, "PARSE_ERROR", "Could not parse import file")
	
	var changed: Array = []
	
	for section in settings:
		for key in settings[section]:
			var old_value = config.get_value(section, key, null)
			var new_value = settings[section][key]
			config.set_value(section, key, new_value)
			changed.append({
				"section": section,
				"key": key,
				"old_value": str(old_value),
				"new_value": str(new_value)
			})
	
	err = config.save(import_path)
	if err != OK:
		return _error(cmd_id, "SAVE_ERROR", "Could not save import file")
	
	# Reimport if requested
	if reimport:
		editor_interface.get_resource_filesystem().reimport_files([path])
	
	return _success(cmd_id, {
		"path": path,
		"import_path": import_path,
		"changes": changed,
		"reimported": reimport
	})


## Get all resources that depend on a given resource.
## [br][br]
## [param params]:
## - 'path' (String, required): Path to the resource.
## - 'recursive' (bool, default false): Search recursively for transitive dependencies.
func cmd_get_resource_dependencies(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var path: String = params.get("path", "")
	var recursive: bool = params.get("recursive", false)
	
	if path.is_empty():
		return _error(cmd_id, "MISSING_PARAM", "Missing 'path' parameter")
	
	if not FileAccess.file_exists(path):
		return _error(cmd_id, "FILE_NOT_FOUND", "Resource not found: " + path)
	
	# Get what this resource depends on
	var dependencies: PackedStringArray = ResourceLoader.get_dependencies(path)
	var depends_on: Array = []
	for dep in dependencies:
		# Dependencies format: "path::type"
		var parts := dep.split("::")
		depends_on.append({
			"path": parts[0] if parts.size() > 0 else dep,
			"type": parts[1] if parts.size() > 1 else "unknown"
		})
	
	# Find what depends on this resource (reverse lookup)
	var dependents: Array = []
	var fs := editor_interface.get_resource_filesystem()
	var root_dir := fs.get_filesystem()
	_find_dependents(root_dir, path, dependents, recursive, {})
	
	return _success(cmd_id, {
		"path": path,
		"depends_on": depends_on,
		"depends_on_count": depends_on.size(),
		"dependents": dependents,
		"dependents_count": dependents.size()
	})


## Helper: Recursively find files that depend on a resource.
func _find_dependents(dir: EditorFileSystemDirectory, target_path: String, 
					  dependents: Array, recursive: bool, checked: Dictionary) -> void:
	for i in range(dir.get_file_count()):
		var file_path := dir.get_file_path(i)
		if checked.has(file_path):
			continue
		checked[file_path] = true
		
		var deps := ResourceLoader.get_dependencies(file_path)
		for dep in deps:
			var dep_path: String = dep.split("::")[0] if "::" in dep else dep
			if dep_path == target_path:
				dependents.append({
					"path": file_path,
					"type": dir.get_file_type(i)
				})
				break
	
	for i in range(dir.get_subdir_count()):
		_find_dependents(dir.get_subdir(i), target_path, dependents, recursive, checked)


## Find broken resource references in the project.
## [br][br]
## [param params]:
## - 'directory' (String, default "res://"): Directory to scan.
## - 'extensions' (Array, optional): File extensions to check.
func cmd_find_broken_references(cmd_id: Variant, params: Dictionary) -> Dictionary:
	var result = _require_editor(cmd_id)
	if result.has("error"):
		return result
	
	var directory: String = params.get("directory", "res://")
	var extensions: Array = params.get("extensions", ["tscn", "tres", "gd"])
	
	var broken_refs: Array = []
	var files_checked := 0
	
	var fs := editor_interface.get_resource_filesystem()
	var root_dir := fs.get_filesystem()
	
	_scan_for_broken_refs(root_dir, extensions, broken_refs, files_checked)
	
	return _success(cmd_id, {
		"directory": directory,
		"broken_references": broken_refs,
		"broken_count": broken_refs.size(),
		"files_checked": files_checked
	})


## Helper: Scan directory for broken references.
func _scan_for_broken_refs(dir: EditorFileSystemDirectory, extensions: Array,
						   broken_refs: Array, files_checked: int) -> int:
	for i in range(dir.get_file_count()):
		var file_path := dir.get_file_path(i)
		var ext := file_path.get_extension()
		
		if ext in extensions:
			files_checked += 1
			var deps := ResourceLoader.get_dependencies(file_path)
			for dep in deps:
				var dep_path: String = dep.split("::")[0] if "::" in dep else dep
				if not dep_path.is_empty() and not FileAccess.file_exists(dep_path):
					broken_refs.append({
						"file": file_path,
						"missing_dependency": dep_path
					})
	
	for i in range(dir.get_subdir_count()):
		files_checked = _scan_for_broken_refs(dir.get_subdir(i), extensions, broken_refs, files_checked)
	
	return files_checked


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
