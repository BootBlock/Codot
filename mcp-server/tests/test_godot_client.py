"""
Unit tests for the Codot WebSocket client.

These tests verify the client functionality using mocks
where a real Godot connection isn't available.
"""

import asyncio
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from codot.godot_client import GodotClient


class TestGodotClientInit:
    """Tests for GodotClient initialization."""

    def test_default_host_and_port(self):
        """Client should use default host and port."""
        client = GodotClient()
        assert client.host == "127.0.0.1"
        assert client.port == 6850

    def test_custom_host_and_port(self):
        """Client should accept custom host and port."""
        client = GodotClient(host="192.168.1.100", port=9999)
        assert client.host == "192.168.1.100"
        assert client.port == 9999

    def test_uri_property(self):
        """URI property should be correctly formatted."""
        client = GodotClient(host="localhost", port=1234)
        assert client.uri == "ws://localhost:1234"

    def test_initial_state(self):
        """Client should start in disconnected state."""
        client = GodotClient()
        assert client.websocket is None
        assert client.is_connected is False
        assert len(client._pending_requests) == 0


class TestGodotClientConnection:
    """Tests for connection management."""

    @pytest.mark.asyncio
    async def test_connect_timeout(self):
        """Connect should handle timeout gracefully."""
        client = GodotClient(host="192.0.2.1", port=9999)  # Non-routable IP
        result = await client.connect(timeout=0.5)
        assert result is False
        assert client.is_connected is False

    @pytest.mark.asyncio
    async def test_disconnect_when_not_connected(self):
        """Disconnect should handle not being connected."""
        client = GodotClient()
        # Should not raise
        await client.disconnect()
        assert client.is_connected is False


class TestGodotClientCommands:
    """Tests for command sending."""

    @pytest.mark.asyncio
    async def test_send_command_not_connected(self):
        """Sending command when not connected should return error."""
        client = GodotClient()
        result = await client.send_command("ping")
        
        assert result["success"] is False
        assert result["error"]["code"] == "NOT_CONNECTED"

    @pytest.mark.asyncio
    async def test_send_command_with_params(self):
        """Command params should be included in request."""
        client = GodotClient()
        
        # Mock the websocket
        mock_ws = AsyncMock()
        mock_ws.open = True
        client.websocket = mock_ws
        
        # Create a mock response future
        async def mock_send(data):
            import json
            parsed = json.loads(data)
            # Verify the command structure
            assert parsed["command"] == "test_cmd"
            assert parsed["params"] == {"key": "value"}
            
            # Simulate immediate response by setting the future
            request_id = parsed["id"]
            if request_id in client._pending_requests:
                client._pending_requests[request_id].set_result({
                    "id": request_id,
                    "success": True,
                    "result": {}
                })
        
        mock_ws.send = mock_send
        
        # Start a receive task that doesn't block
        client._receive_task = asyncio.create_task(asyncio.sleep(10))
        
        result = await client.send_command("test_cmd", {"key": "value"}, timeout=1)
        
        client._receive_task.cancel()
        try:
            await client._receive_task
        except asyncio.CancelledError:
            pass


class TestGodotClientProperties:
    """Tests for client properties."""

    def test_is_connected_false_when_no_websocket(self):
        """is_connected should be False when websocket is None."""
        client = GodotClient()
        client.websocket = None
        assert client.is_connected is False

    def test_is_connected_false_when_closed(self):
        """is_connected should be False when websocket is closed."""
        client = GodotClient()
        mock_ws = MagicMock()
        # websockets 15.0+ uses state.name
        mock_ws.state.name = "CLOSED"
        client.websocket = mock_ws
        assert client.is_connected is False

    def test_is_connected_true_when_open(self):
        """is_connected should be True when websocket is open."""
        client = GodotClient()
        mock_ws = MagicMock()
        # websockets 15.0+ uses state.name
        mock_ws.state.name = "OPEN"
        client.websocket = mock_ws
        assert client.is_connected is True
