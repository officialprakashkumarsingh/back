import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models.dart';
import 'character_service.dart';
import 'message_queue.dart';
import 'utils/message_parsing.dart';
import 'widgets/html_preview_dialog.dart';
import 'widgets/input_bar.dart';

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

  http.Client? _httpClient;
  final CharacterService _characterService = CharacterService();


  final _prompts = ['Explain quantum computing', 'Write a Python snippet', 'Draft an email to my boss', 'Ideas for weekend trip'];
  
  // MODIFICATION: Robust function to fix server-side encoding errors (mojibake).
  // This is the core fix for rendering emojis and special characters correctly.
  String _fixServerEncoding(String text) {
    try {
      // This function corrects text that was encoded in UTF-8 but mistakenly interpreted as Latin-1.
      // 1. We take the garbled string and encode it back into bytes using Latin-1.
      //    This recovers the original, correct UTF-8 byte sequence.
      final originalBytes = latin1.encode(text);
      // 2. We then decode these bytes using the correct UTF-8 format.
      //    `allowMalformed: true` makes this more robust against potential errors.
      return utf8.decode(originalBytes, allowMalformed: true);
    } catch (e) {
      // If anything goes wrong, return the original text to prevent the app from crashing.
      return text;
    }
  }

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
    _httpClient?.close();
    super.dispose();
  }

  List<Message> getMessages() => _messages;

  void loadChatSession(List<Message> messages) {
    setState(() {
      _awaitingReply = false;
      _httpClient?.close();
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

    // Regular AI chat - AI is now aware of external tools it can access
    // The AI will mention and use external tools based on user requests

    _httpClient = http.Client();
    final memoryContext = _getMemoryContext();
    final fullPrompt = memoryContext.isNotEmpty ? '$memoryContext\n\nUser: $prompt' : prompt;

    try {
      final request = http.Request('POST', Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions'));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ahamaibyprakash25',
      });
      // Build message content with optional image
      Map<String, dynamic> messageContent;
      if (_uploadedImageBase64 != null && _uploadedImageBase64!.isNotEmpty) {
        messageContent = {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': fullPrompt,
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': _uploadedImageBase64!,
              },
            },
          ],
        };
      } else {
        messageContent = {'role': 'user', 'content': fullPrompt};
      }

      final systemMessage = {
        'role': 'system',
        'content': '''You are AhamAI, an intelligent assistant. You provide helpful, accurate, and comprehensive responses to user questions.

Be helpful, conversational, and provide detailed explanations when needed. You can write code, explain concepts, help with problems, and engage in discussions on a wide variety of topics.

📸 SCREENSHOT CAPABILITY:
When users ask for screenshots of websites, you can generate them using this URL format:
https://s.wordpress.com/mshots/v1/[URL_ENCODED_WEBSITE]?w=1920&h=1080

Examples:
- For google.com: https://s.wordpress.com/mshots/v1/https%3A%2F%2Fgoogle.com?w=1920&h=1080
- For github.com: https://s.wordpress.com/mshots/v1/https%3A%2F%2Fgithub.com?w=1920&h=1080
- For any site: https://s.wordpress.com/mshots/v1/[URL_ENCODED_SITE]?w=1920&h=1080

Simply include the screenshot URL in your response using markdown image syntax: ![Screenshot Description](screenshot_url)

The app will automatically render these images inline with your response.

Always be polite, professional, and aim to provide the most useful response possible.'''
      };

      request.body = json.encode({
        'model': widget.selectedModel,
        'messages': [systemMessage, messageContent],
        'stream': true,
      });

      final response = await _httpClient!.send(request);

      if (response.statusCode == 200) {
        final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
        var botMessage = Message.bot('', isStreaming: true);
        final botMessageIndex = _messages.length;
        
        setState(() {
          _messages.add(botMessage);
        });

        String accumulatedText = '';
        await for (final line in stream) {
          if (!mounted || _httpClient == null) break;
          
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            if (jsonStr.trim() == '[DONE]') break;
            
            try {
              final data = json.decode(jsonStr);
              final content = data['choices']?[0]?['delta']?['content'];
              if (content != null) {
                accumulatedText += _fixServerEncoding(content);
                setState(() {
                  // Update only text during streaming, don't parse content yet
                  _messages[botMessageIndex] = _messages[botMessageIndex].copyWith(
                    text: accumulatedText,
                    isStreaming: true,
                    // For streaming, use raw text as displayText and keep codes empty
                    displayText: accumulatedText,
                    codes: [], // Clear codes during streaming to prevent duplication
                  );
                });
                _scrollToBottom();
              }
            } catch (e) {
              // Continue on JSON parsing errors
            }
          }
        }

        setState(() {
          _messages[botMessageIndex] = Message.bot(
            accumulatedText,
            isStreaming: false,
          );
        });

        // Update memory with the completed conversation
        _updateConversationMemory(prompt, accumulatedText);

        // Ensure UI scrolls to bottom after processing
        _scrollToBottom();

      } else {
        // Handle different status codes more gracefully
        String errorMessage;
        if (response.statusCode == 400) {
          errorMessage = 'Bad request. Please check your message format and try again.';
        } else if (response.statusCode == 401) {
          errorMessage = 'Authentication failed. Please check API credentials.';
        } else if (response.statusCode == 429) {
          errorMessage = 'Rate limit exceeded. Please wait a moment and try again.';
        } else if (response.statusCode >= 500) {
          errorMessage = 'Server error. Please try again in a moment.';
        } else {
          errorMessage = 'Sorry, there was an error processing your request. Status: ${response.statusCode}';
        }
        
        setState(() {
          _messages.add(Message.bot(errorMessage));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(Message.bot('Sorry, I\'m having trouble connecting right now. Please try again. Error: ${e.toString().length > 100 ? e.toString().substring(0, 100) + '...' : e.toString()}'));
        });
      }
    } finally {
      // Clean up resources
      _httpClient?.close();
      _httpClient = null;
      if (mounted) {
        setState(() {
          _awaitingReply = false;
        });
        // Clear uploaded image only after successful processing
        if (_uploadedImageBase64 != null) {
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) _clearUploadedImage();
          });
        }
        // Process next message in queue if available
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
  
  void _stopGeneration() {
    _httpClient?.close();
    _httpClient = null;
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
      _httpClient?.close();
      _httpClient = null;
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
                    return _MessageBubble(
                      key: ValueKey(message.id),
                      message: message,
                      onRegenerate: () => _regenerateResponse(index),
                      onUserMessageTap: () => _showUserMessageOptions(context, message),
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
        // Queue Panel
        Positioned(
          top: 50,
          right: 0,
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
            top: 60,
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
      ],
    );
  }
}

