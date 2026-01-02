#!/usr/bin/env python3
"""
Integration Tests for Codot Plugin <-> MCP Server <-> VSCode Extension

This script tests the full communication stack:
1. MCP Server connectivity and command handling
2. WebSocket protocol correctness
3. Command response format validation
4. Error handling and edge cases

Prerequisites:
- Godot running with Codot plugin enabled
- (Optional) VS Code with Codot Bridge extension for full integration

Run with: python test_integration.py
"""

import asyncio
import sys
import json
import time
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, Any

# Add the codot package to path
sys.path.insert(0, str(Path(__file__).parent))

from codot.godot_client import GodotClient


@dataclass
class TestResult:
    """Result of a single test."""
    name: str
    passed: bool
    duration: float
    error: Optional[str] = None
    details: Optional[dict] = None


class IntegrationTests:
    """Integration test suite for Codot system."""
    
    def __init__(self):
        self.client: Optional[GodotClient] = None
        self.results: list[TestResult] = []
    
    async def setup(self) -> bool:
        """Connect to the MCP server."""
        print("Connecting to Godot MCP server...")
        self.client = GodotClient()
        try:
            await self.client.connect()
            print("✓ Connected successfully\n")
            return True
        except Exception as e:
            print(f"✗ Failed to connect: {e}")
            return False
    
    async def teardown(self):
        """Disconnect from the server."""
        if self.client:
            await self.client.close()
    
    async def run_test(self, name: str, test_func) -> TestResult:
        """Run a single test and record results."""
        start = time.time()
        try:
            result = await test_func()
            duration = time.time() - start
            return TestResult(
                name=name,
                passed=result.get("passed", False),
                duration=duration,
                details=result.get("details")
            )
        except Exception as e:
            duration = time.time() - start
            return TestResult(
                name=name,
                passed=False,
                duration=duration,
                error=str(e)
            )
    
    # ========================================================================
    # Protocol Tests
    # ========================================================================
    
    async def test_ping_response_format(self) -> dict:
        """Verify ping response has correct format."""
        result = await self.client.send_command("ping", {})
        
        # Check required fields
        has_success = "success" in result
        has_id = "id" in result
        success_is_true = result.get("success") is True
        has_result = "result" in result
        
        if has_success and has_id and success_is_true and has_result:
            pong = result["result"].get("pong")
            timestamp = result["result"].get("timestamp")
            return {
                "passed": pong is True and timestamp is not None,
                "details": {"pong": pong, "timestamp": timestamp}
            }
        
        return {
            "passed": False,
            "details": {"response": result}
        }
    
    async def test_error_response_format(self) -> dict:
        """Verify error responses have correct format."""
        result = await self.client.send_command("invalid_command_xyz", {})
        
        has_success = "success" in result
        success_is_false = result.get("success") is False
        has_error = "error" in result
        
        if has_success and success_is_false and has_error:
            error = result["error"]
            has_code = "code" in error
            has_message = "message" in error
            return {
                "passed": has_code and has_message,
                "details": {"error": error}
            }
        
        return {
            "passed": False,
            "details": {"response": result}
        }
    
    async def test_missing_param_error(self) -> dict:
        """Verify missing parameter handling."""
        result = await self.client.send_command("read_file", {})  # Missing 'path'
        
        success = result.get("success")
        error = result.get("error", {})
        code = error.get("code", "")
        
        return {
            "passed": success is False and "MISSING" in code.upper(),
            "details": {"error": error}
        }
    
    async def test_node_not_found_error(self) -> dict:
        """Verify node not found error handling."""
        # First ensure a scene is open
        await self.client.send_command("open_scene", {"path": "res://test_scene.tscn"})
        
        result = await self.client.send_command("get_node_info", {
            "path": "NonExistentNode12345"
        })
        
        success = result.get("success")
        error = result.get("error", {})
        code = error.get("code", "")
        
        return {
            "passed": success is False and "NOT_FOUND" in code.upper(),
            "details": {"error": error}
        }
    
    # ========================================================================
    # Command Tests
    # ========================================================================
    
    async def test_get_status(self) -> dict:
        """Verify get_status returns expected fields."""
        result = await self.client.send_command("get_status", {})
        
        if not result.get("success"):
            return {"passed": False, "details": {"error": result.get("error")}}
        
        status = result.get("result", {})
        expected_fields = ["version", "project_name"]
        has_fields = all(f in status for f in expected_fields)
        
        return {
            "passed": has_fields,
            "details": {"status": status}
        }
    
    async def test_get_project_files(self) -> dict:
        """Verify project file listing."""
        result = await self.client.send_command("get_project_files", {
            "extension": "gd"
        })
        
        if not result.get("success"):
            return {"passed": False, "details": {"error": result.get("error")}}
        
        res = result.get("result", {})
        files = res.get("files", [])
        count = res.get("count", 0)
        
        return {
            "passed": count > 0 and len(files) == count,
            "details": {"count": count, "sample": files[:3] if files else []}
        }
    
    async def test_scene_operations(self) -> dict:
        """Test scene open/save workflow."""
        # Try to open a scene
        result = await self.client.send_command("open_scene", {
            "path": "res://test_scene.tscn"
        })
        
        opened = result.get("success", False)
        
        # Get open scenes
        result = await self.client.send_command("get_open_scenes", {})
        has_scenes = result.get("success", False)
        scenes = result.get("result", {}).get("scenes", [])
        
        return {
            "passed": opened or has_scenes,
            "details": {"opened": opened, "open_scenes": scenes}
        }
    
    async def test_find_file_command(self) -> dict:
        """Test the new find_file command."""
        result = await self.client.send_command("find_file", {
            "pattern": "*.gd",
            "max_results": 5
        })
        
        if not result.get("success"):
            return {"passed": False, "details": {"error": result.get("error")}}
        
        res = result.get("result", {})
        return {
            "passed": res.get("count", 0) > 0,
            "details": {
                "pattern": res.get("pattern"),
                "count": res.get("count"),
                "results": res.get("results", [])[:3]
            }
        }
    
    async def test_search_in_files_command(self) -> dict:
        """Test the new search_in_files command."""
        result = await self.client.send_command("search_in_files", {
            "query": "extends",
            "extensions": ["gd"],
            "max_results": 3
        })
        
        if not result.get("success"):
            return {"passed": False, "details": {"error": result.get("error")}}
        
        res = result.get("result", {})
        return {
            "passed": res.get("files_with_matches", 0) > 0,
            "details": {
                "query": res.get("query"),
                "files_with_matches": res.get("files_with_matches"),
                "total_matches": res.get("total_matches")
            }
        }
    
    async def test_editor_state(self) -> dict:
        """Test editor state retrieval."""
        result = await self.client.send_command("get_editor_state", {})
        
        if not result.get("success"):
            return {"passed": False, "details": {"error": result.get("error")}}
        
        state = result.get("result", {})
        return {
            "passed": True,
            "details": state
        }
    
    # ========================================================================
    # Concurrent Request Tests
    # ========================================================================
    
    async def test_concurrent_requests(self) -> dict:
        """Test handling multiple concurrent requests."""
        commands = [
            ("ping", {}),
            ("get_status", {}),
            ("get_project_files", {"extension": "gd", "recursive": False}),
        ]
        
        # Send all concurrently
        tasks = [
            self.client.send_command(cmd, params)
            for cmd, params in commands
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        successes = sum(
            1 for r in results
            if isinstance(r, dict) and r.get("success")
        )
        
        return {
            "passed": successes == len(commands),
            "details": {
                "total": len(commands),
                "successful": successes
            }
        }
    
    # ========================================================================
    # Run All Tests
    # ========================================================================
    
    async def run_all(self) -> int:
        """Run all integration tests."""
        if not await self.setup():
            return 1
        
        tests = [
            # Protocol tests
            ("Response Format: Ping", self.test_ping_response_format),
            ("Response Format: Error", self.test_error_response_format),
            ("Error: Missing Parameter", self.test_missing_param_error),
            ("Error: Node Not Found", self.test_node_not_found_error),
            
            # Command tests
            ("Command: get_status", self.test_get_status),
            ("Command: get_project_files", self.test_get_project_files),
            ("Command: Scene Operations", self.test_scene_operations),
            ("Command: find_file", self.test_find_file_command),
            ("Command: search_in_files", self.test_search_in_files_command),
            ("Command: get_editor_state", self.test_editor_state),
            
            # Concurrent tests
            ("Concurrent Requests", self.test_concurrent_requests),
        ]
        
        print("=" * 60)
        print("INTEGRATION TESTS")
        print("=" * 60)
        
        for name, test_func in tests:
            print(f"\n▶ {name}...", end=" ")
            result = await self.run_test(name, test_func)
            self.results.append(result)
            
            if result.passed:
                print(f"✓ ({result.duration:.3f}s)")
            else:
                print(f"✗ ({result.duration:.3f}s)")
                if result.error:
                    print(f"   Error: {result.error}")
        
        await self.teardown()
        
        # Summary
        print("\n" + "=" * 60)
        print("SUMMARY")
        print("=" * 60)
        
        passed = sum(1 for r in self.results if r.passed)
        failed = len(self.results) - passed
        
        print(f"\nTotal: {len(self.results)} tests")
        print(f"  ✓ Passed: {passed}")
        print(f"  ✗ Failed: {failed}")
        
        if failed > 0:
            print("\nFailed tests:")
            for r in self.results:
                if not r.passed:
                    print(f"  - {r.name}")
                    if r.error:
                        print(f"    Error: {r.error}")
                    if r.details:
                        print(f"    Details: {json.dumps(r.details, indent=4)[:200]}...")
        
        return 0 if failed == 0 else 1


async def main():
    print("=" * 60)
    print("CODOT INTEGRATION TEST SUITE")
    print("=" * 60)
    print("\nThis tests the Codot Plugin <-> MCP Server communication.\n")
    
    suite = IntegrationTests()
    return await suite.run_all()


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
