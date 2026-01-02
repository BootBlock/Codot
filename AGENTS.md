# AGENTS.md - AI Agent Instructions for Codot Development

This file provides context and instructions for AI coding agents working on the Codot project.

## Project Overview

**Codot** is a bridge between AI coding agents (via Model Context Protocol) and the Godot 4.x game engine. It enables AI systems to directly interact with Godot's editor and running games through a WebSocket connection.

### Architecture

```
┌─────────────────┐     MCP Protocol      ┌──────────────────┐     WebSocket      ┌─────────────────┐
│   AI Agent      │ ◄──────────────────► │   MCP Server     │ ◄────────────────► │  Godot Editor   │
│ (Claude, etc.)  │    (stdio/JSON-RPC)   │   (Python)       │    (port 6850)     │  (GDScript)     │
└─────────────────┘                       └──────────────────┘                    └─────────────────┘
```

### Key Components

| Component | Location | Language | Purpose |
|-----------|----------|----------|---------|
| Godot Plugin | `addons/codot/` | GDScript | Editor plugin with WebSocket server |
| MCP Server | `mcp-src/codot/` | Python | MCP protocol bridge to Godot |
| Tests (GUT) | `test/` | GDScript | Godot unit tests |
| Tests (pytest) | `mcp-src/tests/` | Python | Python unit tests |

## Development Guidelines

### GDScript Conventions

1. **Docstrings**: Use `##` comments above functions for documentation
2. **Type hints**: Always use static typing (`var x: int = 0`)
3. **Naming**: Use `snake_case` for functions/variables, `PascalCase` for classes
4. **Error handling**: Return dictionaries with `success`, `error.code`, `error.message`

```gdscript
## Brief description of what this function does.
## [br][br]
## [param params]: Description of the params dictionary.
## - 'key' (Type, required/optional): Description.
func _cmd_example(cmd_id: Variant, params: Dictionary) -> Dictionary:
    if some_error:
        return _error(cmd_id, "ERROR_CODE", "Human readable message")
    return _success(cmd_id, {"result": value})
```

### Python Conventions

1. **Docstrings**: Use Google-style docstrings
2. **Type hints**: Use Python 3.10+ style (`dict[str, Any]`)
3. **Async**: All WebSocket/MCP operations are async
4. **Logging**: Use the `logger` instance, not print()

```python
async def method_name(self, param: str) -> dict[str, Any]:
    """
    Brief description.
    
    Args:
        param: Description of parameter.
        
    Returns:
        Description of return value.
    """
```

### Adding New Commands

To add a new command, update these files:

1. **`addons/codot/command_handler.gd`**:
   - Add case to `handle_command()` match statement
   - Implement `_cmd_your_command()` function with docstring

2. **`mcp-src/codot/commands.py`**:
   - Add `CommandDefinition` to `COMMANDS` dictionary
   - Include description and JSON Schema for parameters

### Command Response Format

All commands return this structure:

```json
{
  "id": "request-uuid",
  "success": true,
  "result": { /* command-specific data */ }
}
```

Or on error:

```json
{
  "id": "request-uuid", 
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable description"
  }
}
```

### Common Error Codes

| Code | Meaning |
|------|---------|
| `NO_EDITOR` | EditorInterface not available |
| `NO_SCENE` | No scene currently open |
| `MISSING_PARAM` | Required parameter missing |
| `NODE_NOT_FOUND` | Node path doesn't exist |
| `INVALID_TYPE` | Invalid node/resource type |
| `FILE_NOT_FOUND` | File doesn't exist |

## File Structure Reference

```
codot/
├── addons/codot/           # Godot editor plugin
│   ├── plugin.cfg              # Plugin metadata
│   ├── codot.gd           # Main EditorPlugin class
│   ├── websocket_server.gd     # WebSocket server
│   └── command_handler.gd      # Command routing & implementation
├── mcp-src/                    # Python MCP server
│   ├── pyproject.toml          # Python package config
│   ├── codot/
│   │   ├── __init__.py
│   │   ├── server.py           # MCP server entry point
│   │   ├── godot_client.py     # WebSocket client
│   │   └── commands.py         # Command definitions
│   └── tests/                  # pytest tests
├── test/                       # GUT tests for Godot
├── .vscode/mcp.json           # VS Code MCP configuration
└── docs/                       # Documentation
```

## Available MCP Tools

The MCP server exposes 64+ tools. Key categories:

### Scene & Node Operations
- `godot_get_scene_tree` - Get scene hierarchy
- `godot_create_node` - Create nodes
- `godot_set_node_property` - Modify properties
- `godot_delete_node` - Remove nodes

### Game Control
- `godot_play` / `godot_stop` - Run/stop game
- `godot_play_current` - Play current scene

