import 'dart:convert';
import 'package:http/http.dart' as http;

class QuickReplyService {
  static const String _apiUrl = 'https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions';
  static const String _apiKey = 'ahamaibyprakash25';
  
  static Future<List<String>> getAIDynamicSuggestions({
    required String lastBotMessage,
    required String conversationContext,
    required String selectedModel,
  }) async {
    try {
      final client = http.Client();
      
      final request = http.Request('POST', Uri.parse(_apiUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      });

      final systemMessage = {
        'role': 'system',
        'content': '''You are a helpful assistant that generates quick reply suggestions for users to continue conversations.

Based on the AI's last response, generate 5 relevant, concise follow-up questions or statements that a user might want to ask.

Rules:
1. Keep each suggestion under 10 words
2. Make them contextually relevant to the last AI response
3. Vary the types: clarification, examples, next steps, alternatives, deeper dive
4. Make them natural and conversational
5. Return ONLY a JSON array of strings, nothing else

Example format: ["Tell me more", "Show an example", "What's next?", "Any alternatives?", "How does this work?"]'''
      };

      final userMessage = {
        'role': 'user',
        'content': '''Generate quick reply suggestions based on this AI response:

AI Response: "$lastBotMessage"

Context: $conversationContext

Generate 5 relevant follow-up questions/statements as a JSON array.'''
      };

      request.body = jsonEncode({
        'model': selectedModel,
        'messages': [systemMessage, userMessage],
        'stream': false,
        'max_tokens': 200,
        'temperature': 0.7,
      });

      final response = await client.send(request);
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        final content = jsonResponse['choices']?[0]?['message']?['content'] as String?;
        
        if (content != null) {
          // Try to extract JSON array from the response
          final cleanContent = content.trim();
          if (cleanContent.startsWith('[') && cleanContent.endsWith(']')) {
            final List<dynamic> suggestions = jsonDecode(cleanContent);
            return suggestions.cast<String>().take(5).toList();
          }
        }
      }
      
      client.close();
      
      // Fallback to static suggestions if AI fails
      return getFallbackSuggestions();
      
    } catch (e) {
      // Fallback to static suggestions if error occurs
      return getFallbackSuggestions();
    }
  }
  
  static List<String> getFallbackSuggestions() {
    return [
      "Tell me more",
      "Show an example", 
      "What's next?",
      "Any alternatives?",
      "Can you explain further?"
    ];
  }
  
  static List<String> getQuestionBasedSuggestions() {
    return [
      "How do I get started?",
      "What are the basics?",
      "Can you explain step by step?",
      "What tools do I need?",
      "Show me best practices",
      "What are common mistakes?",
      "Give me examples",
      "How does this work?"
    ];
  }
  
  static List<String> getFollowUpSuggestions() {
    return [
      "Continue",
      "Tell me more",
      "What's next?",
      "Explain further",
      "Give another example",
      "Show alternatives"
    ];
  }
}