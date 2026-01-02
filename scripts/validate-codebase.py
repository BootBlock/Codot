#!/usr/bin/env python3
"""
Codebase Validation Script for Codot

This script performs static analysis of the Codot codebase to detect
violations of coding standards and best practices.

OPTIMIZED: All files are cached at startup for efficient validation.

Rules checked:
1. UI elements should be defined in .tscn scene files, not created in GDScript code
2. Python command execution should use script files, not inline code
3. All command functions should have consistent signatures
4. Files should follow naming conventions
5. Critical patterns that cause issues are detected
6. UID reference validation
7. Command registration consistency

Usage:
    python scripts/validate-codebase.py [--verbose]

Exit codes:
    0 - No violations found
    1 - Violations found
    2 - Script error
"""

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class CachedFile:
    """Cached file content for efficient validation."""
    path: Path
    content: str
    lines: list[str]
    
    @classmethod
    def from_path(cls, file_path: Path) -> "CachedFile | None":
        """Load and cache a file. Returns None on error."""
        try:
            content = file_path.read_text(encoding='utf-8')
            return cls(path=file_path, content=content, lines=content.splitlines())
        except Exception:
            return None


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


@dataclass
class FileCache:
    """Cache of all project files for efficient validation."""
    gdscript_files: list[CachedFile] = field(default_factory=list)
    python_files: list[CachedFile] = field(default_factory=list)
    scene_files: list[CachedFile] = field(default_factory=list)
    resource_files: list[CachedFile] = field(default_factory=list)
    uid_files: list[CachedFile] = field(default_factory=list)
    other_files: dict[str, CachedFile] = field(default_factory=dict)


