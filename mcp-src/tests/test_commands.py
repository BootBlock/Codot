"""
Unit tests for the Codot server.

These tests verify the MCP server functionality without requiring
a running Godot instance.
"""

import pytest
from codot.commands import COMMANDS, CommandDefinition


class TestCommandDefinitions:
    """Tests for command definitions."""

    def test_all_commands_have_descriptions(self):
        """Every command should have a non-empty description."""
        for name, cmd in COMMANDS.items():
            assert cmd.description, f"Command '{name}' has no description"
            assert len(cmd.description) > 10, f"Command '{name}' description is too short"

    def test_all_commands_have_input_schema(self):
        """Every command should have an input schema."""
        for name, cmd in COMMANDS.items():
            assert isinstance(cmd.input_schema, dict), \
                f"Command '{name}' input_schema should be a dict"
            assert "type" in cmd.input_schema, \
                f"Command '{name}' input_schema should have 'type'"
            assert cmd.input_schema["type"] == "object", \
                f"Command '{name}' input_schema type should be 'object'"

    def test_required_params_are_in_properties(self):
        """Required parameters should be defined in properties."""
        for name, cmd in COMMANDS.items():
            required = cmd.input_schema.get("required", [])
            properties = cmd.input_schema.get("properties", {})
            
            for param in required:
                assert param in properties, \
                    f"Command '{name}' requires '{param}' but it's not in properties"

    def test_ping_command_exists(self):
        """Ping command should be defined."""
        assert "ping" in COMMANDS
        assert "pong" in COMMANDS["ping"].description.lower() or \
               "ping" in COMMANDS["ping"].description.lower()

    def test_get_status_command_exists(self):
        """Get status command should be defined."""
        assert "get_status" in COMMANDS

    def test_play_commands_exist(self):
        """Game control commands should be defined."""
        assert "play" in COMMANDS
        assert "stop" in COMMANDS
        assert "play_current" in COMMANDS
        assert "play_custom_scene" in COMMANDS

    def test_scene_tree_commands_exist(self):
        """Scene tree inspection commands should be defined."""
        assert "get_scene_tree" in COMMANDS
        assert "get_node_info" in COMMANDS
        assert "get_node_properties" in COMMANDS

    def test_file_commands_exist(self):
        """File operation commands should be defined."""
        assert "read_file" in COMMANDS
        assert "write_file" in COMMANDS
        assert "file_exists" in COMMANDS

    def test_node_manipulation_commands_exist(self):
        """Node manipulation commands should be defined."""
        assert "create_node" in COMMANDS
        assert "delete_node" in COMMANDS
        assert "set_node_property" in COMMANDS
        assert "rename_node" in COMMANDS
        assert "duplicate_node" in COMMANDS

    def test_gut_commands_exist(self):
        """GUT testing commands should be defined."""
        assert "gut_check_installed" in COMMANDS
        assert "gut_run_all" in COMMANDS
        assert "gut_run_script" in COMMANDS
        assert "gut_get_results" in COMMANDS
        assert "gut_list_tests" in COMMANDS
        assert "gut_create_test" in COMMANDS

    def test_input_simulation_commands_exist(self):
        """Input simulation commands should be defined."""
        assert "simulate_key" in COMMANDS
        assert "simulate_mouse_button" in COMMANDS
        assert "simulate_action" in COMMANDS
        assert "get_input_actions" in COMMANDS

    def test_audio_commands_exist(self):
        """Audio control commands should be defined."""
        assert "list_audio_buses" in COMMANDS
        assert "set_audio_bus_volume" in COMMANDS
        assert "set_audio_bus_mute" in COMMANDS

    def test_performance_commands_exist(self):
        """Performance monitoring commands should be defined."""
        assert "get_performance_info" in COMMANDS
        assert "get_memory_info" in COMMANDS


class TestCommandDefinitionDataclass:
    """Tests for the CommandDefinition dataclass."""

    def test_command_definition_with_defaults(self):
        """CommandDefinition should work with minimal args."""
        cmd = CommandDefinition(description="Test command")
        assert cmd.description == "Test command"
        assert cmd.input_schema == {}
        assert cmd.godot_command == ""

    def test_command_definition_with_all_fields(self):
        """CommandDefinition should accept all fields."""
        cmd = CommandDefinition(
            description="Test command",
            input_schema={"type": "object", "properties": {}},
            godot_command="custom_cmd",
        )
        assert cmd.description == "Test command"
        assert cmd.input_schema["type"] == "object"
        assert cmd.godot_command == "custom_cmd"


class TestCommandCount:
    """Tests for command coverage."""

    def test_minimum_command_count(self):
        """Should have a reasonable number of commands."""
        # We expect at least 50 commands based on implementation
        assert len(COMMANDS) >= 50, \
            f"Expected at least 50 commands, got {len(COMMANDS)}"

    def test_command_categories_covered(self):
        """All major command categories should have commands."""
        categories = {
            "status": ["ping", "get_status"],
            "game_control": ["play", "stop", "is_playing"],
            "scene_tree": ["get_scene_tree", "get_node_info"],
            "files": ["read_file", "write_file", "file_exists"],
            "nodes": ["create_node", "delete_node"],
            "testing": ["gut_run_all", "gut_list_tests"],
            "input": ["simulate_key", "simulate_action"],
            "audio": ["list_audio_buses"],
            "debug": ["get_performance_info"],
        }
        
        for category, expected_cmds in categories.items():
            for cmd in expected_cmds:
                assert cmd in COMMANDS, \
                    f"Category '{category}' missing command '{cmd}'"
