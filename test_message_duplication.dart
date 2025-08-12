import 'dart:io';

import 'lib/models.dart';

void main() {
  print('🧪 Testing Message Duplication Fix...\n');
  
  // Test 1: Basic Message Creation
  testBasicMessageCreation();
  
  // Test 2: Streaming Message Updates
  testStreamingMessageUpdates();
  
  // Test 3: Code Block Parsing
  testCodeBlockParsing();
  
  // Test 4: Content Duplication Prevention
  testContentDuplicationPrevention();
  
  print('\n✅ All tests completed!');
}

void testBasicMessageCreation() {
  print('Test 1: Basic Message Creation');
  
  // Test user message
  final userMessage = Message.user('Hello, this is a test message');
  assert(userMessage.sender == Sender.user);
  assert(userMessage.text == 'Hello, this is a test message');
  assert(userMessage.displayText == 'Hello, this is a test message');
  assert(!userMessage.isStreaming);
  print('  ✅ User message creation works correctly');
  
  // Test bot message
  final botMessage = Message.bot('Hi! I can help you with coding tasks.');
  assert(botMessage.sender == Sender.bot);
  assert(botMessage.text == 'Hi! I can help you with coding tasks.');
  assert(botMessage.displayText == 'Hi! I can help you with coding tasks.');
  assert(!botMessage.isStreaming);
  print('  ✅ Bot message creation works correctly');
  
  print('');
}

void testStreamingMessageUpdates() {
  print('Test 2: Streaming Message Updates');
  
  // Create initial streaming message
  var streamingMessage = Message.bot('', isStreaming: true);
  assert(streamingMessage.isStreaming);
  assert(streamingMessage.text == '');
  print('  ✅ Initial streaming message created');
  
  // Simulate streaming updates
  streamingMessage = streamingMessage.copyWith(
    text: 'Hello',
    isStreaming: true,
    displayText: 'Hello',
  );
  assert(streamingMessage.text == 'Hello');
  assert(streamingMessage.displayText == 'Hello');
  assert(streamingMessage.isStreaming);
  print('  ✅ First streaming update works');
  
  streamingMessage = streamingMessage.copyWith(
    text: 'Hello world',
    isStreaming: true,
    displayText: 'Hello world',
  );
  assert(streamingMessage.text == 'Hello world');
  assert(streamingMessage.displayText == 'Hello world');
  assert(streamingMessage.isStreaming);
  print('  ✅ Second streaming update works');
  
  // Finalize message
  streamingMessage = streamingMessage.copyWith(isStreaming: false);
  assert(!streamingMessage.isStreaming);
  print('  ✅ Message finalization works');
  
  print('');
}

void testCodeBlockParsing() {
  print('Test 3: Code Block Parsing');
  
  const messageWithCode = '''
Here's a Python example:

```python
def hello_world():
    print("Hello, World!")
    return "success"
```

And here's some more text after the code.
''';
  
  final message = Message.bot(messageWithCode);
  
  // Check that code was extracted
  assert(message.codes.isNotEmpty, 'Code blocks should be extracted');
  print('  ✅ Code blocks extracted: ${message.codes.length} found');
  
  // Check that code was removed from display text
  assert(!message.displayText.contains('```python'), 'Code blocks should be removed from display text');
  assert(message.displayText.contains('Here\'s a Python example:'), 'Regular text should remain');
  assert(message.displayText.contains('And here\'s some more text'), 'Text after code should remain');
  print('  ✅ Code blocks properly removed from display text');
  
  // Check code content
  final codeBlock = message.codes.first;
  assert(codeBlock.language == 'python', 'Language should be detected as python');
  assert(codeBlock.code.contains('def hello_world'), 'Code content should be preserved');
  print('  ✅ Code block content and language correctly identified');
  
  print('');
}

void testContentDuplicationPrevention() {
  print('Test 4: Content Duplication Prevention');
  
  const messageWithCodeAndText = '''
Let me show you a Flutter widget:

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('Hello Flutter!');
  }
}
```

This widget displays a simple text.
''';
  
  // Test streaming scenario
  var streamingMessage = Message.bot('', isStreaming: true);
  
  // Simulate gradual content building during streaming
  final contentParts = [
    'Let me show you',
    'Let me show you a Flutter widget:\n\n```dart\nclass MyWidget',
    messageWithCodeAndText,
  ];
  
  for (int i = 0; i < contentParts.length; i++) {
    streamingMessage = streamingMessage.copyWith(
      text: contentParts[i],
      isStreaming: true,
      displayText: contentParts[i],
    );
    
    // During streaming, content should not be re-parsed
    // The codes array should remain empty until finalization
    if (i < contentParts.length - 1) {
      assert(streamingMessage.codes.isEmpty, 'Codes should not be parsed during streaming');
    }
  }
  
  print('  ✅ Content not re-parsed during streaming updates');
  
  // Finalize the message - now parsing should happen
  final finalMessage = Message.bot(messageWithCodeAndText, isStreaming: false);
  
  // Check that content is only present in ONE place
  assert(finalMessage.codes.isNotEmpty, 'Code should be extracted in final message');
  assert(!finalMessage.displayText.contains('```dart'), 'Code should not be in display text');
  
  // Verify no duplication
  final codeInDisplayText = finalMessage.displayText.contains('class MyWidget');
  final codeInCodesArray = finalMessage.codes.any((code) => code.code.contains('class MyWidget'));
  
  assert(!codeInDisplayText, 'Code should not appear in display text');
  assert(codeInCodesArray, 'Code should appear in codes array');
  
  print('  ✅ No content duplication detected');
  print('  ✅ Code properly separated from display text');
  
  print('');
}