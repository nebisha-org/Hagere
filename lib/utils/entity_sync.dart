import 'dart:convert';

const Set<String> _transientSyncKeys = {
  'distanceKm',
  '_syncEtag',
  '_syncStampMs',
  '_fieldEtags',
  '_clientUpdatedAtMs',
};

const List<String> _syncStampKeys = [
  '_syncStampMs',
  '_clientUpdatedAtMs',
  'updatedAt',
  'updated_at',
  'postedAt',
  'posted_at',
  'datePosted',
  'date_posted',
  'createdAt',
  'created_at',
  'created',
  'timestamp',
];

int? _parseStampMs(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final n = value.toInt();
    final abs = n.abs();
    return abs >= 1000000000000 ? n : n * 1000;
  }
  final text = value.toString().trim();
  if (text.isEmpty) return null;

  final asInt = int.tryParse(text);
  if (asInt != null) {
    final abs = asInt.abs();
    return abs >= 1000000000000 ? asInt : asInt * 1000;
  }

  final asDate = DateTime.tryParse(text);
  if (asDate == null) return null;
  return asDate.toUtc().millisecondsSinceEpoch;
}

int extractSyncStampMs(Map<String, dynamic> entity) {
  for (final key in _syncStampKeys) {
    final parsed = _parseStampMs(entity[key]);
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }
  return 0;
}

String entitySyncKey(Map<String, dynamic> entity) {
  const keys = ['id', 'entityId', 'place_id', 'placeId', 'item_id', 'itemId'];
  for (final key in keys) {
    final value = entity[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }

  final sk = entity['SK']?.toString().trim() ?? '';
  if (sk.isNotEmpty) return sk;

  final pk = entity['PK']?.toString().trim() ?? '';
  if (pk.isNotEmpty) return pk;

  final fallback = '${entity['name'] ?? ''}|${entity['address'] ?? ''}'.trim();
  if (fallback.isNotEmpty) {
    return 'fallback:${fnv1a32Hex(fallback)}';
  }
  return '';
}

String fnv1a32Hex(String input) {
  var hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
}

dynamic _canonicalizeForHash(dynamic value) {
  if (value is Map) {
    final out = <String, dynamic>{};
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    for (final key in keys) {
      if (_transientSyncKeys.contains(key)) continue;
      out[key] = _canonicalizeForHash(value[key]);
    }
    return out;
  }

  if (value is List) {
    return value.map(_canonicalizeForHash).toList();
  }

  if (value is String || value is num || value is bool || value == null) {
    return value;
  }

  return value.toString();
}

String computeEntityEtag(Map<String, dynamic> entity) {
  final canonical = jsonEncode(_canonicalizeForHash(entity));
  return fnv1a32Hex(canonical);
}

Map<String, String> computeFieldEtags(Map<String, dynamic> entity) {
  final out = <String, String>{};

  void walk(String path, dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      for (final key in keys) {
        if (_transientSyncKeys.contains(key)) continue;
        final next = path.isEmpty ? key : '$path.$key';
        walk(next, value[key]);
      }
      return;
    }

    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final next = '$path[$i]';
        walk(next, value[i]);
      }
      return;
    }

    final leafPath = path.isEmpty ? '<root>' : path;
    final stableValue = value is String || value is num || value is bool
        ? value.toString()
        : (value == null ? 'null' : value.toString());
    out[leafPath] = fnv1a32Hex(stableValue);
  }

  walk('', entity);
  return out;
}

Map<String, dynamic> withSyncMetadata(
  Map<String, dynamic> entity, {
  int? fallbackStampMs,
  String? fallbackEtag,
}) {
  final out = Map<String, dynamic>.from(entity);
  final extractedStampMs = extractSyncStampMs(out);
  final resolvedStampMs = extractedStampMs > 0
      ? extractedStampMs
      : (fallbackStampMs ?? DateTime.now().millisecondsSinceEpoch);

  out['_syncStampMs'] = resolvedStampMs;
  out['_syncEtag'] = (out['_syncEtag']?.toString().trim().isNotEmpty ?? false)
      ? out['_syncEtag'].toString().trim()
      : (fallbackEtag ?? computeEntityEtag(out));
  out['_fieldEtags'] = computeFieldEtags(out);
  return out;
}
