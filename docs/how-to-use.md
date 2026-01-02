# Codot - Installation & Usage Guide

This guide explains how to install, configure, and use Codot to enable AI-assisted Godot development.

## What is Codot?

Codot bridges AI coding assistants with Godot Engine through the Model Context Protocol (MCP). Once set up, AI agents can:

- Read and modify your scene tree
- Create, edit, and delete nodes
- Run and stop your game
- Read and write project files
- Execute GUT tests
- Simulate input (keyboard, mouse, controller)
- Access performance metrics
- And much more (64+ commands)

## Prerequisites

- **Godot Engine 4.3+** (tested with 4.6)
- **Python 3.10+**
- **VS Code** with GitHub Copilot (or another MCP-compatible AI client)
- **Git** (for cloning the repository)

## Installation

### Step 1: Install the Godot Plugin

1. **Copy the addon folder** to your Godot project:

   ```
   your_godot_project/
   └── addons/
       └── codot/
           ├── plugin.cfg
           ├── codot.gd
           ├── websocket_server.gd
           └── command_handler.gd
   ```

2. **Enable the plugin** in Godot:
   - Open your project in Godot
   - Go to **Project → Project Settings → Plugins**
   - Find **Codot** and set it to **Enabled**

3. **Verify activation**:
   - You should see `[Codot] Plugin enabled` in the Output panel
   - The WebSocket server starts on port `6850`

### Step 2: Install the MCP Server

1. **Navigate to the MCP source directory**:

   ```bash
   cd path/to/codot/mcp-server
   ```

2. **Install the Python package**:

   ```bash
   pip install -e .
   ```

   Or with development dependencies (for testing):

   ```bash
   pip install -e ".[dev]"
   ```

3. **Verify installation**:

   ```bash
   python -c "from codot.server import main; print('OK')"
   ```

### Step 3: Configure VS Code

1. **Create the MCP configuration file** at `.vscode/mcp.json` in your project:

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

2. **Alternative: Global installation**

   If you installed the package globally, you can use:

   ```json
   {
     "servers": {
       "codot": {
         "command": "codot-server"
       }
     }
   }
   ```

3. **Restart VS Code** to load the MCP configuration.

## Usage

### Starting a Session

1. **Open Godot** with your project and ensure the Codot plugin is enabled
2. **Open VS Code** in the same project directory
3. **Start a Copilot chat** (or your MCP-compatible AI)
4. The AI will automatically connect to Godot when you ask it to interact with your project

### Example Prompts

Here are some example prompts to try with your AI assistant:

#### Basic Queries

```
"Ping Godot to check the connection"
"Get the status of the Godot project"
"Show me the current scene tree"
```

#### Scene Operations

```
"Create a new Node2D called 'Player' under the root node"
"Add a Sprite2D child to the Player node"
"Set the Player's position to (100, 200)"
"Delete the node at path 'Enemy'"
```

#### Game Control

```
"Run the game"
"Stop the running game"
"Play the scene at res://scenes/level1.tscn"
```

#### File Operations

```
"List all .gd files in the project"
"Read the contents of res://scripts/player.gd"
"Create a new script at res://scripts/enemy.gd with a basic enemy class"
```

#### Testing (requires GUT plugin)

```
"Check if GUT testing framework is installed"
"Run all tests in the test/unit directory"
"Create a new test file for the Player class"
```

### Workflow Example

Here's a typical AI-assisted workflow:

1. **You**: "Create a new 2D scene for a platformer player"

2. **AI** (uses `godot_create_scene`): Creates `res://scenes/player.tscn` with CharacterBody2D root

3. **You**: "Add a CollisionShape2D and Sprite2D to the player"

4. **AI** (uses `godot_create_node` twice): Adds both child nodes

5. **You**: "Create a player movement script"

6. **AI** (uses `godot_write_file`): Creates `res://scripts/player.gd` with movement code

7. **You**: "Run the game and test it"

8. **AI** (uses `godot_play`): Starts the game

## Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CODOT_HOST` | `127.0.0.1` | WebSocket server host |
| `CODOT_PORT` | `6850` | WebSocket server port |

### Changing the Port

If port 6850 is in use, you can change it:

1. **In Godot** (`websocket_server.gd`):
   ```gdscript
   var port: int = 6851  # Change this
   ```

2. **In your MCP config** (`.vscode/mcp.json`):
   ```json
   "env": {
     "CODOT_PORT": "6851"
   }
   ```

## Troubleshooting

### "Not connected to Godot"

- Ensure Godot is running with your project open
- Verify the Codot plugin is enabled (check Output panel)
- Check that nothing else is using port 6850

### "Command not found"

- The command may not be implemented
- Check the AGENTS.md file for available commands

### WebSocket Connection Failed

```bash
# Test the connection manually:
cd mcp-server
python test_connection.py
```

### Plugin Not Appearing in Godot

- Ensure the folder structure is correct: `addons/codot/plugin.cfg`
- Check for GDScript errors in the Output panel
- Try reloading the project (Project → Reload Current Project)

### Python Import Errors

```bash
# Reinstall the package:
cd mcp-server
pip uninstall codot
pip install -e .
```

## Security Considerations

- The WebSocket server binds to `127.0.0.1` (localhost only) by default
- Do not expose port 6850 to the network in production
- The AI can read/write files in your project - review changes before committing

## Advanced: Using with Other AI Clients

Codot uses the standard Model Context Protocol. Any MCP-compatible client can connect:

1. **Claude Desktop**: Add to `claude_desktop_config.json`
2. **Custom clients**: Connect via stdio to `python -m codot.server`

### MCP Inspector

For debugging, use the MCP Inspector:

```bash
npx @anthropic/mcp-inspector python -m codot.server
```

## Updating

To update Codot:

1. **Update the Godot plugin**: Replace `addons/codot/` with the new version
2. **Update the MCP server**:
   ```bash
   cd mcp-server
   git pull
   pip install -e .
   ```

## Getting Help

- **Issues**: Report bugs on the GitHub repository
- **Documentation**: See `AGENTS.md` for development documentation
- **Command Reference**: Ask the AI "What Godot commands are available?"

## Quick Start Checklist

- [ ] Copied `addons/codot/` to your project
- [ ] Enabled the plugin in Project Settings → Plugins
- [ ] Installed Python package with `pip install -e .`
- [ ] Created `.vscode/mcp.json` configuration
- [ ] Restarted VS Code
- [ ] Godot is running with project open
- [ ] Asked the AI to "ping Godot" to verify connection
