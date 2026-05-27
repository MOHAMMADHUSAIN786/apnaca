/// Validates user input BEFORE sending to LLM.
/// Blocks SQL injection, prompt injection, and destructive commands.
class InputValidator {
  /// Returns null if input is safe, or an error message if blocked.
  static String? validate(String input) {
    final lower = input.toLowerCase().trim();

    // 1. Empty check
    if (input.trim().isEmpty) return 'Kuch likhein phir try karein.';

    // 2. Max length
    if (input.length > 500) {
      return 'Message bahut lamba hai. 500 characters se kam likhein.';
    }

    // 3. SQL injection / destructive DB commands
    final sqlPatterns = [
      RegExp(r'\bdrop\s+table\b', caseSensitive: false),
      RegExp(r'\bdrop\s+database\b', caseSensitive: false),
      RegExp(r'\bdelete\s+from\b', caseSensitive: false),
      RegExp(r'\btruncate\b', caseSensitive: false),
      RegExp(r'\balter\s+table\b', caseSensitive: false),
      RegExp(r'\bcreate\s+table\b', caseSensitive: false),
      RegExp(r'\binsert\s+into\b', caseSensitive: false),
      RegExp(r'\bselect\s+\*\b', caseSensitive: false),
      RegExp(r"'.*?'.*?=.*?'.*?'", caseSensitive: false), // ' OR '1'='1
      RegExp(r'--\s*$', multiLine: true),                  // SQL comment
      RegExp(r';\s*(drop|delete|truncate)', caseSensitive: false),
    ];
    for (final pattern in sqlPatterns) {
      if (pattern.hasMatch(lower)) {
        return 'Yeh command allowed nahi hai.';
      }
    }

    // 4. Prompt injection — trying to override system instructions
    final injectionPatterns = [
      RegExp(r'ignore\s+(previous|above|all)\s+instruction', caseSensitive: false),
      RegExp(r'forget\s+(your|all)\s+instruction', caseSensitive: false),
      RegExp(r'you\s+are\s+now\s+a', caseSensitive: false),
      RegExp(r'new\s+system\s+prompt', caseSensitive: false),
      RegExp(r'act\s+as\s+(a\s+)?(?!billing|assistant)', caseSensitive: false),
      RegExp(r'jailbreak', caseSensitive: false),
      RegExp(r'dan\s+mode', caseSensitive: false),
      RegExp(r'pretend\s+you', caseSensitive: false),
      RegExp(r'roleplay\s+as', caseSensitive: false),
      RegExp(r'override\s+(system|prompt)', caseSensitive: false),
      RegExp(r'system\s*:\s*you', caseSensitive: false),
    ];
    for (final pattern in injectionPatterns) {
      if (pattern.hasMatch(lower)) {
        return 'Yeh request allowed nahi hai.';
      }
    }

    // 5. Bulk destructive operations
    final destructivePatterns = [
      RegExp(r'\bdelete\s+all\b', caseSensitive: false),
      RegExp(r'\bsab\s+(kuch\s+)?delete\b', caseSensitive: false),
      RegExp(r'\bremove\s+all\b', caseSensitive: false),
      RegExp(r'\bclear\s+all\b', caseSensitive: false),
      RegExp(r'\bwipe\s+(all|data|database)\b', caseSensitive: false),
      RegExp(r'\bformat\s+(database|db|data)\b', caseSensitive: false),
    ];
    for (final pattern in destructivePatterns) {
      if (pattern.hasMatch(lower)) {
        return 'Bulk delete allowed nahi hai. Kisi ek item ya customer ka naam batao.';
      }
    }

    // 6. Code injection attempts
    final codePatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'eval\s*\(', caseSensitive: false),
      RegExp(r'exec\s*\(', caseSensitive: false),
    ];
    for (final pattern in codePatterns) {
      if (pattern.hasMatch(lower)) {
        return 'Yeh input allowed nahi hai.';
      }
    }

    return null; // ✅ Safe
  }
}
