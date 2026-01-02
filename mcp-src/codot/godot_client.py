"""
WebSocket client for connecting to Godot's Codot plugin.

This module provides the GodotClient class which manages the WebSocket
connection to a running Godot instance. It handles:
- Connection establishment and reconnection
- Command sending with request/response correlation
- Asynchronous message receiving
- Event handling for broadcasts from Godot

The client uses a request-response pattern with UUIDs to correlate
commands with their responses, allowing multiple concurrent commands.
"""

import asyncio
import json
import logging
import uuid
from typing import Any, Callable, Optional

import websockets
from websockets.client import WebSocketClientProtocol

logger = logging.getLogger("codot.client")


class GodotClient:
    """
    WebSocket client for communicating with Godot's Codot plugin.
    
    This client establishes a WebSocket connection to the Codot plugin
    running in Godot. It provides methods to send commands and receive responses,
    with support for concurrent requests and event handling.
    
    Attributes:
        host: The WebSocket server host address.
        port: The WebSocket server port number.
        websocket: The active WebSocket connection, or None if disconnected.
        
    Example:
        >>> client = GodotClient("127.0.0.1", 6850)
        >>> await client.connect()
        >>> result = await client.send_command("ping", {})
        >>> await client.disconnect()
    """

    def __init__(self, host: str = "127.0.0.1", port: int = 6850) -> None:
        """
        Initialize the Godot client.
        
        Args:
            host: WebSocket server host address. Defaults to localhost.
            port: WebSocket server port. Defaults to 6850.
        """
        self.host = host
        self.port = port
        self.websocket: Optional[WebSocketClientProtocol] = None
        self._pending_requests: dict[str, asyncio.Future] = {}
        self._receive_task: Optional[asyncio.Task] = None
        self._event_handlers: dict[str, list[Callable]] = {}

    @property
    def is_connected(self) -> bool:
        """
        Check if connected to Godot.
        
        Returns:
            True if the WebSocket connection is open, False otherwise.
        """
        return self.websocket is not None and self.websocket.open

    @property
    def uri(self) -> str:
        """
        Get the WebSocket URI.
        
        Returns:
            The full WebSocket URI (e.g., "ws://127.0.0.1:6850").
        """
        return f"ws://{self.host}:{self.port}"

    async def connect(self, timeout: float = 5.0) -> bool:
        """
        Connect to Godot's WebSocket server.
        
        Args:
            timeout: Connection timeout in seconds
            
        Returns:
            True if connection successful, False otherwise
        """
        if self.is_connected:
            return True

        try:
            self.websocket = await asyncio.wait_for(
                websockets.connect(self.uri),
                timeout=timeout,
            )
            
            # Start receiving messages
            self._receive_task = asyncio.create_task(self._receive_loop())
            
            logger.info(f"Connected to Godot at {self.uri}")
            return True
            
        except asyncio.TimeoutError:
            logger.warning(f"Connection to Godot timed out after {timeout}s")
            return False
        except ConnectionRefusedError:
            logger.warning(f"Connection to Godot refused at {self.uri}")
            return False
        except Exception as e:
            logger.warning(f"Failed to connect to Godot: {e}")
            return False

    async def disconnect(self) -> None:
        """
        Disconnect from Godot.
        
        Gracefully closes the WebSocket connection, cancels the receive
        task, and cleans up all pending requests by canceling their futures.
        """
        if self._receive_task:
            self._receive_task.cancel()
            try:
                await self._receive_task
            except asyncio.CancelledError:
                pass
            self._receive_task = None

        if self.websocket:
            await self.websocket.close()
            self.websocket = None
            
        # Cancel all pending requests
        for future in self._pending_requests.values():
            if not future.done():
                future.cancel()
        self._pending_requests.clear()
        
        logger.info("Disconnected from Godot")

    async def send_command(
        self,
        command: str,
        params: Optional[dict[str, Any]] = None,
        timeout: float = 30.0,
    ) -> dict[str, Any]:
        """
        Send a command to Godot and wait for response.
        
        Args:
            command: The command name
            params: Command parameters
            timeout: Response timeout in seconds
            
        Returns:
            Response dictionary from Godot
        """
        if not self.is_connected:
            return {
                "success": False,
                "error": {
                    "code": "NOT_CONNECTED",
                    "message": "Not connected to Godot",
                },
            }

        request_id = str(uuid.uuid4())
        request = {
            "id": request_id,
            "command": command,
            "params": params or {},
        }

        # Create future for response
        future: asyncio.Future = asyncio.get_event_loop().create_future()
        self._pending_requests[request_id] = future

        try:
            # Send request
            await self.websocket.send(json.dumps(request))
            logger.debug(f"Sent command: {command} (id: {request_id})")

            # Wait for response
            response = await asyncio.wait_for(future, timeout=timeout)
            return response

        except asyncio.TimeoutError:
            self._pending_requests.pop(request_id, None)
            return {
                "success": False,
                "error": {
                    "code": "TIMEOUT",
                    "message": f"Command '{command}' timed out after {timeout}s",
                },
            }
        except websockets.exceptions.ConnectionClosed:
            self._pending_requests.pop(request_id, None)
            self.websocket = None
            return {
                "success": False,
                "error": {
                    "code": "CONNECTION_CLOSED",
                    "message": "Connection to Godot was closed",
                },
            }
        except Exception as e:
            self._pending_requests.pop(request_id, None)
            return {
                "success": False,
                "error": {
                    "code": "SEND_ERROR",
                    "message": str(e),
                },
            }

    async def _receive_loop(self) -> None:
        """
        Background task to receive messages from Godot.
        
        Runs continuously while connected, processing incoming messages
        and routing them to appropriate handlers. Automatically handles
        connection closure and cleanup.
        """
        try:
            async for message in self.websocket:
                try:
                    data = json.loads(message)
                    await self._handle_message(data)
                except json.JSONDecodeError:
                    logger.warning(f"Received invalid JSON: {message}")
        except websockets.exceptions.ConnectionClosed:
            logger.info("WebSocket connection closed")
        except asyncio.CancelledError:
            raise
        except Exception as e:
            logger.exception(f"Error in receive loop: {e}")
        finally:
            self.websocket = None

    async def _handle_message(self, data: dict[str, Any]) -> None:
        """
        Handle an incoming message from Godot.
        
        Routes messages based on their type:
        - Response messages are matched to pending requests by ID
        - Event messages are emitted to registered handlers
        
        Args:
            data: Parsed JSON message from Godot.
        """
        msg_type = data.get("type", "response")
        
        if msg_type == "response" or "id" in data:
            # This is a response to a command
            request_id = data.get("id")
            if request_id and request_id in self._pending_requests:
                future = self._pending_requests.pop(request_id)
                if not future.done():
                    future.set_result(data)
        
        elif msg_type == "log_event":
            # This is a log event broadcast
            await self._emit_event("log", data.get("data", {}))
        
        elif msg_type == "game_connected":
            # Game instance connected
            await self._emit_event("game_connected", data.get("data", {}))
        
        elif msg_type == "game_disconnected":
            # Game instance disconnected
            await self._emit_event("game_disconnected", data.get("data", {}))

    def on_event(self, event_type: str, handler: Callable) -> None:
        """
        Register an event handler.
        
        Args:
            event_type: The type of event to listen for (e.g., "log", "game_connected").
            handler: Callback function to invoke when the event occurs.
                    Can be sync or async.
        """
        if event_type not in self._event_handlers:
            self._event_handlers[event_type] = []
        self._event_handlers[event_type].append(handler)

    def off_event(self, event_type: str, handler: Callable) -> None:
        """
        Unregister an event handler.
        
        Args:
            event_type: The type of event the handler was registered for.
            handler: The handler function to remove.
        """
        if event_type in self._event_handlers:
            self._event_handlers[event_type].remove(handler)

    async def _emit_event(self, event_type: str, data: dict[str, Any]) -> None:
        """
        Emit an event to all registered handlers.
        
        Invokes all handlers registered for the given event type.
        Supports both sync and async handlers.
        
        Args:
            event_type: The type of event being emitted.
            data: Event data to pass to handlers.
        """
        handlers = self._event_handlers.get(event_type, [])
        for handler in handlers:
            try:
                if asyncio.iscoroutinefunction(handler):
                    await handler(data)
                else:
                    handler(data)
            except Exception as e:
                logger.exception(f"Error in event handler for {event_type}: {e}")
