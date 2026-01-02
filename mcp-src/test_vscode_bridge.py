#!/usr/bin/env python3
"""
Test script to diagnose the VS Code Codot Bridge WebSocket connection.
This simulates what the Godot panel does when sending a prompt.
"""

import asyncio
import json
import sys

try:
    import websockets
except ImportError:
    print("ERROR: websockets library not installed. Run: pip install websockets")
    sys.exit(1)


async def test_connection(port: int = 6851):
    """Test basic connection to VS Code bridge."""
    url = f"ws://127.0.0.1:{port}"
    print(f"\n{'='*60}")
    print(f"Testing connection to VS Code Codot Bridge at {url}")
    print(f"{'='*60}\n")
    
    try:
        async with websockets.connect(url, close_timeout=5) as ws:
            print("✓ Connected successfully!")
            
            # Check for initial connection message
            print("\n--- Waiting for initial message from server ---")
            try:
                initial = await asyncio.wait_for(ws.recv(), timeout=2.0)
                print(f"✓ Received initial message: {initial}")
                data = json.loads(initial)
                print(f"  Parsed: {json.dumps(data, indent=2)}")
            except asyncio.TimeoutError:
                print("✗ No initial message received (timeout)")
            except Exception as e:
                print(f"✗ Error receiving initial message: {e}")
            
            # Send a test prompt (matching what Godot sends)
            print("\n--- Sending test prompt ---")
            test_message = {
                "type": "prompt",
                "prompt_id": "test-123",
                "title": "Test Prompt",
                "content": "This is a test prompt from the diagnostic script.",
                "timestamp": "2026-01-02T12:00:00"
            }
            print(f"Sending: {json.dumps(test_message, indent=2)}")
            await ws.send(json.dumps(test_message))
            print("✓ Message sent")
            
            # Wait for acknowledgment
            print("\n--- Waiting for acknowledgment ---")
            try:
                response = await asyncio.wait_for(ws.recv(), timeout=5.0)
                print(f"✓ Received response: {response}")
                data = json.loads(response)
                print(f"  Parsed: {json.dumps(data, indent=2)}")
                
                # Check if it's an acknowledgment
                if data.get("type") == "ack" or data.get("success") == True:
                    print("\n✓✓✓ SUCCESS: Acknowledgment received correctly! ✓✓✓")
                else:
                    print(f"\n⚠ Response received but not an 'ack': type={data.get('type')}, success={data.get('success')}")
                    
            except asyncio.TimeoutError:
                print("✗ TIMEOUT: No acknowledgment received within 5 seconds")
                print("\n  Possible causes:")
                print("  1. VS Code extension handlePrompt() is failing")
                print("  2. GitHub Copilot Chat extension is not installed")
                print("  3. The ws.send() in extension.ts is not being reached")
            except Exception as e:
                print(f"✗ Error receiving acknowledgment: {e}")
            
            # Send a ping to verify bidirectional communication
            print("\n--- Sending ping test ---")
            await ws.send(json.dumps({"type": "ping"}))
            try:
                pong = await asyncio.wait_for(ws.recv(), timeout=2.0)
                print(f"✓ Pong received: {pong}")
            except asyncio.TimeoutError:
                print("✗ No pong received")
                
    except ConnectionRefusedError:
        print(f"✗ CONNECTION REFUSED: No server listening on port {port}")
        print("\n  Make sure:")
        print("  1. VS Code is running")
        print("  2. Codot Bridge extension is installed and enabled")
        print("  3. Run 'Codot Bridge: Start Server' command in VS Code")
        print(f"  4. The port {port} matches the extension settings")
        
    except Exception as e:
        print(f"✗ Connection error: {type(e).__name__}: {e}")


async def test_message_formats(port: int = 6851):
    """Test different message formats to see which ones get acknowledged."""
    url = f"ws://127.0.0.1:{port}"
    
    print(f"\n{'='*60}")
    print("Testing different message formats")
    print(f"{'='*60}\n")
    
    formats = [
        {
            "name": "New format (content/title)",
            "message": {
                "type": "prompt",
                "prompt_id": "test-1",
                "title": "Test Title",
                "content": "Test content",
                "timestamp": "2026-01-02T12:00:00"
            }
        },
        {
            "name": "Old format (prompt field)",
            "message": {
                "type": "prompt",
                "prompt": "Test prompt text"
            }
        },
        {
            "name": "Body format",
            "message": {
                "type": "prompt",
                "title": "Test",
                "body": "Test body content"
            }
        }
    ]
    
    try:
        async with websockets.connect(url, close_timeout=5) as ws:
            # Consume initial message
            try:
                await asyncio.wait_for(ws.recv(), timeout=1.0)
            except:
                pass
            
            for fmt in formats:
                print(f"\nTesting: {fmt['name']}")
                print(f"  Message: {json.dumps(fmt['message'])}")
                
                await ws.send(json.dumps(fmt['message']))
                
                try:
                    response = await asyncio.wait_for(ws.recv(), timeout=3.0)
                    data = json.loads(response)
                    if data.get("type") == "ack" or data.get("success"):
                        print(f"  ✓ Acknowledged: {response[:100]}")
                    else:
                        print(f"  ⚠ Response: {response[:100]}")
                except asyncio.TimeoutError:
                    print(f"  ✗ No response (timeout)")
                except Exception as e:
                    print(f"  ✗ Error: {e}")
                    
    except ConnectionRefusedError:
        print("✗ Cannot connect to server")
    except Exception as e:
        print(f"✗ Error: {e}")


async def main():
    print("\n" + "="*60)
    print(" VS Code Codot Bridge Diagnostic Tool")
    print("="*60)
    
    # Test with default port
    await test_connection(6851)
    
    # If connected, test message formats
    print("\n")
    await test_message_formats(6851)
    
    print("\n" + "="*60)
    print(" Diagnostic complete")
    print("="*60 + "\n")


if __name__ == "__main__":
    asyncio.run(main())
