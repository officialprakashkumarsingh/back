import 'package:flutter/services.dart';

class CodeExecutionService {
  static const MethodChannel _channel = MethodChannel('com.ahamai.app/code_execution');
  
  // Languages that support execution preview
  static const Set<String> _executableLanguages = {
    // Code execution disabled for Android platform compatibility
  };
  
  static bool isExecutable(String language) {
    return _executableLanguages.contains(language.toLowerCase());
  }
  
  static Future<Map<String, dynamic>> executeCode({
    required String code,
    required String language,
  }) async {
    try {
      final result = await _channel.invokeMethod('executeCode', {
        'code': code,
        'language': language.toLowerCase(),
      });
      
      return {
        'success': true,
        'output': result['output'] ?? '',
        'error': result['error'] ?? '',
        'executionTime': result['executionTime'] ?? 0,
      };
    } on PlatformException catch (e) {
      return {
        'success': false,
        'output': '',
        'error': 'Platform Error: ${e.message}',
        'executionTime': 0,
      };
    } catch (e) {
      return {
        'success': false,
        'output': '',
        'error': 'Execution Error: $e',
        'executionTime': 0,
      };
    }
  }
  
  static String getLanguageExecutor(String language) {
    switch (language.toLowerCase()) {
      case 'javascript':
      case 'js':
        return 'JavaScript Engine';
      default:
        return 'Unknown';
    }
  }
  
  static String getExecutionIcon(String language) {
    switch (language.toLowerCase()) {
      case 'javascript':
      case 'js':
        return '🟨';
      default:
        return '▶️';
    }
  }
}