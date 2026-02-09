import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/env.dart';

class OverridesApi {
  final String baseUrl = apiBaseUrl;

  Future<void> upsertOverride({
    required String entityType,
    required String entityId,
    required String fieldKey,
    required String locale,
    required String value,
    String updatedBy = '',
    String notes = '',
  }) async {
    final uri = Uri.parse('$baseUrl/overrides');
    final body = jsonEncode({
      'entityType': entityType,
      'entityId': entityId,
      'fieldKey': fieldKey,
      'locale': locale,
      'value': value,
      'updatedBy': updatedBy,
      'notes': notes,
    });
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
  }

  Future<Map<String, String>> fetchLatest({
    required String entityType,
    required String entityId,
    required String locale,
  }) async {
    final uri = Uri.parse('$baseUrl/overrides').replace(
      queryParameters: {
        'entityType': entityType,
        'entityId': entityId,
        'locale': locale,
      },
    );
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
    final decoded = jsonDecode(res.body);
    final Map<String, String> out = {};
    if (decoded is Map && decoded['overrides'] is Map) {
      final raw = decoded['overrides'] as Map;
      for (final entry in raw.entries) {
        out[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> fetchHistory({
    required String entityType,
    required String entityId,
    required String fieldKey,
    required String locale,
  }) async {
    final uri = Uri.parse('$baseUrl/overrides').replace(
      queryParameters: {
        'entityType': entityType,
        'entityId': entityId,
        'fieldKey': fieldKey,
        'locale': locale,
        'history': '1',
      },
    );
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) {
      throw Exception(res.body);
    }
    final decoded = jsonDecode(res.body);
    final List items = (decoded is Map && decoded['items'] is List)
        ? decoded['items']
        : const [];
    return items
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
        .toList();
  }
}
