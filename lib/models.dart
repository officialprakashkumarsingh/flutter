/* ----------------------------------------------------------
   MODELS
---------------------------------------------------------- */
enum Sender { user, bot }

class ThoughtContent {
  final String text;
  final String type; // 'thinking', 'thoughts', 'think', 'thought', 'reason', 'reasoning'
  
  ThoughtContent({required this.text, required this.type});
}

class CodeContent {
  final String code;
  final String language; // 'dart', 'python', 'javascript', etc.
  final String extension; // '.dart', '.py', '.js', etc.
  
  CodeContent({required this.code, required this.language, required this.extension});
}

class Message {
  final String id;
  final Sender sender;
  final String text;
  final bool isStreaming;
  final DateTime timestamp;
  final List<ThoughtContent> thoughts;
  final List<CodeContent> codes;
  final String displayText; // Text without thought and code content
  final Map<String, dynamic> toolData; // External tools data

  Message({
    required this.id,
    required this.sender,
    required this.text,
    this.isStreaming = false,
    required this.timestamp,
    this.thoughts = const [],
    this.codes = const [],
    String? displayText,
    this.toolData = const {},
  }) : displayText = displayText ?? text;

  factory Message.user(String text) {
    final timestamp = DateTime.now();
    return Message(
      id: 'user_${timestamp.toIso8601String()}',
      sender: Sender.user,
      text: text,
      timestamp: timestamp,
    );
  }

  factory Message.bot(String text, {bool isStreaming = false, Map<String, dynamic>? toolData}) {
    final timestamp = DateTime.now();
    final result = _parseContent(text);
    return Message(
      id: 'bot_${timestamp.toIso8601String()}',
      sender: Sender.bot,
      text: text,
      isStreaming: isStreaming,
      timestamp: timestamp,
      thoughts: result['thoughts'],
      codes: result['codes'],
      displayText: result['displayText'],
      toolData: toolData ?? {},
    );
  }

  Message copyWith({
    String? id,
    Sender? sender,
    String? text,
    bool? isStreaming,
    DateTime? timestamp,
    List<ThoughtContent>? thoughts,
    List<CodeContent>? codes,
    String? displayText,
    Map<String, dynamic>? toolData,
  }) {
    final newText = text ?? this.text;
    final newDisplayText = displayText ?? (text != null ? null : this.displayText);
    
    if (text != null && displayText == null) {
      // Re-parse content if text changed but displayText wasn't explicitly provided
      final result = _parseContent(newText);
      return Message(
        id: id ?? this.id,
        sender: sender ?? this.sender,
        text: newText,
        isStreaming: isStreaming ?? this.isStreaming,
        timestamp: timestamp ?? this.timestamp,
        thoughts: thoughts ?? result['thoughts'],
        codes: codes ?? result['codes'],
        displayText: result['displayText'],
        toolData: toolData ?? this.toolData,
      );
    }
    
    return Message(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: newText,
      isStreaming: isStreaming ?? this.isStreaming,
      timestamp: timestamp ?? this.timestamp,
      thoughts: thoughts ?? this.thoughts,
      codes: codes ?? this.codes,
      displayText: newDisplayText ?? this.displayText,
      toolData: toolData ?? this.toolData,
    );
  }

