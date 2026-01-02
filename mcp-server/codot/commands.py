"""
Command definitions for Codot tools.

This module defines all 80+ commands available in the Codot system.
Each command is represented as a CommandDefinition that specifies:
- A human-readable description for the MCP tool
- An input schema (JSON Schema) defining the tool's parameters
- An optional alternate Godot command name (if different from the key)

Commands are organized into categories:
- STATUS & INFO: Server health and project information
- GAME CONTROL: Play, stop, and debug running games
- FILE OPERATIONS: Create, read, write, delete, copy, move files
- SCENE MANAGEMENT: Open, save, create, duplicate, and modify scenes
- NODE OPERATIONS: Create, modify, delete, and query scene tree nodes
- EDITOR OPERATIONS: Control editor views, refresh filesystem
- SCRIPT & FILE: Create and edit GDScript files
- RESOURCE OPERATIONS: Create, duplicate, modify resources
- PROJECT: Project-level settings and configuration
- GUT TESTING: GUT test framework integration
- INPUT SIMULATION: Simulate keyboard/mouse/controller input
- SIGNALS: Signal inspection and emission
- METHODS: Method invocation and listing
- GROUPS: Node group management
- ANIMATION: AnimationPlayer control
- AUDIO: Sound playback and management
- DEBUG/PERFORMANCE: Profiling and performance monitoring
- PLUGIN MANAGEMENT: Enable/disable/list plugins

The COMMANDS dictionary maps command names (without 'godot_' prefix) to
their definitions. The MCP server adds the 'godot_' prefix when exposing
these as tools.
"""

from dataclasses import dataclass, field
from typing import Any


@dataclass
class CommandDefinition:
    """
    Definition of a Godot command exposed as an MCP tool.
    
    This dataclass encapsulates all metadata needed to expose a Godot
    command through the MCP protocol as a callable tool.
    
    Attributes:
        description: Human-readable description shown to MCP clients.
                    Should clearly explain what the command does.
        input_schema: JSON Schema dictionary defining the tool's parameters.
                     Follows JSON Schema draft-07 format with 'type', 
                     'properties', and 'required' fields.
        godot_command: Optional alternate command name to send to Godot.
                      If empty, the dictionary key is used as the command.
        enabled: Whether this command is exposed as an MCP tool.
                 Set to False to hide rarely-used commands.
                      
    Example:
        CommandDefinition(
            description="Create a new node in the scene tree",
            input_schema={
                "type": "object",
                "properties": {
                    "type": {"type": "string", "description": "Node type"},
                    "name": {"type": "string", "description": "Node name"},
                },
                "required": ["type", "name"],
            },
        )
    """
    
    description: str
    input_schema: dict[str, Any] = field(default_factory=dict)
    godot_command: str = ""  # If different from the key
    enabled: bool = True  # Whether to expose this command as an MCP tool


# Commands that are disabled by default to reduce tool count.
# These are still available in the COMMANDS dict but not exposed as MCP tools.
# To enable them, set enabled=True on the individual command or modify this set.
DISABLED_COMMANDS: set[str] = {
    # Animation tools - rarely needed for automation/testing
    "list_animations",
    "play_animation",
    "stop_animation",
    "create_animation",
    "add_animation_track",
    "add_animation_keyframe",
    "preview_animation",
    
    # Audio tools - rarely needed for automation/testing  
    "list_audio_buses",
    "set_audio_bus_volume",
    "set_audio_bus_mute",
    
    # Advanced resource tools
    "load_resource",
    "get_resource_info",
    "save_resource",
    "duplicate_resource",
    "set_resource_properties",
    "list_resource_types",
    "get_import_settings",
    "set_import_settings",
    "get_resource_dependencies",
    
    # Editor UI/theme tools - not useful for automation
    "get_editor_theme",
    "get_editor_layout",
    "get_editor_viewport_info",
    
    # Subscription/event tools - complex, rarely used
    "list_event_types",
    "subscribe",
    "unsubscribe",
    "get_subscriptions",
    "poll_events",
    "unsubscribe_all",
    "get_subscription_stats",
    
    # Advanced debug tools - rarely needed
    "get_profiler_data",
    "get_orphan_nodes",
    "get_object_stats",
    "get_stack_info",
    "get_scene_diff",
    
    # Breakpoint tools - usually done in editor
    "get_breakpoints",
    "set_breakpoint",
    "clear_breakpoints",
    
    # Input action management - rarely needed during automation
    "add_input_action",
    "remove_input_action",
    "add_input_event_key",
    "add_input_event_mouse",
    "add_input_event_joypad_button",
    "add_input_event_joypad_axis",
    "clear_input_action_events",
    
    # Autoload management - rarely changed during automation
    "get_autoload",
    "add_autoload",
    "remove_autoload",
    "rename_autoload",
    "set_autoload_path",
    "reorder_autoloads",
    
    # Advanced node operations
    "list_node_signals",
    "emit_signal",
    "list_node_methods",
    "get_nodes_in_group",
    "add_node_to_group",
    "remove_node_from_group",
    "make_node_local",
    "get_node_hierarchy_info",
    
    # Batch/bulk operations - complex, can use individual commands
    "batch_commands",
    "bulk_set_properties",
    "create_complete_scene",
    "create_scene_with_script",
    
    # Less commonly used file operations
    "find_file",
    "find_resources_by_type",
    "search_in_files",
    "find_nodes_by_script",
    "find_broken_references",
    
    # Editor state tools - rarely needed
    "get_editor_settings",
    "get_unsaved_changes",
    "get_recent_files",
    "mark_modified",
    
    # Plugin management - rarely needed during automation
    "enable_plugin",
    "disable_plugin",
    "reload_project",
}


