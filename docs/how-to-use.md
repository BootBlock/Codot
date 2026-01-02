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

### Step 4: Using Codot in Multiple Projects

MCP servers are configured **per-workspace** in VS Code. If you want to use Codot in multiple Godot projects, you have two options:

#### Option A: Global Installation (Recommended)

Install the Codot MCP server globally so any project can use it:

1. **Install the package globally**:

   ```powershell
   # Navigate to the Codot MCP server directory
   cd P:\Source\Godot\Codot\mcp-server
   
   # Install as an editable package (or use 'pip install .' for non-editable)
   pip install -e .
   ```

2. **In each project**, create `.vscode/mcp.json`:

   ```json
   {
     "mcp": {
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
   }
   ```

3. **Reload VS Code** in that workspace (`Ctrl+Shift+P` → "Developer: Reload Window")

4. The AI should now see the `godot_*` MCP tools

#### Option B: Point to Codot Installation

If you don't want to install globally, point directly to the Codot source:

1. **In your other project**, create `.vscode/mcp.json`:

   ```json
   {
     "mcp": {
       "servers": {
         "codot": {
           "command": "python",
           "args": ["-m", "codot.server"],
           "cwd": "P:/Source/Godot/Codot/mcp-server",
           "env": {
             "CODOT_HOST": "127.0.0.1",
             "CODOT_PORT": "6850"
           }
         }
       }
     }
   }
   ```

   **Note:** Replace the `cwd` path with the absolute path to your Codot `mcp-server` folder.

2. **Reload VS Code** in that workspace

#### Verifying the Setup

After configuring, ask the AI:
- "What Godot tools do you have access to?"
- "Ping Godot to check the connection"

