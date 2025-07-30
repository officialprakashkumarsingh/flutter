#!/usr/bin/env python3
"""
File Operations Tool for Flutter Coder App
Provides file reading, editing, deleting, and other file system operations.
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
        self.base_path = Path(base_path).resolve()
    
    def read_file(self, file_path: str, start_line: Optional[int] = None, end_line: Optional[int] = None) -> Dict[str, Any]:
        """Read a file or specific lines from a file."""
        try:
            full_path = self.base_path / file_path
            if not full_path.exists():
                return {
                    "success": False,
                    "error": f"File not found: {file_path}",
                    "operation": "read_file"
                }
            
            with open(full_path, 'r', encoding='utf-8') as f:
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
                "operation": "read_file",
                "info": f"Read {line_info}",
                "size_bytes": len(content.encode('utf-8'))
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to read file: {str(e)}",
                "operation": "read_file"
            }
    
    def write_file(self, file_path: str, content: str, mode: str = "w") -> Dict[str, Any]:
        """Write content to a file."""
        try:
            full_path = self.base_path / file_path
            full_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(full_path, mode, encoding='utf-8') as f:
                f.write(content)
            
            return {
                "success": True,
                "file_path": file_path,
                "operation": "write_file",
                "info": f"{'Created' if mode == 'w' else 'Appended to'} file with {len(content)} characters",
                "size_bytes": len(content.encode('utf-8'))
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to write file: {str(e)}",
                "operation": "write_file"
            }
    
    def edit_file(self, file_path: str, old_content: str, new_content: str) -> Dict[str, Any]:
        """Edit a file by replacing old content with new content."""
        try:
            full_path = self.base_path / file_path
            if not full_path.exists():
                return {
                    "success": False,
                    "error": f"File not found: {file_path}",
                    "operation": "edit_file"
                }
            
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if old_content not in content:
                return {
                    "success": False,
                    "error": "Old content not found in file",
                    "operation": "edit_file"
                }
            
            new_file_content = content.replace(old_content, new_content, 1)  # Replace only first occurrence
            
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(new_file_content)
            
            return {
                "success": True,
                "file_path": file_path,
                "operation": "edit_file",
                "info": f"Replaced content in file",
                "changes": {
                    "old_length": len(old_content),
                    "new_length": len(new_content),
                    "file_size": len(new_file_content.encode('utf-8'))
                }
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to edit file: {str(e)}",
                "operation": "edit_file"
            }
    
    def delete_file(self, file_path: str) -> Dict[str, Any]:
        """Delete a file."""
        try:
            full_path = self.base_path / file_path
            if not full_path.exists():
                return {
                    "success": False,
                    "error": f"File not found: {file_path}",
                    "operation": "delete_file"
                }
            
            full_path.unlink()
            
            return {
                "success": True,
                "file_path": file_path,
                "operation": "delete_file",
                "info": "File deleted successfully"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to delete file: {str(e)}",
                "operation": "delete_file"
            }
    
    def list_directory(self, dir_path: str = ".", include_hidden: bool = False) -> Dict[str, Any]:
        """List directory contents."""
        try:
            full_path = self.base_path / dir_path
            if not full_path.exists():
                return {
                    "success": False,
                    "error": f"Directory not found: {dir_path}",
                    "operation": "list_directory"
                }
            
            if not full_path.is_dir():
                return {
                    "success": False,
                    "error": f"Path is not a directory: {dir_path}",
                    "operation": "list_directory"
                }
            
            items = []
            for item in full_path.iterdir():
                if not include_hidden and item.name.startswith('.'):
                    continue
                
                item_info = {
                    "name": item.name,
                    "path": str(item.relative_to(self.base_path)),
                    "is_directory": item.is_dir(),
                    "is_file": item.is_file(),
                }
                
                if item.is_file():
                    item_info["size_bytes"] = item.stat().st_size
                
                items.append(item_info)
            
            return {
                "success": True,
                "directory": dir_path,
                "items": sorted(items, key=lambda x: (not x["is_directory"], x["name"])),
                "total_items": len(items),
                "operation": "list_directory"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to list directory: {str(e)}",
                "operation": "list_directory"
            }
    
    def create_directory(self, dir_path: str) -> Dict[str, Any]:
        """Create a directory."""
        try:
            full_path = self.base_path / dir_path
            full_path.mkdir(parents=True, exist_ok=True)
            
            return {
                "success": True,
                "directory": dir_path,
                "operation": "create_directory",
                "info": "Directory created successfully"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to create directory: {str(e)}",
                "operation": "create_directory"
            }
    
    def search_files(self, pattern: str, dir_path: str = ".", file_extensions: Optional[List[str]] = None) -> Dict[str, Any]:
        """Search for files matching a pattern."""
        try:
            full_path = self.base_path / dir_path
            if not full_path.exists():
                return {
                    "success": False,
                    "error": f"Directory not found: {dir_path}",
                    "operation": "search_files"
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
                "matches": matches,
                "total_matches": len(matches),
                "operation": "search_files"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to search files: {str(e)}",
                "operation": "search_files"
            }

def main():
    parser = argparse.ArgumentParser(description="File Operations Tool")
    parser.add_argument("operation", choices=[
        "read_file", "write_file", "edit_file", "delete_file", 
        "list_directory", "create_directory", "search_files"
    ])
    parser.add_argument("--base-path", default=".", help="Base path for operations")
    parser.add_argument("--file-path", help="File path")
    parser.add_argument("--dir-path", help="Directory path")
    parser.add_argument("--content", help="Content to write")
    parser.add_argument("--old-content", help="Old content to replace")
    parser.add_argument("--new-content", help="New content to replace with")
    parser.add_argument("--start-line", type=int, help="Start line for reading")
    parser.add_argument("--end-line", type=int, help="End line for reading")
    parser.add_argument("--pattern", help="Search pattern")
    parser.add_argument("--extensions", nargs="*", help="File extensions to filter")
    parser.add_argument("--include-hidden", action="store_true", help="Include hidden files")
    parser.add_argument("--mode", default="w", help="Write mode (w, a)")
    
    args = parser.parse_args()
    
    file_ops = FileOperations(args.base_path)
    result = None
    
    try:
        if args.operation == "read_file":
            if not args.file_path:
                raise ValueError("--file-path is required for read_file")
            result = file_ops.read_file(args.file_path, args.start_line, args.end_line)
            
        elif args.operation == "write_file":
            if not args.file_path or args.content is None:
                raise ValueError("--file-path and --content are required for write_file")
            result = file_ops.write_file(args.file_path, args.content, args.mode)
            
        elif args.operation == "edit_file":
            if not all([args.file_path, args.old_content is not None, args.new_content is not None]):
                raise ValueError("--file-path, --old-content, and --new-content are required for edit_file")
            result = file_ops.edit_file(args.file_path, args.old_content, args.new_content)
            
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
            "operation": args.operation
        }
    
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()