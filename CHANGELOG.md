# Changelog

All notable changes to Codot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-01-02

### Added

#### Godot Plugin (`addons/codot/`)
- WebSocket server on port 6850 for MCP communication
- 64+ commands for AI agent control of Godot
- **Scene Operations**: Create, open, save, modify scenes
- **Node Operations**: Create, delete, reparent, modify node properties
- **Game Control**: Play, stop, play current scene, play custom scene
- **Debug Capture**: Capture errors, warnings, and print statements from running games
- **File Operations**: Read/write files, list project files
- **Script Operations**: Open scripts, check for errors
- **Input Simulation**: Simulate keyboard, mouse, controller input
- **GUT Integration**: Run tests, get results, wait for completion
- **Animation Control**: Play/stop animations, get animation info
- **Audio Control**: Play sounds, manage audio buses
- **Signal Operations**: List signals, emit signals, connect signals
- **Group Operations**: Add/remove nodes from groups
- **Resource Operations**: Load, save, duplicate resources
- AI Chat Dock for sending prompts to VS Code (port 6851)
- Editor debugger plugin for capturing game output
- Robust error handling with structured error codes

#### MCP Server (`mcp-server/`)
- Python MCP server bridging AI agents to Godot
- Full MCP protocol implementation via `mcp` library
- WebSocket client for Godot communication
- Command definitions with JSON Schema validation
- Async architecture for responsive communication

#### VS Code Extension (`vscode-extension/`)
- Codot Bridge extension for receiving AI prompts from Godot
- WebSocket server on port 6851
- Forwards prompts to VS Code Copilot Chat
- Status bar indicator for connection state

#### Documentation
- Comprehensive README with quick start guide
- AGENTS.md with AI agent instructions
- Detailed how-to-use guide

### Technical Details
- Godot 4.3+ required (tested with 4.6-beta)
- Python 3.10+ required
- MIT License

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 0.1.0 | 2026-01-02 | Initial release with 64+ MCP tools |