  // Parse thoughts and code from text and separate them from display text
  static Map<String, dynamic> _parseContent(String text) {
    final List<ThoughtContent> thoughts = [];
    final List<CodeContent> codes = [];
    String displayText = text;
    
    // Regex patterns for different thought types
    final thoughtPatterns = {
      'thinking': RegExp(r'<thinking>(.*?)</thinking>', dotAll: true),
      'thoughts': RegExp(r'<thoughts>(.*?)</thoughts>', dotAll: true),
      'think': RegExp(r'<think>(.*?)</think>', dotAll: true),
      'thought': RegExp(r'<thought>(.*?)</thought>', dotAll: true),
      'reason': RegExp(r'<reason>(.*?)</reason>', dotAll: true),
      'reasoning': RegExp(r'<reasoning>(.*?)</reasoning>', dotAll: true),
    };
    
    // Extract thoughts and remove them from display text
    for (String type in thoughtPatterns.keys) {
      final matches = thoughtPatterns[type]!.allMatches(text);
      for (final match in matches) {
        final thoughtText = match.group(1)?.trim() ?? '';
        if (thoughtText.isNotEmpty) {
          thoughts.add(ThoughtContent(text: thoughtText, type: type));
        }
        // Remove the entire thought block from display text
        displayText = displayText.replaceAll(match.group(0)!, '');
      }
    }
    
    // Code block patterns for different languages
    final codePatterns = {
      // Popular Programming Languages
      'dart': RegExp(r'```dart\n(.*?)```', dotAll: true),
      'python': RegExp(r'```(?:python|py)\n(.*?)```', dotAll: true),
      'javascript': RegExp(r'```(?:javascript|js)\n(.*?)```', dotAll: true),
      'typescript': RegExp(r'```(?:typescript|ts)\n(.*?)```', dotAll: true),
      'java': RegExp(r'```java\n(.*?)```', dotAll: true),
      'kotlin': RegExp(r'```(?:kotlin|kt)\n(.*?)```', dotAll: true),
      'swift': RegExp(r'```swift\n(.*?)```', dotAll: true),
      'rust': RegExp(r'```(?:rust|rs)\n(.*?)```', dotAll: true),
      'go': RegExp(r'```(?:go|golang)\n(.*?)```', dotAll: true),
      'cpp': RegExp(r'```(?:cpp|c\+\+|cxx)\n(.*?)```', dotAll: true),
      'c': RegExp(r'```c\n(.*?)```', dotAll: true),
      'csharp': RegExp(r'```(?:csharp|cs|c#)\n(.*?)```', dotAll: true),
      'php': RegExp(r'```php\n(.*?)```', dotAll: true),
      'ruby': RegExp(r'```(?:ruby|rb)\n(.*?)```', dotAll: true),
      'scala': RegExp(r'```scala\n(.*?)```', dotAll: true),
      'r': RegExp(r'```r\n(.*?)```', dotAll: true),
      'matlab': RegExp(r'```(?:matlab|m)\n(.*?)```', dotAll: true),
      'perl': RegExp(r'```(?:perl|pl)\n(.*?)```', dotAll: true),
      'lua': RegExp(r'```lua\n(.*?)```', dotAll: true),
      'haskell': RegExp(r'```(?:haskell|hs)\n(.*?)```', dotAll: true),
      'elixir': RegExp(r'```(?:elixir|ex)\n(.*?)```', dotAll: true),
      'erlang': RegExp(r'```(?:erlang|erl)\n(.*?)```', dotAll: true),
      'clojure': RegExp(r'```(?:clojure|clj)\n(.*?)```', dotAll: true),
      'ocaml': RegExp(r'```(?:ocaml|ml)\n(.*?)```', dotAll: true),
      'fsharp': RegExp(r'```(?:fsharp|fs|f#)\n(.*?)```', dotAll: true),
      'julia': RegExp(r'```(?:julia|jl)\n(.*?)```', dotAll: true),
      'nim': RegExp(r'```nim\n(.*?)```', dotAll: true),
      'zig': RegExp(r'```zig\n(.*?)```', dotAll: true),
      'crystal': RegExp(r'```(?:crystal|cr)\n(.*?)```', dotAll: true),
      
      // Functional & Logic Programming
      'lisp': RegExp(r'```(?:lisp|lsp)\n(.*?)```', dotAll: true),
      'scheme': RegExp(r'```(?:scheme|scm)\n(.*?)```', dotAll: true),
      'racket': RegExp(r'```racket\n(.*?)```', dotAll: true),
      'prolog': RegExp(r'```(?:prolog|pl)\n(.*?)```', dotAll: true),
      
      // Assembly & Low Level
      'assembly': RegExp(r'```(?:assembly|asm|nasm)\n(.*?)```', dotAll: true),
      'x86': RegExp(r'```x86\n(.*?)```', dotAll: true),
      'arm': RegExp(r'```arm\n(.*?)```', dotAll: true),
      
      // Game Development
      'gdscript': RegExp(r'```(?:gdscript|gd)\n(.*?)```', dotAll: true),
      'hlsl': RegExp(r'```hlsl\n(.*?)```', dotAll: true),
      'glsl': RegExp(r'```glsl\n(.*?)```', dotAll: true),
      'unity': RegExp(r'```unity\n(.*?)```', dotAll: true),
      
      // Emerging Languages
      'solidity': RegExp(r'```(?:solidity|sol)\n(.*?)```', dotAll: true),
      'vyper': RegExp(r'```vyper\n(.*?)```', dotAll: true),
      'move': RegExp(r'```move\n(.*?)```', dotAll: true),
      'cairo': RegExp(r'```cairo\n(.*?)```', dotAll: true),
      
      // Data Science & ML
      'jupyter': RegExp(r'```jupyter\n(.*?)```', dotAll: true),
      'ipynb': RegExp(r'```ipynb\n(.*?)```', dotAll: true),
      'rmd': RegExp(r'```(?:rmd|rmarkdown)\n(.*?)```', dotAll: true),
      
      // Domain Specific
      'verilog': RegExp(r'```(?:verilog|v)\n(.*?)```', dotAll: true),
      'vhdl': RegExp(r'```vhdl\n(.*?)```', dotAll: true),
      'systemverilog': RegExp(r'```(?:systemverilog|sv)\n(.*?)```', dotAll: true),
      
      // Web Technologies
      'html': RegExp(r'```html\n(.*?)```', dotAll: true),
      'css': RegExp(r'```css\n(.*?)```', dotAll: true),
      'scss': RegExp(r'```(?:scss|sass)\n(.*?)```', dotAll: true),
      'less': RegExp(r'```less\n(.*?)```', dotAll: true),
      'vue': RegExp(r'```vue\n(.*?)```', dotAll: true),
      'react': RegExp(r'```(?:react|jsx)\n(.*?)```', dotAll: true),
      'angular': RegExp(r'```angular\n(.*?)```', dotAll: true),
      'svelte': RegExp(r'```svelte\n(.*?)```', dotAll: true),
      
      // Mobile Development
      'flutter': RegExp(r'```flutter\n(.*?)```', dotAll: true),
      'react-native': RegExp(r'```(?:react-native|rn)\n(.*?)```', dotAll: true),
      'xamarin': RegExp(r'```xamarin\n(.*?)```', dotAll: true),
      
      // Data & Configuration
      'sql': RegExp(r'```sql\n(.*?)```', dotAll: true),
      'mysql': RegExp(r'```mysql\n(.*?)```', dotAll: true),
      'postgresql': RegExp(r'```(?:postgresql|postgres)\n(.*?)```', dotAll: true),
      'mongodb': RegExp(r'```(?:mongodb|mongo)\n(.*?)```', dotAll: true),
      'json': RegExp(r'```json\n(.*?)```', dotAll: true),
      'yaml': RegExp(r'```(?:yaml|yml)\n(.*?)```', dotAll: true),
      'xml': RegExp(r'```xml\n(.*?)```', dotAll: true),
      'toml': RegExp(r'```toml\n(.*?)```', dotAll: true),
      'ini': RegExp(r'```ini\n(.*?)```', dotAll: true),
      'env': RegExp(r'```(?:env|dotenv)\n(.*?)```', dotAll: true),
      
      // Shell & Scripting
      'bash': RegExp(r'```(?:bash|sh)\n(.*?)```', dotAll: true),
      'zsh': RegExp(r'```zsh\n(.*?)```', dotAll: true),
      'fish': RegExp(r'```fish\n(.*?)```', dotAll: true),
      'powershell': RegExp(r'```(?:powershell|ps1)\n(.*?)```', dotAll: true),
      'batch': RegExp(r'```(?:batch|bat|cmd)\n(.*?)```', dotAll: true),
      
      // DevOps & Infrastructure
      'dockerfile': RegExp(r'```(?:dockerfile|docker)\n(.*?)```', dotAll: true),
      'terraform': RegExp(r'```(?:terraform|tf)\n(.*?)```', dotAll: true),
      'ansible': RegExp(r'```ansible\n(.*?)```', dotAll: true),
      'kubernetes': RegExp(r'```(?:kubernetes|k8s)\n(.*?)```', dotAll: true),
      'helm': RegExp(r'```helm\n(.*?)```', dotAll: true),
      'nginx': RegExp(r'```nginx\n(.*?)```', dotAll: true),
      'apache': RegExp(r'```apache\n(.*?)```', dotAll: true),
      
      // Version Control
      'git': RegExp(r'```git\n(.*?)```', dotAll: true),
      'gitignore': RegExp(r'```gitignore\n(.*?)```', dotAll: true),
      
      // Documentation
      'markdown': RegExp(r'```(?:markdown|md)\n(.*?)```', dotAll: true),
      'latex': RegExp(r'```(?:latex|tex)\n(.*?)```', dotAll: true),
      'asciidoc': RegExp(r'```(?:asciidoc|adoc)\n(.*?)```', dotAll: true),
      
      // Other Formats
      'csv': RegExp(r'```csv\n(.*?)```', dotAll: true),
      'tsv': RegExp(r'```tsv\n(.*?)```', dotAll: true),
      'log': RegExp(r'```log\n(.*?)```', dotAll: true),
      'diff': RegExp(r'```diff\n(.*?)```', dotAll: true),
      'patch': RegExp(r'```patch\n(.*?)```', dotAll: true),
      
      // Generic (processed last)
      'shell': RegExp(r'```(?:shell|sh)\n(.*?)```', dotAll: true),
      'generic': RegExp(r'```\n(.*?)```', dotAll: true),
    };
    
    final languageExtensions = {
      // Programming Languages
      'dart': '.dart',
      'python': '.py',
      'javascript': '.js',
      'typescript': '.ts',
      'java': '.java',
      'kotlin': '.kt',
      'swift': '.swift',
      'rust': '.rs',
      'go': '.go',
      'cpp': '.cpp',
      'c': '.c',
      'csharp': '.cs',
      'php': '.php',
      'ruby': '.rb',
      'scala': '.scala',
      'r': '.r',
      'matlab': '.m',
      'perl': '.pl',
      'lua': '.lua',
      'haskell': '.hs',
      'elixir': '.ex',
      'erlang': '.erl',
      'clojure': '.clj',
      'ocaml': '.ml',
      'fsharp': '.fs',
      'julia': '.jl',
      'nim': '.nim',
      'zig': '.zig',
      'crystal': '.cr',
      
      // Functional & Logic Programming
      'lisp': '.lsp',
      'scheme': '.scm',
      'racket': '.rkt',
      'prolog': '.pl',
      
      // Assembly & Low Level
      'assembly': '.asm',
      'x86': '.asm',
      'arm': '.asm',
      
      // Game Development
      'gdscript': '.gd',
      'hlsl': '.hlsl',
      'glsl': '.glsl',
      'unity': '.unity',
      
      // Emerging Languages
      'solidity': '.sol',
      'vyper': '.vy',
      'move': '.move',
      'cairo': '.cairo',
      
      // Data Science & ML
      'jupyter': '.ipynb',
      'ipynb': '.ipynb',
      'rmd': '.rmd',
      
      // Domain Specific
      'verilog': '.v',
      'vhdl': '.vhdl',
      'systemverilog': '.sv',
      
      // Web Technologies
      'html': '.html',
      'css': '.css',
      'scss': '.scss',
      'less': '.less',
      'vue': '.vue',
      'react': '.jsx',
      'angular': '.ts',
      'svelte': '.svelte',
      
      // Mobile Development
      'flutter': '.dart',
      'react-native': '.jsx',
      'xamarin': '.cs',
      
      // Data & Configuration
      'sql': '.sql',
      'mysql': '.sql',
      'postgresql': '.sql',
      'mongodb': '.js',
      'json': '.json',
      'yaml': '.yaml',
      'xml': '.xml',
      'toml': '.toml',
      'ini': '.ini',
      'env': '.env',
      
      // Shell & Scripting
      'bash': '.sh',
      'zsh': '.zsh',
      'fish': '.fish',
      'powershell': '.ps1',
      'batch': '.bat',
      
      // DevOps & Infrastructure
      'dockerfile': 'Dockerfile',
      'terraform': '.tf',
      'ansible': '.yml',
      'kubernetes': '.yaml',
      'helm': '.yaml',
      'nginx': '.conf',
      'apache': '.conf',
      
      // Version Control
      'git': '.txt',
      'gitignore': '.gitignore',
      
      // Documentation
      'markdown': '.md',
      'latex': '.tex',
      'asciidoc': '.adoc',
      
      // Other Formats
      'csv': '.csv',
      'tsv': '.tsv',
      'log': '.log',
      'diff': '.diff',
      'patch': '.patch',
      
      // Generic
      'shell': '.sh',
      'generic': '.txt',
    };
    
    // Extract code blocks (excluding generic if specific language found)
    Set<String> processedContent = {};
    for (String language in codePatterns.keys) {
      if (language == 'generic') continue; // Process generic last
      final matches = codePatterns[language]!.allMatches(text);
      for (final match in matches) {
        final codeText = match.group(1)?.trim() ?? '';
        if (codeText.isNotEmpty) {
          codes.add(CodeContent(
            code: codeText,
            language: language,
            extension: languageExtensions[language] ?? '.txt',
          ));
          processedContent.add(match.group(0)!);
          displayText = displayText.replaceAll(match.group(0)!, '');
        }
      }
    }
    
    // Process generic code blocks only if no specific language was found
    if (codes.isEmpty) {
      final matches = codePatterns['generic']!.allMatches(text);
      for (final match in matches) {
        final codeText = match.group(1)?.trim() ?? '';
        if (codeText.isNotEmpty && !processedContent.contains(match.group(0)!)) {
          codes.add(CodeContent(
            code: codeText,
            language: 'generic',
            extension: '.txt',
          ));
          displayText = displayText.replaceAll(match.group(0)!, '');
        }
      }
    }
    
    // Clean up display text
    displayText = displayText.trim();
    
    return {
      'thoughts': thoughts,
      'codes': codes,
      'displayText': displayText,
    };
  }


}

class ChatSession {
  final String title;
  final List<Message> messages;

  ChatSession({required this.title, required this.messages});
}

// NEW USER MODEL
class User {
  final String name;
  final String email;
  final String avatarUrl;

  User({required this.name, required this.email, required this.avatarUrl});
}