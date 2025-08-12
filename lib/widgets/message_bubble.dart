import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_svg/flutter_svg.dart';
import '../models.dart';

/* ----------------------------------------------------------
   MESSAGE BUBBLE - Individual message display with actions
---------------------------------------------------------- */
class MessageBubble extends StatefulWidget {
  final Message message;
  final VoidCallback? onRegenerate;
  final VoidCallback? onUserMessageTap;
  final Widget Function(Message) messageContentBuilder;
  final Function(String modifyType)? onModifyResponse;


  
  const MessageBubble({
    super.key,
    required this.message,
    this.onRegenerate,
    this.onUserMessageTap,
    required this.messageContentBuilder,
    this.onModifyResponse,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with TickerProviderStateMixin {
  bool _showActions = false;
  late AnimationController _actionsAnimationController;
  late Animation<double> _actionsAnimation;
  bool _showUserActions = false;
  late AnimationController _userActionsAnimationController;
  late Animation<double> _userActionsAnimation;

  @override
  void initState() {
    super.initState();
    _actionsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _actionsAnimation = CurvedAnimation(
      parent: _actionsAnimationController,
      curve: Curves.easeOut,
    );
    
    _userActionsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _userActionsAnimation = CurvedAnimation(
      parent: _userActionsAnimationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _actionsAnimationController.dispose();
    _userActionsAnimationController.dispose();
    super.dispose();
  }

  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
      if (_showActions) {
        _actionsAnimationController.forward();
      } else {
        _actionsAnimationController.reverse();
      }
    });
  }

  void _toggleUserActions() {
    setState(() {
      _showUserActions = !_showUserActions;
      if (_showUserActions) {
        _userActionsAnimationController.forward();
      } else {
        _userActionsAnimationController.reverse();
      }
    });
  }

  void _giveFeedback(BuildContext context, bool isPositive) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPositive ? '👍 Thank you for your feedback!' : '👎 Feedback noted. We\'ll improve!',
          style: const TextStyle(
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
    // Hide actions after interaction
    _toggleActions();
  }

  void _copyMessage(BuildContext context) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '📋 Message copied to clipboard!',
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
    // Hide actions after interaction
    _toggleActions();
  }

