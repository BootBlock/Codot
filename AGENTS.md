# AGENTS.md - AI Agent Instructions for Codot Development

This file provides context and instructions for AI coding agents working on the Codot project.

## Project Overview

**Codot** is a bridge between AI coding agents (via Model Context Protocol) and the Godot 4.x game engine. It enables AI systems to directly interact with Godot's editor and running games through a WebSocket connection.

### Architecture

```
┌─────────────────┐     MCP Protocol      ┌──────────────────┐     WebSocket      ┌─────────────────┐
│   AI Agent      │ ◄───────────────────► │   MCP Server     │ ◄────────────────► │  Godot Editor   │
│ (Claude, etc.)  │    (stdio/JSON-RPC)   │   (Python)       │    (port 6850)     │  (GDScript)     │
└─────────────────┘                       └──────────────────┘                    └─────────────────┘
```

### Key Components

| Component | Location | Language | Purpose |
|-----------|----------|----------|---------|
| Godot Plugin | `addons/codot/` | GDScript | Editor plugin with WebSocket server |
| MCP Server | `mcp-server/codot/` | Python | MCP protocol bridge to Godot |
| Tests (GUT) | `test/` | GDScript | Godot unit tests |
| Tests (pytest) | `mcp-server/tests/` | Python | Python unit tests |

## Development Guidelines

### GDScript Conventions

1. **Docstrings**: Use `##` comments above functions for documentation
2. **Type hints**: Always use static typing (`var x: int = 0`)
3. **Naming**: Use `snake_case` for functions/variables, `PascalCase` for classes
4. **Error handling**: Return dictionaries with `success`, `error.code`, `error.message`
5. **Use `self.`**: Always use `self.` prefix when accessing instance members (properties, methods) for clarity
6. **British English**: Use British English spelling throughout (e.g., "colour", "initialise", "behaviour", "serialise")

```gdscript
## Brief description of what this function does.
## [br][br]
## [param params]: Description of the params dictionary.
## - 'key' (Type, required/optional): Description.
func _cmd_example(cmd_id: Variant, params: Dictionary) -> Dictionary:
    if some_error:
        return self._error(cmd_id, "ERROR_CODE", "Human readable message")
    return self._success(cmd_id, {"result": value})
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

Commands are organized into modules under `addons/codot/commands/`. To add a new command:

1. **Find the appropriate module** (or create a new one):
   - `commands_status.gd` - Status, play, stop, debug output
   - `commands_scene_tree.gd` - Scene tree inspection
   - `commands_file.gd` - File read/write/list operations
   - `commands_scene.gd` - Scene open/save/create
   - `commands_editor.gd` - Editor selection and settings
   - `commands_script.gd` - Script editing and errors
   - `commands_node.gd` - Node manipulation
   - `commands_input.gd` - Input simulation
   - `commands_input_map.gd` - InputMap action management
   - `commands_autoload.gd` - Autoload singleton management
   - `commands_gut.gd` - GUT testing framework
   - `commands_advanced.gd` - Signals, methods, groups
   - `commands_resource.gd` - Resources, animations, audio
   - `commands_debug.gd` - Performance, memory, advanced debug
   - `commands_plugin.gd` - Plugin management

2. **Add the command function** to the module:
   - Use `cmd_` prefix (not `_cmd_`)
   - Extend `command_base.gd` for utilities

3. **Register in `command_handler.gd`**:
   - Add case to `handle_command()` match statement
   - Delegate to the appropriate module

4. **Update `mcp-server/codot/commands.py`**:
   - Add `CommandDefinition` to `COMMANDS` dictionary
   - Include description and JSON Schema for parameters

#### Command Module Pattern

```gdscript
## Module description
extends "command_base.gd"

## Command description.
func cmd_example(cmd_id: Variant, params: Dictionary) -> Dictionary:
    var result = _require_scene(cmd_id)  # Use base class utilities
    if result.has("error"):
        return result
    
    var root = _get_scene_root()
    # ... command logic ...
    
    return _success(cmd_id, {"result": value})