### File Operations
- `godot_read_file` / `godot_write_file` - File I/O
- `godot_get_project_files` - List project files

### Testing (GUT)
- `godot_gut_run_all` - Run all tests
- `godot_gut_run_script` - Run specific test file

### Input Simulation
- `godot_simulate_key` - Keyboard input
- `godot_simulate_mouse_button` - Mouse clicks
- `godot_simulate_action` - Input actions

## Testing

### Running GUT Tests
```bash
# From Godot editor, or:
godot -d -s addons/gut/gut_cmdln.gd -gdir=res://test/ -gexit
```

### Running Python Tests
```bash
cd mcp-src
pip install -e ".[dev]"
pytest
```

## Debugging Tips

1. **WebSocket issues**: Check port 6850 isn't blocked
2. **Command not found**: Verify command is in both `command_handler.gd` and `commands.py`
3. **MCP not connecting**: Ensure Godot is running with plugin enabled
4. **Type errors**: GDScript is strictly typed - check parameter types

## Version Requirements

- **Godot**: 4.3+ (tested with 4.6-beta)
- **Python**: 3.10+
- **Dependencies**: See `mcp-src/pyproject.toml`

## Quick Command Reference

When you need to interact with Godot, use these MCP tools:

| Task | Tool |
|------|------|
| Check connection | `godot_ping` |
| Get project info | `godot_get_status` |
| View scene tree | `godot_get_scene_tree` |
| Create a node | `godot_create_node` |
| Run the game | `godot_play` |
| Stop the game | `godot_stop` |
| Read a file | `godot_read_file` |
| Run tests | `godot_gut_run_all` |
| Get debug output | `godot_get_debug_output` |
| Check for errors | `godot_get_recent_errors` |
| Debugger diagnostics | `godot_get_debugger_status` |
| **Run & capture** | `godot_run_and_capture` |
| **Wait for output** | `godot_wait_for_output` |
| **Game state** | `godot_get_game_state` |
| **Run GUT tests** | `godot_gut_run_and_wait` |

## Automation Commands (NEW)

These commands enable fully automated testing workflows:

### godot_run_and_capture
Run a scene and capture all output in one operation. **Recommended for automated testing.**

```
godot_run_and_capture(scene="res://main.tscn", duration=3.0, stop_on_error=true)
→ Returns: {
    "scene": "res://main.tscn",
    "duration_actual": 3.0,
    "stopped_early": false,
    "entries": [...],
    "errors": [],
    "warnings": [],
    "error_count": 0,
    "warning_count": 0
}
```

### godot_wait_for_output
Wait for specific output while the game is running.

```
godot_wait_for_output(wait_for="error", timeout=5.0)
→ Returns: {
    "found": true,
    "elapsed": 1.2,
    "matched_entry": {"type": "error", "message": "..."}
}
```

### godot_get_game_state
Get current game state including debugger health.

```
godot_get_game_state
→ Returns: {
    "is_playing": true,
    "debugger_available": true,
    "game_capture_active": true,
    "session_count": 1,
    "total_entries": 42
}
```

### godot_ping_game
Verify the game-side capture system is responding.

```
godot_ping_game(timeout=2.0)
→ Returns: {"pong": true, "latency": 0.05}
```

### godot_gut_run_and_wait
Run GUT tests and wait for completion. **Recommended for test automation.**

```
godot_gut_run_and_wait(script="res://test/unit/test_player.gd", timeout=30)
→ Returns: {
    "completed": true,
    "elapsed": 5.2,
    "passed_count": 8,
    "failed_count": 0,
    "errors": [],
    "success": true,
    "entries": [...]
}
```

### godot_take_screenshot
Capture a screenshot of the running game.

```
godot_take_screenshot(path="user://screenshot.png", delay=0.5)
→ Returns: {"path": "user://screenshot.png", "exists": true}
```

## Automated Testing Workflow (Recommended)

For fully automated testing without manual intervention:

```
# SIMPLE: Run and check for errors in one call
godot_run_and_capture(duration=3.0, stop_on_error=true)
→ Check error_count == 0

# ADVANCED: Run tests with result parsing
godot_gut_run_and_wait(timeout=60)
→ Check success == true

# INTERACTIVE: Ping game during long runs
godot_play
godot_ping_game  → Verify capture is working
godot_wait_for_output(wait_for="Level loaded", timeout=10)
godot_take_screenshot
godot_stop
godot_get_debug_output
```

## Debug Output Architecture

The debug capture system has two components:

1. **EditorDebuggerPlugin** (`debugger_plugin.gd`) - Runs in the editor
   - Receives messages from the running game via `EngineDebugger`
   - Stores entries in a circular buffer (max 1000)
   - Provides `get_entries()`, `get_summary()`, `get_diagnostics()`

