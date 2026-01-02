"""
MCP Server for Codot.

This module implements the Model Context Protocol (MCP) server that exposes
Godot control functionality as tools that can be used by AI agents.

The server provides:
- Connection management (connect/disconnect to Godot)
- 60+ tools for scene manipulation, file operations, testing, and more
- Automatic command routing to the Godot plugin via WebSocket

Example usage:
    # Run via MCP config in VS Code
    # Or directly:
    python -m codot.server

Environment variables:
    CODOT_HOST: WebSocket host (default: 127.0.0.1)
    CODOT_PORT: WebSocket port (default: 6850)
"""

import asyncio
import json
import logging
import os
import sys
from typing import Any

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

from .godot_client import GodotClient
from .commands import COMMANDS, CommandDefinition, DISABLED_COMMANDS

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("codot")

# Default configuration
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 6850

# Environment variable to enable ALL tools (ignores DISABLED_COMMANDS)
# Set CODOT_ENABLE_ALL_TOOLS=1 to expose all 160+ commands
ENABLE_ALL_TOOLS = os.environ.get("CODOT_ENABLE_ALL_TOOLS", "").lower() in ("1", "true", "yes")


class CodotServer:
    """
    MCP Server for Godot integration.
    
    This server implements the Model Context Protocol and exposes Godot
    control functionality as tools. It maintains a WebSocket connection
    to the Codot plugin running inside the Godot editor.
    
    Attributes:
        host: WebSocket server host address.
        port: WebSocket server port.
        server: MCP Server instance.
        godot_client: WebSocket client for Godot communication.
    """

    def __init__(self, host: str = DEFAULT_HOST, port: int = DEFAULT_PORT) -> None:
        """
        Initialize the MCP server.
        
        Args:
            host: WebSocket host to connect to (default: 127.0.0.1).
            port: WebSocket port to connect to (default: 6850).
        """
        self.host = host
        self.port = port
        self.server = Server("codot")
        self.godot_client = GodotClient(host, port)
        self._setup_handlers()

    def _setup_handlers(self) -> None:
        """
        Set up MCP tool handlers.
        
        Registers handlers for listing available tools and processing
        tool calls. Tools are dynamically generated from COMMANDS dict.
        """

        @self.server.list_tools()
        async def list_tools() -> list[Tool]:
            """
            Return list of available tools.
            
            Includes connection management tools and all Godot command tools
            defined in the COMMANDS dictionary.
            
            Returns:
                List of MCP Tool definitions.
            """
            tools = []
            
            # Add connection status tool
            tools.append(Tool(
                name="godot_connection_status",
                description="Check if connected to Godot and get connection status",
                inputSchema={
                    "type": "object",
                    "properties": {},
                    "required": [],
                },
            ))
            
            # Add connect tool
            tools.append(Tool(
                name="godot_connect",
                description="Connect to the Godot editor. Must be called before using other Godot tools.",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "host": {
                            "type": "string",
                            "description": "Godot WebSocket host (default: 127.0.0.1)",
                            "default": DEFAULT_HOST,
                        },
                        "port": {
                            "type": "integer",
                            "description": "Godot WebSocket port (default: 6850)",
                            "default": DEFAULT_PORT,
                        },
                    },
                    "required": [],
                },
            ))
            
            # Add disconnect tool
            tools.append(Tool(
                name="godot_disconnect",
                description="Disconnect from the Godot editor",
                inputSchema={
                    "type": "object",
                    "properties": {},
                    "required": [],
                },
            ))
            
            # Add all command-based tools (skip disabled ones unless CODOT_ENABLE_ALL_TOOLS is set)
            for cmd_name, cmd_def in COMMANDS.items():
                # Skip commands that are explicitly disabled (unless override is set)
                if not ENABLE_ALL_TOOLS and cmd_name in DISABLED_COMMANDS:
                    continue
                # Also check the enabled flag on the command itself
                if not cmd_def.enabled:
                    continue
                    
                tools.append(Tool(
                    name=f"godot_{cmd_name}",
                    description=cmd_def.description,
                    inputSchema=cmd_def.input_schema,
                ))
            
            return tools

        @self.server.call_tool()
        async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
            """
            Handle tool calls from MCP clients.
            
            Routes tool calls to appropriate handlers, manages errors,
            and formats responses as TextContent.
            
            Args:
                name: The tool name being called.
                arguments: Dictionary of tool arguments.
                
            Returns:
                List containing a single TextContent with JSON response.
            """
            logger.info(f"Tool called: {name} with args: {arguments}")
            
            try:
                result = await self._handle_tool_call(name, arguments)
                return [TextContent(type="text", text=json.dumps(result, indent=2))]
            except Exception as e:
                logger.exception(f"Error handling tool {name}")
                error_result = {
                    "success": False,
                    "error": {
                        "code": "TOOL_ERROR",
                        "message": str(e),
                    },
                }
                return [TextContent(type="text", text=json.dumps(error_result, indent=2))]

    async def _handle_tool_call(
        self, name: str, arguments: dict[str, Any]
    ) -> dict[str, Any]:
        """
        Handle a specific tool call.
        
        Routes the tool call to the appropriate handler:
        - Connection management tools are handled locally
        - Godot commands are forwarded via WebSocket
        
        Args:
            name: The tool name (e.g., "godot_ping", "godot_connect").
            arguments: Tool-specific arguments.
            
        Returns:
            Response dictionary with success/error status and results.
        """
        
        # Handle connection management tools
        if name == "godot_connection_status":
            return {
                "success": True,
                "connected": self.godot_client.is_connected,
                "host": self.host,
                "port": self.port,
            }
        
        if name == "godot_connect":
            host = arguments.get("host", self.host)
            port = arguments.get("port", self.port)
            self.host = host
            self.port = port
            self.godot_client = GodotClient(host, port)
            
            success = await self.godot_client.connect()
            if success:
                return {
                    "success": True,
                    "message": f"Connected to Godot at {host}:{port}",
                }
            else:
                return {
                    "success": False,
                    "error": {
                        "code": "CONNECTION_FAILED",
                        "message": f"Failed to connect to Godot at {host}:{port}. Make sure Godot is running with the Codot plugin enabled.",
                    },
                }
        
        if name == "godot_disconnect":
            await self.godot_client.disconnect()
            return {
                "success": True,
                "message": "Disconnected from Godot",
            }
        
        # Handle command-based tools
        if name.startswith("godot_"):
            cmd_name = name[6:]  # Remove "godot_" prefix
            
            if cmd_name not in COMMANDS:
                return {
                    "success": False,
                    "error": {
                        "code": "UNKNOWN_COMMAND",
                        "message": f"Unknown command: {cmd_name}",
                    },
                }
            
            # Ensure connected
            if not self.godot_client.is_connected:
                # Try to auto-connect
                success = await self.godot_client.connect()
                if not success:
                    return {
                        "success": False,
                        "error": {
                            "code": "NOT_CONNECTED",
                            "message": "Not connected to Godot. Use godot_connect first, or ensure Godot is running with the Codot plugin.",
                        },
                    }
            
            # Send command to Godot
            response = await self.godot_client.send_command(cmd_name, arguments)
            return response
        
        return {
            "success": False,
            "error": {
                "code": "UNKNOWN_TOOL",
                "message": f"Unknown tool: {name}",
            },
        }

    async def run(self) -> None:
        """
        Run the MCP server.
        
        Starts the MCP server using stdio transport, which communicates
        with MCP clients (like VS Code Copilot) via stdin/stdout.
        
        This method blocks until the server is shut down.
        """
        logger.info("Starting Codot server...")
        
        async with stdio_server() as (read_stream, write_stream):
            await self.server.run(
                read_stream,
                write_stream,
                self.server.create_initialization_options(),
            )


def main() -> None:
    """
    Main entry point for the Codot server.
    
    Reads configuration from environment variables:
    - CODOT_HOST: WebSocket host (default: 127.0.0.1)
    - CODOT_PORT: WebSocket port (default: 6850)
    
    Creates and runs the MCP server, blocking until shutdown.
    """
    # Get configuration from environment
    host = os.environ.get("CODOT_HOST", DEFAULT_HOST)
    port = int(os.environ.get("CODOT_PORT", DEFAULT_PORT))
    
    server = CodotServer(host, port)
    asyncio.run(server.run())


if __name__ == "__main__":
    main()
