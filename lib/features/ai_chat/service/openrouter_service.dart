import 'dart:convert';
import 'package:http/http.dart' as http;

import '../model/chat_models.dart';

class OpenRouterService {
  static const _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  // Store your key in flutter_dotenv — never hardcode
  final String apiKey;
  final String model;

  OpenRouterService({
    required this.apiKey,
    this.model = 'google/gemini-2.5-flash'
  });

  /// Sends conversation to LLM and returns raw string response.
  Future<String> chat({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      // Last 10 messages for context
      ...history.takeLast(10).map((m) => m.toJson()),
      {'role': 'user', 'content': userMessage},
    ];

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'com.mg.apnaca',
          },
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'max_tokens': 512,
            'temperature': 0.1,  // low temp = consistent JSON output
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('LLM API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body);
    return json['choices'][0]['message']['content'] as String;
  }
}

// Extension used in repository
extension ListTakeLast<T> on List<T> {
  List<T> takeLast(int n) =>
      length <= n ? this : sublist(length - n);
}
