import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/html_preview_dialog.dart';
import '../widgets/code_execution_dialog.dart';
import 'code_execution_service.dart';

class CodeBlockService {
  static const Map<String, Color> _languageColors = {
    'javascript': Color(0xFFF7DF1E),
    'js': Color(0xFFF7DF1E),
    'typescript': Color(0xFF3178C6),
    'ts': Color(0xFF3178C6),
    'python': Color(0xFF3776AB),
    'py': Color(0xFF3776AB),
    'dart': Color(0xFF0175C2),
    'java': Color(0xFFED8B00),
    'html': Color(0xFFE34F26),
    'css': Color(0xFF1572B6),
    'json': Color(0xFF000000),
    'xml': Color(0xFF0060AC),
    'sql': Color(0xFF336791),
    'php': Color(0xFF777BB4),
    'cpp': Color(0xFF00599C),
    'c': Color(0xFFA8B9CC),
    'go': Color(0xFF00ADD8),
    'rust': Color(0xFF000000),
    'kotlin': Color(0xFF7F52FF),
    'swift': Color(0xFFFA7343),
    'ruby': Color(0xFFCC342D),
  };

  static Color getLanguageColor(String language) {
    return _languageColors[language.toLowerCase()] ?? const Color(0xFF666666);
  }

  static bool isHtmlCode(String language) {
    return language.toLowerCase() == 'html' || language.toLowerCase() == 'htm';
  }

  static bool isExecutableCode(String language) {
    return CodeExecutionService.isExecutable(language);
  }

  static void copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '📋 Code copied to clipboard!',
          style: TextStyle(
            color: Color(0xFF000000),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void previewHtml(BuildContext context, String htmlCode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return HtmlPreviewDialog(htmlContent: htmlCode);
      },
    );
  }

  static void executeCode(BuildContext context, String code, String language) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CodeExecutionDialog(
          code: code,
          language: language,
        );
      },
    );
  }

  static TextStyle getCodeStyle({bool isComment = false, bool isKeyword = false, bool isString = false}) {
    if (isComment) {
      return const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.4,
        color: Color(0xFF6A9955), // Green for comments
        fontWeight: FontWeight.w400,
      );
    } else if (isKeyword) {
      return const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.4,
        color: Color(0xFF569CD6), // Blue for keywords
        fontWeight: FontWeight.w500,
      );
    } else if (isString) {
      return const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.4,
        color: Color(0xFFCE9178), // Orange for strings
        fontWeight: FontWeight.w400,
      );
    }
    
    return const TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.4,
      color: Color(0xFFFFFFFF),
      fontWeight: FontWeight.w400,
    );
  }

  // Basic syntax highlighting (simplified for key languages)
  static List<TextSpan> highlightCode(String code, String language) {
    final lines = code.split('\n');
    List<TextSpan> spans = [];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (line.trim().isEmpty) {
        spans.add(TextSpan(text: '\n', style: getCodeStyle()));
        continue;
      }
      
      // Simple highlighting based on language
      switch (language.toLowerCase()) {
        case 'javascript':
        case 'js':
        case 'typescript':
        case 'ts':
          spans.addAll(_highlightJavaScript(line));
          break;
        case 'python':
        case 'py':
          spans.addAll(_highlightPython(line));
          break;
        case 'html':
          spans.addAll(_highlightHtml(line));
          break;
        case 'css':
          spans.addAll(_highlightCss(line));
          break;
        default:
          spans.add(TextSpan(text: line, style: getCodeStyle()));
      }
      
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: getCodeStyle()));
      }
    }
    
    return spans;
  }

  static List<TextSpan> _highlightJavaScript(String line) {
    final keywords = ['function', 'const', 'let', 'var', 'if', 'else', 'for', 'while', 'return', 'class', 'import', 'export'];
    List<TextSpan> spans = [];
    
    if (line.trim().startsWith('//')) {
      spans.add(TextSpan(text: line, style: getCodeStyle(isComment: true)));
      return spans;
    }
    
    // Simple keyword highlighting
    String remainingLine = line;
    for (String keyword in keywords) {
      if (remainingLine.contains(keyword)) {
        final parts = remainingLine.split(keyword);
        for (int i = 0; i < parts.length; i++) {
          if (i > 0) {
            spans.add(TextSpan(text: keyword, style: getCodeStyle(isKeyword: true)));
          }
          if (parts[i].isNotEmpty) {
            spans.add(TextSpan(text: parts[i], style: getCodeStyle()));
          }
        }
        return spans;
      }
    }
    
    spans.add(TextSpan(text: line, style: getCodeStyle()));
    return spans;
  }

  static List<TextSpan> _highlightPython(String line) {
    List<TextSpan> spans = [];
    
    if (line.trim().startsWith('#')) {
      spans.add(TextSpan(text: line, style: getCodeStyle(isComment: true)));
      return spans;
    }
    
    spans.add(TextSpan(text: line, style: getCodeStyle()));
    return spans;
  }

  static List<TextSpan> _highlightHtml(String line) {
    List<TextSpan> spans = [];
    
    if (line.trim().startsWith('<!--')) {
      spans.add(TextSpan(text: line, style: getCodeStyle(isComment: true)));
      return spans;
    }
    
    spans.add(TextSpan(text: line, style: getCodeStyle()));
    return spans;
  }

  static List<TextSpan> _highlightCss(String line) {
    List<TextSpan> spans = [];
    spans.add(TextSpan(text: line, style: getCodeStyle()));
    return spans;
  }
}