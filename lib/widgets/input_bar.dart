import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/* ----------------------------------------------------------
   INPUT BAR - The main input interface for sending messages
---------------------------------------------------------- */
class InputBar extends StatelessWidget {
  const InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onStop,
    required this.awaitingReply,
    required this.isEditing,
    required this.onCancelEdit,

    required this.onImageUpload,
    this.uploadedImagePath,
    required this.onClearImage,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool awaitingReply;
  final bool isEditing;
  final VoidCallback onCancelEdit;

  final VoidCallback onImageUpload;
  final String? uploadedImagePath;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F3F0), // Main theme background
      ),
      child: Column(
        children: [
          // Edit mode indicator
          if (isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12, top: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF000000).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF000000).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, color: Color(0xFF000000), size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Editing message...", 
                      style: TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onCancelEdit();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          
          // Main input container (smaller height)
          Container(
            margin: EdgeInsets.fromLTRB(20, isEditing ? 0 : 16, 20, 0),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white, // White input background
              borderRadius: BorderRadius.circular(24), // Fully rounded border on both sides
              border: Border.all(
                color: const Color(0xFFEAE9E5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Text input field with reduced height
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: true, // Keep input active during streaming for queue
                    maxLines: 3, // Reduced from 6
                    minLines: 1, // Reduced from 3
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: const Color(0xFF000000),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 16,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: awaitingReply 
                          ? 'Send message to queue while AI responds...' 
                          : uploadedImagePath != null
                              ? 'Image uploaded - Describe or ask about it...'
                              : 'Ask AhamAI',
                      suffixIcon: IconButton(
                        icon: Icon(
                          uploadedImagePath != null ? Icons.close : Icons.attach_file,
                          color: const Color(0xFF6B7280),
                          size: 20,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (uploadedImagePath != null) {
                            onClearImage();
                          } else {
                            onImageUpload();
                          }
                        },
                      ),
                      hintStyle: const TextStyle(
                        color: Color(0xFFA3A3A3),
                        fontSize: 16,
                        height: 1.4,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, // Increased padding for better rounded appearance
                        vertical: 12 // Reduced from 18
                      ),
                    ),
                  ),
                ),
                
                // Send/Stop button
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 6), // Adjusted padding
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stop button (when awaiting reply)
                      if (awaitingReply)
                        GestureDetector(
                          onTap: onStop,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.stop_circle,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                        ),
                      // Send button (always visible)
                      GestureDetector(
                        onTap: onSend,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF000000),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            awaitingReply ? Icons.queue : Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Icons below input bar
          if (!awaitingReply)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image preview removed as requested
                  

                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ShareButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4A9B8E),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}