import 'package:flutter/material.dart';
import '../models.dart';
import '../services/code_block_service.dart';

class EnhancedCodeBlock extends StatefulWidget {
  final List<CodeContent> codes;
  
  const EnhancedCodeBlock({super.key, required this.codes});
  
  @override
  State<EnhancedCodeBlock> createState() => _EnhancedCodeBlockState();
}

class _EnhancedCodeBlockState extends State<EnhancedCodeBlock> {
  bool _isExpanded = true;
  
  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.codes.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: _toggleExpansion,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.code_rounded,
                    size: 16,
                    color: const Color(0xFF000000),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isExpanded 
                          ? '${widget.codes.length} Code Block${widget.codes.length > 1 ? 's' : ''}'
                          : _getCodePreview(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: _isExpanded ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: const Color(0xFF000000),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Code blocks
          if (_isExpanded)
            ...widget.codes.map((codeContent) => _buildCodeBlock(codeContent)),
        ],
      ),
    );
  }
  
  Widget _buildCodeBlock(CodeContent codeContent) {
    final isHtml = CodeBlockService.isHtmlCode(codeContent.language);
    final languageColor = CodeBlockService.getLanguageColor(codeContent.language);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with language and actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: languageColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    codeContent.extension.toUpperCase(),
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
                    onPressed: () => CodeBlockService.previewHtml(context, codeContent.code),
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
                  onPressed: () => CodeBlockService.copyCode(context, codeContent.code),
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
                      codeContent.code,
                      codeContent.language,
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
  
  String _getCodePreview() {
    if (widget.codes.isEmpty) return '';
    final firstCode = widget.codes.first;
    final preview = firstCode.code.length > 50 
        ? '${firstCode.code.substring(0, 50)}...'
        : firstCode.code;
    return preview;
  }
}