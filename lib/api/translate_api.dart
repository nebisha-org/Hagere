import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/env.dart';

class TranslateApi {
  final String baseUrl = apiBaseUrl;

  Future<Map<String, String>> translateBatch(
    List<String> texts, {
    String target = 'am',
    String source = 'en',
  }) async {
    if (texts.isEmpty) return {};
    final uri = Uri.parse('$baseUrl/translate');
    final payload = {
      'source': source,
      'target': target,
      'texts': texts,
    };

    final res = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('Translate failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final List items = decoded is Map && decoded['items'] is List
        ? decoded['items'] as List
        : const [];

    final out = <String, String>{};
    for (final item in items) {
      if (item is Map) {
        final original = item['text']?.toString() ?? '';
        final translated = item['translated']?.toString() ?? original;
        if (original.isNotEmpty) {
          out[original] = translated;
        }
      }
    }
    return out;
  }
}
