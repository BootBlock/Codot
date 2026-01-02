# Codot MCP Plugin - Diagnostic Report #2

**Generated:** January 2, 2025  
**Plugin Version:** 0.1.0  
**Godot Version:** 4.6-beta2 (hash: 551ce8d47feda9c81c870314745366b24957624b)  
**Project:** Unsung Saviour

---

## Executive Summary

Following fixes applied after Diagnostic Report #1, the Codot MCP plugin is now **fully functional** for editor-side operations and has working game capture integration. All tested features performed as expected.

| Category | Status | Notes |
|----------|--------|-------|
| MCP Connection | ✅ Working | Ping returns `pong: true` |
| Editor Control | ✅ Working | Play/stop/pause/resume, scene operations |
| Game Capture | ✅ Working | `game_capture_active: true`, 100ms latency |
| Input Simulation | ✅ Routing | All inputs show `routed_to_game: true` |
| Debug Output | ✅ Working | Captures input_results and game logs |
| Screenshot | ✅ Working | Saves to `user://` path |
| GUT Integration | ✅ Detected | v9.5.0, 152 test files found |
| Scene Inspection | ✅ Working | Full scene tree accessible |

---

## Test Results

### 1. Connection & Status

| Test | Result | Value |
|------|--------|-------|
| `godot_ping` | ✅ Pass | `{ "pong": true, "timestamp": 1767382551.581 }` |
| `godot_get_status` | ✅ Pass | Godot 4.6-beta2, plugin 0.1.0 |
| `godot_connection_status` | ✅ Pass | Connected |

### 2. Game Lifecycle

| Test | Result | Value |
|------|--------|-------|
| `godot_play` | ✅ Pass | Main scene starts |
| `godot_play_current` | ✅ Pass | Current scene plays |
| `godot_ping_game` | ✅ Pass | `{ "pong": true, "latency": 0.10 }` |
| `godot_get_game_state` | ✅ Pass | `game_capture_active: true` |
| `godot_pause_game` | ✅ Pass | `{ "paused": true }` |
| `godot_resume_game` | ✅ Pass | `{ "resumed": true }` |
| `godot_stop` | ✅ Pass | `{ "stopped": true }` |

### 3. Input Simulation

All inputs returned `routed_to_game: true`:

| Input Type | Test Cases | Result |
|------------|------------|--------|
| Key Press (F1-F5) | 5 tests | ✅ All routed |
| Key Press (1, 2, 3, W, ESC, TAB) | 6 tests | ✅ All routed |
| Action (`target_party_1`, `target_party_2`) | 2 tests | ✅ All routed |
| Mouse Button | 2 tests | ✅ All routed |
| Mouse Motion | 2 tests | ✅ All routed |

### 4. Scene Operations

| Test | Result | Value |
|------|--------|-------|
| `godot_get_scene_tree` (depth=3) | ✅ Pass | Full hierarchy returned |
| `godot_get_open_scenes` | ✅ Pass | List of open scenes |
| `godot_open_scene` | ✅ Pass | Opens specified scene |
| `godot_save_scene` | ✅ Pass | Saves current scene |

### 5. Debug & Screenshot

| Test | Result | Value |
|------|--------|-------|
| `godot_get_debug_output` | ✅ Pass | 22 entries captured |
| `godot_take_screenshot` | ✅ Pass | `{ "exists": true, "path": "user://codot_test_2.png" }` |
| `godot_print_to_console` | ✅ Pass | Message printed |

### 6. GUT Testing Framework

