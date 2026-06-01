// lib/features/ai_chat/service/openrouter_service.dart
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../model/chat_models.dart';

class OpenRouterService {
  static const _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  final String apiKey;
  final String model;

  // FIX 10 — Retry config
  static const int _maxRetries   = 2;   // 3 total attempts (1 + 2 retries)
  static const Duration _retryDelay = Duration(seconds: 1);

  OpenRouterService({
    required this.apiKey,
    this.model = 'google/gemini-2.0-flash-001',
  });

  // ════════════════════════════════════════════════════════════════
  //  FIX 10 — NETWORK RETRY LOGIC
  //
  //  BEFORE: single HTTP call — any timeout/network error = instant failure
  //  AFTER:
  //    - Max 2 retries on timeout / network error (3 total attempts)
  //    - 1 second delay between retries
  //    - On 3rd failure, throws with clear user-friendly message
  //    - Logs each retry attempt for debugging
  //    - Does NOT retry on 4xx (bad request) — only network/timeout errors
  // ════════════════════════════════════════════════════════════════
  Future<String> chat({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history.takeLast(10).map((m) => m.toJson()),
      {'role': 'user', 'content': userMessage},
    ];

    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'max_tokens': 512,
      'temperature': 0.1,
    });

    Exception? lastError;

    // FIX 10 — Retry loop: attempt 0 (first try) + up to _maxRetries
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          // FIX 10 — Wait before retry
          developer.log(
            'LLM retry attempt $attempt/$_maxRetries...',
            name: 'ApnaCA.LLM',
          );
          await Future.delayed(_retryDelay);
        }

        final response = await http
            .post(
          Uri.parse(_baseUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'com.mg.apnaca',
          },
          body: body,
        )
            .timeout(const Duration(seconds: 20));

        // FIX 10 — Do NOT retry on 4xx (client errors — bad request, auth)
        // Only retry on 5xx or network exceptions
        if (response.statusCode == 400 ||
            response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.statusCode == 422) {
          throw Exception('LLM API error ${response.statusCode}: ${response.body}');
        }

        if (response.statusCode != 200) {
          // 5xx or unexpected — retryable
          throw Exception('LLM API error ${response.statusCode}: ${response.body}');
        }

        final json = jsonDecode(response.body);
        return json['choices'][0]['message']['content'] as String;

      } on Exception catch (e) {
        lastError = e;
        final errStr = e.toString();

        // FIX 10 — Only retry on network / timeout / server errors
        final isRetryable = errStr.contains('TimeoutException') ||
            errStr.contains('SocketException') ||
            errStr.contains('HandshakeException') ||
            errStr.contains('Connection refused') ||
            errStr.contains('Network is unreachable') ||
            errStr.contains('500') ||
            errStr.contains('502') ||
            errStr.contains('503');

        if (!isRetryable) {
          // Non-retryable error (auth, bad request etc.) — fail fast
          developer.log(
            'LLM non-retryable error: $errStr',
            name: 'ApnaCA.LLM',
          );
          rethrow;
        }

        developer.log(
          'LLM attempt ${attempt + 1} failed: $errStr',
          name: 'ApnaCA.LLM',
        );

        // If this was the last attempt, fall through to throw below
        if (attempt == _maxRetries) break;
      }
    }

    // FIX 10 — All 3 attempts failed — throw with clear message
    developer.log(
      'LLM failed after ${_maxRetries + 1} attempts. Last error: $lastError',
      name: 'ApnaCA.LLM',
    );
    throw Exception(
      '📶 Network problem: LLM ${_maxRetries + 1} baar try karne ke baad bhi respond '
          'nahi kar raha. Internet check karein aur dobara try karein. '
          '(Last error: $lastError)',
    );
  }
}

// Extension used in repository
extension ListTakeLast<T> on List<T> {
  List<T> takeLast(int n) =>
      length <= n ? this : sublist(length - n);
}