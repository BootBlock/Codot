# Codot

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Godot 4.3+](https://img.shields.io/badge/Godot-4.3%2B-blue.svg)](https://godotengine.org/)
[![Python 3.10+](https://img.shields.io/badge/Python-3.10%2B-green.svg)](https://www.python.org/)

**Codot** is a bridge between AI coding agents and the Godot 4.x game engine. It enables AI systems like GitHub Copilot, Claude, and other MCP-compatible assistants to directly control Godot's editor and running games.

## ✨ Features

- **64+ MCP Tools** - Create nodes, modify scenes, run games, capture debug output, and more
- **Real-time Control** - Play, pause, and interact with running games
- **Full Scene Access** - Read and modify the scene tree, node properties, and scripts
- **Debug Capture** - Capture errors, warnings, and print statements from running games
- **GUT Integration** - Run and monitor GUT unit tests
- **Input Simulation** - Simulate keyboard, mouse, and controller input
- **AI Chat Dock** - Send prompts from Godot directly to VS Code AI assistants

## 🏗️ Architecture

```
┌─────────────────┐     MCP Protocol      ┌──────────────────┐     WebSocket      ┌─────────────────┐
│   AI Agent      │ ◄──────────────────► │   MCP Server     │ ◄────────────────► │  Godot Editor   │
│ (Claude, etc.)  │    (stdio/JSON-RPC)   │   (Python)       │    (port 6850)     │  (GDScript)     │
└─────────────────┘                       └──────────────────┘                    └─────────────────┘
```

The system consists of three components:

| Component | Language | Purpose |
|-----------|----------|---------|
| **Godot Plugin** (`addons/codot/`) | GDScript | Editor plugin with WebSocket server |
| **MCP Server** (`mcp-server/`) | Python | Bridges MCP protocol to Godot WebSocket |
| **VS Code Extension** (`vscode-extension/`) | TypeScript | Receives AI prompts from Godot |

## 🚀 Quick Start

### 1. Install the Godot Plugin

Copy the `addons/codot/` folder into your Godot project's `addons/` directory:

```
your-project/
├── addons/
│   └── codot/          ← Copy this folder
├── project.godot
└── ...
```

Enable the plugin in Godot: **Project → Project Settings → Plugins → Codot → Enable**

### 2. Install the MCP Server

```bash
cd mcp-server
pip install -e .
```

### 3. Configure VS Code

Create `.vscode/mcp.json` in your project:

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

### 4. Start Using

1. Open your Godot project (plugin auto-starts)
2. Open VS Code with Copilot or another MCP client
3. Ask the AI to interact with Godot!

**Example prompts:**
- "Create a Player node with a Sprite2D child"
- "Run the game and check for errors"
- "What nodes are in the current scene?"

## 📦 Installation Options

### Option A: Copy Plugin Only (Recommended for Users)

Just copy `addons/codot/` to your project. This is all you need for the Godot side.

### Option B: Clone Full Repository (Recommended for Development)

```bash
git clone https://github.com/yourusername/codot.git
cd codot
pip install -e mcp-server/
```

## 🛠️ Available Tools

### Scene & Node Operations
| Tool | Description |
|------|-------------|
| `godot_get_scene_tree` | Get the scene hierarchy |
| `godot_create_node` | Create a new node |
| `godot_delete_node` | Remove a node |
| `godot_set_node_property` | Modify node properties |
| `godot_get_node_properties` | Read node properties |

### Game Control
| Tool | Description |
|------|-------------|
| `godot_play` | Start the main scene |
| `godot_play_current` | Play the current scene |
| `godot_stop` | Stop the running game |
| `godot_is_playing` | Check if game is running |

### Debug & Testing
| Tool | Description |
|------|-------------|
| `godot_get_debug_output` | Get captured logs/errors |
| `godot_run_and_capture` | Run scene and capture output |
| `godot_gut_run_all` | Run all GUT tests |
| `godot_gut_run_script` | Run specific test file |

### File Operations
| Tool | Description |
|------|-------------|
| `godot_read_file` | Read file contents |
| `godot_write_file` | Write file contents |
| `godot_get_project_files` | List project files |

See [AGENTS.md](AGENTS.md) for the complete list of 64+ tools.

## 🔧 Configuration

### WebSocket Port

The plugin listens on port `6850` by default. To change:

**Godot side:** Modify `addons/codot/websocket_server.gd`

**MCP side:** Set environment variable:
```bash
export CODOT_PORT=6850
```

### AI Chat Dock

The optional AI Chat dock (port `6851`) lets you send prompts from Godot to VS Code. Install the VS Code extension:

```bash
cd vscode-extension
npm install
npm run compile
# Install the generated .vsix file
```

## 🧪 Running Tests

### GUT Tests (Godot)
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/ -gexit
```

### Python Tests
```bash
cd mcp-server
pip install -e ".[dev]"
pytest
```

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🔗 Links

- [Documentation](docs/how-to-use.md)
- [AI Agent Instructions](AGENTS.md)
- [Changelog](CHANGELOG.md)
