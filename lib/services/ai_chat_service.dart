import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';

class AIChatService {
  static const String _apiUrl = 'https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions';
  static const String _apiKey = 'ahamaibyprakash25';

  static Future<Stream<String>> generateResponse({
    required String prompt,
    required String selectedModel,
    required String memoryContext,
    String? uploadedImageBase64,
  }) async {
    final client = http.Client();
    
    try {
      final request = http.Request('POST', Uri.parse(_apiUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      });

      // Build message content with optional image
      Map<String, dynamic> messageContent;
      final fullPrompt = memoryContext.isNotEmpty ? '$memoryContext\n\nUser: $prompt' : prompt;
      
      if (uploadedImageBase64 != null && uploadedImageBase64.isNotEmpty) {
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
                'url': uploadedImageBase64,
              },
            },
          ],
        };
      } else {
        messageContent = {
          'role': 'user',
          'content': fullPrompt,
        };
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

      request.body = jsonEncode({
        'model': selectedModel,
        'messages': [systemMessage, messageContent],
        'stream': true,
        'max_tokens': 4000,
        'temperature': 0.7,
      });

      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        client.close();
        throw Exception('API request failed with status: ${response.statusCode}');
      }

      return response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((line) => line.trim().isNotEmpty && line.startsWith('data: '))
          .map((line) => line.substring(6))
          .where((data) => data.trim() != '[DONE]')
          .map((data) {
            try {
              final json = jsonDecode(data);
              final delta = json['choices']?[0]?['delta'];
              return delta?['content'] as String? ?? '';
            } catch (e) {
              return '';
            }
          })
          .where((content) => content.isNotEmpty);
          
    } catch (e) {
      client.close();
      throw Exception('Failed to generate response: $e');
    }
  }

  static String fixServerEncoding(String text) {
    return text
        .replaceAll('â€™', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€', '"')
        .replaceAll('â€"', '—')
        .replaceAll('â€"', '–')
        .replaceAll('â€¦', '…')
        .replaceAll('Ã©', 'é')
        .replaceAll('Ã¡', 'á')
        .replaceAll('Ã­', 'í')
        .replaceAll('Ã³', 'ó')
        .replaceAll('Ãº', 'ú')
        .replaceAll('Ã±', 'ñ')
        .replaceAll('Ã§', 'ç');
  }
}