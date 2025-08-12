import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MessageQueue {
  static final MessageQueue _instance = MessageQueue._internal();
  factory MessageQueue() => _instance;
  MessageQueue._internal();

  final List<String> _queuedMessages = [];
  final ValueNotifier<List<String>> _queueNotifier = ValueNotifier([]);
  
  List<String> get queuedMessages => List.unmodifiable(_queuedMessages);
  ValueNotifier<List<String>> get queueNotifier => _queueNotifier;
  
  void addMessage(String message) {
    _queuedMessages.add(message);
    _queueNotifier.value = List.from(_queuedMessages);
  }
  
  String? getNextMessage() {
    if (_queuedMessages.isEmpty) return null;
    final message = _queuedMessages.removeAt(0);
    _queueNotifier.value = List.from(_queuedMessages);
    return message;
  }
  
  void clearQueue() {
    _queuedMessages.clear();
    _queueNotifier.value = [];
  }
  
  bool get hasMessages => _queuedMessages.isNotEmpty;
  int get messageCount => _queuedMessages.length;
}

class QueuePanel extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onDismiss;
  
  const QueuePanel({
    super.key,
    required this.isVisible,
    this.onDismiss,
  });

  @override
  State<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends State<QueuePanel> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }
  
  @override
  void didUpdateWidget(QueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _slideController.forward();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _slideController.reverse();
    }
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }
  
  void _removeMessage(int index) {
    final queue = MessageQueue();
    if (index < queue._queuedMessages.length) {
      queue._queuedMessages.removeAt(index);
      queue._queueNotifier.value = List.from(queue._queuedMessages);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();
    
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: 320,
        margin: const EdgeInsets.only(right: 16, bottom: 80),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F3F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFEAE9E5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFEAE9E5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF000000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Message Queue',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF000000),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<List<String>>(
                    valueListenable: MessageQueue().queueNotifier,
                    builder: (context, messages, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${messages.length}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFFFFFF),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000000).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_right_rounded,
                        size: 16,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Queue items
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ValueListenableBuilder<List<String>>(
                valueListenable: MessageQueue().queueNotifier,
                builder: (context, messages, child) {
                  if (messages.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAE9E5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 24,
                              color: Color(0xFFA3A3A3),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No messages queued',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFFA3A3A3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Send messages while AI is thinking',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFFA3A3A3),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFEAE9E5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF000000),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFFFFFF),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                message,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF000000),
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _removeMessage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAE9E5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Footer
            if (MessageQueue().hasMessages)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFEAE9E5),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Color(0xFF666666),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Messages will be sent automatically',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => MessageQueue().clearQueue(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Clear All',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}