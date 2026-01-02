# Codot TODO - Future Improvements

This document tracks potential improvements, optimizations, and new features for the Codot project.

---

## 🏗️ Architecture Improvements

### High Priority

- [ ] **Command Batching** - Allow multiple commands in a single WebSocket message to reduce round-trips
  - Send array of commands, receive array of responses
  - Useful for bulk operations like setting multiple node properties

- [ ] **Connection Persistence** - Handle WebSocket reconnection gracefully
  - Auto-reconnect on disconnect
  - Queue commands during reconnection
  - Expose connection state to MCP clients

- [ ] **Command Timeout Handling** - Add configurable timeouts on the GDScript side
  - Cancel long-running operations
  - Return timeout errors to client
  - Prevent zombie commands

### Medium Priority

- [ ] **Streaming Responses** - For large data (scene trees, file contents)
  - Chunk large responses to avoid memory issues
  - Progress callbacks for long operations

- [ ] **Event Subscription System** - Push notifications instead of polling
  - Subscribe to scene changes, errors, game events
  - WebSocket push messages for real-time updates
  - Reduce need for repeated `get_debug_output` calls

- [ ] **Plugin Hot-Reload** - Reload Codot without restarting Godot
  - Graceful shutdown/restart of WebSocket server
  - Preserve connection state if possible

---

## 🎮 New Commands

### Editor Access

- [ ] **`get_editor_theme`** - Get current editor theme colors
- [ ] **`get_editor_layout`** - Get dock positions, window sizes
- [ ] **`set_editor_layout`** - Programmatically arrange editor panels
- [ ] **`get_undo_redo_history`** - See what can be undone
- [ ] **`undo` / `redo`** - Programmatic undo/redo
- [ ] **`get_recent_files`** - Recently opened files list
- [ ] **`open_script_at_line`** - Open a script and jump to specific line

### Asset Management

- [ ] **`import_asset`** - Import external files (images, audio, 3D models)
- [ ] **`reimport_asset`** - Force reimport of an asset
- [ ] **`get_import_settings`** - Get import configuration for an asset
- [ ] **`set_import_settings`** - Modify import settings
- [ ] **`get_resource_dependencies`** - Find what depends on a resource
- [ ] **`find_broken_references`** - Detect missing/broken resource paths

### Scene Operations

- [ ] **`duplicate_node`** - Clone a node with optional deep copy
- [ ] **`reparent_node`** - Move node to different parent
- [ ] **`instantiate_scene`** - Add scene as child (like Ctrl+Shift+A)
- [ ] **`make_node_local`** - Convert inherited scene node to local
- [ ] **`get_scene_diff`** - Compare scene to saved version
- [ ] **`get_node_script`** - Get script attached to a node
- [ ] **`attach_script`** - Attach a script to a node

### Debugging & Profiling

- [ ] **`set_breakpoint`** - Add/remove script breakpoints
- [ ] **`get_breakpoints`** - List all breakpoints
- [ ] **`get_performance_metrics`** - FPS, memory, draw calls
- [ ] **`get_profiler_data`** - Detailed profiler information
- [ ] **`get_orphan_nodes`** - Find memory leaks
- [ ] **`get_memory_usage`** - Detailed memory breakdown
- [ ] **`pause_game` / `resume_game`** - Pause running game

### Animation

- [ ] **`get_animation_list`** - List animations in AnimationPlayer
- [ ] **`create_animation`** - Create new animation
- [ ] **`add_animation_track`** - Add track to animation
- [ ] **`set_animation_keyframe`** - Insert keyframes
- [ ] **`preview_animation`** - Play animation in editor

### Tilemap Support

- [ ] **`get_tilemap_info`** - Get tilemap configuration
- [ ] **`set_tilemap_cell`** - Place tiles programmatically
- [ ] **`get_tilemap_cells`** - Read tile data
- [ ] **`create_tileset`** - Generate tileset from image

### 2D/3D Specific

- [ ] **`get_camera_transform`** - Get editor camera position/rotation
- [ ] **`set_camera_transform`** - Position editor camera
- [ ] **`screenshot_editor_viewport`** - Capture editor view (not game)
- [ ] **`raycast_from_editor`** - 3D picking in editor viewport

---

## 🔧 Command Improvements

### Existing Command Enhancements

- [ ] **`run_and_capture`** improvements:
  - Add `wait_for_ready` option to wait for specific "ready" signal
  - Add `capture_screenshots` to auto-capture at intervals
  - Return FPS/performance data during run

- [ ] **`get_scene_tree`** improvements:
  - Add depth limiting option
  - Include script paths in output
  - Include visibility state
  - Add search/filter capability

- [ ] **`get_debug_output`** improvements:
  - Add regex pattern matching for messages
  - Add severity level filtering (error > warning > info)
  - Include stack traces when available

- [ ] **`write_file`** improvements:
  - Add `create_backup` option
  - Add `dry_run` to preview changes
  - Support file templates

