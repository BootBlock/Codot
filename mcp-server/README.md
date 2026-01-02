# Codot Server

Python MCP server that enables AI agents (like GitHub Copilot, Claude, etc.) to control and monitor the Godot game engine via Model Context Protocol.

## Installation

### From Source

```bash
cd mcp-server
pip install -e .
```

### With Development Dependencies

```bash
pip install -e ".[dev]"
```

## Configuration

### VS Code MCP Settings

Add to your VS Code `settings.json` or `.vscode/mcp.json`:

```json
{
  "servers": {
    "codot": {
      "command": "python",
      "args": ["-m", "codot.server"],
      "env": {
        "CODOT_HOST": "127.0.0.1",
        "CODOT_PORT": "6850"
      }
    }
  }
}
```

Or if installed globally:

```json
{
  "servers": {
    "codot": {
      "command": "codot-server"
    }
  }
}
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CODOT_HOST` | `127.0.0.1` | Godot WebSocket host |
| `CODOT_PORT` | `6850` | Godot WebSocket port |

## Available Tools

### Connection Management

| Tool | Description |
|------|-------------|
| `godot_connection_status` | Check connection status |
| `godot_connect` | Connect to Godot |
| `godot_disconnect` | Disconnect from Godot |

### Status & Info

| Tool | Description |
|------|-------------|
| `godot_ping` | Ping the server |
| `godot_get_status` | Get Godot status (version, project, etc.) |
| `godot_get_capabilities` | List available commands |

### Play Control

| Tool | Description |
|------|-------------|
| `godot_play_scene` | Play a specific scene |
| `godot_play_current_scene` | Play the current scene |
| `godot_play_main_scene` | Play the main scene |
| `godot_stop_scene` | Stop the game |
| `godot_is_playing` | Check if game is running |

### Debug & Logging

| Tool | Description |
|------|-------------|
| `godot_get_logs` | Get recent logs |
| `godot_clear_logs` | Clear log buffer |
| `godot_subscribe_logs` | Enable log streaming |

### Input Simulation

| Tool | Description |
|------|-------------|
| `godot_simulate_action` | Trigger an input action |
| `godot_simulate_key` | Simulate keyboard input |
| `godot_simulate_mouse_motion` | Move the mouse |
| `godot_simulate_mouse_button` | Click mouse button |

### Scene Inspection

| Tool | Description |
|------|-------------|
| `godot_get_scene_tree` | Get scene tree structure |
| `godot_get_node_info` | Get node details |

### Script Execution

| Tool | Description |
|------|-------------|
| `godot_execute_script` | Execute GDScript code |

## Usage Example

Once configured, you can ask your AI assistant to:

```
"Connect to Godot and start the main scene"
"Check if there are any errors in the game logs"
"Simulate pressing the jump button"
"Stop the game and check for warnings"
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AI Agent (Claude, etc.)                 │
│                                                             │
│  "Start the game and simulate pressing W for 2 seconds"    │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ MCP Protocol (stdio)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Codot Server                           │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Tool        │  │ Godot       │  │ Command             │ │
│  │ Handler     │──│ Client      │──│ Definitions         │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ WebSocket (ws://127.0.0.1:6850)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Godot with Codot Plugin                │
└─────────────────────────────────────────────────────────────┘
```

## Development

### Running Tests

```bash
pytest
```

### Type Checking

```bash
mypy codot
```

### Formatting

```bash
black codot
```

## License

MIT License - See LICENSE file for details.