# Command definitions - these match the implemented commands in command_handler.gd
COMMANDS: dict[str, CommandDefinition] = {
    # ========================================================================
    # STATUS & INFO
    # ========================================================================
    "ping": CommandDefinition(
        description="Ping the Godot server to check if it's responding. Returns pong and timestamp.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_status": CommandDefinition(
        description="Get the current status of Godot including version, running state, and project info",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    # ========================================================================
    # GAME CONTROL
    # ========================================================================
    "play": CommandDefinition(
        description="Start playing the main scene defined in project settings",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
        godot_command="play",
    ),
    
    "play_current": CommandDefinition(
        description="Start playing the currently open scene in the Godot editor",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
        godot_command="play_current",
    ),
    
    "play_custom_scene": CommandDefinition(
        description="Start playing a specific scene by path",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the scene file (e.g., 'res://scenes/main.tscn')",
                },
            },
            "required": ["path"],
        },
    ),
    
    "stop": CommandDefinition(
        description="Stop the currently running game/scene",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
        godot_command="stop",
    ),
    
    "is_playing": CommandDefinition(
        description="Check if a scene/game is currently running",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "pause_game": CommandDefinition(
        description="Pause the running game. Requires a game to be running.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "resume_game": CommandDefinition(
        description="Resume a paused game. Requires a game to be running.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_debug_output": CommandDefinition(
        description="Get debug output from Godot's debugger plugin or log file. Returns errors, warnings, and log entries with structured data (file paths, line numbers). Use this to check for runtime errors after playing a scene.",
        input_schema={
            "type": "object",
            "properties": {
                "lines": {
                    "type": "integer",
                    "description": "Maximum number of entries to return (default: 50)",
                    "default": 50,
                },
                "filter": {
                    "type": "string",
                    "enum": ["all", "error", "warning", "print"],
                    "description": "Filter entries by type (default: 'all')",
                    "default": "all",
                },
                "since_id": {
                    "type": "integer",
                    "description": "Only return entries after this ID. Use the value returned by clear_debug_log to track new entries.",
                    "default": 0,
                },
            },
            "required": [],
        },
    ),
    
    "clear_debug_log": CommandDefinition(
        description="Mark the current position in the debug log. Returns a 'since_id' value to use with get_debug_output to only see new entries. Call this before running a scene.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_debugger_status": CommandDefinition(
        description="Get the status of the debugger plugin, including whether it's capturing output, what message types have been seen, and diagnostics info. Useful for troubleshooting debug capture.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_editor_log": CommandDefinition(
        description="Read the Godot editor log file directly. This is a fallback/alternative to the debugger plugin that reads from the godot.log file.",
        input_schema={
            "type": "object",
            "properties": {
                "lines": {
                    "type": "integer",
                    "description": "Maximum number of lines to return (default: 100)",
                    "default": 100,
                },
                "filter": {
                    "type": "string",
                    "enum": ["all", "error", "warning", "print"],
                    "description": "Filter entries by type (default: 'all')",
                    "default": "all",
                },
                "tail": {
                    "type": "boolean",
                    "description": "If true, return the last N lines; if false, return first N lines (default: true)",
                    "default": True,
                },
            },
            "required": [],
        },
    ),
    
    # ========================================================================
    # SCENE TREE INSPECTION
    # ========================================================================
    "get_scene_tree": CommandDefinition(
        description="Get the scene tree structure of the currently edited scene. Returns a hierarchical view of all nodes.",
        input_schema={
            "type": "object",
            "properties": {
                "max_depth": {
                    "type": "integer",
                    "description": "Maximum depth to traverse (default: 10)",
                    "default": 10,
                },
                "include_visibility": {
                    "type": "boolean",
                    "description": "Include visibility state for CanvasItem/Node3D nodes",
                    "default": False,
                },
                "include_scripts": {
                    "type": "boolean",
                    "description": "Include script paths in output",
                    "default": True,
                },
                "filter_type": {
                    "type": "string",
                    "description": "Only include nodes of this type (e.g., 'Sprite2D', 'CollisionShape2D')",
                    "default": "",
                },
                "filter_name": {
                    "type": "string",
                    "description": "Only include nodes matching this name pattern",
                    "default": "",
                },
            },
            "required": [],
        },
    ),
    
    "get_node_info": CommandDefinition(
        description="Get detailed information about a specific node in the scene tree",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node (e.g., '.' for root, 'Player', 'Level/Enemies/Boss')",
                },
            },
            "required": ["path"],
        },
    ),
    
    "get_node_properties": CommandDefinition(
        description="Get all editable properties of a node",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node",
                },
            },
            "required": ["path"],
        },
    ),
    
    # ========================================================================
    # FILE OPERATIONS
    # ========================================================================
    "get_project_files": CommandDefinition(
        description="List files in the project directory, optionally filtered by extension",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Starting path (default: 'res://')",
                    "default": "res://",
                },
                "extension": {
                    "type": "string",
                    "description": "Filter by file extension (e.g., '.gd', '.tscn')",
                    "default": "",
                },
                "recursive": {
                    "type": "boolean",
                    "description": "Whether to search recursively (default: true)",
                    "default": True,
                },
            },
            "required": [],
        },
    ),
    
    "read_file": CommandDefinition(
        description="Read the contents of a file in the project",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the file (e.g., 'res://scripts/player.gd')",
                },
            },
            "required": ["path"],
        },
    ),
    
    "write_file": CommandDefinition(
        description="Write content to a file in the project. Use with caution!",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the file (e.g., 'res://scripts/new_script.gd')",
                },
                "content": {
                    "type": "string",
                    "description": "Content to write to the file",
                },
            },
            "required": ["path", "content"],
        },
    ),
    
    "file_exists": CommandDefinition(
        description="Check if a file or directory exists",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to check",
                },
            },
            "required": ["path"],
        },
    ),
    
    "create_directory": CommandDefinition(
        description="Create a directory (and any parent directories). Returns created (bool), already_exists (bool).",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Directory path to create (e.g., 'res://new_folder/subfolder')",
                },
            },
            "required": ["path"],
        },
    ),
    
    "delete_file": CommandDefinition(
        description="Delete a file. Returns deleted (bool).",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "File path to delete",
                },
            },
            "required": ["path"],
        },
    ),
    
    "delete_directory": CommandDefinition(
        description="Delete a directory. Must be empty unless recursive=true. Returns deleted (bool), files_deleted (int).",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Directory path to delete",
                },
                "recursive": {
                    "type": "boolean",
                    "description": "Delete all contents recursively (default: false)",
                    "default": False,
                },
            },
            "required": ["path"],
        },
    ),
    
    "rename_file": CommandDefinition(
        description="Rename or move a file or directory. Returns renamed (bool), type ('file' or 'directory').",
        input_schema={
            "type": "object",
            "properties": {
                "from_path": {
                    "type": "string",
                    "description": "Source path",
                },
                "to_path": {
                    "type": "string",
                    "description": "Destination path",
                },
            },
            "required": ["from_path", "to_path"],
        },
    ),
    
    "copy_file": CommandDefinition(
        description="Copy a file to a new location. Returns copied (bool).",
        input_schema={
            "type": "object",
            "properties": {
                "from_path": {
                    "type": "string",
                    "description": "Source file path",
                },
                "to_path": {
                    "type": "string",
                    "description": "Destination file path",
                },
                "overwrite": {
                    "type": "boolean",
                    "description": "Overwrite if destination exists (default: false)",
                    "default": False,
                },
            },
            "required": ["from_path", "to_path"],
        },
    ),
    
    "get_file_info": CommandDefinition(
        description="Get information about a file or directory (size, modified time, etc.).",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "File or directory path",
                },
            },
            "required": ["path"],
        },
    ),
    
    # ========================================================================
    # QUICK FIND OPERATIONS
    # ========================================================================
    "find_file": CommandDefinition(
        description="Find files by name pattern (glob-like matching). Returns matching file paths. Use to quickly locate files without scanning the entire project.",
        input_schema={
            "type": "object",
            "properties": {
                "pattern": {
                    "type": "string",
                    "description": "Search pattern - supports wildcards: 'player' (contains), '*.gd' (ends with), 'test_*' (starts with)",
                },
                "path": {
                    "type": "string",
                    "description": "Directory to search in (default: 'res://')",
                    "default": "res://",
                },
                "extensions": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Limit to specific extensions (e.g., ['gd', 'tscn']). Empty = all files.",
                },
                "max_results": {
                    "type": "integer",
                    "description": "Maximum number of results (default: 50)",
                    "default": 50,
                },
                "case_sensitive": {
                    "type": "boolean",
                    "description": "Case-sensitive matching (default: false)",
                    "default": False,
                },
            },
            "required": ["pattern"],
        },
    ),
    
    "find_resources_by_type": CommandDefinition(
        description="Find all resources of a specific type in the project. Useful for finding all scripts, scenes, textures, etc. Returns array of {path, type}.",
        input_schema={
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "description": "Resource type to find: 'Script', 'PackedScene', 'Texture2D', 'AudioStream', 'Shader', 'Material', 'Resource', 'Font', 'Animation', 'Mesh', 'Theme'",
                },
                "path": {
                    "type": "string",
                    "description": "Directory to search in (default: 'res://')",
                    "default": "res://",
                },
                "max_results": {
                    "type": "integer",
                    "description": "Maximum number of results (default: 100)",
                    "default": 100,
                },
            },
            "required": ["type"],
        },
    ),
    
    "search_in_files": CommandDefinition(
        description="Search for text within files (grep-like). Returns files with matches, line numbers, and context. Useful for finding usages of classes, functions, or variables.",
        input_schema={
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Text to search for",
                },
                "path": {
                    "type": "string",
                    "description": "Directory to search in (default: 'res://')",
                    "default": "res://",
                },
                "extensions": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "File extensions to search (default: ['gd', 'tscn', 'tres', 'cfg', 'json', 'md', 'txt'])",
                },
                "case_sensitive": {
                    "type": "boolean",
                    "description": "Case-sensitive search (default: false)",
                    "default": False,
                },
                "max_results": {
                    "type": "integer",
                    "description": "Maximum number of files with matches (default: 50)",
                    "default": 50,
                },
                "context_lines": {
                    "type": "integer",
                    "description": "Lines of context around matches (default: 1)",
                    "default": 1,
                },
            },
            "required": ["query"],
        },
    ),
    
    "find_nodes_by_script": CommandDefinition(
        description="Find all nodes that use a specific script. Searches scene files (.tscn) for script references. Returns scene paths and node names.",
        input_schema={
            "type": "object",
            "properties": {
                "script_path": {
                    "type": "string",
                    "description": "Path to the script (e.g., 'res://player.gd')",
                },
                "search_scenes": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Specific scenes to search. If not specified, searches all .tscn files.",
                },
                "max_results": {
                    "type": "integer",
                    "description": "Maximum number of results (default: 50)",
                    "default": 50,
                },
            },
            "required": ["script_path"],
        },
    ),
    
    # ========================================================================
    # SCENE OPERATIONS
    # ========================================================================
    "open_scene": CommandDefinition(
        description="Open a scene file in the editor. Returns opened (bool), path, and open_scenes list. Verifies the scene was actually opened.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the scene file (e.g., 'res://scenes/main.tscn')",
                },
            },
            "required": ["path"],
        },
    ),
    
    "save_scene": CommandDefinition(
        description="Save the current scene. Returns saved (bool), path, file_updated (bool), and error_code. Will fail with UNSAVED_SCENE if the scene has never been saved (use create_scene instead).",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "save_all_scenes": CommandDefinition(
        description="Save all open scenes. Returns saved (bool), scene_count, and scenes list.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_open_scenes": CommandDefinition(
        description="Get a list of all open scene files",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    # ========================================================================
    # EDITOR OPERATIONS
    # ========================================================================
    "get_selected_nodes": CommandDefinition(
        description="Get information about the currently selected nodes in the editor",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "select_node": CommandDefinition(
        description="Select a node in the scene tree",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node to select",
                },
            },
            "required": ["path"],
        },
    ),
    
    "get_editor_settings": CommandDefinition(
        description="Get some editor settings (theme, font size)",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_editor_state": CommandDefinition(
        description="Get comprehensive editor state including: is_playing, open_scenes, current_scene, current_scene_modified, selected_nodes, has_unsaved_changes, and modified_scenes. Use this to check if operations succeeded or to verify editor state before making changes.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_unsaved_changes": CommandDefinition(
        description="Check if there are unsaved changes in the editor. Returns has_unsaved, unsaved_scenes, current_scene_path, and current_scene_is_new. Use this before closing scenes or to verify saves completed.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    # ========================================================================
    # SCRIPT OPERATIONS
    # ========================================================================
    "get_script_errors": CommandDefinition(
        description="Check a script for errors",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the script file",
                },
            },
            "required": [],
        },
    ),
    
    "open_script": CommandDefinition(
        description="Open a script in the editor and optionally jump to a line",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the script file",
                },
                "line": {
                    "type": "integer",
                    "description": "Line number to jump to (optional)",
                    "default": 0,
                },
            },
            "required": ["path"],
        },
    ),
    
    "get_breakpoints": CommandDefinition(
        description="Get all breakpoints set in scripts",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Optional: filter to a specific script path",
                },
            },
            "required": [],
        },
    ),
    
    "set_breakpoint": CommandDefinition(
        description="Set or clear a breakpoint in a script. Opens the script at the specified line.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the script file",
                },
                "line": {
                    "type": "integer",
                    "description": "Line number (1-based)",
                },
                "enabled": {
                    "type": "boolean",
                    "description": "Whether to set (true) or clear (false) the breakpoint",
                    "default": True,
                },
            },
            "required": ["path", "line"],
        },
    ),
    
    "clear_breakpoints": CommandDefinition(
        description="Clear all breakpoints in all scripts or a specific script",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Script path. If empty, clears all breakpoints",
                },
            },
            "required": [],
        },
    ),
    
    # ========================================================================
    # PROJECT INFO
    # ========================================================================
    "get_project_settings": CommandDefinition(
        description="Get project settings (name, version, main scene, etc.)",
        input_schema={
            "type": "object",
            "properties": {
                "keys": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Specific setting keys to retrieve. If empty, returns common settings.",
                    "default": [],
                },
            },
            "required": [],
        },
    ),
    
    "list_resources": CommandDefinition(
        description="List resources of a specific type (scenes, scripts, textures, audio, etc.)",
        input_schema={
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "description": "Resource type: 'scenes', 'scripts', 'textures', 'audio', 'shaders', 'resources', or empty for all",
                    "enum": ["", "scenes", "scripts", "textures", "audio", "shaders", "resources"],
                    "default": "",
                },
                "path": {
                    "type": "string",
                    "description": "Starting path (default: 'res://')",
                    "default": "res://",
                },
            },
            "required": [],
        },
    ),
    
    "get_open_dialogs": CommandDefinition(
        description="Detect if any modal dialog is currently open in the Godot editor. Use this before running commands that might fail due to open dialogs (e.g., 'There is no defined scene to run' error dialog).",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "dismiss_dialog": CommandDefinition(
        description="Dismiss/close an open dialog in the Godot editor. Use after detecting an open dialog with get_open_dialogs.",
        input_schema={
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "description": "Action to take: 'ok' to confirm, 'cancel' to dismiss",
                    "enum": ["ok", "cancel"],
                    "default": "ok",
                },
                "dialog_name": {
                    "type": "string",
                    "description": "Optional: specific dialog name to close",
                    "default": "",
                },
            },
            "required": [],
        },
    ),
    
    "refresh_filesystem": CommandDefinition(
        description="Refresh the editor's FileSystem dock to detect new/modified files. Use after creating files externally.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "reimport_resource": CommandDefinition(
        description="Reimport a specific resource file. Useful after modifying import settings or source files.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Resource path to reimport",
                },
            },
            "required": ["path"],
        },
    ),
    
    "mark_modified": CommandDefinition(
        description="Mark a resource as unsaved/modified in the editor.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Resource path to mark as modified",
                },
            },
            "required": ["path"],
        },
    ),
    
    "get_current_screen": CommandDefinition(
        description="Get the current editor screen/view (2D, 3D, Script, AssetLib).",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "set_current_screen": CommandDefinition(
        description="Switch to a specific editor screen (2D, 3D, Script, AssetLib).",
        input_schema={
            "type": "object",
            "properties": {
                "screen": {
                    "type": "string",
                    "description": "Screen name to switch to",
                    "enum": ["2D", "3D", "Script", "AssetLib"],
                },
            },
            "required": ["screen"],
        },
    ),
    
    "get_project_config": CommandDefinition(
        description="Get the project-level Codot config (pre/post prompts stored per-project). Returns the .codot/config.json settings.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "set_project_config": CommandDefinition(
        description="Set a project-level Codot config setting. Stores in .codot/config.json. Supported keys: pre_prompt_message, post_prompt_message, wrap_prompts_with_prefix_suffix",
        input_schema={
            "type": "object",
            "properties": {
                "key": {
                    "type": "string",
                    "description": "Setting key to set",
                    "enum": ["pre_prompt_message", "post_prompt_message", "wrap_prompts_with_prefix_suffix"],
                },
                "value": {
                    "type": ["string", "boolean", "null"],
                    "description": "Value to set. Pass null to remove the setting (revert to editor settings).",
                },
            },
            "required": ["key", "value"],
        },
    ),
    
    # ========================================================================
    # UNDO/REDO
    # ========================================================================
    "undo": CommandDefinition(
        description="Undo the last action in the editor. Works on scene-level or global history depending on context.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "redo": CommandDefinition(
        description="Redo the last undone action in the editor. Works on scene-level or global history depending on context.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_undo_redo_status": CommandDefinition(
        description="Get the current undo/redo history status (has_undo, has_redo, history_count, current action name)",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_recent_files": CommandDefinition(
        description="Get list of recently opened scenes and files",
        input_schema={
            "type": "object",
            "properties": {
                "max_count": {
                    "type": "integer",
                    "description": "Maximum number of files to return (default: 20)",
                    "default": 20,
                },
                "filter": {
                    "type": "string",
                    "description": "Filter by extension, e.g., 'tscn', 'gd'",
                    "default": "",
                },
            },
            "required": [],
        },
    ),
    
    # ========================================================================
    # NODE MANIPULATION
    # ========================================================================
    "create_node": CommandDefinition(
        description="Create a new node in the scene tree",
        input_schema={
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "description": "Node type to create (e.g., 'Node2D', 'Sprite2D', 'CharacterBody2D', 'Label')",
                },
                "name": {
                    "type": "string",
                    "description": "Name for the new node (optional)",
                    "default": "",
                },
                "parent": {
                    "type": "string",
                    "description": "Path to parent node (default: '.' for scene root)",
                    "default": ".",
                },
            },
            "required": ["type"],
        },
    ),
    
    "delete_node": CommandDefinition(
        description="Delete a node from the scene tree",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node to delete",
                },
            },
            "required": ["path"],
        },
    ),
    
    "set_node_property": CommandDefinition(
        description="Set a property on a node. For Vector2/Vector3, pass {x, y} or {x, y, z} objects.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node",
                },
                "property": {
                    "type": "string",
                    "description": "Property name to set (e.g., 'position', 'rotation', 'visible')",
                },
                "value": {
                    "description": "Value to set. Use objects for vectors: {x: 100, y: 200}",
                },
            },
            "required": ["path", "property", "value"],
        },
    ),
    
    "rename_node": CommandDefinition(
        description="Rename a node in the scene tree",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node to rename",
                },
                "name": {
                    "type": "string",
                    "description": "New name for the node",
                },
            },
            "required": ["path", "name"],
        },
    ),
    
    "move_node": CommandDefinition(
        description="Move a node to a new parent in the scene tree",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node to move",
                },
                "new_parent": {
                    "type": "string",
                    "description": "Path to the new parent node",
                },
            },
            "required": ["path", "new_parent"],
        },
    ),
    
    "duplicate_node": CommandDefinition(
        description="Duplicate a node in the scene tree",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node to duplicate",
                },
                "new_name": {
                    "type": "string",
                    "description": "Name for the duplicate (optional, auto-generated if not provided)",
                    "default": "",
                },
            },
            "required": ["path"],
        },
    ),
    
    "instantiate_scene": CommandDefinition(
        description="Instantiate a scene as a child of a node (like Ctrl+Shift+A in the editor)",
        input_schema={
            "type": "object",
            "properties": {
                "scene": {
                    "type": "string",
                    "description": "Path to the scene file to instantiate (e.g., 'res://scenes/player.tscn')",
                },
                "parent": {
                    "type": "string",
                    "description": "Parent node path (default: '.' for scene root)",
                    "default": ".",
                },
                "name": {
                    "type": "string",
                    "description": "Name for the instantiated node (optional, uses scene's root name if not provided)",
                    "default": "",
                },
            },
            "required": ["scene"],
        },
    ),
    
    "get_node_script": CommandDefinition(
        description="Get the script attached to a node",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Node path",
                },
            },
            "required": ["path"],
        },
    ),
    
    "attach_script": CommandDefinition(
        description="Attach a script to a node",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Node path",
                },
                "script": {
                    "type": "string",
                    "description": "Script file path (e.g., 'res://scripts/player.gd')",
                },
            },
            "required": ["path", "script"],
        },
    ),
    
    "detach_script": CommandDefinition(
        description="Detach (remove) the script from a node",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Node path",
                },
            },
            "required": ["path"],
        },
    ),
    
    "make_node_local": CommandDefinition(
        description="Make an inherited scene node local, breaking the inheritance link",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Node path to make local",
                },
            },
            "required": ["path"],
        },
    ),
    
    "get_node_hierarchy_info": CommandDefinition(
        description="Get node hierarchy information including scene instance status",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Node path",
                },
            },
            "required": ["path"],
        },
    ),
    
    # ========================================================================
    # SCENE CREATION
    # ========================================================================
    "create_scene": CommandDefinition(
        description="Create a new scene file and open it in the editor",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path for the new scene (e.g., 'res://scenes/level1.tscn')",
                },
                "root_type": {
                    "type": "string",
                    "description": "Type of the root node (default: 'Node2D')",
                    "default": "Node2D",
                },
                "root_name": {
                    "type": "string",
                    "description": "Name for the root node (optional, defaults to filename)",
                    "default": "",
                },
            },
            "required": ["path"],
        },
    ),
    
    "new_inherited_scene": CommandDefinition(
        description="Create a new scene that inherits from an existing scene",
        input_schema={
            "type": "object",
            "properties": {
                "base_scene": {
                    "type": "string",
                    "description": "Path to the base scene to inherit from",
                },
                "path": {
                    "type": "string",
                    "description": "Path for the new inherited scene",
                },
            },
            "required": ["base_scene", "path"],
        },
    ),
    
    "duplicate_scene": CommandDefinition(
        description="Duplicate an existing scene to a new path. Returns duplicated (bool), source_path, dest_path, opened (bool).",
        input_schema={
            "type": "object",
            "properties": {
                "source_path": {
                    "type": "string",
                    "description": "Source scene path to duplicate",
                },
                "dest_path": {
                    "type": "string",
                    "description": "Destination path for the duplicated scene",
                },
                "open": {
                    "type": "boolean",
                    "description": "Open the duplicated scene in editor (default: true)",
                    "default": True,
                },
            },
            "required": ["source_path", "dest_path"],
        },
    ),
    
    "get_scene_dependencies": CommandDefinition(
        description="Get all dependencies of a scene (scripts, textures, other scenes, etc.). Returns dependencies array and count, organized by type.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Scene path to analyze",
                },
                "recursive": {
                    "type": "boolean",
                    "description": "Include transitive dependencies (default: false)",
                    "default": False,
                },
            },
            "required": ["path"],
        },
    ),
    
    "reload_current_scene": CommandDefinition(
        description="Reload the currently edited scene from disk. Useful after external modifications.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "close_scene": CommandDefinition(
        description="Close a scene in the editor. Can optionally save before closing.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Scene path to close (empty = current scene)",
                    "default": "",
                },
                "save": {
                    "type": "boolean",
                    "description": "Save before closing (default: true)",
                    "default": True,
                },
            },
            "required": [],
        },
    ),
    
    # ========================================================================
    # INPUT SIMULATION
    # ========================================================================
    "simulate_key": CommandDefinition(
        description="Simulate a keyboard key press/release during game runtime",
        input_schema={
            "type": "object",
            "properties": {
                "key": {
                    "type": "string",
                    "description": "Key name (e.g., 'W', 'SPACE', 'ENTER', 'UP', 'F1')",
                },
                "pressed": {
                    "type": "boolean",
                    "description": "True for key press, False for key release",
                    "default": True,
                },
                "echo": {
                    "type": "boolean",
                    "description": "Whether this is an echo (held key repeat)",
                    "default": False,
                },
                "shift": {
                    "type": "boolean",
                    "description": "Shift modifier pressed",
                    "default": False,
                },
                "ctrl": {
                    "type": "boolean",
                    "description": "Ctrl modifier pressed",
                    "default": False,
                },
                "alt": {
                    "type": "boolean",
                    "description": "Alt modifier pressed",
                    "default": False,
                },
                "meta": {
                    "type": "boolean",
                    "description": "Meta/Win/Cmd modifier pressed",
                    "default": False,
                },
            },
            "required": ["key"],
        },
    ),
    
    "simulate_mouse_button": CommandDefinition(
        description="Simulate a mouse button press/release during game runtime",
        input_schema={
            "type": "object",
            "properties": {
                "button": {
                    "type": "integer",
                    "description": "Mouse button (1=left, 2=right, 3=middle, 4=wheel up, 5=wheel down)",
                    "default": 1,
                },
                "pressed": {
                    "type": "boolean",
                    "description": "True for press, False for release",
                    "default": True,
                },
                "x": {
                    "type": "number",
                    "description": "X position in pixels",
                    "default": 0,
                },
                "y": {
                    "type": "number",
                    "description": "Y position in pixels",
                    "default": 0,
                },
                "double_click": {
                    "type": "boolean",
                    "description": "Whether this is a double-click",
                    "default": False,
                },
            },
            "required": [],
        },
    ),
    
    "simulate_mouse_motion": CommandDefinition(
        description="Simulate mouse movement during game runtime",
        input_schema={
            "type": "object",
            "properties": {
                "x": {
                    "type": "number",
                    "description": "Absolute X position in pixels",
                    "default": 0,
                },
                "y": {
                    "type": "number",
                    "description": "Absolute Y position in pixels",
                    "default": 0,
                },
                "relative_x": {
                    "type": "number",
                    "description": "Relative X movement",
                    "default": 0,
                },
                "relative_y": {
                    "type": "number",
                    "description": "Relative Y movement",
                    "default": 0,
                },
                "button_mask": {
                    "type": "integer",
                    "description": "Bitmask of held mouse buttons",
                    "default": 0,
                },
            },
            "required": [],
        },
    ),
    
    "simulate_action": CommandDefinition(
        description="Simulate an input action (as defined in Project Settings > Input Map)",
        input_schema={
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "description": "Name of the input action (e.g., 'ui_accept', 'jump', 'move_left')",
                },
                "pressed": {
                    "type": "boolean",
                    "description": "True for action pressed, False for released",
                    "default": True,
                },
                "strength": {
                    "type": "number",
                    "description": "Action strength (0.0 to 1.0), useful for analog inputs",
                    "default": 1.0,
                },
            },
            "required": ["action"],
        },
    ),
    
    "get_input_actions": CommandDefinition(
        description="Get all input actions defined in the project's Input Map",
        input_schema={
            "type": "object",
            "properties": {
                "include_builtins": {
                    "type": "boolean",
                    "description": "Include built-in UI actions (ui_*)",
                    "default": False,
                },
            },
            "required": [],
        },
    ),
    
    "get_input_action": CommandDefinition(
        description="Get detailed information about a specific input action including all key/button bindings",
        input_schema={
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "description": "Name of the input action to query",
                },
            },
            "required": ["action"],
        },
    ),
    
    "add_input_action": CommandDefinition(
        description="Add a new input action to the Input Map",
        input_schema={
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "description": "Name of the new input action",
                },
                "deadzone": {
                    "type": "number",
                    "description": "Deadzone for analog inputs (0.0 to 1.0)",
                    "default": 0.5,
                },
            },
            "required": ["action"],
        },
    ),
    
    "remove_input_action": CommandDefinition(
        description="Remove an input action from the Input Map",
        input_schema={
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "description": "Name of the input action to remove",
                },
            },
            "required": ["action"],
        },
    ),
    
    "add_input_event_key": CommandDefinition(
        description="Add a keyboard key binding to an input action",
        input_schema={
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "description": "Name of the input action",
                },
                "key": {
                    "type": "string",
                    "description": "Key name (e.g., 'W', 'SPACE', 'ENTER', 'UP', 'F1')",
                },
                "shift": {
                    "type": "boolean",
                    "description": "Require Shift modifier",
                    "default": False,
                },
                "ctrl": {
                    "type": "boolean",
                    "description": "Require Ctrl modifier",
                    "default": False,
                },
                "alt": {
                    "type": "boolean",
                    "description": "Require Alt modifier",
                    "default": False,
                },
                "meta": {
                    "type": "boolean",
                    "description": "Require Meta/Win/Cmd modifier",
                    "default": False,
                },
            },
            "required": ["action", "key"],
        },
    ),
    
    "add_input_event_mouse": CommandDefinition(
        description="Add a mouse button binding to an input action",
        input_schema={
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "description": "Name of the input action",
                },
                "button": {
                    "type": "integer",
                    "description": "Mouse button (1=left, 2=right, 3=middle)",
                },
            },
            "required": ["action", "button"],
        },
    ),
    
    "add_input_event_joypad_button": CommandDefinition(
        description="Add a gamepad button binding to an input action",
        input_schema={
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "description": "Name of the input action",
                },
                "button": {
                    "type": "integer",
                    "description": "Joypad button index (0=A/Cross, 1=B/Circle, etc.)",
                },
                "device": {
                    "type": "integer",
                    "description": "Device ID (-1 for all devices)",
                    "default": -1,
                },
            },
            "required": ["action", "button"],
        },
    ),
    
    "add_input_event_joypad_axis": CommandDefinition(
        description="Add a gamepad axis binding to an input action",
        input_schema={
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "description": "Name of the input action",
                },
                "axis": {
                    "type": "integer",
                    "description": "Axis index (0=left stick X, 1=left stick Y, etc.)",
                },
                "axis_value": {
                    "type": "number",
                    "description": "Axis value (-1.0 for negative, 1.0 for positive)",
                    "default": 1.0,
                },
                "device": {
                    "type": "integer",
                    "description": "Device ID (-1 for all devices)",
                    "default": -1,
                },
            },
            "required": ["action", "axis"],
        },
    ),
    
    "clear_input_action_events": CommandDefinition(
        description="Remove all input events (bindings) from an input action",
        input_schema={
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "description": "Name of the input action to clear",
                },
            },
            "required": ["action"],
        },
    ),
    
    # ========================================================================
    # GUT TESTING FRAMEWORK
    # ========================================================================
    "gut_check_installed": CommandDefinition(
        description="Check if GUT testing framework is installed in the project",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "gut_run_all": CommandDefinition(
        description="Run all GUT tests in specified directories",
        input_schema={
            "type": "object",
            "properties": {
                "dirs": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Test directories (default: ['res://test/unit/'])",
                    "default": ["res://test/unit/"],
                },
                "log_level": {
                    "type": "integer",
                    "description": "Log level 0-3 (default: 1)",
                    "default": 1,
                },
                "include_subdirs": {
                    "type": "boolean",
                    "description": "Include subdirectories",
                    "default": True,
                },
                "output_file": {
                    "type": "string",
                    "description": "JUnit XML output file path",
                    "default": "user://gut_results.xml",
                },
            },
            "required": [],
        },
    ),
    
    "gut_run_script": CommandDefinition(
        description="Run a specific GUT test script",
        input_schema={
            "type": "object",
            "properties": {
                "script": {
                    "type": "string",
                    "description": "Path to test script (e.g., 'res://test/unit/test_player.gd')",
                },
                "log_level": {
                    "type": "integer",
                    "description": "Log level 0-3",
                    "default": 1,
                },
                "output_file": {
                    "type": "string",
                    "description": "JUnit XML output file path",
                    "default": "user://gut_results.xml",
                },
            },
            "required": ["script"],
        },
    ),
    
    "gut_run_test": CommandDefinition(
        description="Run a specific test function within a GUT test script",
        input_schema={
            "type": "object",
            "properties": {
                "script": {
                    "type": "string",
                    "description": "Path to test script",
                },
                "test_name": {
                    "type": "string",
                    "description": "Name of the test function to run",
                },
                "log_level": {
                    "type": "integer",
                    "description": "Log level 0-3",
                    "default": 1,
                },
                "output_file": {
                    "type": "string",
                    "description": "JUnit XML output file path",
                    "default": "user://gut_results.xml",
                },
            },
            "required": ["script", "test_name"],
        },
    ),
    
    "gut_get_results": CommandDefinition(
        description="Parse and retrieve GUT test results from JUnit XML file",
        input_schema={
            "type": "object",
            "properties": {
                "file": {
                    "type": "string",
                    "description": "Path to JUnit XML results file",
                    "default": "user://gut_results.xml",
                },
            },
            "required": [],
        },
    ),
    
    "gut_list_tests": CommandDefinition(
        description="List all GUT test files and their test functions",
        input_schema={
            "type": "object",
            "properties": {
                "dirs": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Directories to search for tests",
                    "default": ["res://test/"],
                },
                "prefix": {
                    "type": "string",
                    "description": "Test file prefix",
                    "default": "test_",
                },
                "suffix": {
                    "type": "string",
                    "description": "Test file suffix",
                    "default": ".gd",
                },
            },
            "required": [],
        },
    ),
    
    "gut_create_test": CommandDefinition(
        description="Create a new GUT test file with boilerplate code",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path for the new test file (e.g., 'res://test/unit/test_player.gd')",
                },
                "name": {
                    "type": "string",
                    "description": "Name of the first test function to create",
                    "default": "",
                },
                "class_to_test": {
                    "type": "string",
                    "description": "Path to the class being tested (for reference)",
                    "default": "",
                },
            },
            "required": ["path"],
        },
    ),
    
    # ========================================================================
    # SIGNAL OPERATIONS
    # ========================================================================
    "list_node_signals": CommandDefinition(
        description="List all signals available on a node",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node",
                },
            },
            "required": ["path"],
        },
    ),
    
    "emit_signal": CommandDefinition(
        description="Emit a signal on a node",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node",
                },
                "signal": {
                    "type": "string",
                    "description": "Name of the signal to emit",
                },
                "args": {
                    "type": "array",
                    "description": "Arguments to pass with the signal",
                    "default": [],
                },
            },
            "required": ["path", "signal"],
        },
    ),
    
    # ========================================================================
    # METHOD CALLING
    # ========================================================================
    "call_method": CommandDefinition(
        description="Call a method on a node",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node",
                },
                "method": {
                    "type": "string",
                    "description": "Name of the method to call",
                },
                "args": {
                    "type": "array",
                    "description": "Arguments to pass to the method",
                    "default": [],
                },
            },
            "required": ["path", "method"],
        },
    ),
    
    "list_node_methods": CommandDefinition(
        description="List methods available on a node",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node",
                },
                "include_inherited": {
                    "type": "boolean",
                    "description": "Include inherited methods (can be many)",
                    "default": False,
                },
            },
            "required": ["path"],
        },
    ),
    
    # ========================================================================
    # GROUP OPERATIONS
    # ========================================================================
    "get_nodes_in_group": CommandDefinition(
        description="Get all nodes in a specific group",
        input_schema={
            "type": "object",
            "properties": {
                "group": {
                    "type": "string",
                    "description": "Name of the group",
                },
            },
            "required": ["group"],
        },
    ),
    
    "add_node_to_group": CommandDefinition(
        description="Add a node to a group",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node",
                },
                "group": {
                    "type": "string",
                    "description": "Name of the group",
                },
                "persistent": {
                    "type": "boolean",
                    "description": "Whether the group membership is saved with the scene",
                    "default": True,
                },
            },
            "required": ["path", "group"],
        },
    ),
    
    "remove_node_from_group": CommandDefinition(
        description="Remove a node from a group",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the node",
                },
                "group": {
                    "type": "string",
                    "description": "Name of the group",
                },
            },
            "required": ["path", "group"],
        },
    ),
    
    # ========================================================================
    # RESOURCE OPERATIONS
    # ========================================================================
    "load_resource": CommandDefinition(
        description="Load and get info about a resource file",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the resource (e.g., 'res://assets/sprite.png')",
                },
            },
            "required": ["path"],
        },
    ),
    
    "get_resource_info": CommandDefinition(
        description="Get detailed information about a resource including its properties",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the resource",
                },
            },
            "required": ["path"],
        },
    ),
    
    # ========================================================================
    # ANIMATION OPERATIONS
    # ========================================================================
    "list_animations": CommandDefinition(
        description="List all animations in an AnimationPlayer node",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the AnimationPlayer node",
                },
            },
            "required": ["path"],
        },
    ),
    
    "play_animation": CommandDefinition(
        description="Play an animation on an AnimationPlayer node",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the AnimationPlayer node",
                },
                "animation": {
                    "type": "string",
                    "description": "Name of the animation to play",
                },
                "blend": {
                    "type": "number",
                    "description": "Custom blend time (-1 for default)",
                    "default": -1,
                },
                "speed": {
                    "type": "number",
                    "description": "Playback speed",
                    "default": 1.0,
                },
                "from_end": {
                    "type": "boolean",
                    "description": "Play from end (reverse)",
                    "default": False,
                },
            },
            "required": ["path", "animation"],
        },
    ),
    
    "stop_animation": CommandDefinition(
        description="Stop animation playback on an AnimationPlayer node",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the AnimationPlayer node",
                },
                "keep_state": {
                    "type": "boolean",
                    "description": "Keep the current animation state",
                    "default": True,
                },
            },
            "required": ["path"],
        },
    ),
    
    # ========================================================================
    # AUDIO OPERATIONS
    # ========================================================================
    "list_audio_buses": CommandDefinition(
        description="List all audio buses and their settings",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "set_audio_bus_volume": CommandDefinition(
        description="Set the volume of an audio bus",
        input_schema={
            "type": "object",
            "properties": {
                "bus": {
                    "type": "string",
                    "description": "Name of the audio bus",
                    "default": "Master",
                },
                "volume_db": {
                    "type": "number",
                    "description": "Volume in decibels (0 = normal, negative = quieter)",
                    "default": 0,
                },
            },
            "required": [],
        },
    ),
    
    "set_audio_bus_mute": CommandDefinition(
        description="Mute or unmute an audio bus",
        input_schema={
            "type": "object",
            "properties": {
                "bus": {
                    "type": "string",
                    "description": "Name of the audio bus",
                    "default": "Master",
                },
                "mute": {
                    "type": "boolean",
                    "description": "True to mute, False to unmute",
                    "default": True,
                },
            },
            "required": [],
        },
    ),
    
    "create_resource": CommandDefinition(
        description="Create a new resource of a specified type (e.g., Resource, ShaderMaterial, Theme). Returns created (bool), type, path, properties_set.",
        input_schema={
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "description": "Resource type to create (e.g., 'Resource', 'ShaderMaterial', 'Theme', 'StyleBoxFlat')",
                },
                "path": {
                    "type": "string",
                    "description": "Path to save the resource (e.g., 'res://resources/my_resource.tres')",
                },
                "properties": {
                    "type": "object",
                    "description": "Initial properties to set on the resource",
                    "default": {},
                },
            },
            "required": ["type", "path"],
        },
    ),
    
    "save_resource": CommandDefinition(
        description="Save an existing resource to disk. Returns saved (bool), path, type.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Resource path to save",
                },
            },
            "required": ["path"],
        },
    ),
    
    "duplicate_resource": CommandDefinition(
        description="Duplicate a resource to a new path. Returns duplicated (bool), source_path, dest_path, type.",
        input_schema={
            "type": "object",
            "properties": {
                "source_path": {
                    "type": "string",
                    "description": "Source resource path",
                },
                "dest_path": {
                    "type": "string",
                    "description": "Destination path for the duplicate",
                },
                "subresources": {
                    "type": "boolean",
                    "description": "Also duplicate embedded subresources (default: false)",
                    "default": False,
                },
            },
            "required": ["source_path", "dest_path"],
        },
    ),
    
    "set_resource_properties": CommandDefinition(
        description="Set properties on an existing resource. Returns properties_set array and properties_failed array.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Resource path",
                },
                "properties": {
                    "type": "object",
                    "description": "Properties to set (key-value pairs)",
                },
                "save": {
                    "type": "boolean",
                    "description": "Save after setting properties (default: true)",
                    "default": True,
                },
            },
            "required": ["path", "properties"],
        },
    ),
    
    "list_resource_types": CommandDefinition(
        description="List all available resource types that can be created. Returns types array and count.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    # ========================================================================
    # DEBUG/PERFORMANCE
    # ========================================================================
    "get_performance_info": CommandDefinition(
        description="Get performance metrics (FPS, memory, object counts, etc.)",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_memory_info": CommandDefinition(
        description="Get memory usage information",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    # ========================================================================
    # CONSOLE/OUTPUT
    # ========================================================================
    "print_to_console": CommandDefinition(
        description="Print a message to Godot's output console",
        input_schema={
            "type": "object",
            "properties": {
                "message": {
                    "type": "string",
                    "description": "Message to print",
                },
                "level": {
                    "type": "string",
                    "enum": ["info", "warning", "error"],
                    "description": "Log level",
                    "default": "info",
                },
            },
            "required": ["message"],
        },
    ),
    
    "get_recent_errors": CommandDefinition(
        description="Get information about recent errors (limited availability)",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    # ========================================================================
    # AUTOLOAD MANAGEMENT
    # ========================================================================
    "get_autoloads": CommandDefinition(
        description="List all autoload singletons defined in the project. Autoloads are scripts or scenes that are automatically loaded at project start.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_autoload": CommandDefinition(
        description="Get detailed information about a specific autoload singleton including its path and order.",
        input_schema={
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Name of the autoload singleton",
                },
            },
            "required": ["name"],
        },
    ),
    
    "add_autoload": CommandDefinition(
        description="Add a new autoload singleton to the project. The script or scene will be automatically loaded at project start.",
        input_schema={
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Name for the autoload (used to access it as a singleton)",
                },
                "path": {
                    "type": "string",
                    "description": "Path to the script or scene file (e.g., 'res://globals/game_manager.gd')",
                },
                "enabled": {
                    "type": "boolean",
                    "description": "Whether the autoload is enabled",
                    "default": True,
                },
            },
            "required": ["name", "path"],
        },
    ),
    
    "remove_autoload": CommandDefinition(
        description="Remove an autoload singleton from the project.",
        input_schema={
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Name of the autoload to remove",
                },
            },
            "required": ["name"],
        },
    ),
    
    "rename_autoload": CommandDefinition(
        description="Rename an existing autoload singleton.",
        input_schema={
            "type": "object",
            "properties": {
                "old_name": {
                    "type": "string",
                    "description": "Current name of the autoload",
                },
                "new_name": {
                    "type": "string",
                    "description": "New name for the autoload",
                },
            },
            "required": ["old_name", "new_name"],
        },
    ),
    
    "set_autoload_path": CommandDefinition(
        description="Change the path of an existing autoload singleton.",
        input_schema={
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Name of the autoload",
                },
                "path": {
                    "type": "string",
                    "description": "New path for the autoload",
                },
            },
            "required": ["name", "path"],
        },
    ),
    
    "reorder_autoloads": CommandDefinition(
        description="Change the loading order of autoloads. Autoloads are loaded in order, so this affects dependency resolution.",
        input_schema={
            "type": "object",
            "properties": {
                "order": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "List of autoload names in desired order (e.g., ['GameManager', 'AudioManager', 'UIManager'])",
                },
            },
            "required": ["order"],
        },
    ),
    
    # ========================================================================
    # PLUGIN MANAGEMENT
    # ========================================================================
    "enable_plugin": CommandDefinition(
        description="Enable an editor plugin by its name or folder name. Use get_plugins to see available plugins.",
        input_schema={
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Plugin name or folder name (e.g., 'Codot', 'gut', 'godot_copilot')",
                },
            },
            "required": ["name"],
        },
    ),
    
    "disable_plugin": CommandDefinition(
        description="Disable an editor plugin by its name or folder name. Use get_plugins to see available plugins.",
        input_schema={
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Plugin name or folder name (e.g., 'Codot', 'gut', 'godot_copilot')",
                },
            },
            "required": ["name"],
        },
    ),
    
    "get_plugins": CommandDefinition(
        description="List all available editor plugins and their enabled status. Shows plugin name, description, version, and whether it's enabled.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "reload_project": CommandDefinition(
        description="Reload the current project by restarting the Godot editor. WARNING: This will close and reopen the project, disconnecting the WebSocket connection. You will need to wait and reconnect after the editor restarts.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    # ========================================================================
    # ADVANCED TESTING & AUTOMATION
    # ========================================================================
    "run_and_capture": CommandDefinition(
        description="Run a scene and capture output for automated testing. Runs the scene for a specified duration, captures all debug output, and returns results including any errors. This is the recommended way to test a scene and check for errors in one operation.",
        input_schema={
            "type": "object",
            "properties": {
                "scene": {
                    "type": "string",
                    "description": "Scene path to run. If not specified, runs current scene.",
                },
                "duration": {
                    "type": "number",
                    "description": "How long to run in seconds (default: 2.0)",
                    "default": 2.0,
                },
                "filter": {
                    "type": "string",
                    "description": "Filter output by 'all', 'error', 'warning' (default: 'all')",
                    "enum": ["all", "error", "warning"],
                    "default": "all",
                },
                "stop_on_error": {
                    "type": "boolean",
                    "description": "Stop immediately if an error is detected (default: false)",
                    "default": False,
                },
            },
            "required": [],
        },
    ),
    
    "wait_for_output": CommandDefinition(
        description="Wait for specific output from the running game. Useful for waiting for a specific event or message during automated testing.",
        input_schema={
            "type": "object",
            "properties": {
                "timeout": {
                    "type": "number",
                    "description": "Maximum time to wait in seconds (default: 5.0)",
                    "default": 5.0,
                },
                "wait_for": {
                    "type": "string",
                    "description": "What to wait for: 'error', 'warning', 'any', or a specific message substring",
                    "default": "any",
                },
                "poll_interval": {
                    "type": "number",
                    "description": "How often to check in seconds (default: 0.25)",
                    "default": 0.25,
                },
            },
            "required": [],
        },
    ),
    
    "ping_game": CommandDefinition(
        description="Ping the running game to verify the debug capture system is working. Returns latency if successful.",
        input_schema={
            "type": "object",
            "properties": {
                "timeout": {
                    "type": "number",
                    "description": "Maximum time to wait for pong (default: 2.0)",
                    "default": 2.0,
                },
            },
            "required": [],
        },
    ),
    
    "get_game_state": CommandDefinition(
        description="Get the current state of the running game including play status, debugger info, and capture system health.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "take_screenshot": CommandDefinition(
        description="Take a screenshot of the running game. Requires the game to be running with the Codot capture system active.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Where to save the screenshot (default: user://screenshot.png)",
                    "default": "user://screenshot.png",
                },
                "delay": {
                    "type": "number",
                    "description": "Wait before taking screenshot in seconds (default: 0.0)",
                    "default": 0.0,
                },
            },
            "required": [],
        },
    ),
    
    # ========================================================================
    # ENHANCED GUT TESTING
    # ========================================================================
    "gut_run_and_wait": CommandDefinition(
        description="Run GUT tests and wait for results. This is the recommended way to run tests as it handles starting GUT, waiting for completion, and gathering results in one operation.",
        input_schema={
            "type": "object",
            "properties": {
                "script": {
                    "type": "string",
                    "description": "Specific test script to run (e.g., 'res://test/unit/test_example.gd')",
                },
                "test": {
                    "type": "string",
                    "description": "Specific test function to run (e.g., 'test_something')",
                },
                "timeout": {
                    "type": "number",
                    "description": "Maximum time to wait in seconds (default: 30.0)",
                    "default": 30.0,
                },
                "include_output": {
                    "type": "boolean",
                    "description": "Include captured output in results (default: true)",
                    "default": True,
                },
            },
            "required": [],
        },
    ),
    
    "gut_get_summary": CommandDefinition(
        description="Get a summary of the last GUT test run. Parses captured output for test results, passed/failed counts, and error details.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    # ========================================================================
    # BATCH & COMPOUND COMMANDS
    # ========================================================================
    "batch_commands": CommandDefinition(
        description="Execute multiple commands in sequence. Useful for performing complex operations that require multiple steps. Can return results from all commands or just the final one.",
        input_schema={
            "type": "object",
            "properties": {
                "commands": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "command": {
                                "type": "string",
                                "description": "Command name (e.g., 'create_node', 'set_node_property')",
                            },
                            "params": {
                                "type": "object",
                                "description": "Parameters for the command",
                            },
                        },
                        "required": ["command"],
                    },
                    "description": "Array of commands to execute",
                },
                "stop_on_error": {
                    "type": "boolean",
                    "description": "Stop execution if a command fails (default: true)",
                    "default": True,
                },
                "return_all_results": {
                    "type": "boolean",
                    "description": "Return results from all commands (default: false, returns last result)",
                    "default": False,
                },
            },
            "required": ["commands"],
        },
    ),
    
    "bulk_set_properties": CommandDefinition(
        description="Set multiple properties on one or more nodes in a single call. More efficient than multiple set_node_property calls.",
        input_schema={
            "type": "object",
            "properties": {
                "operations": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "node_path": {
                                "type": "string",
                                "description": "Path to the node",
                            },
                            "properties": {
                                "type": "object",
                                "description": "Dictionary of property names to values",
                            },
                            "property": {
                                "type": "string",
                                "description": "Single property name (alternative to properties dict)",
                            },
                            "value": {
                                "description": "Single property value (use with property)",
                            },
                        },
                        "required": ["node_path"],
                    },
                    "description": "Array of property set operations",
                },
                "stop_on_error": {
                    "type": "boolean",
                    "description": "Stop if a property set fails (default: false)",
                    "default": False,
                },
            },
            "required": ["operations"],
        },
    ),
    
    "create_complete_scene": CommandDefinition(
        description="Create a complete scene with nodes in a single call. Specify root type, child nodes, and properties. More efficient than creating scene + multiple create_node calls.",
        input_schema={
            "type": "object",
            "properties": {
                "scene_path": {
                    "type": "string",
                    "description": "Path to save the scene (e.g., 'res://scenes/player.tscn')",
                },
                "root_type": {
                    "type": "string",
                    "description": "Type of the root node (default: 'Node2D')",
                    "default": "Node2D",
                },
                "root_name": {
                    "type": "string",
                    "description": "Name of the root node (default: derived from scene path)",
                },
                "nodes": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "type": {
                                "type": "string",
                                "description": "Node type (e.g., 'Sprite2D', 'CollisionShape2D')",
                            },
                            "name": {
                                "type": "string",
                                "description": "Node name",
                            },
                            "parent": {
                                "type": "string",
                                "description": "Parent node path relative to root (default: '.' for root)",
                            },
                            "properties": {
                                "type": "object",
                                "description": "Properties to set on the node",
                            },
                        },
                        "required": ["type", "name"],
                    },
                    "description": "Array of child nodes to create",
                },
                "save": {
                    "type": "boolean",
                    "description": "Save the scene after creation (default: true)",
                    "default": True,
                },
            },
            "required": ["scene_path"],
        },
    ),
    
    "create_scene_with_script": CommandDefinition(
        description="Create a scene with a script attached to the root node in a single call. Creates both .tscn and .gd files.",
        input_schema={
            "type": "object",
            "properties": {
                "scene_path": {
                    "type": "string",
                    "description": "Path to save the scene (e.g., 'res://scenes/player.tscn'). Script will be saved with .gd extension.",
                },
                "script_content": {
                    "type": "string",
                    "description": "GDScript content for the attached script",
                },
                "root_type": {
                    "type": "string",
                    "description": "Type of the root node (default: 'Node2D')",
                    "default": "Node2D",
                },
                "root_name": {
                    "type": "string",
                    "description": "Name of the root node (default: derived from scene path)",
                },
            },
            "required": ["scene_path", "script_content"],
        },
    ),
    
    # ========================================================================
    # EVENT SUBSCRIPTION SYSTEM
    # ========================================================================
    "list_event_types": CommandDefinition(
        description="List all available event types for subscription. Events can be subscribed to for real-time notifications about editor and game state changes.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "subscribe": CommandDefinition(
        description="Subscribe to an event type to receive notifications. Returns a subscription_id for managing the subscription.",
        input_schema={
            "type": "object",
            "properties": {
                "client_id": {
                    "type": "string",
                    "description": "Unique client identifier for this subscription",
                },
                "event_type": {
                    "type": "string",
                    "description": "Type of event to subscribe to (e.g., 'scene_changed', 'node_added', 'debug_output')",
                },
                "filter": {
                    "type": "object",
                    "description": "Optional filter criteria for the event (e.g., {'node_type': 'Node2D'} for node_added)",
                },
            },
            "required": ["client_id", "event_type"],
        },
    ),
    
    "unsubscribe": CommandDefinition(
        description="Unsubscribe from an event using the subscription_id.",
        input_schema={
            "type": "object",
            "properties": {
                "subscription_id": {
                    "type": "string",
                    "description": "The subscription ID returned from subscribe",
                },
            },
            "required": ["subscription_id"],
        },
    ),
    
    "get_subscriptions": CommandDefinition(
        description="Get all active subscriptions for a client.",
        input_schema={
            "type": "object",
            "properties": {
                "client_id": {
                    "type": "string",
                    "description": "Unique client identifier",
                },
            },
            "required": ["client_id"],
        },
    ),
    
    "poll_events": CommandDefinition(
        description="Poll for pending events for a client. Use when push notifications are not available.",
        input_schema={
            "type": "object",
            "properties": {
                "client_id": {
                    "type": "string",
                    "description": "Unique client identifier",
                },
                "max_events": {
                    "type": "integer",
                    "description": "Maximum number of events to return (default: 100)",
                    "default": 100,
                },
                "clear": {
                    "type": "boolean",
                    "description": "Clear events after polling (default: true)",
                    "default": True,
                },
            },
            "required": ["client_id"],
        },
    ),
    
    "unsubscribe_all": CommandDefinition(
        description="Unsubscribe from all events for a client. Useful for cleanup.",
        input_schema={
            "type": "object",
            "properties": {
                "client_id": {
                    "type": "string",
                    "description": "Unique client identifier",
                },
            },
            "required": ["client_id"],
        },
    ),
    
    "get_subscription_stats": CommandDefinition(
        description="Get statistics about event subscriptions.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    # ========================================================================
    # ASSET MANAGEMENT
    # ========================================================================
    "get_import_settings": CommandDefinition(
        description="Get import settings for a resource. Shows how textures, audio, models, etc. are configured for import.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the resource file (e.g., 'res://textures/player.png')",
                },
            },
            "required": ["path"],
        },
    ),
    
    "set_import_settings": CommandDefinition(
        description="Modify import settings for a resource and optionally reimport it.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the resource file",
                },
                "settings": {
                    "type": "object",
                    "description": "Dictionary of import settings to change (e.g., {'compress/mode': 2, 'flags/filter': false})",
                },
                "reimport": {
                    "type": "boolean",
                    "description": "Reimport the resource after changing settings (default: true)",
                    "default": True,
                },
            },
            "required": ["path", "settings"],
        },
    ),
    
    "get_resource_dependencies": CommandDefinition(
        description="Get dependencies of a resource - what it depends on and what depends on it.",
        input_schema={
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Path to the resource file",
                },
                "include_dependents": {
                    "type": "boolean",
                    "description": "Also scan for files that depend on this resource (default: true)",
                    "default": True,
                },
            },
            "required": ["path"],
        },
    ),
    
    "find_broken_references": CommandDefinition(
        description="Scan project for broken resource references. Finds missing files, invalid paths, and orphaned resources.",
        input_schema={
            "type": "object",
            "properties": {
                "directory": {
                    "type": "string",
                    "description": "Directory to scan (default: 'res://' for entire project)",
                    "default": "res://",
                },
                "extensions": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "File extensions to scan (default: ['.tscn', '.tres', '.gd'])",
                },
            },
            "required": [],
        },
    ),
    
    # ========================================================================
    # EDITOR THEME/LAYOUT
    # ========================================================================
    "get_editor_theme": CommandDefinition(
        description="Get current editor theme information including colors, fonts, and style settings.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_editor_layout": CommandDefinition(
        description="Get current editor layout including dock positions, panel visibility, and window configuration.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_editor_viewport_info": CommandDefinition(
        description="Get viewport information for 2D/3D editors including camera position, zoom, and view settings.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    # ========================================================================
    # ANIMATION
    # ========================================================================
    "create_animation": CommandDefinition(
        description="Create a new animation in an AnimationPlayer node.",
        input_schema={
            "type": "object",
            "properties": {
                "node_path": {
                    "type": "string",
                    "description": "Path to the AnimationPlayer node",
                },
                "animation_name": {
                    "type": "string",
                    "description": "Name for the new animation",
                },
                "length": {
                    "type": "number",
                    "description": "Length of the animation in seconds (default: 1.0)",
                    "default": 1.0,
                },
                "loop_mode": {
                    "type": "string",
                    "enum": ["none", "linear", "pingpong"],
                    "description": "Loop mode: 'none', 'linear' (loop), or 'pingpong' (back and forth)",
                    "default": "none",
                },
            },
            "required": ["node_path", "animation_name"],
        },
    ),
    
    "add_animation_track": CommandDefinition(
        description="Add a track to an animation (value, position, rotation, scale, method, etc.).",
        input_schema={
            "type": "object",
            "properties": {
                "node_path": {
                    "type": "string",
                    "description": "Path to the AnimationPlayer node",
                },
                "animation_name": {
                    "type": "string",
                    "description": "Name of the animation to add the track to",
                },
                "track_type": {
                    "type": "string",
                    "enum": ["value", "position_3d", "rotation_3d", "scale_3d", "blend_shape", "method", "bezier", "audio", "animation"],
                    "description": "Type of track to create",
                },
                "track_path": {
                    "type": "string",
                    "description": "Node path and property for the track (e.g., 'Sprite2D:modulate' or 'Player:position')",
                },
            },
            "required": ["node_path", "animation_name", "track_type", "track_path"],
        },
    ),
    
    "add_animation_keyframe": CommandDefinition(
        description="Add a keyframe to an animation track at a specific time.",
        input_schema={
            "type": "object",
            "properties": {
                "node_path": {
                    "type": "string",
                    "description": "Path to the AnimationPlayer node",
                },
                "animation_name": {
                    "type": "string",
                    "description": "Name of the animation",
                },
                "track_index": {
                    "type": "integer",
                    "description": "Index of the track (0-based)",
                },
                "time": {
                    "type": "number",
                    "description": "Time in seconds for the keyframe",
                },
                "value": {
                    "description": "Value for the keyframe (type depends on track type)",
                },
            },
            "required": ["node_path", "animation_name", "track_index", "time", "value"],
        },
    ),
    
    "preview_animation": CommandDefinition(
        description="Preview an animation in the editor by playing it.",
        input_schema={
            "type": "object",
            "properties": {
                "node_path": {
                    "type": "string",
                    "description": "Path to the AnimationPlayer node",
                },
                "animation_name": {
                    "type": "string",
                    "description": "Name of the animation to preview",
                },
                "seek_time": {
                    "type": "number",
                    "description": "Optional time to seek to before playing",
                },
            },
            "required": ["node_path", "animation_name"],
        },
    ),
    
    # ========================================================================
    # SCENE DIFF
    # ========================================================================
    "get_scene_diff": CommandDefinition(
        description="Compare current scene state to the saved version. Shows added/removed/modified nodes and property changes.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    # ========================================================================
    # PROFILER/MEMORY
    # ========================================================================
    "get_profiler_data": CommandDefinition(
        description="Get comprehensive profiler data from Performance monitors (FPS, memory, objects, physics, rendering, etc.).",
        input_schema={
            "type": "object",
            "properties": {
                "category": {
                    "type": "string",
                    "enum": ["all", "time", "memory", "objects", "rendering", "physics_2d", "physics_3d", "navigation"],
                    "description": "Category filter (default: 'all')",
                    "default": "all",
                },
            },
            "required": [],
        },
    ),
    
    "get_orphan_nodes": CommandDefinition(
        description="Get orphan node count to detect potential memory leaks. Orphan nodes are nodes not in the scene tree.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_object_stats": CommandDefinition(
        description="Get detailed object statistics including counts, memory usage, and resource stats.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
    
    "get_stack_info": CommandDefinition(
        description="Get current GDScript call stack information for debugging.",
        input_schema={
            "type": "object",
            "properties": {},
            "required": [],
        },
    ),
}
