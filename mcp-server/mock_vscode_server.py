#!/usr/bin/env python3
"""Mock VS Code Bridge server to test Godot connection."""
import asyncio
import json
import websockets


async def handler(websocket):
    """Handle WebSocket connections."""
    print("Client connected!")
    
    # Send initial connection message (like VS Code does)
    await websocket.send(json.dumps({
        "type": "connected",
        "message": "Connected to Mock VS Code Bridge"
    }))
    
    try:
        async for message in websocket:
            print(f"Received: {message}")
            data = json.loads(message)
            
            if data.get("type") == "prompt":
                # Send acknowledgment
                ack = {
                    "type": "ack",
                    "success": True,
                    "message": "Prompt received successfully",
                    "prompt_id": data.get("prompt_id", ""),
                    "title": data.get("title", "")
                }
                print(f"Sending ack: {json.dumps(ack)}")
                await websocket.send(json.dumps(ack))
            elif data.get("type") == "ping":
                await websocket.send(json.dumps({"type": "pong"}))
            else:
                await websocket.send(json.dumps({"type": "unknown"}))
    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")
    except Exception as e:
        print(f"Error: {e}")


async def main():
    """Run the mock server."""
    port = 6851
    print(f"Starting mock VS Code server on port {port}...")
    print("Press Ctrl+C to stop")
    print("Now try 'Send to AI' in Godot!")
    
    async with websockets.serve(handler, "127.0.0.1", port):
        await asyncio.Future()  # Run forever


if __name__ == "__main__":
    asyncio.run(main())