- [ ] **`gut_run_and_wait`** improvements:
  - Parse GUT's JSON output file for accurate results
  - Support test tags/categories
  - Add coverage reporting

### Error Handling

- [ ] **Structured Error Types** - Consistent error codes across all commands
- [ ] **Validation Layer** - Validate parameters before execution
- [ ] **Suggestions** - Include suggested fixes in error messages

---

## 📡 Debug Capture Improvements

### Output Capture

- [ ] **Automatic Print Capture** - Capture all print() calls without explicit API
  - Hook into Godot's logging system
  - May require engine modification or creative workarounds

- [ ] **Stack Trace Enhancement** - Always include call stack for errors
- [ ] **Source Mapping** - Map error locations to original source
- [ ] **Log Levels** - Support for DEBUG, INFO, WARNING, ERROR, CRITICAL
- [ ] **Log Categories** - Filter by subsystem (physics, rendering, audio)

### Screenshot Capture

- [ ] **Multi-Viewport Support** - Capture from SubViewports
- [ ] **Comparison Screenshots** - Diff against baseline images
- [ ] **Animated GIF Capture** - Record short gameplay clips
- [ ] **Editor Screenshot** - Capture editor UI state

---

## 🧪 Testing Improvements

### GUT Integration

- [ ] **Better Result Parsing** - Read GUT's JSON result file
- [ ] **Test Discovery** - List available tests without running
- [ ] **Test Filtering** - Run by tag, pattern, or category
- [ ] **Parallel Test Execution** - Run independent tests concurrently
- [ ] **Coverage Integration** - Code coverage reporting
- [ ] **Benchmark Support** - Performance regression testing

### Automated Testing

- [ ] **Visual Regression Testing** - Compare screenshots between runs
- [ ] **Input Recording/Playback** - Record and replay user input
- [ ] **Fuzzy Testing** - Random input generation
- [ ] **Integration Test Framework** - Multi-step test scenarios

---

## 🔌 Plugin System

- [ ] **Command Plugins** - Allow third-party command extensions
  - Register custom commands from GDScript
  - Hot-reload command plugins

- [ ] **Event Plugins** - Custom event emitters
- [ ] **Middleware** - Pre/post processing of commands

---

## 📊 Monitoring & Observability

- [ ] **Metrics Export** - Prometheus/OpenTelemetry integration
- [ ] **Command Analytics** - Track command usage patterns
- [ ] **Performance Tracing** - Measure command execution times
- [ ] **Health Endpoint** - HTTP endpoint for monitoring

---

## 🌐 MCP Server Improvements

### Python Side

- [ ] **Connection Pooling** - Reuse WebSocket connections
- [ ] **Request Queuing** - Handle burst of requests gracefully
- [ ] **Caching Layer** - Cache static data (project files, scene structure)
- [ ] **Retry Logic** - Automatic retry with exponential backoff
- [ ] **Rate Limiting** - Prevent overwhelming Godot

### Protocol

- [ ] **Binary Protocol Option** - MessagePack or Protocol Buffers for performance
- [ ] **Compression** - Compress large responses
- [ ] **Authentication** - Optional API key support

---

## 📚 Documentation

- [ ] **API Reference** - Auto-generated from command definitions
- [ ] **Tutorial Series** - Step-by-step guides for common workflows
- [ ] **Video Demos** - Show AI agents building games
- [ ] **Example Projects** - Sample games built with Codot assistance
- [ ] **Troubleshooting Guide** - Common issues and solutions

---

## 🎯 Priority Matrix

| Priority | Effort | Items |
|----------|--------|-------|
| 🔴 High | Low | Command timeout handling, Better error messages |
| 🔴 High | Medium | Event subscription, Connection persistence |
| 🟡 Medium | Low | get_node_script, attach_script, duplicate_node |
| 🟡 Medium | Medium | set_breakpoint, get_profiler_data |
| 🟢 Low | High | Binary protocol, Visual regression testing |

---

## 💡 Ideas for Exploration

These are speculative features that need more research:

- **AI-Native Features**
  - Semantic scene search ("find the player node")
  - Natural language property modification
  - Code generation templates
  - Automatic refactoring suggestions

- **Collaborative Features**
  - Multi-agent coordination
  - Lock/unlock resources
  - Change conflict detection

- **Integration Possibilities**
  - VS Code extension for dual-panel editing
  - GitHub Actions for CI/CD
  - Blender/asset pipeline integration

---

## ✅ Recently Completed

- [x] Async command handling with proper await (2024-01)
- [x] Plugin management commands (enable/disable/list)
- [x] `run_and_capture` - Combined run + output capture
- [x] `wait_for_output` - Wait for specific output patterns
- [x] `ping_game` - Verify game capture is working
- [x] `get_game_state` - Game and debugger state
- [x] `take_screenshot` - Screenshot capture via game autoload
- [x] `gut_run_and_wait` - Run GUT tests with result waiting
- [x] `gut_get_summary` - Parse GUT test results
- [x] Debug capture system (EditorDebuggerPlugin + autoload)

---

*Last updated: January 2026*