/* ----------------------------------------------------------
   MESSAGE BUBBLE & ACTION BUTTONS - iOS Style Interactions
---------------------------------------------------------- */
class _MessageBubble extends StatefulWidget {
  final Message message;
  final VoidCallback? onRegenerate;
  final VoidCallback? onUserMessageTap;
  const _MessageBubble({
    super.key,
    required this.message,
    this.onRegenerate,
    this.onUserMessageTap,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> with TickerProviderStateMixin {
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
          ? _MessageContentWithInlineCode(message: widget.message)
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
          // Thoughts panel for bot messages - MOVED ABOVE THE MESSAGE
          if (isBot && widget.message.thoughts.isNotEmpty)
            _ThoughtsPanel(thoughts: widget.message.thoughts),

          // Tool results panel for bot messages
          if (isBot && widget.message.toolData.isNotEmpty)
            _ToolResultsPanel(toolData: widget.message.toolData),
          // Agent processing panel removed – agent output will now stream directly in the chat bubble
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
                      _ActionButton(
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
                      _ActionButton(
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
                      // Thumbs up
                      _ActionButton(
                        icon: Icons.thumb_up_rounded,
                        onTap: () => _giveFeedback(context, true),
                        tooltip: 'Good response',
                      ),
                      const SizedBox(width: 8),
                      // Thumbs down
                      _ActionButton(
                        icon: Icons.thumb_down_rounded,
                        onTap: () => _giveFeedback(context, false),
                        tooltip: 'Bad response',
                      ),
                      const SizedBox(width: 8),
                      // Copy
                      _ActionButton(
                        icon: Icons.content_copy_rounded,
                        onTap: () => _copyMessage(context),
                        tooltip: 'Copy text',
                      ),
                      const SizedBox(width: 8),
                      // Regenerate
                      _ActionButton(
                        icon: Icons.refresh_rounded,
                        onTap: () {
                          widget.onRegenerate?.call();
                          _toggleActions();
                        },
                        tooltip: 'Regenerate',
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  
  const _ActionButton({
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



/* ----------------------------------------------------------
   CODE PANEL - Collapsible panel for code blocks
---------------------------------------------------------- */
class _CodePanel extends StatefulWidget {
  final List<CodeContent> codes;
  
  const _CodePanel({required this.codes});
  
  @override
  State<_CodePanel> createState() => _CodePanelState();
}

class _CodePanelState extends State<_CodePanel> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }
  
  void _copyCode(String code) {
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
  
  String _getCodePreview() {
    if (widget.codes.isEmpty) return '';
    final firstCode = widget.codes.first;
    final preview = firstCode.code.length > 50 
        ? '${firstCode.code.substring(0, 50)}...'
        : firstCode.code;
    return preview;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle button
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
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFA3A3A3),
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
          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.codes.map((codeContent) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAE9E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with language and copy button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF000000),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                codeContent.extension.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFFFFFF),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => _copyCode(codeContent.code),
                              icon: const Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: Color(0xFF000000),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Code content
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
                            child: Text(
                              codeContent.code,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xFFFFFFFF),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------
   THOUGHTS PANEL - Collapsible panel for AI thinking content
---------------------------------------------------------- */
class _ThoughtsPanel extends StatefulWidget {
  final List<ThoughtContent> thoughts;
  
  const _ThoughtsPanel({required this.thoughts});
  
  @override
  State<_ThoughtsPanel> createState() => _ThoughtsPanelState();
}

class _ThoughtsPanelState extends State<_ThoughtsPanel> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }
  
  String _getThoughtsPreview() {
    if (widget.thoughts.isEmpty) return '';
    final firstThought = widget.thoughts.first;
    final preview = firstThought.text.length > 50 
        ? '${firstThought.text.substring(0, 50)}...'
        : firstThought.text;
    return preview;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, top: 8, bottom: 4),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle button
          InkWell(
            onTap: _toggleExpansion,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isExpanded 
                          ? 'Thoughts (${widget.thoughts.length})'
                          : _getThoughtsPreview(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFA3A3A3),
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
          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.thoughts.map((thought) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F3F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          thought.type.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFFFFFF),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        thought.text,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF000000),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------
   TOOL RESULTS PANEL - Displays external tool execution results
---------------------------------------------------------- */
class _ToolResultsPanel extends StatefulWidget {
  final Map<String, dynamic> toolData;
  
  const _ToolResultsPanel({required this.toolData});
  
  @override
  State<_ToolResultsPanel> createState() => _ToolResultsPanelState();
}

class _ToolResultsPanelState extends State<_ToolResultsPanel> with SingleTickerProviderStateMixin {
  bool _isExpanded = true; // Start expanded for better visibility
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    // Start expanded
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF000000).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle button
          InkWell(
            onTap: _toggleExpansion,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.build_circle_rounded,
                    size: 16,
                    color: const Color(0xFF000000),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tool Results (${widget.toolData.length})',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF000000),
                        fontWeight: FontWeight.w600,
                      ),
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
          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.toolData.entries.map((entry) {
                  final toolName = entry.key;
                  final result = entry.value as Map<String, dynamic>;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAE9E5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with tool name and status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: result['success'] == true ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  toolName.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFFFFFF),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                result['success'] == true ? Icons.check_circle : Icons.error,
                                size: 16,
                                color: result['success'] == true ? Colors.green : Colors.red,
                              ),
                              const Spacer(),
                              if (result['execution_time'] != null)
                                Text(
                                  'Executed',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFFA3A3A3),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Tool result content
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              
                              // Result details
                              if ((result['url'] != null) ||
                                  (result['models'] != null) ||
                                  (result['new_model'] != null) ||
                                  (result['api_status'] != null) ||
                                  (result['error'] != null))
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (result['url'] != null)
                                        _buildResultRow('URL', result['url']),
                                      if (result['models'] != null)
                                        _buildResultRow('Models Count', '${(result['models'] as List).length}'),
                                      if (result['new_model'] != null)
                                        _buildResultRow('New Model', result['new_model']),
                                      if (result['api_status'] != null)
                                        _buildResultRow('API Status', result['api_status']),
                                      if (result['error'] != null)
                                        _buildResultRow('Error', result['error'], isError: true),
                                    ],
                                  ),
                                ),

                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
                color: isError ? Colors.red[300] : const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
}

/* ----------------------------------------------------------
   ANIMATED MODE ICON - Reusable component with animated border
---------------------------------------------------------- */
class _AnimatedModeIcon extends StatefulWidget {
  final bool isActive;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AnimatedModeIcon({
    required this.isActive,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_AnimatedModeIcon> createState() => _AnimatedModeIconState();
}

class _AnimatedModeIconState extends State<_AnimatedModeIcon> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Clean icon with subtle active state
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.isActive 
                          ? const Color(0xFF6366F1).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        color: widget.isActive 
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF6B7280),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                      color: widget.isActive 
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/* ----------------------------------------------------------
   MESSAGE CONTENT WITH INLINE CODE - Renders message with inline code panels
---------------------------------------------------------- */
class _MessageContentWithInlineCode extends StatelessWidget {
  final Message message;
  
  const _MessageContentWithInlineCode({required this.message});
  
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

    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // For streaming messages, just show the raw text
        if (message.isStreaming) 
          MarkdownBody(
            data: message.displayText,
            imageBuilder: (uri, title, alt) => _buildImageWidget(uri.toString()),
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
          )
        else ...[
          // For finished messages, use displayText (with code blocks removed) 
          if (message.displayText.isNotEmpty)
            MarkdownBody(
              data: message.displayText,
              imageBuilder: (uri, title, alt) => _buildImageWidget(uri.toString()),
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
          // Add code panels from message.codes (only for finished messages)
          ...message.codes.map((codeContent) => Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: _InlineCodePanel(codeContent: codeContent),
          )),
        ],
      ],
    );
  }
}

/* ----------------------------------------------------------
   INLINE CODE PANEL - Code panel that appears within message content
---------------------------------------------------------- */
class _InlineCodePanel extends StatefulWidget {
  final CodeContent codeContent;
  
