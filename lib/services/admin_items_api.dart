import 'package:http/http.dart' as http;

import '../config/env.dart';

class AdminItemsApi {
  AdminItemsApi({String? baseUrl}) : baseUrl = baseUrl ?? entitiesBaseUrl;

  final String baseUrl;

  Future<void> deleteItem({
    required String pk,
    String sk = 'META',
    required String adminKey,
    required String deletedBy,
  }) async {
    final trimmedKey = adminKey.trim();
    if (trimmedKey.isEmpty) {
      throw Exception('Missing QC admin key (X-Admin-Key)');
    }
    final trimmedDeletedBy = deletedBy.trim();
    if (trimmedDeletedBy.isEmpty) {
      throw Exception('Missing deleted by name (X-Admin-Name)');
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
        'x-admin-name': trimmedDeletedBy,
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Delete failed (${res.statusCode}): ${res.body}');
    }
  }
}
