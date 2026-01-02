# Codot - Godot Plugin

This is the Godot 4.x plugin component of Codot, which enables AI agents to control and monitor Godot games via Model Context Protocol.

## Installation

### Option 1: Copy to Your Project (Recommended)
1. Copy the entire `addons/codot` folder to your project's `addons/` directory
2. In Godot, go to **Project → Project Settings → Plugins**
3. Enable "Codot"

The plugin will automatically register the `CodotOutputCapture` autoload, which is required for:
- Capturing debug output from running games
- Input simulation in running games
- Screenshots from running games

### Option 2: Symlink (for development)
```bash
# Windows (PowerShell as Admin)
New-Item -ItemType Junction -Path "your_project/addons/codot" -Target "path/to/codot/addons/codot"

# Linux/macOS
ln -s /path/to/codot/addons/codot your_project/addons/codot
```

## Configuration

After enabling the plugin, configure it in **Project → Project Settings**:

| Setting | Default | Description |
|---------|---------|-------------|
| `codot/network/port` | `6850` | WebSocket server port |
| `codot/network/autostart_server` | `true` | Start server when plugin loads |
| `codot/debug/verbose_logging` | `false` | Enable debug output |

## Autoloads

### CodotOutputCapture (Automatic)

This autoload is **automatically registered** when you enable the Codot plugin. It provides:
- Capturing debug output (print, errors, warnings) from running games
- Receiving input simulation commands from the editor
- Screenshot capture from running games

The autoload uses Godot's `EngineDebugger` to communicate with the editor, which works across the editor/game process boundary.

### CodotGameConnector (Optional, Advanced)

For real-time game state access while the game is running, you can optionally add the `CodotGameConnector` as an autoload:

1. Go to **Project → Project Settings → Autoload**
2. Add `addons/codot/game_connector.gd`
3. Name it `CodotGame` (or any name you prefer)

This enables additional features:
- Real-time scene tree inspection (from game's perspective)
- Variable monitoring
- Method calling on game nodes

**Note:** Most users don't need this - the automatic `CodotOutputCapture` handles input simulation and output capture.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         EDITOR PROCESS                                   │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ Codot Plugin                                                       │  │
│  │  ├─ WebSocket Server (port 6850) ◄─── MCP Server (Python)          │  │
│  │  ├─ Command Handler                                                │  │
│  │  └─ EditorDebuggerPlugin ───────────────────────────┐              │  │
│  └──────────────────────────────────────────────────────│──────────────┘  │
└─────────────────────────────────────────────────────────│─────────────────┘
                                                          │ EngineDebugger
                                                          │ Protocol
┌─────────────────────────────────────────────────────────│─────────────────┐
│                         GAME PROCESS                    ▼                 │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ CodotOutputCapture (autoload)                                      │  │
│  │  ├─ Receives input commands → Input.parse_input_event()           │  │
│  │  ├─ Captures errors/warnings → Sends to editor                     │  │
│  │  └─ Takes screenshots → Sends result to editor                     │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────┘
```

## Available Commands

### Editor Control
- `play_scene` - Start a specific scene
- `play_current_scene` - Start the currently edited scene
- `play_main_scene` - Start the main scene
- `stop_scene` - Stop the running game
- `is_playing` - Check if a game is running

### Debug/Logging
- `get_logs` - Retrieve captured logs
- `clear_logs` - Clear the log buffer
- `subscribe_logs` - Enable real-time log streaming

### Input Simulation
- `simulate_action` - Trigger an input action
- `simulate_key` - Simulate keyboard input
- `simulate_mouse_motion` - Move the mouse
- `simulate_mouse_button` - Click mouse buttons

### Scene Inspection
- `get_scene_tree` - Get the scene tree structure
- `get_node_info` - Get detailed node information

### Script Execution
- `execute_script` - Execute GDScript code

## Protocol

Commands are sent as JSON over WebSocket:

```json
{
  "id": "unique-request-id",
  "command": "command_name",
  "params": {
    "param1": "value1"
  }
}
```

Responses:

```json
{
  "id": "unique-request-id",
  "success": true,
  "result": { }
}
```

Errors:

```json
{
  "id": "unique-request-id",
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message"
  }
}
```

## License

MIT License - See LICENSE file for details.
