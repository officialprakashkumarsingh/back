import '../models.dart';

/* ----------------------------------------------------------
   MESSAGE SEGMENTS - Data classes for parsing message content
---------------------------------------------------------- */
abstract class MessageSegment {}

class TextSegment extends MessageSegment {
  final String text;
  TextSegment(this.text);
}

class CodeSegment extends MessageSegment {
  final CodeContent codeContent;
  CodeSegment(this.codeContent);
}

/* ----------------------------------------------------------
   MESSAGE PARSING - Utility function to parse message into segments
---------------------------------------------------------- */
List<MessageSegment> parseMessageIntoSegments(String text) {
  final segments = <MessageSegment>[];
  
  // Define patterns for different code languages
  final codePatterns = {
    'dart': RegExp(r'```(?:dart|flutter)\s*\n(.*?)\n```', dotAll: true),
    'python': RegExp(r'```(?:python|py)\s*\n(.*?)\n```', dotAll: true),
    'javascript': RegExp(r'```(?:javascript|js)\s*\n(.*?)\n```', dotAll: true),
    'typescript': RegExp(r'```(?:typescript|ts)\s*\n(.*?)\n```', dotAll: true),
    'java': RegExp(r'```java\s*\n(.*?)\n```', dotAll: true),
    'cpp': RegExp(r'```(?:cpp|c\+\+|cxx)\s*\n(.*?)\n```', dotAll: true),
    'c': RegExp(r'```c\s*\n(.*?)\n```', dotAll: true),
    'rust': RegExp(r'```rust\s*\n(.*?)\n```', dotAll: true),
    'go': RegExp(r'```go\s*\n(.*?)\n```', dotAll: true),
    'html': RegExp(r'```html\s*\n(.*?)\n```', dotAll: true),
    'css': RegExp(r'```css\s*\n(.*?)\n```', dotAll: true),
    'json': RegExp(r'```json\s*\n(.*?)\n```', dotAll: true),
    'xml': RegExp(r'```xml\s*\n(.*?)\n```', dotAll: true),
    'yaml': RegExp(r'```(?:yaml|yml)\s*\n(.*?)\n```', dotAll: true),
    'sql': RegExp(r'```sql\s*\n(.*?)\n```', dotAll: true),
    'bash': RegExp(r'```(?:bash|sh|shell)\s*\n(.*?)\n```', dotAll: true),
    'powershell': RegExp(r'```(?:powershell|ps1)\s*\n(.*?)\n```', dotAll: true),
    'generic': RegExp(r'```(?:\w*\s*)?\n(.*?)\n```', dotAll: true),
  };
  
  final languageExtensions = {
    'dart': '.dart',
    'python': '.py',
    'javascript': '.js',
    'typescript': '.ts',
    'java': '.java',
    'cpp': '.cpp',
    'c': '.c',
    'rust': '.rs',
    'go': '.go',
    'html': '.html',
    'css': '.css',
    'json': '.json',
    'xml': '.xml',
    'yaml': '.yaml',
    'sql': '.sql',
    'bash': '.sh',
    'powershell': '.ps1',
    'generic': '.txt',
  };
  
  // Find all code blocks and their positions
  final codeBlocks = <({int start, int end, CodeContent code})>[];
  
  for (String language in codePatterns.keys) {
    final matches = codePatterns[language]!.allMatches(text);
    for (final match in matches) {
      final codeText = match.group(1)?.trim() ?? '';
      if (codeText.isNotEmpty) {
        codeBlocks.add((
          start: match.start,
          end: match.end,
          code: CodeContent(
            code: codeText,
            language: language,
            extension: languageExtensions[language] ?? '.txt',
          ),
        ));
      }
    }
  }
  
  // Sort code blocks by position
  codeBlocks.sort((a, b) => a.start.compareTo(b.start));
  
  // Split text into segments
  int lastEnd = 0;
  for (final block in codeBlocks) {
    // Add text before this code block
    if (block.start > lastEnd) {
      final textContent = text.substring(lastEnd, block.start).trim();
      if (textContent.isNotEmpty) {
        segments.add(TextSegment(textContent));
      }
    }
    
    // Add the code block
    segments.add(CodeSegment(block.code));
    lastEnd = block.end;
  }
  
  // Add remaining text after the last code block
  if (lastEnd < text.length) {
    final textContent = text.substring(lastEnd).trim();
    if (textContent.isNotEmpty) {
      segments.add(TextSegment(textContent));
    }
  }
  
  // If no code blocks found, treat entire text as one text segment
  if (codeBlocks.isEmpty) {
    segments.add(TextSegment(text));
  }
  
  return segments;
}