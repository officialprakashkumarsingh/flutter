#!/usr/bin/env python3
"""
Code Analysis Tool for Flutter Coder App
Provides code structure analysis, dependency mapping, and planning assistance.
"""

import os
import sys
import json
import argparse
import re
from pathlib import Path
from typing import Dict, Any, List, Optional, Set
import ast

class CodeAnalysis:
    def __init__(self, base_path: str = "."):
        self.base_path = Path(base_path).resolve()
        self.supported_extensions = {
            '.py': 'python',
            '.dart': 'dart',
            '.js': 'javascript',
            '.ts': 'typescript',
            '.java': 'java',
            '.kt': 'kotlin',
            '.swift': 'swift',
            '.cpp': 'cpp',
            '.c': 'c',
            '.h': 'header',
            '.hpp': 'header',
            '.json': 'json',
            '.yaml': 'yaml',
            '.yml': 'yaml',
            '.md': 'markdown',
            '.txt': 'text'
        }
    
    def analyze_project_structure(self, max_depth: int = 3) -> Dict[str, Any]:
        """Analyze the overall project structure."""
        try:
            structure = self._build_directory_tree(self.base_path, max_depth)
            file_stats = self._get_file_statistics()
            dependencies = self._analyze_dependencies()
            
            return {
                "success": True,
                "structure": structure,
                "statistics": file_stats,
                "dependencies": dependencies,
                "operation": "analyze_project_structure"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to analyze project structure: {str(e)}",
                "operation": "analyze_project_structure"
            }
    
    def _build_directory_tree(self, path: Path, max_depth: int, current_depth: int = 0) -> Dict[str, Any]:
        """Build a directory tree structure."""
        if current_depth >= max_depth:
            return {"type": "truncated", "reason": "max_depth_reached"}
        
        if not path.is_dir():
            return {"type": "file", "size": path.stat().st_size if path.exists() else 0}
        
        children = {}
        try:
            for item in path.iterdir():
                if item.name.startswith('.') and item.name not in ['.git', '.github']:
                    continue
                children[item.name] = self._build_directory_tree(item, max_depth, current_depth + 1)
        except PermissionError:
            return {"type": "directory", "error": "permission_denied"}
        
        return {"type": "directory", "children": children}
    
    def _get_file_statistics(self) -> Dict[str, Any]:
        """Get file statistics for the project."""
        stats = {
            "total_files": 0,
            "total_directories": 0,
            "files_by_language": {},
            "total_size_bytes": 0,
            "largest_files": []
        }
        
        file_sizes = []
        
        for item in self.base_path.rglob("*"):
            if item.is_file():
                stats["total_files"] += 1
                size = item.stat().st_size
                stats["total_size_bytes"] += size
                
                ext = item.suffix.lower()
                lang = self.supported_extensions.get(ext, 'other')
                stats["files_by_language"][lang] = stats["files_by_language"].get(lang, 0) + 1
                
                file_sizes.append({
                    "path": str(item.relative_to(self.base_path)),
                    "size": size
                })
            elif item.is_dir():
                stats["total_directories"] += 1
        
        # Get top 10 largest files
        stats["largest_files"] = sorted(file_sizes, key=lambda x: x["size"], reverse=True)[:10]
        
        return stats
    
    def _analyze_dependencies(self) -> Dict[str, Any]:
        """Analyze project dependencies."""
        dependencies = {
            "package_files": [],
            "import_patterns": {},
            "external_dependencies": set(),
            "internal_modules": set()
        }
        
        # Look for package files
        package_files = [
            "pubspec.yaml",  # Flutter/Dart
            "package.json",  # Node.js
            "requirements.txt",  # Python
            "Pipfile",  # Python Pipenv
            "setup.py",  # Python
            "Cargo.toml",  # Rust
            "pom.xml",  # Maven/Java
            "build.gradle",  # Gradle
            "composer.json"  # PHP
        ]
        
        for pkg_file in package_files:
            pkg_path = self.base_path / pkg_file
            if pkg_path.exists():
                dependencies["package_files"].append(pkg_file)
        
        # Analyze imports in source files
        for item in self.base_path.rglob("*"):
            if item.is_file() and item.suffix in ['.dart', '.py', '.js', '.ts']:
                try:
                    imports = self._extract_imports(item)
                    if imports:
                        dependencies["import_patterns"][str(item.relative_to(self.base_path))] = imports
                except Exception:
                    continue
        
        # Convert sets to lists for JSON serialization
        dependencies["external_dependencies"] = list(dependencies["external_dependencies"])
        dependencies["internal_modules"] = list(dependencies["internal_modules"])
        
        return dependencies
    
    def _extract_imports(self, file_path: Path) -> List[str]:
        """Extract import statements from a file."""
        imports = []
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if file_path.suffix == '.dart':
                # Dart imports
                import_pattern = r"import\s+['\"]([^'\"]+)['\"]"
                imports = re.findall(import_pattern, content)
            elif file_path.suffix == '.py':
                # Python imports
                import_pattern = r"(?:from\s+(\S+)\s+import|import\s+(\S+))"
                matches = re.findall(import_pattern, content)
                imports = [match[0] or match[1] for match in matches]
            elif file_path.suffix in ['.js', '.ts']:
                # JavaScript/TypeScript imports
                import_pattern = r"import.*?from\s+['\"]([^'\"]+)['\"]"
                imports = re.findall(import_pattern, content)
        except Exception:
            pass
        
        return imports
    
    def analyze_file_content(self, file_path: str) -> Dict[str, Any]:
        """Analyze the content of a specific file."""
        try:
            full_path = self.base_path / file_path
            if not full_path.exists():
                return {
                    "success": False,
                    "error": f"File not found: {file_path}",
                    "operation": "analyze_file_content"
                }
            
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            analysis = {
                "file_path": file_path,
                "language": self.supported_extensions.get(full_path.suffix.lower(), 'unknown'),
                "line_count": len(content.splitlines()),
                "char_count": len(content),
                "size_bytes": len(content.encode('utf-8')),
                "imports": self._extract_imports(full_path),
                "functions": [],
                "classes": [],
                "complexity_score": 0
            }
            
            # Language-specific analysis
            if full_path.suffix == '.py':
                analysis.update(self._analyze_python_file(content))
            elif full_path.suffix == '.dart':
                analysis.update(self._analyze_dart_file(content))
            
            return {
                "success": True,
                "analysis": analysis,
                "operation": "analyze_file_content"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to analyze file: {str(e)}",
                "operation": "analyze_file_content"
            }
    
    def _analyze_python_file(self, content: str) -> Dict[str, Any]:
        """Analyze Python-specific content."""
        try:
            tree = ast.parse(content)
            functions = []
            classes = []
            
            for node in ast.walk(tree):
                if isinstance(node, ast.FunctionDef):
                    functions.append({
                        "name": node.name,
                        "line": node.lineno,
                        "args": [arg.arg for arg in node.args.args],
                        "is_async": isinstance(node, ast.AsyncFunctionDef)
                    })
                elif isinstance(node, ast.ClassDef):
                    classes.append({
                        "name": node.name,
                        "line": node.lineno,
                        "methods": [n.name for n in node.body if isinstance(n, ast.FunctionDef)]
                    })
            
            return {"functions": functions, "classes": classes}
        except Exception:
            return {"functions": [], "classes": []}
    
    def _analyze_dart_file(self, content: str) -> Dict[str, Any]:
        """Analyze Dart-specific content."""
        functions = []
        classes = []
        
        # Simple regex-based analysis for Dart
        class_pattern = r"class\s+(\w+)(?:\s+extends\s+\w+)?(?:\s+implements\s+[\w,\s]+)?\s*\{"
        function_pattern = r"(?:static\s+)?(?:Future\s*<[^>]*>|[A-Za-z_][A-Za-z0-9_<>]*)\s+(\w+)\s*\([^)]*\)\s*(?:async\s*)?\{"
        
        for match in re.finditer(class_pattern, content):
            classes.append({
                "name": match.group(1),
                "line": content[:match.start()].count('\n') + 1
            })
        
        for match in re.finditer(function_pattern, content):
            functions.append({
                "name": match.group(1),
                "line": content[:match.start()].count('\n') + 1
            })
        
        return {"functions": functions, "classes": classes}
    
    def generate_implementation_plan(self, task_description: str, relevant_files: List[str] = None) -> Dict[str, Any]:
        """Generate an implementation plan for a given task."""
        try:
            # Analyze relevant files
            file_contexts = []
            if relevant_files:
                for file_path in relevant_files:
                    analysis = self.analyze_file_content(file_path)
                    if analysis["success"]:
                        file_contexts.append(analysis["analysis"])
            
            # Generate plan structure
            plan = {
                "task": task_description,
                "estimated_complexity": self._estimate_complexity(task_description),
                "suggested_approach": self._suggest_approach(task_description),
                "files_to_modify": relevant_files or [],
                "steps": self._generate_steps(task_description),
                "potential_issues": self._identify_potential_issues(task_description),
                "testing_strategy": self._suggest_testing_strategy(task_description)
            }
            
            return {
                "success": True,
                "plan": plan,
                "file_contexts": file_contexts,
                "operation": "generate_implementation_plan"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to generate plan: {str(e)}",
                "operation": "generate_implementation_plan"
            }
    
    def _estimate_complexity(self, task: str) -> str:
        """Estimate task complexity based on keywords."""
        high_complexity_keywords = ['refactor', 'architecture', 'migration', 'integration', 'database', 'authentication']
        medium_complexity_keywords = ['feature', 'component', 'service', 'api', 'optimization']
        low_complexity_keywords = ['fix', 'update', 'modify', 'style', 'text']
        
        task_lower = task.lower()
        
        if any(keyword in task_lower for keyword in high_complexity_keywords):
            return "high"
        elif any(keyword in task_lower for keyword in medium_complexity_keywords):
            return "medium"
        elif any(keyword in task_lower for keyword in low_complexity_keywords):
            return "low"
        else:
            return "medium"
    
    def _suggest_approach(self, task: str) -> List[str]:
        """Suggest implementation approach based on task description."""
        approaches = []
        task_lower = task.lower()
        
        if 'ui' in task_lower or 'interface' in task_lower:
            approaches.append("Focus on UI/UX components and user interaction")
        if 'api' in task_lower or 'backend' in task_lower:
            approaches.append("Design API endpoints and data flow")
        if 'database' in task_lower or 'data' in task_lower:
            approaches.append("Plan data models and storage strategy")
        if 'test' in task_lower:
            approaches.append("Implement comprehensive testing strategy")
        
        if not approaches:
            approaches.append("Break down into smaller, manageable components")
        
        return approaches
    
    def _generate_steps(self, task: str) -> List[Dict[str, str]]:
        """Generate implementation steps."""
        steps = [
            {"step": 1, "action": "Analyze requirements and existing code", "description": "Understand the current state and requirements"},
            {"step": 2, "action": "Design solution architecture", "description": "Plan the technical approach and structure"},
            {"step": 3, "action": "Implement core functionality", "description": "Build the main features and logic"},
            {"step": 4, "action": "Add error handling and validation", "description": "Ensure robustness and user experience"},
            {"step": 5, "action": "Test and verify implementation", "description": "Validate functionality and fix issues"},
            {"step": 6, "action": "Document and optimize", "description": "Add documentation and performance optimizations"}
        ]
        
        return steps
    
    def _identify_potential_issues(self, task: str) -> List[str]:
        """Identify potential implementation issues."""
        issues = []
        task_lower = task.lower()
        
        if 'integration' in task_lower:
            issues.append("API compatibility and version conflicts")
        if 'performance' in task_lower:
            issues.append("Memory usage and execution time optimization")
        if 'ui' in task_lower:
            issues.append("Cross-platform compatibility and responsive design")
        if 'database' in task_lower:
            issues.append("Data migration and backup strategies")
        
        issues.append("Code maintainability and future extensibility")
        return issues
    
    def _suggest_testing_strategy(self, task: str) -> List[str]:
        """Suggest testing approaches."""
        strategies = ["Unit tests for core functionality"]
        task_lower = task.lower()
        
        if 'ui' in task_lower:
            strategies.append("Widget tests for UI components")
        if 'api' in task_lower:
            strategies.append("Integration tests for API endpoints")
        if 'database' in task_lower:
            strategies.append("Database transaction tests")
        
        strategies.append("End-to-end testing for complete workflows")
        return strategies

def main():
    parser = argparse.ArgumentParser(description="Code Analysis Tool")
    parser.add_argument("operation", choices=[
        "analyze_project_structure", "analyze_file_content", "generate_implementation_plan"
    ])
    parser.add_argument("--base-path", default=".", help="Base path for analysis")
    parser.add_argument("--file-path", help="File path to analyze")
    parser.add_argument("--task-description", help="Task description for planning")
    parser.add_argument("--relevant-files", nargs="*", help="Relevant files for planning")
    parser.add_argument("--max-depth", type=int, default=3, help="Maximum depth for structure analysis")
    
    args = parser.parse_args()
    
    analyzer = CodeAnalysis(args.base_path)
    result = None
    
    try:
        if args.operation == "analyze_project_structure":
            result = analyzer.analyze_project_structure(args.max_depth)
            
        elif args.operation == "analyze_file_content":
            if not args.file_path:
                raise ValueError("--file-path is required for analyze_file_content")
            result = analyzer.analyze_file_content(args.file_path)
            
        elif args.operation == "generate_implementation_plan":
            if not args.task_description:
                raise ValueError("--task-description is required for generate_implementation_plan")
            result = analyzer.generate_implementation_plan(args.task_description, args.relevant_files)
        
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