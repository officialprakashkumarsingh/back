import 'package:flutter/material.dart';
import '../services/quick_reply_service.dart';

class QuickReplySuggestions extends StatefulWidget {
  final String? lastBotMessage;
  final String conversationContext;
  final String selectedModel;
  final Function(String) onSuggestionTapped;
  final bool isVisible;
  
  const QuickReplySuggestions({
    super.key,
    this.lastBotMessage,
    required this.conversationContext,
    required this.selectedModel,
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
  
  List<String> _suggestions = [];
  bool _isLoadingSuggestions = false;
  
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
        _loadAISuggestions();
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }
  
  Future<void> _loadAISuggestions() async {
    if (widget.lastBotMessage == null || _isLoadingSuggestions) return;
    
    setState(() {
      _isLoadingSuggestions = true;
      _suggestions = ["Tell me more", "Show example", "What's next?"]; // Loading placeholders
    });
    
    try {
      final aiSuggestions = await QuickReplyService.getAIDynamicSuggestions(
        lastBotMessage: widget.lastBotMessage!,
        conversationContext: widget.conversationContext,
        selectedModel: widget.selectedModel,
      );
      
      if (mounted) {
        setState(() {
          _suggestions = aiSuggestions;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = QuickReplyService.getFallbackSuggestions();
          _isLoadingSuggestions = false;
        });
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
    
    final suggestions = _suggestions.isNotEmpty ? _suggestions : ["Loading..."];
    
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
                        onTap: _isLoadingSuggestions ? null : () => widget.onSuggestionTapped(suggestions[index]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _isLoadingSuggestions 
                                ? const Color(0xFFEAE9E5).withOpacity(0.6)
                                : const Color(0xFFEAE9E5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFD0CFCB),
                              width: 0.5,
                            ),
                          ),
                          child: Center(
                            child: _isLoadingSuggestions && suggestions[index] == "Loading..."
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF666666)),
                                    ),
                                  )
                                : Text(
                                    suggestions[index],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _isLoadingSuggestions 
                                          ? const Color(0xFF666666)
                                          : const Color(0xFF000000),
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