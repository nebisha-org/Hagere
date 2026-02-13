import 'package:http/http.dart' as http;

import '../config/env.dart';

class AdminItemsApi {
  AdminItemsApi({String? baseUrl}) : baseUrl = baseUrl ?? entitiesBaseUrl;

  final String baseUrl;

  Future<void> deleteItem({
    required String pk,
    String sk = 'META',
    required String adminKey,
  }) async {
    final trimmedKey = adminKey.trim();
    if (trimmedKey.isEmpty) {
      throw Exception('Missing QC admin key (X-Admin-Key)');
    }
    final trimmedPk = pk.trim();
    if (trimmedPk.isEmpty) {
      throw Exception('Missing item PK');
    }

    final base = Uri.parse(baseUrl);
    final uri = base.replace(
      pathSegments: [
        ...base.pathSegments.where((s) => s.isNotEmpty),
        'admin',
        'items',
        trimmedPk, // auto-encoded (important: PK contains "#")
      ],
      queryParameters: {'sk': sk.trim().isEmpty ? 'META' : sk.trim()},
    );

    final res = await http.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        'x-admin-key': trimmedKey,
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Delete failed (${res.statusCode}): ${res.body}');
    }
  }
}