  void _shareMessage(BuildContext context) {
    HapticFeedback.lightImpact();
    // For now, copy to clipboard (can implement actual sharing later)
    Clipboard.setData(ClipboardData(text: widget.message.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '🔗 Message ready to share!',
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
    // Hide actions after interaction
    _toggleActions();
  }

  void _showModifyOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    _toggleActions(); // Hide action buttons
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFEAE9E5),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const Text(
                      'Modify Response',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildModifyOption(
                      context,
                      icon: Icons.unfold_more,
                      title: 'Expand Response',
                      subtitle: 'Make it more detailed and comprehensive',
                      onTap: () => _handleModifyOption(context, 'expand'),
                    ),
                    _buildModifyOption(
                      context,
                      icon: Icons.unfold_less,
                      title: 'Shorten Response',
                      subtitle: 'Make it more concise and to the point',
                      onTap: () => _handleModifyOption(context, 'shorten'),
                    ),
                    _buildModifyOption(
                      context,
                      icon: Icons.lightbulb_outline,
                      title: 'Explain Simply',
                      subtitle: 'Use simpler language and examples',
                      onTap: () => _handleModifyOption(context, 'simplify'),
                    ),
                    _buildModifyOption(
                      context,
                      icon: Icons.work_outline,
                      title: 'Professional Tone',
                      subtitle: 'Make it more formal and professional',
                      onTap: () => _handleModifyOption(context, 'professional'),
                    ),
                    _buildModifyOption(
                      context,
                      icon: Icons.chat_bubble_outline,
                      title: 'Casual Tone',
                      subtitle: 'Make it more friendly and conversational',
                      onTap: () => _handleModifyOption(context, 'casual'),
                    ),
                    _buildModifyOption(
                      context,
                      icon: Icons.list_alt,
                      title: 'Add Examples',
                      subtitle: 'Include practical examples and use cases',
                      onTap: () => _handleModifyOption(context, 'examples'),
                    ),
                    _buildModifyOption(
                      context,
                      icon: Icons.emoji_emotions_outlined,
                      title: 'Add Humor',
                      subtitle: 'Make it more engaging with appropriate humor',
                      onTap: () => _handleModifyOption(context, 'humor'),
                    ),
                    _buildModifyOption(
                      context,
                      icon: Icons.psychology_outlined,
                      title: 'Technical Deep Dive',
                      subtitle: 'Add technical details and explanations',
                      onTap: () => _handleModifyOption(context, 'technical'),
                    ),
                    _buildModifyOption(
                      context,
                      icon: Icons.trending_up,
                      title: 'Action-Oriented',
                      subtitle: 'Focus on actionable steps and solutions',
                      onTap: () => _handleModifyOption(context, 'actionable'),
                    ),
                    _buildModifyOption(
                      context,
                      icon: Icons.quiz_outlined,
                      title: 'Question-Based',
                      subtitle: 'Present information through questions',
                      onTap: () => _handleModifyOption(context, 'questions'),
                    ),
                    _buildModifyOption(
                      context,
                      icon: Icons.article_outlined,
                      title: 'Structured Format',
                      subtitle: 'Organize with clear headings and sections',
                      onTap: () => _handleModifyOption(context, 'structured'),
                    ),
                    _buildModifyOption(
                      context,
                      icon: Icons.timeline,
                      title: 'Step-by-Step',
                      subtitle: 'Break down into sequential steps',
                      onTap: () => _handleModifyOption(context, 'steps'),
                    ),
                    const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModifyOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F3F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD0CFCB), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAE9E5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFF000000),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Color(0xFF666666),
            ),
          ],
        ),
      ),
    );
  }

  void _handleModifyOption(BuildContext context, String modifyType) {
    Navigator.pop(context); // Close the bottom sheet
    
    if (widget.onModifyResponse != null) {
      widget.onModifyResponse!(modifyType);
    }
    
    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✨ Modifying response to be ${_getModifyDescription(modifyType)}...',
          style: const TextStyle(
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

  String _getModifyDescription(String modifyType) {
    switch (modifyType) {
      case 'expand':
        return 'more detailed';
      case 'shorten':
        return 'more concise';
      case 'simplify':
        return 'simpler';
      case 'professional':
        return 'more professional';
      case 'casual':
        return 'more casual';
      case 'examples':
        return 'include examples';
      case 'humor':
        return 'more engaging';
      case 'technical':
        return 'more technical';
      case 'actionable':
        return 'action-focused';
      case 'questions':
        return 'question-based';
      case 'structured':
        return 'better structured';
      case 'steps':
        return 'step-by-step';
      default:
        return 'modified';
    }
  }

  Widget _buildImageWidget(String url) {
    try {
      Widget image;
      if (url.startsWith('data:image')) {
        final commaIndex = url.indexOf(',');
        final header = url.substring(5, commaIndex);
        final mime = header.split(';').first;
        final base64Data = url.substring(commaIndex + 1);
        final bytes = base64Decode(base64Data);
        if (mime == 'image/svg+xml') {
          image = SvgPicture.memory(bytes, fit: BoxFit.contain);
        } else {
          image = Image.memory(bytes, fit: BoxFit.contain);
        }
      } else {
        if (url.toLowerCase().endsWith('.svg')) {
          image = SvgPicture.network(
            url,
            fit: BoxFit.contain,
            placeholderBuilder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
        } else {
          image = Image.network(url, fit: BoxFit.contain);
        }
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300, maxWidth: double.infinity),
          child: image,
        ),
      );
    } catch (_) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBot = widget.message.sender == Sender.bot;
    final isUser = widget.message.sender == Sender.user;
    final canShowActions = isBot && !widget.message.isStreaming && widget.message.text.isNotEmpty && widget.onRegenerate != null;

    Widget bubbleContent = Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: isBot ? Colors.transparent : const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: isBot
          ? widget.messageContentBuilder(widget.message)
          : Text(
              widget.message.text, 
              style: const TextStyle(
                fontSize: 15, 
                height: 1.5, 
                color: Color(0xFF000000),
                fontWeight: FontWeight.w500,
              ),
            ),
    );

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          // Message content
          if (isUser)
            GestureDetector(
              onTap: _toggleUserActions,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _showUserActions ? const Color(0xFFEAE9E5).withOpacity(0.3) : Colors.transparent,
                ),
                child: bubbleContent,
              ),
            )
          else if (isBot && canShowActions)
            GestureDetector(
              onTap: _toggleActions,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _showActions ? const Color(0xFFEAE9E5).withOpacity(0.3) : Colors.transparent,
                ),
                child: bubbleContent,
              ),
            )
          else
            bubbleContent,
          // User message actions
          if (isUser && _showUserActions)
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.2, 0),
                end: Offset.zero,
              ).animate(_userActionsAnimation),
              child: FadeTransition(
                opacity: _userActionsAnimation,
                child: Container(
                  margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Copy
                      ActionButton(
                        icon: Icons.content_copy_rounded,
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: widget.message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '📋 Message copied to clipboard!',
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
                          _toggleUserActions();
                        },
                        tooltip: 'Copy text',
                      ),
                      const SizedBox(width: 8),
                      // Edit & Resend
                      ActionButton(
                        icon: Icons.edit_rounded,
                        onTap: () {
                          // Call the existing edit functionality
                          if (widget.onUserMessageTap != null) {
                            widget.onUserMessageTap!();
                          }
                          _toggleUserActions();
                        },
                        tooltip: 'Edit & Resend',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // iOS-style action buttons that slide in for bot messages
          if (canShowActions && _showActions)
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-0.2, 0),
                end: Offset.zero,
              ).animate(_actionsAnimation),
              child: FadeTransition(
                opacity: _actionsAnimation,
                child: Container(
                  margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Copy
                      ActionButton(
                        icon: Icons.content_copy_rounded,
                        onTap: () => _copyMessage(context),
                        tooltip: 'Copy text',
                      ),
                      const SizedBox(width: 8),
                      // Regenerate
                      ActionButton(
                        icon: Icons.refresh_rounded,
                        onTap: () {
                          widget.onRegenerate?.call();
                          _toggleActions();
                        },
                        tooltip: 'Regenerate',
                      ),
                      const SizedBox(width: 8),
                      // Modify Response
                      ActionButton(
                        icon: Icons.auto_fix_high,
                        onTap: () => _showModifyOptions(context),
                        tooltip: 'Modify response',
                      ),
                    ],
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  
  const ActionButton({
    super.key,
    required this.icon, 
    required this.onTap,
    this.tooltip,
  });
  
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.black,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon, 
              color: const Color(0xFF000000), 
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}