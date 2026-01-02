#!/usr/bin/env python3
"""
Codebase Validation Script for Codot

This script performs static analysis of the Codot codebase to detect
violations of coding standards and best practices.

Rules checked:
1. UI elements should be defined in .tscn scene files, not created in GDScript code
2. Python command execution should use script files, not inline code
3. All command functions should have consistent signatures
4. Files should follow naming conventions
5. Critical patterns that cause issues are detected

Usage:
    python scripts/validate-codebase.py [--fix] [--verbose]

Exit codes:
    0 - No violations found
    1 - Violations found
    2 - Script error
"""

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass
class Violation:
    """Represents a coding standard violation."""
    file: str
    line: int
    rule: str
    message: str
    severity: str = "error"  # error, warning, info
    
    def __str__(self) -> str:
        return f"{self.file}:{self.line}: [{self.severity}] {self.rule}: {self.message}"


class CodebaseValidator:
    """Validates the Codot codebase for coding standard violations."""
    
    def __init__(self, root_path: Path, verbose: bool = False):
        self.root_path = root_path
        self.verbose = verbose
        self.violations: list[Violation] = []
        
        # Patterns that indicate UI being created in code (should be in .tscn)
        # These patterns look for actual UI node instantiation, not just comments
        self.ui_creation_patterns = [
            # Only match when UI nodes are instantiated and added as children in what looks like a UI setup
            (r'^\s*var\s+\w+\s*=\s*(Button|Label|LineEdit|TextEdit|RichTextLabel)\.new\(\)', 'Direct UI widget creation'),
            (r'^\s*var\s+\w+\s*=\s*(VBoxContainer|HBoxContainer|MarginContainer|PanelContainer|ScrollContainer)\.new\(\)', 'Container created in code'),
        ]
        
        # Files that are allowed to create UI in code (exceptions)
        self.ui_creation_exceptions = [
            'command_handler',  # May need dynamic node creation for commands
            'test_',  # Test files
            '_test.gd',
            'commands_',  # Command modules may need dynamic node creation
            'input_simulator',  # Input simulation creates fake buttons
            '_old.gd',  # Backup files
        ]
        
        # GDScript command signature pattern
        self.command_signature_pattern = re.compile(
            r'^func\s+cmd_(\w+)\s*\(\s*cmd_id\s*:\s*Variant\s*(?:,\s*(?:_?params)\s*:\s*Dictionary)?\s*\)'
        )
        
        # Python inline code pattern (often causes syntax errors)
        self.python_inline_patterns = [
            (r'python\s+-c\s*["\'].*\\n.*["\']', 'Multi-line Python in -c flag (use script file instead)'),
            (r'python\s+-c\s*["\'].*\{[^}]*\}.*\{[^}]*\}.*["\']', 'Complex f-string in -c flag (escaping issues)'),
        ]
    
    def log(self, message: str) -> None:
        """Print verbose log message."""
        if self.verbose:
            print(f"  [INFO] {message}")
    
    def add_violation(
        self, 
        file: Path, 
        line: int, 
        rule: str, 
        message: str,
        severity: str = "error"
    ) -> None:
        """Add a violation to the list."""
        rel_path = str(file.relative_to(self.root_path))
        self.violations.append(Violation(rel_path, line, rule, message, severity))
    
    def validate_gdscript_file(self, file_path: Path) -> None:
        """Validate a GDScript file for violations."""
        self.log(f"Checking {file_path.name}")
        
        try:
            content = file_path.read_text(encoding='utf-8')
            lines = content.splitlines()
        except Exception as e:
            self.add_violation(file_path, 0, "READ_ERROR", f"Could not read file: {e}")
            return
        
        # Check if this file is an exception for UI creation
        is_ui_exception = any(exc in file_path.name for exc in self.ui_creation_exceptions)
        
        for line_num, line in enumerate(lines, 1):
            # Rule 1: UI Creation in Code
            if not is_ui_exception:
                for pattern, msg in self.ui_creation_patterns:
                    if re.search(pattern, line, re.IGNORECASE):
                        self.add_violation(
                            file_path, line_num, "UI_IN_CODE",
                            f"{msg}. Consider using a .tscn scene file instead.",
                            severity="warning"
                        )
            
            # Rule 2: Command function signature consistency
            if file_path.name.startswith('commands_'):
                match = re.match(r'^func\s+cmd_\w+\s*\(', line)
                if match:
                    # Check if it has the correct signature
                    full_match = self.command_signature_pattern.match(line)
                    if not full_match:
                        # Check if params is missing
                        if 'params' not in line and '_params' not in line:
                            self.add_violation(
                                file_path, line_num, "CMD_SIGNATURE",
                                "Command function missing 'params: Dictionary' parameter",
                                severity="error"
                            )
            
            # Rule 3: Check for common GDScript issues
            if 'get_scene_root(cmd_id)' in line:
                self.add_violation(
                    file_path, line_num, "DEPRECATED_CALL",
                    "Use _get_scene_root() without cmd_id after _require_scene() check",
                    severity="warning"
                )
    
    def validate_python_file(self, file_path: Path) -> None:
        """Validate a Python file for violations."""
        self.log(f"Checking {file_path.name}")
        
        try:
            content = file_path.read_text(encoding='utf-8')
            lines = content.splitlines()
        except Exception as e:
            self.add_violation(file_path, 0, "READ_ERROR", f"Could not read file: {e}")
            return
        
        for line_num, line in enumerate(lines, 1):
            # Rule: Complex inline Python execution
            for pattern, msg in self.python_inline_patterns:
                if re.search(pattern, line):
                    self.add_violation(
                        file_path, line_num, "INLINE_PYTHON",
                        f"{msg}",
                        severity="warning"
                    )
    
    def validate_scene_file(self, file_path: Path) -> None:
        """Validate a scene (.tscn) file for violations."""
        self.log(f"Checking {file_path.name}")
        
        try:
            content = file_path.read_text(encoding='utf-8')
        except Exception as e:
            self.add_violation(file_path, 0, "READ_ERROR", f"Could not read file: {e}")
            return
        
        # Check for missing script references
        if '[ext_resource' not in content and '[sub_resource' not in content:
            if '[node' in content:
                # Scene with nodes but no resources might be okay
                pass
    
    def validate_directory_structure(self) -> None:
        """Validate the project directory structure."""
        
        # Check for required directories
        required_dirs = [
            'addons/codot/commands',
            'mcp-server/codot',
            'mcp-server/tests',
            'test/unit',
        ]
        
        for dir_path in required_dirs:
            full_path = self.root_path / dir_path
            if not full_path.exists():
                self.add_violation(
                    self.root_path, 0, "MISSING_DIR",
                    f"Required directory missing: {dir_path}",
                    severity="error"
                )
    
    def validate_command_registration(self) -> None:
        """Check that all command functions are registered in command_handler.gd."""
        commands_dir = self.root_path / 'addons' / 'codot' / 'commands'
        handler_path = self.root_path / 'addons' / 'codot' / 'command_handler.gd'
        
        if not commands_dir.exists() or not handler_path.exists():
            return
        
        try:
            handler_content = handler_path.read_text(encoding='utf-8')
        except Exception:
            return
        
        # Find all cmd_ functions in command modules
        for gd_file in commands_dir.glob('commands_*.gd'):
            try:
                content = gd_file.read_text(encoding='utf-8')
            except Exception:
                continue
            
            for match in re.finditer(r'^func\s+(cmd_\w+)\s*\(', content, re.MULTILINE):
                func_name = match.group(1)
                # Check if it's registered in the handler
                if func_name not in handler_content:
                    self.add_violation(
                        gd_file, 0, "UNREGISTERED_CMD",
                        f"Command function '{func_name}' not found in command_handler.gd",
                        severity="warning"
                    )
    
    def validate_python_command_definitions(self) -> None:
        """Check that all GDScript commands have Python definitions."""
        handler_path = self.root_path / 'addons' / 'codot' / 'command_handler.gd'
        py_commands_path = self.root_path / 'mcp-server' / 'codot' / 'commands.py'
        
        if not handler_path.exists() or not py_commands_path.exists():
            return
        
        try:
            handler_content = handler_path.read_text(encoding='utf-8')
            py_content = py_commands_path.read_text(encoding='utf-8')
        except Exception:
            return
        
        # Extract command names from handler (match statement cases)
        handler_commands = set()
        for match in re.finditer(r'^\s+"(\w+)":\s*$', handler_content, re.MULTILINE):
            handler_commands.add(match.group(1))
        
        # Extract command names from Python
        py_commands = set()
        for match in re.finditer(r'^\s+"(\w+)":\s*CommandDefinition\(', py_content, re.MULTILINE):
            py_commands.add(match.group(1))
        
        # Find commands in handler but not in Python
        missing_py = handler_commands - py_commands
        for cmd in missing_py:
            # Skip some internal commands
            if cmd not in ['ping']:
                self.add_violation(
                    py_commands_path, 0, "MISSING_PY_DEF",
                    f"Command '{cmd}' defined in GDScript but missing Python CommandDefinition",
                    severity="warning"
                )
    
    def run(self) -> int:
        """Run all validations and return exit code."""
        print(f"Validating codebase at: {self.root_path}")
        print("=" * 60)
        
        # Validate directory structure
        print("\n[1/5] Checking directory structure...")
        self.validate_directory_structure()
        
        # Validate GDScript files
        print("\n[2/5] Checking GDScript files...")
        for gd_file in self.root_path.rglob('*.gd'):
            # Skip addons that aren't ours
            if 'addons' in str(gd_file) and 'codot' not in str(gd_file):
                continue
            self.validate_gdscript_file(gd_file)
        
        # Validate Python files
        print("\n[3/5] Checking Python files...")
        for py_file in (self.root_path / 'mcp-server').rglob('*.py'):
            self.validate_python_file(py_file)
        
        # Validate scene files
        print("\n[4/5] Checking scene files...")
        for tscn_file in self.root_path.rglob('*.tscn'):
            if 'addons' in str(tscn_file) and 'codot' not in str(tscn_file):
                continue
            self.validate_scene_file(tscn_file)
        
        # Cross-file validations
        print("\n[5/5] Checking command registration...")
        self.validate_command_registration()
        self.validate_python_command_definitions()
        
        # Report results
        print("\n" + "=" * 60)
        
        if not self.violations:
            print("✅ No violations found!")
            return 0
        
        # Group by severity
        errors = [v for v in self.violations if v.severity == "error"]
        warnings = [v for v in self.violations if v.severity == "warning"]
        infos = [v for v in self.violations if v.severity == "info"]
        
        if errors:
            print(f"\n❌ ERRORS ({len(errors)}):")
            for v in errors:
                print(f"  {v}")
        
        if warnings:
            print(f"\n⚠️  WARNINGS ({len(warnings)}):")
            for v in warnings:
                print(f"  {v}")
        
        if infos:
            print(f"\nℹ️  INFO ({len(infos)}):")
            for v in infos:
                print(f"  {v}")
        
        print(f"\nTotal: {len(errors)} errors, {len(warnings)} warnings, {len(infos)} info")
        
        return 1 if errors else 0


def main():
    parser = argparse.ArgumentParser(
        description="Validate Codot codebase for coding standard violations"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show verbose output"
    )
    parser.add_argument(
        "--path", "-p",
        type=str,
        default=None,
        help="Path to project root (default: auto-detect)"
    )
    
    args = parser.parse_args()
    
    # Find project root
    if args.path:
        root_path = Path(args.path)
    else:
        # Try to find project root from script location
        script_path = Path(__file__).resolve()
        root_path = script_path.parent.parent
        
        # Verify it's the right directory
        if not (root_path / 'addons' / 'codot').exists():
            # Try current directory
            root_path = Path.cwd()
            if not (root_path / 'addons' / 'codot').exists():
                print("Error: Could not find Codot project root")
                print("Run from project root or use --path option")
                return 2
    
    validator = CodebaseValidator(root_path, verbose=args.verbose)
    return validator.run()


if __name__ == "__main__":
    sys.exit(main())
