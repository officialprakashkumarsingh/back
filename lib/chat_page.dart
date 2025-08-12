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
import 'widgets/message_bubble.dart';
import 'services/message_modifier_service.dart';

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
                    return MessageBubble(
                      key: ValueKey(message.id),
                      message: message,
                      onRegenerate: () => _regenerateResponse(index),
                      onUserMessageTap: () => _showUserMessageOptions(context, message),
                      onModifyResponse: (modifyType) => _modifyResponse(index, modifyType),
                      messageContentBuilder: (message) {
                        if (message.sender == Sender.bot) {
                          // For bot messages, render with markdown
                          return MarkdownBody(
                            data: message.isStreaming ? message.displayText : message.displayText,
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



