import '../config/env.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../cache/entities_cache.dart';
import '../utils/entity_sync.dart';

class EntitiesApi {
  final String baseUrl = entitiesBaseUrl;
  // Request a global radius so backend can return far items when nearby data is sparse.
  static const int _closestItemsRadiusKm = 20000;
  static const int _myEntitiesChunkSize = 40;
  final Set<String> _revalidateInFlight = <String>{};

  /// HOME SPONSORED
  Future<List<Map<String, dynamic>>> getHomeSponsored({String? locale}) async {
    final query = <String, String>{};
    if (locale != null && locale.trim().isNotEmpty) {
      query['locale'] = locale.trim();
    }
    final uri = Uri.parse('$entitiesBaseUrl/entities/home-sponsored')
        .replace(queryParameters: query.isEmpty ? null : query);
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) throw Exception(res.body);

    final decoded = jsonDecode(res.body);
    final List items = (decoded is Map && decoded['items'] is List)
        ? decoded['items']
        : const [];

    return items
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
        .toList();
  }

  /// ENTITIES (MAIN)
  Future<List<Map<String, dynamic>>> fetchEntities({
    required double lat,
    required double lon,
    int? limit,
  }) async {
    final query = <String, String>{
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radiusKm': _closestItemsRadiusKm.toString(),
    };
    if (limit != null) {
      query['limit'] = limit.toString();
    }

    final uri =
        Uri.parse('$entitiesBaseUrl/entities').replace(queryParameters: query);

    if (kDebugMode) {
      debugPrint('[EntitiesApi] GET $uri');
    }
    final sw = Stopwatch()..start();
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (kDebugMode) {
      debugPrint(
          '[EntitiesApi] status=${res.statusCode} ${sw.elapsedMilliseconds}ms');
    }
    if (res.statusCode != 200) throw Exception(res.body);
    return _decodeEntities(res.body);
  }

  /// ENTITY BY ID
  Future<Map<String, dynamic>> fetchEntityById(
    String entityId, {
    String? locale,
  }) async {
    final uri = Uri.parse('$entitiesBaseUrl/entities/$entityId').replace(
      queryParameters: (locale != null && locale.trim().isNotEmpty)
          ? {'locale': locale.trim()}
          : null,
    );
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) throw Exception(res.body);

    final decoded = jsonDecode(res.body);
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    throw Exception('Unexpected entity response: ${res.body}');
  }

  /// USER-OWNED ENTITIES BY AUTH OWNER ID
  Future<List<Map<String, dynamic>>> fetchOwnedEntities({
    required String ownerId,
    int limit = 200,
  }) async {
    final cleanOwnerId = ownerId.trim();
    if (cleanOwnerId.isEmpty) return <Map<String, dynamic>>[];

    final uri = Uri.parse('$entitiesBaseUrl/entities').replace(
      queryParameters: {
        'ownerId': cleanOwnerId,
        'limit': limit.toString(),
      },
    );
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) throw Exception(res.body);
    final items = _decodeEntities(res.body);
    return items
        .where(
            (item) => (item['ownerId'] ?? '').toString().trim() == cleanOwnerId)
        .toList();
  }

  /// ENTITIES BY ID LIST (used for guest/local posted history fallback)
  Future<List<Map<String, dynamic>>> fetchEntitiesByIds({
    required List<String> ids,
    int limit = 200,
  }) async {
    final cleanedIds = <String>[];
    final seen = <String>{};
    for (final rawId in ids) {
      final id = rawId.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      cleanedIds.add(id);
    }
    if (cleanedIds.isEmpty) return <Map<String, dynamic>>[];

    final resultsById = <String, Map<String, dynamic>>{};
    for (var i = 0; i < cleanedIds.length; i += _myEntitiesChunkSize) {
      final end = (i + _myEntitiesChunkSize < cleanedIds.length)
          ? i + _myEntitiesChunkSize
          : cleanedIds.length;
      final chunk = cleanedIds.sublist(i, end);
      final uri = Uri.parse('$entitiesBaseUrl/entities').replace(
        queryParameters: {
          'ids': chunk.join(','),
          'limit': limit.toString(),
        },
      );
      final res = await http.get(uri, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) throw Exception(res.body);
      final chunkItems = _decodeEntities(res.body);
      for (final item in chunkItems) {
        final id = (item['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        resultsById[id] = item;
      }
    }

    // Preserve caller order (usually newest-first local history).
    final ordered = <Map<String, dynamic>>[];
    for (final id in cleanedIds) {
      final item = resultsById[id];
      if (item != null) {
        ordered.add(item);
      }
    }
    return ordered;
  }

  Uri _entitiesUri({
    required double lat,
    required double lon,
    int? limit,
  }) {
    final query = <String, String>{
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radiusKm': _closestItemsRadiusKm.toString(),
    };
    if (limit != null) {
      query['limit'] = limit.toString();
    }
    return Uri.parse('$entitiesBaseUrl/entities')
        .replace(queryParameters: query);
  }

  List<Map<String, dynamic>> _decodeEntities(String body) {
    final decoded = jsonDecode(body);
    final List rawItems = decoded is List
        ? decoded
        : ((decoded is Map && decoded['items'] is List)
            ? decoded['items'] as List
            : const []);
    if (rawItems.isEmpty) return <Map<String, dynamic>>[];
    return rawItems
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (e) => withSyncMetadata(_toStringMap(e)),
        )
        .toList();
  }

  Map<String, dynamic> _toStringMap(Map raw) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }

  List<Map<String, dynamic>> _cachedItems(Map<String, dynamic> cached) {
    final rawItems = EntitiesCache.items(cached);
    if (rawItems.isEmpty) return <Map<String, dynamic>>[];
    return rawItems
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => withSyncMetadata(_toStringMap(e)))
        .toList();
  }

  int? _clientUpdatedAtMs(Map<String, dynamic> entity) {
    final raw = entity['_clientUpdatedAtMs'];
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  Map<String, dynamic> _pickLatestEntity(
    Map<String, dynamic> cached,
    Map<String, dynamic> server,
  ) {
    final local = withSyncMetadata(cached);
    final remote = withSyncMetadata(server);

    final localStamp = extractSyncStampMs(local);
    final remoteStamp = extractSyncStampMs(remote);
    if (remoteStamp > localStamp) return remote;
    if (localStamp > remoteStamp) return local;

    final localEtag =
        (local['_syncEtag'] ?? computeEntityEtag(local)).toString();
    final remoteEtag =
        (remote['_syncEtag'] ?? computeEntityEtag(remote)).toString();
    if (localEtag == remoteEtag) return remote;

    final localClientStamp = _clientUpdatedAtMs(local) ?? 0;
    final remoteClientStamp = _clientUpdatedAtMs(remote) ?? 0;
    if (localClientStamp > remoteClientStamp) return local;
    return remote;
  }

  List<Map<String, dynamic>> _mergeEntities({
    required List<Map<String, dynamic>> cachedItems,
    required List<Map<String, dynamic>> serverItems,
  }) {
    final cachedByKey = <String, Map<String, dynamic>>{};
    for (final item in cachedItems) {
      final key = entitySyncKey(item);
      if (key.isEmpty) continue;
      cachedByKey[key] = withSyncMetadata(item);
    }

    final merged = <Map<String, dynamic>>[];
    for (final serverRaw in serverItems) {
      final server = withSyncMetadata(serverRaw);
      final key = entitySyncKey(server);
      if (key.isEmpty) {
        merged.add(server);
        continue;
      }

      final cached = cachedByKey.remove(key);
      if (cached == null) {
        merged.add(server);
        continue;
      }

      merged.add(_pickLatestEntity(cached, server));
    }

    // Preserve only recently-local-mutated cache rows if server didn't include
    // them yet (eventual consistency window).
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const maxRetainMs = 15 * 60 * 1000;
    for (final leftover in cachedByKey.values) {
      final localStamp = _clientUpdatedAtMs(leftover);
      if (localStamp == null) continue;
      if (nowMs - localStamp <= maxRetainMs) {
        merged.add(withSyncMetadata(leftover));
      }
    }

    return merged;
  }

  String _collectionEtag(List<Map<String, dynamic>> items) {
    final parts = items
        .map(
            (item) => (item['_syncEtag'] ?? computeEntityEtag(item)).toString())
        .toList()
      ..sort();
    return '"${fnv1a32Hex(parts.join('|'))}"';
  }

  Future<List<Map<String, dynamic>>> _fetchAndUpdateCache({
    required Box box,
    required String cacheKey,
    required Uri uri,
    required List<Map<String, dynamic>> cachedItems,
    required Map<String, dynamic>? cached,
    required bool forceRefresh,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final etag = cached == null ? null : EntitiesCache.etag(cached);
    if (!forceRefresh && etag != null && etag.isNotEmpty) {
      headers['If-None-Match'] = etag;
    }
    final lastModified =
        cached == null ? null : EntitiesCache.lastModified(cached);
    if (!forceRefresh &&
        lastModified != null &&
        lastModified.trim().isNotEmpty) {
      headers['If-Modified-Since'] = lastModified;
    }

    if (kDebugMode) {
      debugPrint('[EntitiesApi] GET $uri (cached=${cached != null})');
    }
    final sw = Stopwatch()..start();
    final res = await http.get(uri, headers: headers);
    if (kDebugMode) {
      debugPrint(
        '[EntitiesApi] status=${res.statusCode} ${sw.elapsedMilliseconds}ms',
      );
    }

    if (res.statusCode == 304 && cached != null) {
      await EntitiesCache.touch(
        box,
        cacheKey,
        itemsJson: cachedItems,
        etag: EntitiesCache.etag(cached),
        lastModified: EntitiesCache.lastModified(cached),
        validatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      return cachedItems;
    }

    if (res.statusCode != 200) throw Exception(res.body);
    final serverItems = _decodeEntities(res.body);
    final mergedItems = _mergeEntities(
      cachedItems: cachedItems,
      serverItems: serverItems,
    );
    final responseEtag = res.headers['etag'];
    await EntitiesCache.write(
      box,
      cacheKey,
      itemsJson: mergedItems,
      etag: (responseEtag != null && responseEtag.isNotEmpty)
          ? responseEtag
          : _collectionEtag(mergedItems),
      lastModified: res.headers['last-modified'],
      validatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return mergedItems;
  }

  void _revalidateInBackground({
    required Box box,
    required String cacheKey,
    required Uri uri,
    required List<Map<String, dynamic>> cachedItems,
    required Map<String, dynamic>? cached,
  }) {
    if (_revalidateInFlight.contains(cacheKey)) return;
    _revalidateInFlight.add(cacheKey);
    Future(() async {
      try {
        await _fetchAndUpdateCache(
          box: box,
          cacheKey: cacheKey,
          uri: uri,
          cachedItems: cachedItems,
          cached: cached,
          forceRefresh: false,
        );
      } catch (_) {
        // Keep stale cache visible if background revalidate fails.
      } finally {
        _revalidateInFlight.remove(cacheKey);
      }
    });
  }

  /// CACHE WRAPPER
  Future<List<Map<String, dynamic>>> fetchEntitiesCached({
    required String regionKey,
    required double lat,
    required double lon,
    int? limit,
    bool forceRefresh = false,
    String? locale,
  }) async {
    final box = Hive.box(EntitiesCache.boxName);
    final limitKey = limit?.toString() ?? 'all';
    final localeKey = (locale ?? 'en').toLowerCase();
    final baseKey = baseUrl.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final cacheKey =
        'entities::$baseKey::$regionKey::l$limitKey::lang$localeKey';

    final cached = EntitiesCache.read(box, cacheKey);
    final cachedItems =
        cached == null ? <Map<String, dynamic>>[] : _cachedItems(cached);
    final uri = _entitiesUri(
      lat: lat,
      lon: lon,
      limit: limit,
    );

    if (!forceRefresh && cached != null) {
      _revalidateInBackground(
        box: box,
        cacheKey: cacheKey,
        uri: uri,
        cachedItems: cachedItems,
        cached: cached,
      );
      return cachedItems;
    }

    try {
      return await _fetchAndUpdateCache(
        box: box,
        cacheKey: cacheKey,
        uri: uri,
        cachedItems: cachedItems,
        cached: cached,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      if (cached != null) {
        return cachedItems;
      }
      rethrow;
    }
  }
}
