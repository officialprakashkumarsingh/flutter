#!/usr/bin/env python3
"""
File Operations Tool for Flutter Coder App
Provides file reading, editing, deleting, and other file system operations.
Enhanced with robust path handling and working directory detection.
"""

import os
import sys
import json
import argparse
import shutil
from pathlib import Path
from typing import Dict, Any, List, Optional

class FileOperations:
    def __init__(self, base_path: str = "."):
        # Enhanced base path resolution with multiple fallbacks
        self.original_base_path = base_path
        
        # Try to resolve the base path with various strategies
        if os.path.isabs(base_path):
            # Absolute path provided
            self.base_path = Path(base_path)
        else:
            # Relative path - try current working directory first
            current_dir = Path.cwd()
            candidate_path = current_dir / base_path
            
            if candidate_path.exists():
                self.base_path = candidate_path.resolve()
            else:
                # Fallback to current directory
                self.base_path = current_dir
        
        # Ensure the base path exists and is accessible
        if not self.base_path.exists():
            try:
                self.base_path.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                # Final fallback to current directory
                self.base_path = Path.cwd()
    
    def _get_safe_path(self, file_path: str) -> Path:
        """Get a safe, resolved path for file operations."""
        if os.path.isabs(file_path):
            return Path(file_path)
        else:
            return self.base_path / file_path
    
    def _get_environment_info(self) -> Dict[str, Any]:
        """Get comprehensive environment information for debugging."""
        return {
            "cwd": str(Path.cwd()),
            "base_path": str(self.base_path),
            "base_path_exists": self.base_path.exists(),
            "base_path_readable": os.access(self.base_path, os.R_OK),
            "base_path_writable": os.access(self.base_path, os.W_OK),
            "python_version": sys.version,
            "script_location": str(Path(__file__).resolve()),
            "args": sys.argv
        }
    
    def read_file(self, file_path: str, start_line: Optional[int] = None, end_line: Optional[int] = None) -> Dict[str, Any]:
        """Read a file or specific lines from a file."""
        try:
            full_path = self._get_safe_path(file_path)
            
            if not full_path.exists():
                # Try alternative locations
                alternatives = [
                    Path.cwd() / file_path,
                    Path.cwd() / "lib" / file_path,
                    Path.cwd() / "src" / file_path,
                ]
                
                found_path = None
                for alt_path in alternatives:
                    if alt_path.exists():
                        found_path = alt_path
                        break
                
                if found_path:
                    full_path = found_path
                else:
                    return {
                        "success": False,
                        "error": f"File not found: {file_path}",
                        "operation": "read_file",
                        "searched_paths": [str(p) for p in [full_path] + alternatives],
                        "environment": self._get_environment_info()
                    }
            
            with open(full_path, 'r', encoding='utf-8', errors='replace') as f:
                lines = f.readlines()
            
            # If specific line range requested
            if start_line is not None or end_line is not None:
                start_idx = (start_line - 1) if start_line else 0
                end_idx = end_line if end_line else len(lines)
                lines = lines[start_idx:end_idx]
                content = ''.join(lines)
                line_info = f"lines {start_line or 1}-{end_line or len(lines)}"
            else:
                content = ''.join(lines)
                line_info = f"full file ({len(lines)} lines)"
            
            return {
                "success": True,
                "content": content,
                "line_count": len(lines),
                "file_path": file_path,
                "resolved_path": str(full_path),
                "operation": "read_file",
                "info": f"Read {line_info}",
                "environment": self._get_environment_info()
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to read file: {str(e)}",
                "operation": "read_file",
                "file_path": file_path,
                "environment": self._get_environment_info()
            }

    def write_file(self, file_path: str, content: str, mode: str = "w") -> Dict[str, Any]:
        """Write content to a file with enhanced path handling."""
        try:
            full_path = self._get_safe_path(file_path)
            
            # Ensure directory exists
            full_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write the file
            with open(full_path, mode, encoding='utf-8') as f:
                f.write(content)
            
            # Verify the write was successful
            if full_path.exists():
                actual_size = full_path.stat().st_size
                with open(full_path, 'r', encoding='utf-8') as f:
                    written_content = f.read()
                
                return {
                    "success": True,
                    "file_path": file_path,
                    "resolved_path": str(full_path),
                    "operation": "write_file",
                    "info": f"{'Created' if mode == 'w' else 'Appended to'} file with {len(content)} characters",
                    "size_bytes": len(content.encode('utf-8')),
                    "actual_file_size": actual_size,
                    "verification": {
                        "content_matches": written_content == content,
                        "expected_length": len(content),
                        "actual_length": len(written_content)
                    },
                    "environment": self._get_environment_info()
                }
            else:
                return {
                    "success": False,
                    "error": "File was not created (verification failed)",
                    "operation": "write_file",
                    "file_path": file_path,
                    "resolved_path": str(full_path),
                    "environment": self._get_environment_info()
                }
            
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to write file: {str(e)}",
                "operation": "write_file",
                "file_path": file_path,
                "environment": self._get_environment_info()
            }
    
    def edit_file(self, file_path: str, old_content: str, new_content: str) -> Dict[str, Any]:
        """Edit a file by replacing old content with new content."""
        try:
            full_path = self._get_safe_path(file_path)
            
            if not full_path.exists():
                return {
                    "success": False,
                    "error": f"File not found: {file_path}",
                    "operation": "edit_file",
                    "resolved_path": str(full_path),
                    "environment": self._get_environment_info()
                }
            
            with open(full_path, 'r', encoding='utf-8', errors='replace') as f:
                content = f.read()
            
            if old_content and old_content not in content:
                return {
                    "success": False,
                    "error": "Old content not found in file",
                    "operation": "edit_file",
                    "file_path": file_path,
                    "resolved_path": str(full_path),
                    "searched_for": old_content[:100] + "..." if len(old_content) > 100 else old_content,
                    "environment": self._get_environment_info()
                }
            
            # Replace content
            if old_content:
                new_file_content = content.replace(old_content, new_content, 1)  # Replace only first occurrence
            else:
                # If no old content specified, append new content
                new_file_content = content + new_content
            
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(new_file_content)
            
            return {
                "success": True,
                "file_path": file_path,
                "resolved_path": str(full_path),
                "operation": "edit_file",
                "info": f"Replaced content in file",
                "changes": {
                    "old_length": len(old_content),
                    "new_length": len(new_content),
                    "file_size": len(new_file_content.encode('utf-8'))
                },
                "environment": self._get_environment_info()
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to edit file: {str(e)}",
                "operation": "edit_file",
                "file_path": file_path,
                "environment": self._get_environment_info()
            }

    def delete_file(self, file_path: str) -> Dict[str, Any]:
        """Delete a file."""
        try:
            full_path = self._get_safe_path(file_path)
            
            if not full_path.exists():
                return {
                    "success": False,
                    "error": f"File not found: {file_path}",
                    "operation": "delete_file",
                    "resolved_path": str(full_path),
                    "environment": self._get_environment_info()
                }
            
            full_path.unlink()
            
            return {
                "success": True,
                "file_path": file_path,
                "resolved_path": str(full_path),
                "operation": "delete_file",
                "info": f"Deleted file",
                "environment": self._get_environment_info()
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to delete file: {str(e)}",
                "operation": "delete_file",
                "file_path": file_path,
                "environment": self._get_environment_info()
            }

    def list_directory(self, dir_path: str = ".", include_hidden: bool = False) -> Dict[str, Any]:
        """List directory contents."""
        try:
            full_path = self._get_safe_path(dir_path)
            
            if not full_path.exists():
                return {
                    "success": False,
                    "error": f"Directory not found: {dir_path}",
                    "operation": "list_directory",
                    "resolved_path": str(full_path),
                    "environment": self._get_environment_info()
                }
            
            if not full_path.is_dir():
                return {
                    "success": False,
                    "error": f"Path is not a directory: {dir_path}",
                    "operation": "list_directory",
                    "resolved_path": str(full_path),
                    "environment": self._get_environment_info()
                }
            
            items = []
            for item in full_path.iterdir():
                if not include_hidden and item.name.startswith('.'):
                    continue
                
                item_info = {
                    "name": item.name,
                    "path": str(item.relative_to(self.base_path)),
                    "is_file": item.is_file(),
                    "is_directory": item.is_dir(),
                }
                
                if item.is_file():
                    item_info["size_bytes"] = item.stat().st_size
                
                items.append(item_info)
            
            return {
                "success": True,
                "directory": dir_path,
                "resolved_path": str(full_path),
                "items": items,
                "total_items": len(items),
                "operation": "list_directory",
                "environment": self._get_environment_info()
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to list directory: {str(e)}",
                "operation": "list_directory",
                "directory": dir_path,
                "environment": self._get_environment_info()
            }

    def create_directory(self, dir_path: str) -> Dict[str, Any]:
        """Create a directory."""
        try:
            full_path = self._get_safe_path(dir_path)
            full_path.mkdir(parents=True, exist_ok=True)
            
            return {
                "success": True,
                "directory": dir_path,
                "resolved_path": str(full_path),
                "operation": "create_directory",
                "info": f"Created directory",
                "environment": self._get_environment_info()
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to create directory: {str(e)}",
                "operation": "create_directory",
                "directory": dir_path,
                "environment": self._get_environment_info()
            }

    def search_files(self, pattern: str, dir_path: str = ".", file_extensions: Optional[List[str]] = None) -> Dict[str, Any]:
        """Search for files matching a pattern."""
        try:
            full_path = self._get_safe_path(dir_path)
            
            if not full_path.exists():
                return {
                    "success": False,
                    "error": f"Directory not found: {dir_path}",
                    "operation": "search_files",
                    "resolved_path": str(full_path),
                    "environment": self._get_environment_info()
                }
            
            matches = []
            
            for item in full_path.rglob(pattern):
                if item.is_file():
                    if file_extensions:
                        if not any(item.name.endswith(ext) for ext in file_extensions):
                            continue
                    
                    matches.append({
                        "name": item.name,
                        "path": str(item.relative_to(self.base_path)),
                        "size_bytes": item.stat().st_size
                    })
            
            return {
                "success": True,
                "pattern": pattern,
                "directory": dir_path,
                "resolved_path": str(full_path),
                "matches": matches,
                "total_matches": len(matches),
                "operation": "search_files",
                "environment": self._get_environment_info()
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to search files: {str(e)}",
                "operation": "search_files",
                "pattern": pattern,
                "directory": dir_path,
                "environment": self._get_environment_info()
            }

