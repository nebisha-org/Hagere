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

  static Future<void> touch(
    Box box,
    String cacheKey, {
    required List<dynamic> itemsJson,
    String? etag,
  }) async {
    await write(box, cacheKey, itemsJson: itemsJson, etag: etag);
  }

  static Future<bool> applyOverrideToAll({
    required String entityId,
    required String fieldKey,
    required String value,
    String? locale,
  }) async {
    final box = Hive.box(boxName);
    final localeKey = locale?.toLowerCase().trim();
    bool updated = false;

    for (final key in box.keys) {
      if (key is! String) continue;
      if (localeKey != null && !key.contains('::lang$localeKey')) {
        continue;
      }
      final cached = read(box, key);
      if (cached == null) continue;
      final itemsJson = items(cached);
      bool changed = false;

      for (final item in itemsJson) {
        if (item is! Map) continue;
        if (!_matchesEntity(item, entityId)) continue;
        if (_setPathValue(item, fieldKey, value)) {
          changed = true;
        }
      }

      if (changed) {
        await write(
          box,
          key,
          itemsJson: itemsJson,
          etag: etag(cached),
        );
        updated = true;
      }
    }

    return updated;
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

  static bool _matchesEntity(Map<dynamic, dynamic> item, String entityId) {
    final id = item['id'] ??
        item['entityId'] ??
        item['item_id'] ??
        item['itemId'];
    return id?.toString() == entityId;
  }

  static bool _setPathValue(
    Map<dynamic, dynamic> target,
    String path,
    String value,
  ) {
    if (path.isEmpty) return false;
    final parts = path.split('.');
    dynamic cur = target;
    for (int idx = 0; idx < parts.length; idx++) {
      final part = parts[idx];
      final match = RegExp(r'^([^\[\]]+)(?:\[(\d+)\])?$').firstMatch(part);
      if (match == null) {
        return false;
      }
      final key = match.group(1)!;
      final indexStr = match.group(2);
      final isLast = idx == parts.length - 1;

      if (indexStr == null) {
        if (cur is! Map) return false;
        if (isLast) {
          cur[key] = value;
          return true;
        }
        if (cur[key] is! Map) {
          cur[key] = <String, dynamic>{};
        }
        cur = cur[key];
        continue;
      }

      final index = int.tryParse(indexStr);
      if (index == null || cur is! Map) return false;
      if (cur[key] is! List) {
        cur[key] = <dynamic>[];
      }
      final list = cur[key] as List<dynamic>;
      while (list.length <= index) {
        list.add('');
      }
      if (isLast) {
        list[index] = value;
        return true;
      }
      if (list[index] is! Map) {
        list[index] = <String, dynamic>{};
      }
      cur = list[index];
    }
    return false;
  }
}
