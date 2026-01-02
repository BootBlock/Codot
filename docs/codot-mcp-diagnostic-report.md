# Codot MCP Server Diagnostic Report

**Date:** January 2, 2026  
**Godot Version:** 4.6-beta2 (official)  
**Codot Plugin Version:** 0.1.0  
**Project:** Unsung Saviour

## Executive Summary

The Codot MCP integration is **partially working**. Editor-level commands function correctly, but **input simulation does not affect the running game**. The root cause appears to be that input events are being queued and parsed via `Input.parse_input_event()`, but this may not work when called from an `@tool` script running in the editor context while the game is running in a separate process.

---

## Test Results

### ✅ Working Features

| Feature | Status | Evidence |
|---------|--------|----------|
| Ping Godot | ✅ Pass | `pong: true` |
| Connection Status | ✅ Pass | Connected to `127.0.0.1:6850` |
| Get Editor State | ✅ Pass | Returns open scenes, selected nodes |
| Open Scene | ✅ Pass | Successfully opened `res://game/world.tscn` |
| Play/Stop Game | ✅ Pass | `playing: true`, `stopped: true` |
| Get Performance Info | ✅ Pass | Returns FPS (10), memory (~593MB), node count (23,678) |
| Print to Console | ✅ Pass | Message appears in Godot output |
| Get Input Actions | ✅ Pass | Returns 88 actions (mostly UI builtins) |
| Run and Capture | ✅ Pass | Ran for 20 seconds, 0 errors |

### ❌ Non-Working Features

| Feature | Status | Evidence |
|---------|--------|----------|
| Simulate Key Press | ❌ Fail | F3 key simulated but no visual response in game |
| Simulate Mouse Click | ❌ Fail | Clicks simulated but no party member selected |
| Simulate Action | ❌ Fail | `target_party_3` action returns "Action not found" |
| Ping Game | ❌ Fail | `pong: false, timeout: true` |
| Game Capture Active | ❌ Fail | `game_capture_active: false` |
| Take Screenshot | ❌ Fail | `exists: false` after screenshot request |

---

## Root Cause Analysis

### Issue 1: Input Events Not Reaching Game Process

**Location:** `addons/codot/input_simulator.gd`

```gdscript
func _flush_pending_inputs() -> void:
    for event in _pending_inputs:
        Input.parse_input_event(event)  # <-- THIS IS THE PROBLEM
    _pending_inputs.clear()
```

**Problem:** The `Input.parse_input_event()` call happens in the **editor process**, not the **game process**. When you press F5 to run a game in Godot, it spawns a **separate process**. The editor and game do not share the same `Input` singleton.

**Evidence:**
- `simulate_key` returns `simulated: true` (editor thinks it worked)
- Game shows no response to input
- `ping_game` times out (game capture not responding)

### Issue 2: Game Capture System Not Active

**Status Field:** `game_capture_active: false`

This suggests that the `CodotGame` autoload (game_connector.gd) is either:
1. Not registered as an autoload in the project
2. Not properly connecting back to the Codot WebSocket server
3. Failing silently during initialization

### Issue 3: Input Actions Not Registered

When calling `get_input_actions(include_builtins=false)`, only 16 editor-related actions are returned. The game-specific actions (`target_party_1` through `target_party_5`) are **not visible**.

**Possible causes:**
1. Actions are defined in `project.godot` but not loaded when querying from editor
2. Actions are added dynamically at runtime (not in InputMap)
3. MCP server is querying InputMap before the game project's settings are fully loaded

---

## Diagnostic Data

### Debugger Status
```json
{
  "debugger_plugin_available": true,
  "game_capture_active": false,
  "is_playing": true,
  "message_types_seen": {},
  "session_count": 1,
  "total_entries": 1
}
```

### Performance Info (Game Running)
```json
{
  "fps": 10.0,
  "memory_static": 621945297.0,
  "object_count": 94158.0,
  "object_node_count": 23655.0,
  "render_total_draw_calls": 438.0
}
```

### Input Simulator Architecture
```
┌─────────────────────────────────────────────────────────┐
│                   EDITOR PROCESS                        │
│  ┌─────────────────────────────────────────────────┐    │
│  │ Codot Plugin (@tool)                            │    │
│  │  ├─ WebSocket Server (port 6850)                │    │
│  │  ├─ Command Handler                             │    │
│  │  └─ Input Simulator                             │    │
│  │       └─ Input.parse_input_event() ← HERE       │    │
│  └─────────────────────────────────────────────────┘    │
│                         ⬇ Events parsed here            │
│                         ✗ But game is a separate process│
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   GAME PROCESS                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │ CodotGame Autoload (if registered)              │    │
│  │  └─ Should connect to WebSocket                 │    │
│  │  └─ Should receive input commands               │ ❌  │
│  │  └─ Should call Input.parse_input_event()       │    │
│  └─────────────────────────────────────────────────┘    │
│                         ⬇ Events would be parsed here   │
│                         ✓ Game would respond            │
└─────────────────────────────────────────────────────────┘
```

---

## Recommendations

### 1. Verify CodotGame Autoload Registration

Check `project.godot` for:
```ini
[autoload]
CodotGame="*res://addons/codot/game_connector.gd"
```

If missing, add it in Project Settings → Autoload.

### 2. Implement Game-Side Input Handling

The input simulator should send input commands **to the game process** via WebSocket, not parse them in the editor. The `game_connector.gd` autoload should:

1. Connect to the Codot WebSocket server when the game starts
2. Listen for input simulation commands
3. Call `Input.parse_input_event()` from **within the game process**

### 3. Add Bidirectional Communication

Current architecture:
```
MCP Client → Python Bridge → Editor WebSocket
```

Required architecture:
```
MCP Client → Python Bridge → Editor WebSocket
                                    ↓
                              Game WebSocket ← CodotGame autoload
```

### 4. Debug Game Connector

Add logging to `game_connector.gd`:
```gdscript
func _ready() -> void:
    print("[CodotGame] Autoload initializing...")
    # Connection logic
    print("[CodotGame] Connected: ", is_connected)
```

Check Godot's Output panel when running the game.

---

## Files to Investigate

| File | Purpose | Issue |
|------|---------|-------|
| `addons/codot/game_connector.gd` | Game-side WebSocket client | Not connecting or not registered |
| `addons/codot/input_simulator.gd` | Input event generation | Parsing in wrong process |
| `addons/codot/commands/commands_input.gd` | Input command handlers | May need to route to game |
| `project.godot` | Autoload configuration | Verify CodotGame is registered |

---

## Test Commands for Debugging

```python
# Check if game connector is working
ping_game(timeout=5)

# Check game state
get_game_state()

# Verify debugger capture
get_debugger_status()
```

---

## Conclusion

The Codot MCP server successfully controls the **Godot editor** but cannot inject input into the **running game**. This is an architectural issue where input events are parsed in the editor process instead of being forwarded to the game process. The `CodotGame` autoload either isn't registered or isn't properly bridging communication to the game.
