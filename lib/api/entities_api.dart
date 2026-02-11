import '../config/env.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../cache/entities_cache.dart';

class EntitiesApi {
  final String baseUrl = entitiesBaseUrl;

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
      debugPrint('[EntitiesApi] status=${res.statusCode} ${sw.elapsedMilliseconds}ms');
    }
    if (res.statusCode != 200) throw Exception(res.body);

    final decoded = jsonDecode(res.body);

    final List rawItems = decoded is List
        ? decoded
        : ((decoded is Map && decoded['items'] is List)
            ? decoded['items'] as List
            : const []);

    if (rawItems.isEmpty) return <Map<String, dynamic>>[];

    // 🔑 THIS is the real fix: never cast blindly
    return rawItems
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
        .toList();
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

  Uri _entitiesUri({
    required double lat,
    required double lon,
    int? limit,
  }) {
    final query = <String, String>{
      'lat': lat.toString(),
      'lon': lon.toString(),
    };
    if (limit != null) {
      query['limit'] = limit.toString();
    }
    return Uri.parse('$entitiesBaseUrl/entities').replace(queryParameters: query);
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
        .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
        .toList();
  }

  /// CACHE WRAPPER
  Future<List<Map<String, dynamic>>> fetchEntitiesCached({
    required String regionKey,
    required double lat,
    required double lon,
    int? limit,
    Duration ttl = const Duration(hours: 12),
    bool forceRefresh = false,
    String? locale,
  }) async {
    final box = Hive.box(EntitiesCache.boxName);
    final limitKey = limit?.toString() ?? 'all';
    final localeKey = (locale ?? 'en').toLowerCase();
    final cacheKey = 'entities::$regionKey::l$limitKey::lang$localeKey';

    final cached = EntitiesCache.read(box, cacheKey);
    if (!forceRefresh && cached != null && EntitiesCache.isFresh(cached, ttl)) {
      final items = EntitiesCache.items(cached);
      return items
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
          .toList();
    }

    try {
      final uri = _entitiesUri(
        lat: lat,
        lon: lon,
        limit: limit,
      );
      final headers = <String, String>{'Accept': 'application/json'};
      final etag = cached == null ? null : EntitiesCache.etag(cached);
      if (etag != null && etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
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
          itemsJson: EntitiesCache.items(cached),
          etag: EntitiesCache.etag(cached),
        );
        final items = EntitiesCache.items(cached);
        return items
            .whereType<Map>()
            .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
            .toList();
      }

      if (res.statusCode != 200) throw Exception(res.body);
      final items = _decodeEntities(res.body);
      await EntitiesCache.write(
        box,
        cacheKey,
        itemsJson: items,
        etag: res.headers['etag'],
      );
      return items;
    } catch (e) {
      if (cached != null) {
        final items = EntitiesCache.items(cached);
        return items
            .whereType<Map>()
            .map<Map<String, dynamic>>((item) => item.cast<String, dynamic>())
            .toList();
      }
      rethrow;
    }
  }
}