2. **CodotOutputCapture** (`output_capture.gd`) - Runs in the game (autoload)
   - Sends messages back to editor via `EngineDebugger.send_message("codot:...", data)`
   - Can explicitly capture errors, warnings, and print statements
   - Auto-registered as an autoload by the plugin

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    Running Game                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  CodotOutputCapture (autoload)                      │    │
│  │  - EngineDebugger.send_message("codot:entry", {...})│    │
│  └───────────────────────┬─────────────────────────────┘    │
└──────────────────────────│──────────────────────────────────┘
                           │ EngineDebugger protocol
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Godot Editor                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  EditorDebuggerPlugin                               │    │
│  │  - _capture("codot:entry", data, session_id)        │    │
│  │  - Stores in _entries array                         │    │
│  └───────────────────────┬─────────────────────────────┘    │
│                          ▼                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  CommandHandler                                      │    │
│  │  - get_debug_output → debugger_plugin.get_entries() │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Message Types

| Message | Description |
|---------|-------------|
| `codot:ready` | Game-side capture initialized |
| `codot:entry` | Captured log entry (error/warning/print) |
| `codot:test_complete` | Test finished signal |
| `codot:pong` | Response to ping from editor |
| `codot:screenshot` | Request screenshot from game |
| `codot:screenshot_result` | Screenshot result from game |

## Plugin Management Commands

Manage editor plugins programmatically:

### godot_get_plugins
List all available editor plugins and their enabled status.

```
godot_get_plugins
→ Returns: {
    "plugins": [
        {"name": "Codot", "folder": "codot", "enabled": true, "version": "0.1.0"},
        {"name": "Gut", "folder": "gut", "enabled": true, "version": "9.3.0"}
    ]
}
```

### godot_enable_plugin / godot_disable_plugin
Enable or disable an editor plugin by name.

```
godot_enable_plugin(name="gut")
godot_disable_plugin(name="gut")
```

**Note**: Disabling the Codot plugin will disconnect the WebSocket connection.

### godot_reload_project
Restart the Godot editor to reload the project. **WARNING**: This disconnects the WebSocket.

## Important Implementation Notes

### Async Command Handling
Commands that use `await` (like `run_and_capture`, `wait_for_output`, `ping_game`) are properly 
awaited in `codot.gd`:

```gdscript
func _on_command_received(client_id: int, command: Dictionary) -> void:
    var response = await _handler.handle_command(command)
    _server.send_response(client_id, response)
```

This ensures the WebSocket response is only sent after the async operation completes.

## Debug Output Workflow

To run a Godot project and capture/act on errors:

### Step 1: Mark Current Log Position
```
godot_clear_debug_log
→ Returns: {"source": "debugger", "marked": true, "since_id": 42}
```

### Step 2: Run the Scene
```
godot_play
→ Returns: {"playing": true}
```

### Step 3: Wait and Check for Errors
```
godot_get_debug_output with {"since_id": 42, "filter": "error"}
→ Returns: {
    "source": "debugger",
    "entries": [
        {"id": 43, "type": "error", "message": "...", "file": "res://player.gd", "line": 25, "source": "game"}
    ],
    "errors": [...],
    "warnings": [...],
    "is_playing": true,
    "last_id": 45,
    "error_count": 1,
    "warning_count": 0
}
```

### Step 4: Analyze and Fix
If errors are found, you can:
1. Read the error messages (now with structured file paths and line numbers!)
2. Use `godot_read_file` to examine the problematic script
3. Fix the code
4. Use `godot_stop` then `godot_play` to test again

### Checking Debugger Health
```
godot_get_debugger_status
→ Returns: {
    "debugger_plugin_available": true,
    "is_playing": false,
    "message_types_seen": {"codot:ready": 1, "codot:entry": 5},
    "game_capture_active": true,
    "total_entries": 10,
    "session_count": 1
}
```

### Explicit Error Capture (Game-Side)

Scripts can explicitly send captured output to the editor:

```gdscript
# Get the autoload
var capture = get_node_or_null("/root/CodotOutputCapture")

if capture:
    capture.capture_error("Something went wrong", "res://script.gd", 42)
    capture.capture_warning("This might be a problem")
    capture.capture_print("Debug info")
```

### Example AI Workflow
```
User: "Run my game and tell me if there are any errors"

1. godot_clear_debug_log → since_id: 42
2. godot_play → playing: true
3. [Wait 2-3 seconds for game to start]
4. godot_get_debug_output(since_id=42, filter="error")
5. If errors found:
   - Use structured data (file, line, source fields) to locate the problem
   - source="game" means it came from CodotOutputCapture
   - source="debugger" means it came from EditorDebuggerPlugin
