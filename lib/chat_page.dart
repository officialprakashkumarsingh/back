import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'character_service.dart';
import 'message_queue.dart';
import 'widgets/input_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/enhanced_code_block.dart';
import 'widgets/custom_markdown_code_builder.dart';
import 'widgets/quick_reply_suggestions.dart';
import 'widgets/message_reactions.dart';
import 'services/message_modifier_service.dart';
import 'services/ai_chat_service.dart';

/* ----------------------------------------------------------
   CHAT PAGE
---------------------------------------------------------- */
class ChatPage extends StatefulWidget {
  final void Function(Message botMessage) onBookmark;
  final String selectedModel;
  const ChatPage({super.key, required this.onBookmark, required this.selectedModel});

  @override
  State<ChatPage> createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <Message>[
    Message.bot('Hi, I\'m AhamAI. Ask me anything!'),
  ];
  bool _awaitingReply = false;
  String? _editingMessageId;

  // Web search and image upload modes
  bool _webSearchMode = false;
  String? _uploadedImagePath;
  String? _uploadedImageBase64;

  // Add memory system for general chat
  final List<String> _conversationMemory = [];
  static const int _maxMemorySize = 10;

  // Queue panel state
  bool _showQueuePanel = false;
  final MessageQueue _messageQueue = MessageQueue();
  
  // Quick reply state
  bool _showQuickReplies = false;


  final CharacterService _characterService = CharacterService();


  final _prompts = ['Explain quantum computing', 'Write a Python snippet', 'Draft an email to my boss', 'Ideas for weekend trip'];
  
  // MODIFICATION: Robust function to fix server-side encoding errors (mojibake).


  @override
  void initState() {
    super.initState();
    _characterService.addListener(_onCharacterChanged);
    _updateGreetingForCharacter();
    _controller.addListener(() {
      setState(() {}); // Refresh UI when text changes
    });
  }