  const _InlineCodePanel({required this.codeContent});
  
  @override
  State<_InlineCodePanel> createState() => _InlineCodePanelState();
}

class _InlineCodePanelState extends State<_InlineCodePanel> {
  bool _isExpanded = true; // Start expanded for inline display
  
  void _copyCode(String code) {
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
  
  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }
  
  void _previewHtml(String htmlCode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return HtmlPreviewDialog(htmlContent: htmlCode);
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle button
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
                          ? widget.codeContent.language.toUpperCase()
                          : '${widget.codeContent.language.toUpperCase()} - ${widget.codeContent.code.length > 50 ? "${widget.codeContent.code.substring(0, 50)}..." : widget.codeContent.code}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFA3A3A3),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: _isExpanded ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.codeContent.language.toLowerCase() == 'html')
                    IconButton(
                      onPressed: () => _previewHtml(widget.codeContent.code),
                      icon: const Icon(
                        Icons.preview_rounded,
                        size: 16,
                        color: Color(0xFF000000),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  IconButton(
                    onPressed: () => _copyCode(widget.codeContent.code),
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: Color(0xFF000000),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
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
          // Expandable content
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAE9E5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with language and copy button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF000000),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.codeContent.extension.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFFFFFF),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _copyCode(widget.codeContent.code),
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: Color(0xFF000000),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Code content
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
                          child: Text(
                            widget.codeContent.code,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFFFFFFFF),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}



