class QuickReplyService {
  static List<String> getContextualSuggestions(String lastBotMessage) {
    final lowerMessage = lastBotMessage.toLowerCase();
    
    // Programming/Code related suggestions
    if (lowerMessage.contains('code') || lowerMessage.contains('function') || 
        lowerMessage.contains('class') || lowerMessage.contains('variable')) {
      return [
        "Can you explain this in more detail?",
        "Show me an example",
        "What are the best practices?",
        "How do I debug this?",
        "Are there any alternatives?"
      ];
    }
    
    // Tutorial/Learning suggestions
    if (lowerMessage.contains('tutorial') || lowerMessage.contains('learn') ||
        lowerMessage.contains('beginner') || lowerMessage.contains('guide')) {
      return [
        "What's the next step?",
        "Can you give me practice exercises?",
        "What prerequisites do I need?",
        "Show me a complete example",
        "What common mistakes should I avoid?"
      ];
    }
    
    // Problem solving suggestions
    if (lowerMessage.contains('error') || lowerMessage.contains('problem') ||
        lowerMessage.contains('issue') || lowerMessage.contains('fix')) {
      return [
        "How do I prevent this in the future?",
        "Are there other solutions?",
        "What caused this problem?",
        "Can you walk me through the fix?",
        "Is there a simpler approach?"
      ];
    }
    
    // Explanation/Concept suggestions
    if (lowerMessage.contains('concept') || lowerMessage.contains('theory') ||
        lowerMessage.contains('explain') || lowerMessage.contains('understand')) {
      return [
        "Can you simplify this?",
        "Give me a real-world example",
        "How does this compare to...?",
        "What are the key benefits?",
        "When should I use this?"
      ];
    }
    
    // List/Comparison suggestions
    if (lowerMessage.contains('options') || lowerMessage.contains('types') ||
        lowerMessage.contains('ways') || lowerMessage.contains('methods')) {
      return [
        "Which one do you recommend?",
        "What are the pros and cons?",
        "Show me examples of each",
        "Which is best for beginners?",
        "How do I choose between them?"
      ];
    }
    
    // Technical documentation suggestions
    if (lowerMessage.contains('api') || lowerMessage.contains('documentation') ||
        lowerMessage.contains('reference') || lowerMessage.contains('syntax')) {
      return [
        "Show me the parameters",
        "What's the return value?",
        "Do you have a working example?",
        "What are common use cases?",
        "How do I handle errors?"
      ];
    }
    
    // General follow-up suggestions
    return [
      "Tell me more about this",
      "Can you expand on that?",
      "Show me an example",
      "What else should I know?",
      "How can I apply this?",
      "Are there any gotchas?",
      "What's the best practice?",
      "Can you simplify this?"
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