If the AI says it doesn't have access to MCP tools, double-check:
- The `.vscode/mcp.json` file exists in the workspace root
- The JSON syntax is valid (no trailing commas, correct brackets)
- You've reloaded the VS Code window after creating the file
- Python and the codot package are accessible from your PATH

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
| `CODOT_ENABLE_ALL_TOOLS` | `false` | Set to `1` to enable all 160+ tools (by default, ~95 tools are enabled to stay under VS Code's 128 tool limit) |

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


## Command Reference

Codot provides 80+ commands organized into categories:

### Status & Info
| Command | Description |
|---------|-------------|
| `ping` | Check if Godot is responding |
| `get_status` | Get project info, version, running state |

### Game Control
| Command | Description |
|---------|-------------|
| `play` | Run the main scene |
| `play_current` | Run the currently edited scene |
| `play_custom_scene` | Run a specific scene by path |
| `stop` | Stop the running game |
| `is_playing` | Check if game is running |

### File Operations
| Command | Description |
|---------|-------------|
| `read_file` | Read file contents |
| `write_file` | Write content to a file |
| `file_exists` | Check if file/directory exists |
| `get_project_files` | List project files with optional filtering |
| `create_directory` | Create a directory (recursive) |
| `delete_file` | Delete a file |
| `delete_directory` | Delete a directory (optionally recursive) |
| `rename_file` | Rename or move a file/directory |
| `copy_file` | Copy a file |
| `get_file_info` | Get file metadata (size, modified time) |

### Scene Operations
| Command | Description |
|---------|-------------|
| `open_scene` | Open a scene in the editor |
| `save_scene` | Save the current scene |
| `save_all_scenes` | Save all open scenes |
| `get_open_scenes` | List currently open scenes |
| `create_scene` | Create a new scene with root node |
| `new_inherited_scene` | Create an inherited scene |
| `duplicate_scene` | Duplicate a scene to a new path |
| `get_scene_dependencies` | Get all resources used by a scene |
| `reload_current_scene` | Reload scene from disk |
| `close_scene` | Close a scene in the editor |

### Node Operations
| Command | Description |
|---------|-------------|
| `get_scene_tree` | Get the scene tree hierarchy |
| `get_node_info` | Get node details |
| `get_node_properties` | Get all node properties |
| `create_node` | Create a new node |
| `delete_node` | Delete a node |
| `set_node_property` | Set a property on a node |
| `rename_node` | Rename a node |
| `move_node` | Move node to new parent |
| `duplicate_node` | Duplicate a node |

### Editor Operations
| Command | Description |
|---------|-------------|
| `get_selected_nodes` | Get currently selected nodes |
| `select_node` | Select a node in the editor |
| `get_editor_state` | Get editor state (selected node, open scene, etc.) |
| `get_editor_settings` | Get editor settings |
| `get_project_settings` | Get project settings |
| `list_resources` | List resources by type |
| `get_open_dialogs` | Detect open modal dialogs |
| `dismiss_dialog` | Close an open dialog |
| `refresh_filesystem` | Refresh the FileSystem dock |
| `reimport_resource` | Force reimport of a resource |
| `get_current_screen` | Get current editor view (2D, 3D, Script, AssetLib) |
| `set_current_screen` | Switch editor view |

### Resource Operations
| Command | Description |
|---------|-------------|
| `load_resource` | Load and get resource info |
| `get_resource_info` | Get detailed resource properties |
| `create_resource` | Create a new resource |
| `save_resource` | Save a resource |
| `duplicate_resource` | Duplicate a resource |
| `set_resource_properties` | Set properties on a resource |
| `list_resource_types` | List all creatable resource types |

### Animation & Audio
| Command | Description |
|---------|-------------|
| `list_animations` | List animations in an AnimationPlayer |
| `play_animation` | Play an animation |
| `stop_animation` | Stop an animation |
| `list_audio_buses` | List audio buses |
| `set_audio_bus_volume` | Set bus volume |
| `set_audio_bus_mute` | Mute/unmute a bus |

### Input Simulation
| Command | Description |
|---------|-------------|
| `simulate_key` | Simulate keyboard input |
| `simulate_mouse_button` | Simulate mouse clicks |
| `simulate_mouse_motion` | Simulate mouse movement |
| `simulate_action` | Simulate input action |
| `get_input_actions` | List defined input actions |

### Testing (GUT)
| Command | Description |
|---------|-------------|
| `gut_check_installed` | Check if GUT is installed |
| `gut_run_all` | Run all tests |
| `gut_run_script` | Run tests in a specific file |
| `gut_run_test` | Run a specific test |
| `gut_get_results` | Get test results |
| `gut_list_tests` | List available tests |
| `gut_create_test` | Create a new test file |

### Debug & Performance
| Command | Description |
|---------|-------------|
| `get_debug_output` | Get captured debug output |
| `clear_debug_log` | Clear debug log |
| `get_debugger_status` | Get debugger plugin status |
| `get_performance_info` | Get FPS, memory, object counts |
| `get_memory_info` | Get memory usage details |
| `print_to_console` | Print to Godot's output |
| `get_recent_errors` | Get recent errors |
| `run_and_capture` | Run a scene and capture all output |
| `wait_for_output` | Wait for specific output patterns |
| `take_screenshot` | Capture a screenshot |

### Plugin Management
| Command | Description |
|---------|-------------|
| `get_plugins` | List editor plugins |
| `enable_plugin` | Enable a plugin |
| `disable_plugin` | Disable a plugin |
| `reload_project` | Reload the project |

---

## VS Code Codot Bridge Extension

The Codot Bridge VS Code extension enables sending prompts directly from Godot's Codot panel to VS Code's AI assistants (GitHub Copilot, Claude, etc.).

### Installing the Extension

1. **From pre-built VSIX**:
   ```bash
   code --install-extension vscode-extension/codot-bridge-0.1.0.vsix
   ```

2. **The extension auto-starts** when VS Code opens (if `codot-bridge.autoStart` is enabled).

### Extension Commands

| Command | Description |
|---------|-------------|
| `Codot: Start Bridge Server` | Start the WebSocket server |
| `Codot: Stop Bridge Server` | Stop the WebSocket server |
| `Codot: Show Bridge Status` | Display connection status |

### Rebuilding the Extension

If you modify the extension source code in `vscode-extension/`, you need to rebuild and reinstall it:

#### Prerequisites

```bash
# Install Node.js dependencies (first time only)
cd vscode-extension
npm install

# Install vsce globally for packaging (first time only)
npm install -g @vscode/vsce
```

#### Compile and Reinstall

```bash
cd vscode-extension

# Compile TypeScript to JavaScript
npm run compile

# Package as VSIX
vsce package

# Install the extension (--force overwrites existing)
code --install-extension codot-bridge-0.1.0.vsix --force
```

#### Reload VS Code

After installing the new extension, you need to reload the VS Code window:
- Press `Ctrl+Shift+P` → "Developer: Reload Window"

> ⚠️ **Warning**: Reloading VS Code will interrupt any in-progress AI chat or automation. Complete your current work before reloading.

#### Quick Rebuild Script (PowerShell)

Create a `rebuild-extension.ps1` script:

```powershell
# Navigate to extension directory
Set-Location -Path "vscode-extension"

# Compile TypeScript
npm run compile

# Package extension
vsce package

# Install extension
code --install-extension codot-bridge-0.1.0.vsix --force

Write-Host "Extension rebuilt and installed. Reload VS Code window to apply changes."
```

### Extension Configuration

The extension supports these settings in VS Code:

| Setting | Default | Description |
|---------|---------|-------------|
| `codot-bridge.autoStart` | `true` | Auto-start server on VS Code launch |
| `codot-bridge.port` | `6851` | WebSocket server port |

### Troubleshooting

**Extension not loading prompts?**
- Check that Godot's Codot plugin is connected (look for WebSocket status in Godot's Output)
- Verify the port settings match between Godot and VS Code
- Check VS Code's Output panel (select "Codot Bridge" from dropdown)

**Prompts not showing in AI chat?**
- Ensure you have an AI extension installed (GitHub Copilot, Copilot Chat, etc.)
- Check that the AI extension is activated and signed in
