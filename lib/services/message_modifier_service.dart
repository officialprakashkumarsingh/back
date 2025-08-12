class MessageModifierService {
  static String getModificationInstruction(String modifyType) {
    switch (modifyType) {
      case 'expand':
        return 'more detailed and comprehensive, with additional explanations and context';
      case 'shorten':
        return 'more concise and to the point, removing unnecessary details while keeping key information';
      case 'simplify':
        return 'explained in simpler terms with easier language and practical examples';
      case 'professional':
        return 'written in a more formal and professional tone suitable for business contexts';
      case 'casual':
        return 'written in a more friendly, conversational, and casual tone';
      case 'examples':
        return 'enhanced with practical examples, use cases, and real-world applications';
      default:
        return 'modified';
    }
  }

  static String createModificationPrompt(
    String originalUserPrompt,
    String botResponseText,
    String modifyType,
  ) {
    final modificationInstruction = getModificationInstruction(modifyType);
    
    return '''$originalUserPrompt

Please modify your previous response to be $modificationInstruction. Keep the same core information but adjust the style/format as requested.

Previous response:
$botResponseText''';
  }
}