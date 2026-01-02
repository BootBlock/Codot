# Contributing to Codot

Thank you for your interest in contributing to Codot! This document provides guidelines and instructions for contributing.

## 🌟 Ways to Contribute

- **Bug Reports**: Found a bug? Open an issue with reproduction steps
- **Feature Requests**: Have an idea? Open an issue to discuss
- **Code Contributions**: Submit pull requests for fixes or features
- **Documentation**: Improve docs, fix typos, add examples
- **Testing**: Add tests, report edge cases

## 🚀 Getting Started

### Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/codot.git
   cd codot
   ```

2. **Open in Godot**
   - Open `project.godot` in Godot 4.3+
   - Enable the Codot plugin in Project Settings

3. **Install Python dependencies**
   ```bash
   cd mcp-server
   pip install -e ".[dev]"
   ```

4. **Install VS Code extension dependencies** (optional)
   ```bash
   cd vscode-extension
   npm install
   ```

## 📁 Project Structure

```
codot/
├── addons/codot/           # Godot plugin (GDScript) - SOURCE OF TRUTH
│   ├── plugin.cfg          # Plugin metadata
│   ├── codot.gd            # Main EditorPlugin
│   ├── command_handler.gd  # Command implementations
│   ├── websocket_server.gd # WebSocket server
│   └── ...
├── mcp-server/             # Python MCP server
│   ├── codot/              # Python package
│   │   ├── server.py       # MCP server entry
│   │   ├── commands.py     # Command definitions
│   │   └── godot_client.py # WebSocket client
│   └── tests/              # Python tests
├── vscode-extension/       # VS Code extension (TypeScript)
├── test/                   # GUT tests for Godot
└── docs/                   # Documentation
```

## 📝 Code Style

### GDScript (Godot Plugin)

```gdscript
## Brief description of the function.
## [br][br]
## [param params]: Description of parameters.
## - 'key' (Type, required/optional): Description.
func _cmd_example(cmd_id: Variant, params: Dictionary) -> Dictionary:
    # Use static typing
    var value: String = params.get("key", "default")
    
    # Return structured responses
    if some_error:
        return _error(cmd_id, "ERROR_CODE", "Human readable message")
    return _success(cmd_id, {"result": value})
```

**Guidelines:**
- Use `##` docstrings above functions
- Always use static typing (`var x: int = 0`)
- Use `snake_case` for functions/variables
- Use `PascalCase` for classes
- Return `_success()` or `_error()` from command handlers

### Python (MCP Server)

```python
async def method_name(self, param: str) -> dict[str, Any]:
    """
    Brief description.
    
    Args:
        param: Description of parameter.
        
    Returns:
        Description of return value.
    """
    pass
```

**Guidelines:**
- Use Google-style docstrings
- Use Python 3.10+ type hints
- Use `async/await` for I/O operations
- Use `logger` instead of `print()`
- Format with `black`

### TypeScript (VS Code Extension)

- Use TypeScript strict mode
- Follow VS Code extension guidelines
- Use `async/await` for promises

## 🔧 Adding New Commands

To add a new MCP command:

### 1. Implement in GDScript (`addons/codot/command_handler.gd`)

```gdscript
# Add to handle_command() match statement:
"your_command":
    return _cmd_your_command(cmd_id, params)

# Implement the function:
## Description of what this command does.
func _cmd_your_command(cmd_id: Variant, params: Dictionary) -> Dictionary:
    var required_param: String = params.get("param", "")
    if required_param.is_empty():
        return _error(cmd_id, "MISSING_PARAM", "Missing 'param' parameter")
    
    # Do something
    return _success(cmd_id, {"result": "value"})
```

### 2. Define in Python (`mcp-server/codot/commands.py`)

```python
"your_command": CommandDefinition(
    description="Description shown to AI agents",
    input_schema={
        "type": "object",
        "properties": {
            "param": {
                "type": "string",
                "description": "Description of this parameter",
            },
        },
        "required": ["param"],
    },
),
```

### 3. Test your command

```bash
# Python test
cd mcp-server
python -c "
import asyncio
from codot.godot_client import GodotClient

async def test():
    client = GodotClient()
    await client.connect()
    result = await client.send_command('your_command', {'param': 'value'})
    print(result)
    await client.disconnect()

asyncio.run(test())
"
```

## 🧪 Testing

### Run GUT Tests (Godot)

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/ -gexit
```

Or use MCP:
```
godot_gut_run_all
```

### Run Python Tests

```bash
cd mcp-server
pytest -v
```

### Manual Testing

1. Open Godot with the project
2. Run the Python test scripts in `mcp-server/`
3. Verify commands work as expected

## 🔀 Pull Request Process

1. **Fork** the repository
2. **Create a branch** for your feature: `git checkout -b feature/your-feature`
3. **Make your changes** following the code style guidelines
4. **Add tests** for new functionality
5. **Update documentation** if needed (especially AGENTS.md for new commands)
6. **Test thoroughly** - both GUT tests and Python tests
7. **Commit** with clear messages: `git commit -m "Add feature: description"`
8. **Push** to your fork: `git push origin feature/your-feature`
9. **Open a Pull Request** with a clear description

### PR Checklist

- [ ] Code follows project style guidelines
- [ ] New commands are documented in AGENTS.md
- [ ] Tests pass (GUT and pytest)
- [ ] No GDScript warnings in editor
- [ ] Documentation updated if needed

## ❌ Common Error Codes

When implementing commands, use these standard error codes:

| Code | When to Use |
|------|-------------|
| `NO_EDITOR` | EditorInterface not available |
| `NO_SCENE` | No scene currently open |
| `MISSING_PARAM` | Required parameter missing |
| `NODE_NOT_FOUND` | Node path doesn't exist |
| `INVALID_TYPE` | Invalid node/resource type |
| `FILE_NOT_FOUND` | File doesn't exist |
| `INVALID_PATH` | Path format is invalid |
| `SCRIPT_ERROR` | Script has errors |
| `SAVE_FAILED` | Failed to save file/scene |

## 📜 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## ❓ Questions?

- Open an issue for questions
- Check existing issues and discussions
- Read [AGENTS.md](AGENTS.md) for AI agent documentation