  @override
  void dispose() {
    _characterService.removeListener(_onCharacterChanged);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<Message> getMessages() => _messages;

  void loadChatSession(List<Message> messages) {
    setState(() {
      _awaitingReply = false;
      _messages.clear();
      _messages.addAll(messages);
    });
  }

  void _onCharacterChanged() {
    if (mounted) {
      _updateGreetingForCharacter();
    }
  }



  void _updateGreetingForCharacter() {
    final selectedCharacter = _characterService.selectedCharacter;
    setState(() {
      if (_messages.isNotEmpty && _messages.first.sender == Sender.bot && _messages.length == 1) {
        if (selectedCharacter != null) {
          _messages.first = Message.bot('Hello! I\'m ${selectedCharacter.name}. ${selectedCharacter.description}. How can I help you today?');
        } else {
          _messages.first = Message.bot('Hi, I\'m AhamAI. Ask me anything!');
        }
      }
    });
  }

  void _startEditing(Message message) {
    setState(() {
      _editingMessageId = message.id;
      _controller.text = message.text;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    });
  }
  
  void _cancelEditing() {
    setState(() {
      _editingMessageId = null;
      _controller.clear();
    });
  }

  void _showUserMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF4F3F0),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.copy_all_rounded, color: Color(0xFF8E8E93)),
              title: const Text('Copy', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Copied to clipboard')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFF8E8E93)),
              title: const Text('Edit & Resend', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _startEditing(message);
              },
            ),
          ],
        );
      },
    );
  }

  void _updateConversationMemory(String userMessage, String aiResponse) {
    final memoryEntry = 'User: $userMessage\nAI: $aiResponse';
    _conversationMemory.add(memoryEntry);
    
    // Keep only the last 10 memory entries
    if (_conversationMemory.length > _maxMemorySize) {
      _conversationMemory.removeAt(0);
    }
  }

  String _getMemoryContext() {
    if (_conversationMemory.isEmpty) return '';
    return 'Previous conversation context:\n${_conversationMemory.join('\n\n')}\n\nCurrent conversation:';
  }

  Future<void> _generateResponse(String prompt) async {
    if (widget.selectedModel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No model selected'), backgroundColor: Color(0xFFEAE9E5)),
      );
      return;
    }

    setState(() => _awaitingReply = true);

    try {
      final responseStream = await AIChatService.generateResponse(
        prompt: prompt,
        selectedModel: widget.selectedModel,
        memoryContext: _getMemoryContext(),
        uploadedImageBase64: _uploadedImageBase64,
      );

      // Create bot message placeholder
      final botMessage = Message.bot('');
      setState(() => _messages.add(botMessage));
      final botMessageIndex = _messages.length - 1;

      String accumulatedText = '';
      await for (final content in responseStream) {
        if (!mounted || !_awaitingReply) break;

        accumulatedText += AIChatService.fixServerEncoding(content);
        setState(() {
          _messages[botMessageIndex] = _messages[botMessageIndex].copyWith(
            text: accumulatedText,
            isStreaming: true,
            displayText: accumulatedText,
            codes: [], // Clear codes during streaming to prevent duplication
          );
        });
        _scrollToBottom();
      }

      // Final update when streaming is complete
      if (mounted && _awaitingReply) {
        setState(() {
          _messages[botMessageIndex] = _messages[botMessageIndex].copyWith(isStreaming: false);
          _awaitingReply = false;
        });

        _updateConversationMemory(prompt, accumulatedText);

        if (_uploadedImageBase64 != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _clearUploadedImage();
          });
        }
        _processNextQueuedMessage();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _awaitingReply = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEAE9E5)),
        );
        
        if (_uploadedImageBase64 != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _clearUploadedImage();
          });
        }
        _processNextQueuedMessage();
      }
    }
  }



  void _regenerateResponse(int botMessageIndex) {
    int userMessageIndex = botMessageIndex - 1;
    if (userMessageIndex >= 0 && _messages[userMessageIndex].sender == Sender.user) {
      String lastUserPrompt = _messages[userMessageIndex].text;
      setState(() => _messages.removeAt(botMessageIndex));
      _generateResponse(lastUserPrompt);
    }
  }

  void _modifyResponse(int botMessageIndex, String modifyType) {
    if (botMessageIndex < 0 || botMessageIndex >= _messages.length) return;
    
    final botMessage = _messages[botMessageIndex];
    if (botMessage.sender != Sender.bot || botMessage.isStreaming) return;

    // Get the original user message
    int userMessageIndex = botMessageIndex - 1;
    if (userMessageIndex < 0 || _messages[userMessageIndex].sender != Sender.user) return;
    
    final modifiedPrompt = MessageModifierService.createModificationPrompt(
      _messages[userMessageIndex].text,
      botMessage.text,
      modifyType,
    );

    // Remove the old bot response and generate a new one
    setState(() => _messages.removeAt(botMessageIndex));
    _generateResponse(modifiedPrompt);
  }
  
  void _stopGeneration() {
    if(mounted) {
      setState(() {
        if (_awaitingReply && _messages.isNotEmpty && _messages.last.isStreaming) {
           final lastIndex = _messages.length - 1;
           _messages[lastIndex] = _messages.last.copyWith(isStreaming: false);
        }
        _awaitingReply = false;
      });
      // Process next message in queue if available
      _processNextQueuedMessage();
    }
  }

  void _processNextQueuedMessage() {
    if (!_awaitingReply && _messageQueue.hasMessages) {
      final nextMessage = _messageQueue.getNextMessage();
      if (nextMessage != null) {
        // Add small delay to make the flow feel natural
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && !_awaitingReply) {
            _sendMessageDirectly(nextMessage);
          }
        });
      }
    }
  }

  void _sendMessageDirectly(String messageText) {
    setState(() {
      _messages.add(Message.user(messageText));
    });
    _generateResponse(messageText);
    _scrollToBottom();
  }

  void startNewChat() {
    setState(() {
      _awaitingReply = false;
      _editingMessageId = null;
      _conversationMemory.clear(); // Clear memory for fresh start
      _messages.clear();
      final selectedCharacter = _characterService.selectedCharacter;
      if (selectedCharacter != null) {
        _messages.add(Message.bot('Fresh chat started with ${selectedCharacter.name}. How can I help?'));
      } else {
        _messages.add(Message.bot('Hi, I\'m AhamAI. Ask me anything!'));
      }
    });
  }



  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _send({String? text}) async {
    final messageText = text ?? _controller.text.trim();
    if (messageText.isEmpty) return;

    // If AI is currently responding, add to queue instead
    if (_awaitingReply) {
      _messageQueue.addMessage(messageText);
      _controller.clear();
      setState(() {
        _showQueuePanel = true;
      });
      HapticFeedback.lightImpact();
      return;
    }

    final isEditing = _editingMessageId != null;
    if (isEditing) {
      final messageIndex = _messages.indexWhere((m) => m.id == _editingMessageId);
      if (messageIndex != -1) {
        setState(() {
          _messages.removeRange(messageIndex, _messages.length);
        });
      }
    }
    
    _controller.clear();
    setState(() {
      _messages.add(Message.user(messageText));
      _editingMessageId = null;
    });

    _scrollToBottom();
    HapticFeedback.lightImpact();
    await _generateResponse(messageText);
  }

  void _toggleWebSearch() {
    setState(() {
      _webSearchMode = !_webSearchMode;
    });
  }

  Future<void> _handleImageUpload() async {
    try {
      await _showImageSourceDialog();
    } catch (e) {
      // Handle error
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showImageSourceDialog() async {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFFF4F3F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFC4C4C4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Title
            Text(
              'Select Image Source',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF000000),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Camera option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF000000)),
              ),
              title: Text(
                'Take Photo',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF000000),
                ),
              ),
              subtitle: Text(
                'Capture with camera',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA3A3A3),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            
            // Gallery option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF000000)),
              ),
              title: Text(
                'Choose from Gallery',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF000000),
                ),
              ),
              subtitle: Text(
                'Select from photos',
                style: GoogleFonts.inter(
                  color: const Color(0xFFA3A3A3),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        setState(() {
          _uploadedImagePath = pickedFile.path;
          _uploadedImageBase64 = 'data:image/jpeg;base64,$base64Image';
        });
        
        // Add image message to chat
        final imageMessage = Message.user("📷 Image uploaded: ${pickedFile.name}");
        setState(() {
          _messages.add(imageMessage);
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearUploadedImage() {
    setState(() {
      _uploadedImagePath = null;
      _uploadedImageBase64 = null;
    });
  }



  @override
  Widget build(BuildContext context) {
    final emptyChat = _messages.length <= 1;
    return Stack(
      children: [
        Container(
          color: const Color(0xFFF4F3F0),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _messages.length,
                  itemBuilder: (_, index) {
                    final message = _messages[index];
                    return MessageBubble(
                      key: ValueKey(message.id),
                      message: message,
                      onRegenerate: () => _regenerateResponse(index),
                      onUserMessageTap: () => _showUserMessageOptions(context, message),
                      onModifyResponse: (modifyType) => _modifyResponse(index, modifyType),
                      onReaction: (emoji) => _handleReaction(index, emoji),
                      onBotMessageTap: () => _showQuickReplies(),
                      messageContentBuilder: (message) {
                        if (message.sender == Sender.bot) {
                          // For bot messages, render with markdown and enhanced code blocks
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.displayText.isNotEmpty)
                                MarkdownBody(
                                  data: message.displayText,
                                  builders: {
                                    'code': CustomMarkdownCodeBuilder(),
                                  },
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(
                                      fontSize: 15, 
                                      height: 1.5, 
                                      color: Color(0xFF000000),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    code: TextStyle(
                                      backgroundColor: const Color(0xFFEAE9E5),
                                      color: const Color(0xFF000000),
                                      fontFamily: 'SF Mono',
                                      fontSize: 14,
                                    ),
                                    codeblockDecoration: BoxDecoration(
                                      color: const Color(0xFFEAE9E5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    h1: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                                    h2: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                                    h3: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                                    listBullet: const TextStyle(color: Color(0xFFA3A3A3)),
                                    blockquote: const TextStyle(color: Color(0xFFA3A3A3)),
                                    strong: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                                    em: const TextStyle(color: Color(0xFF000000), fontStyle: FontStyle.italic),
                                  ),
                                ),
                            ],
                          );
                        } else {
                          // For user messages, simple text
                          return Text(
                            message.text,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: Color(0xFF000000),
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          if (emptyChat && _editingMessageId == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _prompts.map((p) => Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _controller.text = p;
                            _send();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAE9E5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              p,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF000000),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),

                        SafeArea(
            top: false,
            left: false,
            right: false,
            child: InputBar(
              controller: _controller,
              onSend: () => _send(),
              onStop: _stopGeneration,
              awaitingReply: _awaitingReply,
              isEditing: _editingMessageId != null,
              onCancelEdit: _cancelEditing,

              onImageUpload: _handleImageUpload,
              uploadedImagePath: _uploadedImagePath,
              onClearImage: _clearUploadedImage,
            ),
          ),
            ],
          ),
        ),
        // Queue Panel - positioned just above input area
        Positioned(
          bottom: 100, // Just above the input area
          right: 0,
          left: 0,
          child: QueuePanel(
            isVisible: _showQueuePanel && _messageQueue.hasMessages,
            onDismiss: () {
              setState(() {
                _showQueuePanel = false;
              });
            },
          ),
        ),
        // Queue Button (shows when there are queued messages but panel is hidden)
        if (_messageQueue.hasMessages && !_showQueuePanel)
          Positioned(
            bottom: 110, // Just above the input area
            right: 20,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _messageQueue.queueNotifier,
              builder: (context, messages, child) {
                if (messages.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _showQueuePanel = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${messages.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF000000),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Queue',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        // Quick Reply Suggestions positioned above input area
        Positioned(
          bottom: 160, // Above input area and queue panel
          left: 0,
          right: 0,
          child: QuickReplySuggestions(
            lastBotMessage: _messages.isNotEmpty && _messages.last.sender == Sender.bot ? _messages.last.text : null,
            conversationContext: _messages.map((m) => '${m.sender.name}: ${m.text}').take(5).join('\n'),
            selectedModel: widget.selectedModel,
            onSuggestionTapped: _handleQuickReply,
            isVisible: _showQuickReplies,
          ),
        ),
      ],
    );
  }

  // Handle message reactions
  void _handleReaction(int messageIndex, String emoji) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reacted with $emoji'),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  // Show quick replies
  void _showQuickReplies() {
    setState(() {
      _showQuickReplies = true;
    });
  }
  
  // Handle quick reply selection
  void _handleQuickReply(String reply) {
    _controller.text = reply;
    setState(() {
      _showQuickReplies = false;
    });
    _send();
  }
}