class CodebaseValidator:
    """Validates the Codot codebase for coding standard violations."""
    
    def __init__(self, root_path: Path, verbose: bool = False):
        self.root_path = root_path
        self.verbose = verbose
        self.violations: list[Violation] = []
        self.cache = FileCache()
        
        # Patterns that indicate UI being created in code (should be in .tscn)
        self.ui_creation_patterns = [
            (r'^\s*var\s+\w+\s*=\s*(Button|Label|LineEdit|TextEdit|RichTextLabel)\.new\(\)', 'Direct UI widget creation'),
            (r'^\s*var\s+\w+\s*=\s*(VBoxContainer|HBoxContainer|MarginContainer|PanelContainer|ScrollContainer)\.new\(\)', 'Container created in code'),
        ]
        
        # Files that are allowed to create UI in code (exceptions)
        self.ui_creation_exceptions = [
            'command_handler', 'test_', '_test.gd', 'commands_', 
            'input_simulator', '_old.gd',
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
        
        # Async patterns that can cause race conditions
        self.async_race_patterns = [
            (r'_websocket\.get_available_packet_count\(\)', 'Direct packet reading may race with _process()'),
        ]
        
        # Hardcoded values patterns
        self.hardcoded_patterns = [
            (r'=\s*(6850|6851)\s*(?:#|$)', 'Hardcoded port number - consider using constant or setting'),
        ]
        
        self.hardcoded_exclude_patterns = [
            r'^\s*const\s+',
            r'DEFAULT_\w+\s*:?=',
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
    
    def _should_skip_addon(self, file_path: Path) -> bool:
        """Check if file is in a non-codot addon and should be skipped."""
        path_str = str(file_path)
        return 'addons' in path_str and 'codot' not in path_str
    
    def cache_all_files(self) -> None:
        """Cache all project files for efficient validation."""
        
        # Cache GDScript files
        for gd_file in self.root_path.rglob('*.gd'):
            if self._should_skip_addon(gd_file):
                continue
            cached = CachedFile.from_path(gd_file)
            if cached:
                self.cache.gdscript_files.append(cached)
        self.log(f"Cached {len(self.cache.gdscript_files)} GDScript files")
        
        # Cache Python files
        mcp_server_path = self.root_path / 'mcp-server'
        if mcp_server_path.exists():
            for py_file in mcp_server_path.rglob('*.py'):
                cached = CachedFile.from_path(py_file)
                if cached:
                    self.cache.python_files.append(cached)
        self.log(f"Cached {len(self.cache.python_files)} Python files")
        
        # Cache scene files
        for tscn_file in self.root_path.rglob('*.tscn'):
            if self._should_skip_addon(tscn_file):
                continue
            cached = CachedFile.from_path(tscn_file)
            if cached:
                self.cache.scene_files.append(cached)
        self.log(f"Cached {len(self.cache.scene_files)} scene files")
        
        # Cache resource files
        for tres_file in self.root_path.rglob('*.tres'):
            if self._should_skip_addon(tres_file):
                continue
            cached = CachedFile.from_path(tres_file)
            if cached:
                self.cache.resource_files.append(cached)
        self.log(f"Cached {len(self.cache.resource_files)} resource files")
        
        # Cache UID files
        for uid_file in self.root_path.rglob('*.uid'):
            if self._should_skip_addon(uid_file):
                continue
            cached = CachedFile.from_path(uid_file)
            if cached:
                self.cache.uid_files.append(cached)
        self.log(f"Cached {len(self.cache.uid_files)} UID files")
        
        # Cache specific files
        for named_file in ['project.godot']:
            file_path = self.root_path / named_file
            if file_path.exists():
                cached = CachedFile.from_path(file_path)
                if cached:
                    self.cache.other_files[named_file] = cached
    
    def validate_gdscript_file(self, cached_file: CachedFile) -> None:
        """Validate a GDScript file for violations."""
        file_path = cached_file.path
        lines = cached_file.lines
        
        self.log(f"Checking {file_path.name}")
        
        is_ui_exception = any(exc in file_path.name for exc in self.ui_creation_exceptions)
        
        for line_num, line in enumerate(lines, 1):
            # Rule 1: UI Creation in Code
            if not is_ui_exception:
                for pattern, msg in self.ui_creation_patterns:
                    if re.search(pattern, line, re.IGNORECASE):
                        self.add_violation(file_path, line_num, "UI_IN_CODE",
                            f"{msg}. Consider using a .tscn scene file instead.", severity="warning")
            
            # Rule 2: Command function signature consistency
            if file_path.name.startswith('commands_'):
                if re.match(r'^func\s+cmd_\w+\s*\(', line):
                    if not self.command_signature_pattern.match(line):
                        if 'params' not in line and '_params' not in line:
                            self.add_violation(file_path, line_num, "CMD_SIGNATURE",
                                "Command function missing 'params: Dictionary' parameter", severity="error")
            
            # Rule 3: Check for deprecated calls
            if 'get_scene_root(cmd_id)' in line:
                self.add_violation(file_path, line_num, "DEPRECATED_CALL",
                    "Use _get_scene_root() without cmd_id after _require_scene() check", severity="warning")
            
            # Rule 4: Async race patterns
            if 'send_prompt' not in file_path.name:
                for pattern, msg in self.async_race_patterns:
                    if re.search(pattern, line):
                        self.add_violation(file_path, line_num, "ASYNC_RACE",
                            f"{msg} - use flag-based communication instead", severity="info")
            
            # Rule 5: Const naming shadowing
            shadow_match = re.match(r'^const\s+(Codot\w*)\s*=\s*preload\(', line)
            if shadow_match:
                const_name = shadow_match.group(1)
                if not const_name.endswith('Ref') and not const_name.endswith('Class'):
                    self.add_violation(file_path, line_num, "SHADOW_GLOBAL",
                        f"Const '{const_name}' may shadow global class. Consider '{const_name}Ref'", severity="warning")
            
            # Rule 6: Hardcoded port numbers
            for pattern, msg in self.hardcoded_patterns:
                if re.search(pattern, line):
                    if '#' in line and ('port' in line.lower() or 'default' in line.lower()):
                        continue
                    skip = any(re.search(ep, line) for ep in self.hardcoded_exclude_patterns)
                    if not skip:
                        self.add_violation(file_path, line_num, "HARDCODED_VALUE", msg, severity="info")
            
            # Rule 7: Public functions without return types
            public_func_match = re.match(r'^func\s+([a-z_]\w*)\s*\([^)]*\)\s*(?:->|:)', line)
            if public_func_match and '->' not in line:
                func_name = public_func_match.group(1)
                if not func_name.startswith('_') and not func_name.startswith('test_'):
                    self.add_violation(file_path, line_num, "MISSING_RETURN_TYPE",
                        f"Public function '{func_name}' missing return type annotation", severity="info")
    
    def validate_python_file(self, cached_file: CachedFile) -> None:
        """Validate a Python file for violations."""
        self.log(f"Checking {cached_file.path.name}")
        
        for line_num, line in enumerate(cached_file.lines, 1):
            for pattern, msg in self.python_inline_patterns:
                if re.search(pattern, line):
                    self.add_violation(cached_file.path, line_num, "INLINE_PYTHON", msg, severity="warning")
    
    def validate_scene_file(self, cached_file: CachedFile) -> None:
        """Validate a scene (.tscn) file for violations."""
        self.log(f"Checking {cached_file.path.name}")
    
    def validate_uid_references(self) -> None:
        """Validate that all UID references point to existing files."""
        self.log("Checking UID references...")
        
        uid_pattern = re.compile(r'uid="(uid://[a-z0-9]+)"')
        uid_reference_pattern = re.compile(r'["=](uid://[a-z0-9]+)["\s\n]')
        
        # Collect all valid UIDs from cached files
        valid_uids: set[str] = set()
        
        for cached in self.cache.scene_files + self.cache.resource_files:
            for match in uid_pattern.finditer(cached.content):
                valid_uids.add(match.group(1))
        
        for cached in self.cache.uid_files:
            content = cached.content.strip()
            if content.startswith('uid://'):
                valid_uids.add(content)
        
        self.log(f"Found {len(valid_uids)} valid UIDs")
        
        # Check references in scene and resource files
        files_to_check = self.cache.scene_files + self.cache.resource_files
        if 'project.godot' in self.cache.other_files:
            files_to_check.append(self.cache.other_files['project.godot'])
        
        for cached in files_to_check:
            for line_num, line in enumerate(cached.lines, 1):
                for match in uid_reference_pattern.finditer(line):
                    uid = match.group(1)
                    if f'uid="{uid}"' in line:
                        continue
                    if uid not in valid_uids:
                        self.add_violation(cached.path, line_num, "INVALID_UID",
                            f"Reference to non-existent UID: {uid}", severity="error")

    def validate_directory_structure(self) -> None:
        """Validate the project directory structure."""
        required_dirs = [
            'addons/codot/commands',
            'mcp-server/codot',
            'mcp-server/tests',
            'test/unit',
        ]
        
        for dir_path in required_dirs:
            if not (self.root_path / dir_path).exists():
                self.add_violation(self.root_path, 0, "MISSING_DIR",
                    f"Required directory missing: {dir_path}", severity="error")
    
    def validate_command_registration(self) -> None:
        """Check that all command functions are registered in command_handler.gd."""
        handler_cached = None
        for cached in self.cache.gdscript_files:
            if cached.path.name == 'command_handler.gd':
                handler_cached = cached
                break
        
        if not handler_cached:
            return
        
        handler_content = handler_cached.content
        
        for cached in self.cache.gdscript_files:
            if not cached.path.name.startswith('commands_'):
                continue
            
            for match in re.finditer(r'^func\s+(cmd_\w+)\s*\(', cached.content, re.MULTILINE):
                func_name = match.group(1)
                if func_name not in handler_content:
                    self.add_violation(cached.path, 0, "UNREGISTERED_CMD",
                        f"Command function '{func_name}' not found in command_handler.gd", severity="warning")
    
    def validate_python_command_definitions(self) -> None:
        """Check that all GDScript commands have Python definitions."""
        handler_cached = None
        py_commands_cached = None
        
        for cached in self.cache.gdscript_files:
            if cached.path.name == 'command_handler.gd':
                handler_cached = cached
                break
        
        for cached in self.cache.python_files:
            if cached.path.name == 'commands.py':
                py_commands_cached = cached
                break
        
        if not handler_cached or not py_commands_cached:
            return
        
        handler_commands = set()
        for match in re.finditer(r'^\s+"(\w+)":\s*$', handler_cached.content, re.MULTILINE):
            handler_commands.add(match.group(1))
        
        py_commands = set()
        for match in re.finditer(r'^\s+"(\w+)":\s*CommandDefinition\(', py_commands_cached.content, re.MULTILINE):
            py_commands.add(match.group(1))
        
        missing_py = handler_commands - py_commands
        for cmd in missing_py:
            if cmd not in ['ping']:
                self.add_violation(py_commands_cached.path, 0, "MISSING_PY_DEF",
                    f"Command '{cmd}' defined in GDScript but missing Python CommandDefinition", severity="warning")
    
    def run(self) -> int:
        """Run all validations and return exit code."""
        print(f"Validating codebase at: {self.root_path}")
        print("=" * 60)
        
        print("\n[1/6] Caching project files...")
        self.cache_all_files()
        
        print("\n[2/6] Checking directory structure...")
        self.validate_directory_structure()
        
        print("\n[3/6] Checking GDScript files...")
        for cached in self.cache.gdscript_files:
            self.validate_gdscript_file(cached)
        
        print("\n[4/6] Checking Python files...")
        for cached in self.cache.python_files:
            self.validate_python_file(cached)
        
        print("\n[5/6] Checking scene files...")
        for cached in self.cache.scene_files:
            self.validate_scene_file(cached)
        
        print("\n[6/6] Checking command registration and UID references...")
        self.validate_command_registration()
        self.validate_python_command_definitions()
        self.validate_uid_references()
        
        print("\n" + "=" * 60)
        
        if not self.violations:
            print("✅ No violations found!")
            return 0
        
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
        
        total_files = (len(self.cache.gdscript_files) + len(self.cache.python_files) + 
                       len(self.cache.scene_files) + len(self.cache.resource_files))
        print(f"Files checked: {total_files}")
        
        return 1 if errors else 0


def main():
    parser = argparse.ArgumentParser(description="Validate Codot codebase for coding standard violations")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show verbose output")
    parser.add_argument("--path", "-p", type=str, default=None, help="Path to project root")
    
    args = parser.parse_args()
    
    if args.path:
        root_path = Path(args.path)
    else:
        script_path = Path(__file__).resolve()
        root_path = script_path.parent.parent
        
        if not (root_path / 'addons' / 'codot').exists():
            root_path = Path.cwd()
            if not (root_path / 'addons' / 'codot').exists():
                print("Error: Could not find Codot project root")
                print("Run from project root or use --path option")
                return 2
    
    validator = CodebaseValidator(root_path, verbose=args.verbose)
    return validator.run()


if __name__ == "__main__":
    sys.exit(main())