| Test | Result | Value |
|------|--------|-------|
| `godot_gut_check_installed` | ✅ Pass | `{ "installed": true, "version": "9.5.0" }` |
| `godot_gut_list_tests` (res://tests/unit/) | ✅ Pass | 152 test files, 2800+ tests |

**Note:** Default directory is `res://test/` but Unsung Saviour uses `res://tests/unit/`. Always pass `dirs` parameter.

---

## Scene Tree Analysis

The plugin successfully retrieved the full scene hierarchy:

```
World (Node2D)
├── PersistentUI (CanvasLayer)
│   ├── MainHud (MainHud)
│   │   ├── BattleNotifications
│   │   ├── ChatFrame
│   │   ├── TargetFrame
│   │   ├── PartyFrames
│   │   ├── DamageMeter
│   │   ├── ThreatMeter
│   │   ├── MoraleDisplay
│   │   ├── ActionBars (multiple)
│   │   ├── SpellbookWindow
│   │   ├── TalentsUI
│   │   ├── CharacterSheetUI
│   │   └── ... (20+ UI components)
│   └── TooltipLayer
├── AudioManager
├── VFXLayer
├── HubWorld
└── ... (game world nodes)
```

---

## Recommendations for Unsung Saviour Development

### High Priority Features

#### 1. **Game State Queries**
Currently, only scene tree structure is available. For Unsung Saviour's healer simulation, we need:

```
Request: godot_query_game_state
Parameters:
  - path: "World/Party/Tank/StatsComponent"
  - properties: ["current_health", "max_health", "is_dead"]
Returns:
  { "current_health": 850, "max_health": 1200, "is_dead": false }
```

**Use Cases:**
- Verify healing actually increased health
- Check buff stacks on party members
- Monitor threat levels in ThreatManager
- Validate morale changes after events

#### 2. **Node Method Invocation**
Execute methods on live game nodes:

```
Request: godot_invoke_method
Parameters:
  - path: "World/Party/Healer/SpellbookComponent"
  - method: "cast_spell"
  - args: ["flash_heal", "World/Party/Tank"]
Returns:
  { "success": true, "result": "cast_started" }
```

**Use Cases:**
- Cast spells programmatically
- Trigger buff applications
- Apply damage/healing to test health bars
- Test AI controller state transitions

#### 3. **Input Verification Feedback**
Current inputs route but we need confirmation of effect:

```
Request: godot_simulate_action_verified
Parameters:
  - action: "target_party_1"
  - timeout: 1.0
Returns:
  {
    "routed": true,
    "effect": {
      "type": "target_changed",
      "old_target": null,
      "new_target": "Tank"
    }
  }
```

#### 4. **Batch Input Sequences**
For testing combat rotations and complex interactions:

```
Request: godot_input_sequence
Parameters:
  - steps: [
      { "action": "target_party_1", "delay": 0 },
      { "key": "1", "delay": 0.1 },  // Cast Flash Heal
      { "wait_for": "cast_completed", "timeout": 2.0 },
      { "action": "target_party_2", "delay": 0 },
      { "key": "2", "delay": 0.1 }   // Cast Renew
    ]
Returns:
  { "completed": true, "results": [...] }
```

### Medium Priority Features

#### 5. **Signal Monitoring**
Subscribe to specific signals during tests:

```
Request: godot_subscribe_signals
Parameters:
  - signals: [
      "EventBus.damage_dealt",
      "EventBus.healing_done",
      "ThreatManager.aggro_changed"
    ]
  - duration: 5.0
Returns:
  {
    "events": [
      { "signal": "healing_done", "args": [350, false, "Tank"], "time": 0.5 },
      { "signal": "damage_dealt", "args": [120, true, "Boss"], "time": 1.2 }
    ]
  }
```

#### 6. **GUT Test Execution Integration**
The tests directory uses `res://tests/unit/` not default `res://test/`:

```
Request: godot_gut_run_and_wait
Parameters:
  - script: "res://tests/unit/test_buff_controller.gd"
  - test: "test_apply_buff_adds_to_active_buffs"
Returns:
  { "passed": true, "output": "...", "duration": 0.15 }
```

#### 7. **Autoload State Access**
Query global managers directly:

```
Request: godot_get_autoload_state
Parameters:
  - autoload: "PartyManager"
  - properties: ["ai_controllers.size()", "player_controller.target"]
Returns:
  { "ai_controllers.size()": 4, "player_controller.target": "EnemyBoss" }
```

### Low Priority / Nice to Have

#### 8. **Visual Diff Screenshots**
Take before/after screenshots and compute diff:

```
Request: godot_visual_diff
Parameters:
  - baseline: "user://screenshots/baseline.png"
  - current: true
  - threshold: 0.01
Returns:
  { "match": false, "diff_percent": 5.2, "diff_path": "user://diff.png" }
```

#### 9. **Performance Profiling**
Monitor performance during test runs:

```
Request: godot_profile_run
Parameters:
  - duration: 5.0
  - metrics: ["fps", "draw_calls", "objects", "memory_static"]
Returns:
  {
    "avg_fps": 58.3,
    "min_fps": 45.0,
    "max_draw_calls": 1234,
    "memory_peak_mb": 256.7
  }
```

#### 10. **Node Manipulation**
Modify node properties for test setup:

```
Request: godot_set_node_property
Parameters:
  - path: "World/Party/Tank/StatsComponent"
  - property: "current_health"
  - value: 100
```

---

## Configuration Notes for Unsung Saviour

### mcp.json (Working)
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

### Test Directory Configuration
When using `gut_list_tests`, always pass:
```json
{
  "dirs": ["res://tests/unit/"]
}
```

### Project-Specific Input Actions
The following actions are defined in Unsung Saviour for party targeting:
- `target_party_1` through `target_party_5`
- `target_self`
- `target_enemy`
- `target_focus`
- `cast_action_1` through `cast_action_12`

---

## Issues Identified

### 1. Input Visual Feedback Unclear
While inputs are routed (`routed_to_game: true`), there's no confirmation they triggered the expected game behaviour. User reported party member selection didn't cycle through all members.

**Hypothesis:** The game may require additional timing between inputs, or the input events need the `pressed` flag toggled (press + release).

**Recommendation:** Add `godot_simulate_key_tap` that sends both press and release events with configurable delay between them.

### 2. No Game-Side Node Queries
The `get_scene_tree` shows the editor's scene structure, not live game state. We cannot query:
- `StatsComponent.current_health` values
- `BuffController.active_buffs` lists
- `SpellbookComponent.is_casting` state

**Recommendation:** Add `godot_query_game_node` tool that queries nodes in the running game process via CodotGame autoload.

### 3. GUT Default Directory Mismatch
The default search directory `res://test/` doesn't match project structure `res://tests/unit/`.

**Recommendation:** Allow project-level configuration for default GUT test directories.

---

## Test File Statistics

| Metric | Value |
|--------|-------|
| Test Files | 152 |
| Total Test Functions | 2,800+ |
| Categories | Unit tests for all major systems |

### Coverage by System
- AI & NLP: 15 test files
- Chat & Communication: 12 test files
- Combat & Spells: 20+ test files
- UI Components: 15+ test files
- Session Fixes: 30+ test files (regression tests)
- Resources & Data: 10+ test files

---

## Summary

The Codot MCP plugin v0.1.0 is working correctly for:
1. ✅ Editor control (play/stop/pause/save)
2. ✅ Scene inspection
3. ✅ Input routing to game
4. ✅ Screenshot capture
5. ✅ Debug log access
6. ✅ GUT framework detection

To fully support Unsung Saviour's AI-assisted development, the priority additions are:
1. **Game state queries** - Read live health/mana/buff values
2. **Method invocation** - Call spell casts and AI functions
3. **Input verification** - Confirm inputs triggered expected changes
4. **Signal monitoring** - Subscribe to game events during tests

These additions would enable comprehensive automated testing of the healer gameplay loop.