```

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
| `DIALOG_OPEN` | Modal dialog blocking operation |

## ⚠️ CRITICAL: Automation & Development Workflow

### VS Code Window Reload Halts Automation

**IMPORTANT**: Reloading the VS Code window (e.g., `Developer: Reload Window`) will:
- Stop any in-progress AI chat/automation
- Require the user to manually tell the AI to continue
- Increase costs due to interrupted workflows

**Avoid these actions during automation:**
- `Developer: Reload Window`
- Installing extensions that require reload
- Changing workspace settings that trigger reload

**If you need to test extension changes:**
1. Complete current automation first
2. Inform the user that a reload is needed
3. After reload, remind the user to re-invoke the AI to continue

### AI Can Restart Godot Plugins

The AI can programmatically disable and re-enable Godot plugins using MCP commands:

```
# Disable and re-enable a plugin to reload it
godot_disable_plugin(name="codot")
godot_enable_plugin(name="codot")
```

**Use cases:**
- Reloading after script changes in plugin code
- Testing plugin activation/deactivation
- Resetting plugin state

**WARNING**: Disabling the Codot plugin will disconnect the WebSocket. You'll need to wait for reconnection after re-enabling.

### MCP Server Changes Require Extension Repackaging

When modifying the MCP server (`mcp-server/codot/`), changes are picked up automatically on next VS Code restart. However, if you modify the VS Code extension (`vscode-extension/`):

1. **Rebuild the extension:**
   ```bash
   cd vscode-extension
   npm run compile
   ```

2. **Reinstall the extension:**
   ```bash
   code --install-extension codot-bridge-0.1.0.vsix --force
   ```

3. **Reload VS Code window** (this will interrupt automation - see above)

### Git Commit Requirements

**ALWAYS** generate a Git commit title and description when completing work:

```markdown
## Git Commit

**Title:** [type]: Brief description (max 50 chars)

**Description:**
- What was changed
- Why it was changed
- Any breaking changes or important notes

**Type prefixes:**
- feat: New feature
- fix: Bug fix
- docs: Documentation only
- style: Formatting, missing semicolons, etc.
- refactor: Code change that neither fixes nor adds
- test: Adding missing tests
- chore: Maintenance, build changes
```

**Example:**
```
feat: Add delete button to archived prompts

- Added 🗑 button next to Restore button in archived list
- Implemented _on_delete_archived_prompt handler
- Updated GUT tests for delete functionality
```

## AI Agent Best Practices & Common Pitfalls

### ⚠️ CRITICAL: Avoid These Common Issues

#### 1. Python Inline Code Syntax Errors

**NEVER** use complex inline Python with `python -c "..."` - it causes `SyntaxError: unterminated string literal`:

```python
# ❌ BAD - Will fail with syntax errors due to escaping issues
python -c "import asyncio; print(f'Result: {result.get(\"key\")}')"

# ✅ GOOD - Create a script file instead
create_file("test_script.py", content)
run_in_terminal("python test_script.py")
```

**Why this fails:**
- Nested quotes require complex escaping
- F-strings with dictionary access (`{result.get("key")}`) are especially problematic  
- Multi-line code in `-c` flags is error-prone
- Terminal escaping varies by platform (Windows vs Unix)

**Solution:** Always create a temporary `.py` file for anything beyond trivial one-liners.

#### 2. Modal Dialog Detection

Commands can fail silently if a modal dialog is open in Godot (e.g., "There is no defined scene to run").

**Before running game-related commands:**
```
1. godot_get_open_dialogs → Check for blocking dialogs
2. If dialog found: godot_dismiss_dialog(action="ok") 
3. Then proceed with godot_play, etc.
```

#### 3. Function Signature Consistency

All command functions MUST accept both `cmd_id` and `params`:

```gdscript
# ❌ BAD - Missing params parameter
func cmd_example(cmd_id: Variant) -> Dictionary:

