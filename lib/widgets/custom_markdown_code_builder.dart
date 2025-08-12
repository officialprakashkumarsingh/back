import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../services/code_block_service.dart';

class CustomMarkdownCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String? language = element.attributes['class']?.replaceFirst('language-', '');
    final String code = element.textContent;
    
    if (code.isEmpty) return null;
    
    final isHtml = CodeBlockService.isHtmlCode(language ?? '');
    final languageColor = CodeBlockService.getLanguageColor(language ?? '');
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with language and actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (language != null && language.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: languageColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      language.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const Spacer(),
                if (isHtml)
                  IconButton(
                    onPressed: () => CodeBlockService.previewHtml(
                      navigatorKey.currentContext!, 
                      code
                    ),
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: Color(0xFF000000),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: 'Preview HTML',
                  ),
                IconButton(
                  onPressed: () => CodeBlockService.copyCode(
                    navigatorKey.currentContext!, 
                    code
                  ),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: Color(0xFF000000),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: 'Copy code',
                ),
              ],
            ),
          ),
          // Code content with syntax highlighting
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: RichText(
                  text: TextSpan(
                    children: CodeBlockService.highlightCode(
                      code,
                      language ?? '',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Global navigator key for accessing context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();