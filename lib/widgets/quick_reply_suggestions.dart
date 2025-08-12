import 'package:flutter/material.dart';
import '../services/quick_reply_service.dart';

class QuickReplySuggestions extends StatefulWidget {
  final String? lastBotMessage;
  final Function(String) onSuggestionTapped;
  final bool isVisible;
  
  const QuickReplySuggestions({
    super.key,
    this.lastBotMessage,
    required this.onSuggestionTapped,
    required this.isVisible,
  });

  @override
  State<QuickReplySuggestions> createState() => _QuickReplySuggestionsState();
}

class _QuickReplySuggestionsState extends State<QuickReplySuggestions> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }
  
  @override
  void didUpdateWidget(QuickReplySuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();
    
    final suggestions = widget.lastBotMessage != null 
        ? QuickReplyService.getContextualSuggestions(widget.lastBotMessage!)
        : QuickReplyService.getQuestionBasedSuggestions();
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * _slideAnimation.value),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => widget.onSuggestionTapped(suggestions[index]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAE9E5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFD0CFCB),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            suggestions[index],
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF000000),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}