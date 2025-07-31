void main() {
  // Test new flexible patterns
  final patterns = {
    'python': RegExp(r'```(?:python|py)\s*(.*?)```', dotAll: true),
    'javascript': RegExp(r'```(?:javascript|js)\s*(.*?)```', dotAll: true),
    'html': RegExp(r'```html\s*(.*?)```', dotAll: true),
  };
  
  // Test cases - different formatting including problematic ones
  final testCases = [
    '```python\nprint("hello")\n```',
    '```py\nprint("hello")\n```', 
    '```javascript\nconsole.log("hello");\n```',
    '```js\nconsole.log("hello");\n```',
    '```html\n<div>Hello</div>\n```',
    // Without newline
    '```python\nprint("hello")```',
    '```pythonprint("hello")```', // No space after language
    '```python print("hello")```', // Space instead of newline
    '```python  \nprint("hello")```', // Space + newline
  ];
  
  for (final testCase in testCases) {
    print('\nTesting: ${testCase.replaceAll('\n', '\\n')}');
    
    bool found = false;
    for (final entry in patterns.entries) {
      final matches = entry.value.allMatches(testCase);
      if (matches.isNotEmpty) {
        for (final match in matches) {
          print('  ✅ ${entry.key}: "${match.group(1)}"');
          found = true;
        }
      }
    }
    if (!found) {
      print('  ❌ No patterns matched');
    }
  }
}