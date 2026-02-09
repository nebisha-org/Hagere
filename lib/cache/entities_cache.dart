import 'dart:convert';
import 'package:hive/hive.dart';

class EntitiesCache {
  static const String boxName = 'entities_cache_v1';

  static Future<Box> open() => Hive.openBox(boxName);

  static String key({required String regionKey, required String categoryId}) =>
      '$regionKey::$categoryId';

  static Map<String, dynamic>? read(Box box, String cacheKey) {
    final raw = box.get(cacheKey);
    if (raw is String && raw.isNotEmpty) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> write(
    Box box,
    String cacheKey, {
    required List<dynamic> itemsJson, // list of maps (already json-ready)
    String? etag,
  }) async {
    final payload = <String, dynamic>{
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'etag': etag,
      'items': itemsJson,
    };
    await box.put(cacheKey, jsonEncode(payload));
  }

  static Future<void> clearAll() async {
    final box = Hive.box(boxName);
    await box.clear();
  }

  static bool isFresh(Map<String, dynamic> cached, Duration ttl) {
    final ts = (cached['updatedAt'] ?? 0) as int;
    final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
    return ageMs >= 0 && ageMs <= ttl.inMilliseconds;
  }

  static List<dynamic> items(Map<String, dynamic> cached) {
    final v = cached['items'];
    return v is List ? v : const [];
  }

  static String? etag(Map<String, dynamic> cached) {
    final v = cached['etag'];
    return v is String ? v : null;
  }
}