# ✅ GOOD - Use _params if not used
func cmd_example(cmd_id: Variant, _params: Dictionary) -> Dictionary:
```

#### 4. UI Elements in Code vs Scene Files

**NEVER** create UI elements (Button, Label, VBox, etc.) directly in GDScript code:

```gdscript
# ❌ BAD - UI created in code
var button = Button.new()
button.text = "Click me"
add_child(button)

# ✅ GOOD - Load UI from scene file
var dock_scene = preload("res://addons/codot/codot_panel.tscn")
var dock = dock_scene.instantiate()
add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
```

**Why:**
- Scene files are easier to edit visually
- Reduces code complexity
- Better separation of concerns
- Easier to maintain and modify layout

#### 5. WebSocket API Compatibility

The `websockets` Python library changed its API in version 15.0+:

```python
# ❌ OLD API (deprecated)
self.websocket.open  # AttributeError in v15+

# ✅ NEW API
self.websocket.state.name == "OPEN"
```

#### 6. WebSocket Race Conditions in GDScript

When using WebSocket with `_process()` polling, **never read packets directly** in async functions:

```gdscript
# ❌ BAD - Race condition with _process() consuming packets
func send_and_wait() -> bool:
    _websocket.send_text(message)
    while timeout:
        _websocket.poll()
        # This competes with _process() for packets!
        while _websocket.get_available_packet_count() > 0:
            var packet = _websocket.get_packet()  # Might miss messages!
            
# ✅ GOOD - Use flag-based communication
var _waiting_for_ack: bool = false
var _ack_received: bool = false

func send_and_wait() -> bool:
    _waiting_for_ack = true
    _ack_received = false
    _websocket.send_text(message)
    while timeout and not _ack_received:
        await get_tree().create_timer(0.1).timeout
    _waiting_for_ack = false
    return _ack_received

func _handle_message(text: String) -> void:
    var data = parse_json(text)
    if _waiting_for_ack and data.type == "ack":
        _ack_received = true
        return