def main():
    parser = argparse.ArgumentParser(description="Enhanced File Operations Tool")
    parser.add_argument("operation", choices=[
        "read_file", "write_file", "edit_file", "delete_file", 
        "list_directory", "create_directory", "search_files", "environment_info"
    ])
    parser.add_argument("--base-path", default=".", help="Base path for operations")
    parser.add_argument("--file-path", help="File path")
    parser.add_argument("--dir-path", help="Directory path")
    parser.add_argument("--content", help="Content to write", default="")
    parser.add_argument("--old-content", help="Old content to replace", default="")
    parser.add_argument("--new-content", help="New content to replace with", default="")
    parser.add_argument("--start-line", type=int, help="Start line for reading")
    parser.add_argument("--end-line", type=int, help="End line for reading")
    parser.add_argument("--pattern", help="Search pattern")
    parser.add_argument("--extensions", nargs="*", help="File extensions to filter")
    parser.add_argument("--include-hidden", action="store_true", help="Include hidden files")
    parser.add_argument("--mode", default="w", help="Write mode (w, a)")
    
    args = parser.parse_args()
    
    # Enhanced debug logging
    print(f"DEBUG: Operation={args.operation}, CWD={os.getcwd()}", file=sys.stderr)
    print(f"DEBUG: Base path={args.base_path}, File path={args.file_path}", file=sys.stderr)
    print(f"DEBUG: Content length={len(args.content or '')}", file=sys.stderr)
    
    file_ops = FileOperations(args.base_path)
    result = None
    
    try:
        if args.operation == "environment_info":
            result = {
                "success": True,
                "operation": "environment_info",
                "environment": file_ops._get_environment_info()
            }
        elif args.operation == "read_file":
            if not args.file_path:
                raise ValueError("--file-path is required for read_file")
            result = file_ops.read_file(args.file_path, args.start_line, args.end_line)
            
        elif args.operation == "write_file":
            if not args.file_path:
                raise ValueError("--file-path is required for write_file")
            result = file_ops.write_file(args.file_path, args.content or "", args.mode)
            
        elif args.operation == "edit_file":
            if not args.file_path:
                raise ValueError("--file-path is required for edit_file")
            result = file_ops.edit_file(args.file_path, args.old_content or "", args.new_content or "")
            
        elif args.operation == "delete_file":
            if not args.file_path:
                raise ValueError("--file-path is required for delete_file")
            result = file_ops.delete_file(args.file_path)
            
        elif args.operation == "list_directory":
            dir_path = args.dir_path or "."
            result = file_ops.list_directory(dir_path, args.include_hidden)
            
        elif args.operation == "create_directory":
            if not args.dir_path:
                raise ValueError("--dir-path is required for create_directory")
            result = file_ops.create_directory(args.dir_path)
            
        elif args.operation == "search_files":
            if not args.pattern:
                raise ValueError("--pattern is required for search_files")
            dir_path = args.dir_path or "."
            result = file_ops.search_files(args.pattern, dir_path, args.extensions)
        
        if result is None:
            result = {"success": False, "error": "Unknown operation"}
            
    except Exception as e:
        result = {
            "success": False,
            "error": f"Operation failed: {str(e)}",
            "operation": args.operation,
            "environment": file_ops._get_environment_info()
        }
    
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()