# Codot Bridge - VS Code Extension

This VS Code extension creates a bridge between Godot's Codot plugin and VS Code's AI assistants (GitHub Copilot, Claude, etc.).

## Features

- WebSocket server that receives prompts from Godot
- Automatically forwards prompts to the active AI chat
- Status bar indicator showing connection status
- Context-aware prompts (includes current scene, selected nodes)

## Installation

### From Source

1. Navigate to the extension directory:
   ```bash
   cd vscode-extension
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Compile TypeScript:
   ```bash
   npm run compile
   ```

4. Install the extension in VS Code:
   - Open VS Code
   - Press `F5` to run in debug mode, or
   - Run `code --install-extension codot-bridge-0.1.0.vsix` after packaging

### Package as VSIX

```bash
npm install -g @vscode/vsce
vsce package
```

## Usage

1. The extension starts automatically when VS Code opens
2. In Godot, open the "AI Chat" dock panel (usually in the right dock)
3. Type your prompt and click "Send to AI"
4. The prompt will appear in VS Code's Copilot Chat

## Commands

- `Codot: Start Bridge Server` - Start the WebSocket server
- `Codot: Stop Bridge Server` - Stop the WebSocket server  
- `Codot: Show Bridge Status` - Show current server status

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `codot-bridge.port` | `6851` | WebSocket server port |
| `codot-bridge.autoStart` | `true` | Auto-start server on VS Code launch |

## How It Works

```
┌─────────────────┐     WebSocket      ┌─────────────────┐     Copilot API    ┌─────────────────┐
│  Godot Editor   │ ──────────────────► │  Codot Bridge   │ ──────────────────► │  AI Assistant   │
│  (AI Chat Dock) │     port 6851       │  (VS Code Ext)  │                     │  (Copilot/etc)  │
└─────────────────┘                     └─────────────────┘                     └─────────────────┘
```

## Requirements

- VS Code 1.85.0 or higher
- GitHub Copilot Chat extension (recommended)
- Node.js 18+ (for development)