```

**Why:** The `_process()` function runs every frame and consumes packets via `_process_incoming_messages()`. 
Any other code trying to read packets will race with it and miss messages.

#### 7. VS Code Extension Must Send Acknowledgments

When the VS Code Codot Bridge receives a prompt, it **MUST** send an acknowledgment:

```typescript
// In extension.ts handlePrompt():
ws.send(JSON.stringify({ 
    type: "ack",
    success: true,
    message: "Prompt received",
    prompt_id: message.prompt_id
}));
```

The Godot panel waits for this ack before archiving prompts. Without it:
- Prompt shows "Sent (unconfirmed)"
- Prompt is NOT archived
- User sees warning in Output

### Robust Script Generation Guidelines

When generating scripts that interact with Godot:

1. **Check editor state first:**
   ```
   godot_get_editor_state  → Verify expected state
   godot_get_open_dialogs  → Check for blocking dialogs
   ```

2. **Validate preconditions:**
   - Is a scene open? (`get_scene_tree`)
   - Is the game already playing? (`is_playing`)
   - Does the target file exist? (`file_exists`)

3. **Handle all error responses:**
   ```python
   result = await client.send_command("some_command", params)
   if not result.get("success"):
       error = result.get("error", {})
       handle_error(error.get("code"), error.get("message"))
   ```

4. **Use timeouts appropriately:**
   - Quick commands: 5 seconds
   - File operations: 10 seconds
   - Game execution: 30-60 seconds
   - GUT test runs: 60-120 seconds

### Codebase Validation


Run the validation script before committing changes:

```bash
python scripts/validate-codebase.py --verbose
```

This checks for:
- UI elements created in code (should be in .tscn)
- Command signature consistency
- Missing command registrations
- Python/GDScript cross-reference issues
- Invalid UID references
- Async race condition patterns
- Const names that shadow global classes

## VS Code Codot Bridge Extension

The VS Code extension (`vscode-extension/`) provides a WebSocket server that receives prompts from Godot.

### Starting the Bridge

The extension auto-starts on VS Code startup (if `codot-bridge.autoStart` is true). Manual control:
- **Start**: Command Palette → "Codot: Start Bridge Server"
- **Stop**: Command Palette → "Codot: Stop Bridge Server"
- **Status**: Command Palette → "Codot: Show Bridge Status"

### Message Format (Godot → VS Code)

```json
{
    "type": "prompt",
    "prompt_id": "unique-id",
    "title": "Prompt Title",
    "content": "The actual prompt content...",
    "timestamp": "2026-01-02T12:00:00"
}
```

### Response Format (VS Code → Godot)

```json
{
    "type": "ack",
    "success": true,
    "message": "Prompt sent to Copilot Chat",
    "prompt_id": "unique-id"
}
```

### Rebuilding the Extension

```bash
cd vscode-extension
npm run compile
code --install-extension codot-bridge-0.1.0.vsix --force
# Then reload VS Code window
```

## Codot Panel (Prompt Management)

The Codot panel (`addons/codot/codot_panel.gd` + `.tscn`) provides a UI for managing prompts.

### Features
- Create, edit, delete, duplicate prompts
- Auto-save with dirty flag (1.5s delay)
- Export/Import prompts as JSON
- Send to VS Code AI with confirmation
- Archive sent prompts
- Connection status with tooltips

### Key State Variables

```gdscript
var _waiting_for_ack: bool        # True while waiting for VS Code response
var _ack_received: bool           # Set by _handle_message when ack arrives
var _ack_error: String            # Error message if ack indicates failure
var _is_connected: bool           # WebSocket connection status
var _connection_attempts: int     # Number of connection attempts
```

### Send Flow

1. User clicks "Send to AI" button
2. `send_prompt()` sets `_waiting_for_ack = true`
3. Message sent via WebSocket
4. `_process()` continues polling, `_handle_message()` checks for ack
5. When ack received, `_ack_received = true`
6. `send_prompt()` sees flag, archives prompt if enabled
7. Status shows "Sent ✓"

## File Structure Reference

```
codot/
├── addons/codot/               # Godot editor plugin (SOURCE OF TRUTH)
│   ├── plugin.cfg              # Plugin metadata
│   ├── codot.gd                # Main EditorPlugin class (v0.2.0)
│   ├── codot_panel.gd          # Prompt management panel script
│   ├── codot_panel.tscn        # Prompt panel UI (scene-based)
│   ├── codot_settings.gd       # Editor settings integration
│   ├── websocket_server.gd     # WebSocket server
│   ├── command_handler.gd      # Command routing (delegates to modules)
│   ├── debugger_plugin.gd      # Editor debugger for capturing output
│   ├── output_capture.gd       # Game-side output capture (autoload)
│   └── commands/               # Command module directory
│       ├── command_base.gd     # Base class with common utilities
│       ├── commands_status.gd  # Status, play, stop, debug
│       ├── commands_scene_tree.gd # Scene tree inspection
│       ├── commands_file.gd    # File operations
│       ├── commands_scene.gd   # Scene open/save/create
│       ├── commands_editor.gd  # Editor selection/settings
│       ├── commands_script.gd  # Script editing
│       ├── commands_node.gd    # Node manipulation
│       ├── commands_input.gd   # Input simulation
│       ├── commands_gut.gd     # GUT testing
│       ├── commands_advanced.gd # Signals/methods/groups
│       ├── commands_resource.gd # Resources/animations/audio
│       ├── commands_debug.gd   # Performance/debug/screenshots
│       └── commands_plugin.gd  # Plugin management
├── mcp-server/                 # Python MCP server
│   ├── pyproject.toml          # Python package config
│   ├── codot/
│   │   ├── __init__.py
│   │   ├── server.py           # MCP server entry point
│   │   ├── godot_client.py     # WebSocket client
│   │   └── commands.py         # Command definitions
│   └── tests/                  # pytest tests
├── vscode-extension/           # VS Code Codot Bridge extension
│   ├── package.json            # Extension manifest
│   ├── src/extension.ts        # Bridge server (receives AI prompts)
│   └── README.md               # Extension documentation
├── test/                       # GUT tests for Godot
│   ├── unit/                   # Unit tests
│   │   ├── test_codot_panel.gd # Prompt panel tests
│   │   └── test_codot_settings.gd # Settings tests
│   ├── integration/            # Integration tests
│   └── scenes/                 # Test scenes
├── scripts/                    # Development tools
│   └── validate-codebase.py    # Static analysis validator
├── .vscode/mcp.json            # VS Code MCP configuration
└── docs/                       # Documentation
```

## Available MCP Tools

The MCP server exposes 80+ tools. Key categories:

### Scene & Node Operations
- `godot_get_scene_tree` - Get scene hierarchy
- `godot_create_node` - Create nodes
- `godot_set_node_property` - Modify properties
- `godot_delete_node` - Remove nodes
- `godot_duplicate_scene` - Duplicate a scene
- `godot_get_scene_dependencies` - Get all resources used by a scene

### Game Control
- `godot_play` / `godot_stop` - Run/stop game
- `godot_play_current` - Play current scene

### File Operations
- `godot_read_file` / `godot_write_file` - File I/O
- `godot_get_project_files` - List project files
- `godot_create_directory` - Create directories
- `godot_delete_file` / `godot_delete_directory` - Delete files/directories
- `godot_rename_file` / `godot_copy_file` - Move/copy files
- `godot_get_file_info` - Get file metadata

### Editor Operations
- `godot_refresh_filesystem` - Refresh FileSystem dock
- `godot_reimport_resource` - Force reimport a resource
- `godot_get_current_screen` / `godot_set_current_screen` - Switch editor views

### Resource Operations
- `godot_create_resource` - Create any resource type
- `godot_duplicate_resource` - Duplicate a resource
- `godot_set_resource_properties` - Set resource properties
- `godot_list_resource_types` - List creatable resource types

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
cd mcp-server
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
- **Dependencies**: See `mcp-server/pyproject.toml`

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
| **List input actions** | `godot_get_input_actions` |
| **Add input action** | `godot_add_input_action` |
| **Add key binding** | `godot_add_input_event_key` |
| **List autoloads** | `godot_get_autoloads` |
| **Add autoload** | `godot_add_autoload` |
| **Remove autoload** | `godot_remove_autoload` |

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
│                    Running Game                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  CodotOutputCapture (autoload)                      │    │
│  │  - EngineDebugger.send_message("codot:entry", {...})│    │
│  └───────────────────────┬─────────────────────────────┘    │
└──────────────────────────│──────────────────────────────────┘
                           │ EngineDebugger protocol
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Godot Editor                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  EditorDebuggerPlugin                               │    │
│  │  - _capture("codot:entry", data, session_id)        │    │
│  │  - Stores in _entries array                         │    │
│  └───────────────────────┬─────────────────────────────┘    │
│                          ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  CommandHandler                                     │    │
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

## InputMap Commands

Manage input actions and key bindings programmatically:

### godot_get_input_actions
List all input actions defined in the project.

```
godot_get_input_actions(include_builtins=false)
→ Returns: {
    "actions": [
        {"name": "move_left", "deadzone": 0.5, "event_count": 2},
        {"name": "jump", "deadzone": 0.5, "event_count": 1}
    ],
    "count": 2
}
```

### godot_get_input_action
Get detailed information about a specific input action.

```
godot_get_input_action(action="jump")
→ Returns: {
    "action": "jump",
    "exists": true,
    "deadzone": 0.5,
    "events": [
        {"type": "key", "keycode": "SPACE", "modifiers": {"shift": false, "ctrl": false}}
    ]
}
```

### godot_add_input_action
Add a new input action to the project.

```
godot_add_input_action(action="custom_action", deadzone=0.5)
→ Returns: {"action": "custom_action", "added": true, "deadzone": 0.5}
```

### godot_remove_input_action
Remove an input action from the project.

```
godot_remove_input_action(action="custom_action")
→ Returns: {"action": "custom_action", "removed": true}
```

### godot_add_input_event_key
Add a keyboard key binding to an action.

```
godot_add_input_event_key(action="jump", key="SPACE", shift=false, ctrl=false)
→ Returns: {"action": "jump", "added": true, "key": "SPACE"}
```

### godot_add_input_event_mouse
Add a mouse button binding to an action.

```
godot_add_input_event_mouse(action="fire", button=1)
→ Returns: {"action": "fire", "added": true, "button": 1}
```

### godot_add_input_event_joypad_button
Add a gamepad button binding to an action.

```
godot_add_input_event_joypad_button(action="jump", button=0, device=-1)
→ Returns: {"action": "jump", "added": true, "button": 0}
```

### godot_add_input_event_joypad_axis
Add a gamepad axis binding to an action.

```
godot_add_input_event_joypad_axis(action="move_right", axis=0, axis_value=1.0)
→ Returns: {"action": "move_right", "added": true, "axis": 0}
```

### godot_clear_input_action_events
Remove all bindings from an action.

```
godot_clear_input_action_events(action="jump")
→ Returns: {"action": "jump", "cleared": true, "events_cleared": 2}
```

## Autoload Commands

Manage autoload singletons programmatically:

### godot_get_autoloads
List all autoload singletons in the project.

```
godot_get_autoloads
→ Returns: {
    "autoloads": [
        {"name": "GameManager", "path": "res://globals/game_manager.gd", "enabled": true, "order": 0},
        {"name": "AudioManager", "path": "res://globals/audio_manager.gd", "enabled": true, "order": 1}
    ],
    "count": 2
}
```

### godot_get_autoload
Get detailed information about a specific autoload.

```
godot_get_autoload(name="GameManager")
→ Returns: {
    "name": "GameManager",
    "exists": true,
    "path": "res://globals/game_manager.gd",
    "enabled": true,
    "order": 0
}
```

### godot_add_autoload
Add a new autoload singleton.

```
godot_add_autoload(name="MyManager", path="res://globals/my_manager.gd")
→ Returns: {"name": "MyManager", "added": true, "path": "res://globals/my_manager.gd"}
```

### godot_remove_autoload
Remove an autoload singleton.

```
godot_remove_autoload(name="MyManager")
→ Returns: {"name": "MyManager", "removed": true}
```

### godot_rename_autoload
Rename an existing autoload singleton.

```
godot_rename_autoload(old_name="OldName", new_name="NewName")
→ Returns: {"old_name": "OldName", "new_name": "NewName", "renamed": true}
```

### godot_set_autoload_path
Change the script/scene path of an autoload.

```
godot_set_autoload_path(name="GameManager", path="res://globals/new_game_manager.gd")
→ Returns: {"name": "GameManager", "updated": true, "new_path": "res://globals/new_game_manager.gd"}
```

### godot_reorder_autoloads
Change the loading order of autoloads.

```
godot_reorder_autoloads(order=["AudioManager", "GameManager", "UIManager"])
→ Returns: {"reordered": true, "new_order": ["AudioManager", "GameManager", "UIManager"]}
```

## Security Safeguards

The Codot plugin includes security settings to protect against unintended file access:

### Settings (Editor Settings → Plugin → Codot)

| Setting | Default | Description |
|---------|---------|-------------|
| `restrict_file_access_to_project` | `true` | Only allow file operations within `res://` and `user://` |
| `allow_system_commands` | `false` | Allow execution of system commands (dangerous) |
| `max_file_size_kb` | `1024` | Maximum file size for read/write operations (KB) |

### Path Validation

When `restrict_file_access_to_project` is enabled:
- `res://` paths are always allowed
- `user://` paths are always allowed  
- Absolute paths are only allowed if within the project directory
- Attempts to access files outside the project return `PATH_OUTSIDE_PROJECT` error

### File Size Limits

When reading or writing files:
- Files larger than `max_file_size_kb` return `FILE_TOO_LARGE` error
- Content larger than `max_file_size_kb` returns `CONTENT_TOO_LARGE` error

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
