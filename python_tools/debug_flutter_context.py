#!/usr/bin/env python3
"""
Debug tool to understand Flutter app execution context
"""

import os
import sys
import json
import argparse
from pathlib import Path

def debug_flutter_context():
    """Debug the execution context when called from Flutter app"""
    
    debug_info = {
        "success": True,
        "operation": "debug_flutter_context",
        "execution_context": {
            "current_working_directory": os.getcwd(),
            "script_location": str(Path(__file__).resolve()),
            "script_parent": str(Path(__file__).parent.resolve()),
            "args_received": sys.argv,
            "environment_variables": {
                "HOME": os.environ.get("HOME"),
                "USER": os.environ.get("USER"),
                "PATH": os.environ.get("PATH", "")[:200] + "...",  # Truncated for readability
                "PWD": os.environ.get("PWD"),
            }
        },
        "file_system_analysis": {
            "current_dir_contents": [],
            "parent_dir_contents": [],
            "workspace_exists": os.path.exists("/workspace"),
            "workspace_writable": os.access("/workspace", os.W_OK) if os.path.exists("/workspace") else False,
        },
        "flutter_project_detection": {
            "pubspec_yaml_exists": False,
            "lib_dir_exists": False,
            "android_dir_exists": False,
            "detected_project_root": None,
        },
        "test_operations": {}
    }
    
    # Analyze current directory contents
    try:
        current_dir = Path.cwd()
        debug_info["file_system_analysis"]["current_dir_contents"] = [
            {"name": item.name, "is_dir": item.is_dir(), "size": item.stat().st_size if item.is_file() else 0}
            for item in current_dir.iterdir()
        ][:20]  # Limit to first 20 items
    except Exception as e:
        debug_info["file_system_analysis"]["current_dir_error"] = str(e)
    
    # Analyze parent directory
    try:
        parent_dir = current_dir.parent
        debug_info["file_system_analysis"]["parent_dir_contents"] = [
            {"name": item.name, "is_dir": item.is_dir()}
            for item in parent_dir.iterdir()
        ][:20]  # Limit to first 20 items
    except Exception as e:
        debug_info["file_system_analysis"]["parent_dir_error"] = str(e)
    
    # Flutter project detection
    try:
        # Check for Flutter project indicators
        current_path = Path.cwd()
        for check_path in [current_path, current_path.parent, current_path.parent.parent]:
            if (check_path / "pubspec.yaml").exists():
                debug_info["flutter_project_detection"]["pubspec_yaml_exists"] = True
                debug_info["flutter_project_detection"]["detected_project_root"] = str(check_path)
                break
        
        # Check specific directories
        debug_info["flutter_project_detection"]["lib_dir_exists"] = (current_path / "lib").exists()
        debug_info["flutter_project_detection"]["android_dir_exists"] = (current_path / "android").exists()
        
    except Exception as e:
        debug_info["flutter_project_detection"]["error"] = str(e)
    
    # Test file operations in various locations
    test_locations = [
        ".",
        "/workspace",
        os.getcwd(),
        str(Path.cwd() / "test_files"),
    ]
    
    for location in test_locations:
        location_key = f"test_in_{location.replace('/', '_').replace('.', 'current')}"
        try:
            # Ensure directory exists
            Path(location).mkdir(parents=True, exist_ok=True)
            
            # Test file creation
            test_file = Path(location) / "flutter_debug_test.txt"
            test_content = f"Test from Flutter debug in {location}"
            
            # Write test file
            with open(test_file, 'w') as f:
                f.write(test_content)
            
            # Verify file was created
            if test_file.exists():
                with open(test_file, 'r') as f:
                    read_content = f.read()
                
                debug_info["test_operations"][location_key] = {
                    "success": True,
                    "file_path": str(test_file),
                    "content_written": test_content,
                    "content_read": read_content,
                    "content_matches": test_content == read_content,
                    "file_size": test_file.stat().st_size,
                }
                
                # Clean up
                test_file.unlink()
            else:
                debug_info["test_operations"][location_key] = {
                    "success": False,
                    "error": "File was not created"
                }
                
        except Exception as e:
            debug_info["test_operations"][location_key] = {
                "success": False,
                "error": str(e)
            }
    
    return debug_info

def main():
    parser = argparse.ArgumentParser(description="Debug Flutter execution context")
    parser.add_argument("--operation", default="debug", help="Operation to perform")
    parser.add_argument("--format", choices=["json", "pretty"], default="json", help="Output format")
    
    args = parser.parse_args()
    
    if args.operation == "debug":
        result = debug_flutter_context()
    else:
        result = {
            "success": False,
            "error": f"Unknown operation: {args.operation}"
        }
    
    if args.format == "pretty":
        print("=== FLUTTER DEBUG CONTEXT ===")
        print(f"Working Directory: {result.get('execution_context', {}).get('current_working_directory', 'Unknown')}")
        print(f"Script Location: {result.get('execution_context', {}).get('script_location', 'Unknown')}")
        print(f"Flutter Project Root: {result.get('flutter_project_detection', {}).get('detected_project_root', 'Not found')}")
        print("\nTest Operations:")
        for location, test_result in result.get('test_operations', {}).items():
            status = "✅ SUCCESS" if test_result.get('success') else "❌ FAILED"
            print(f"  {location}: {status}")
            if not test_result.get('success'):
                print(f"    Error: {test_result.get('error')}")
    else:
        print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()