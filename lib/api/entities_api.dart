import '../config/env.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../cache/entities_cache.dart';

class EntitiesApi {
  final String baseUrl = apiBaseUrl;

  /// HOME SPONSORED
  Future<List<Map<String, dynamic>>> getHomeSponsored() async {
    final uri = Uri.parse('$apiBaseUrl/entities/home-sponsored');
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
    double radiusKm = 100,
    int limit = 50,
    bool serverSideGeo = false,
  }) async {
    final query = <String, String>{
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radiusKm': radiusKm.toString(),
      'limit': limit.toString(),
    };
    if (serverSideGeo) {
      query['serverSideGeo'] = 'true';
    }

    final uri =
        Uri.parse('$apiBaseUrl/entities').replace(queryParameters: query);

    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) throw Exception(res.body);

    final decoded = jsonDecode(res.body);

    debugPrint('>+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
    debugPrint('$decoded');
    debugPrint('<+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');

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

  /// CACHE WRAPPER
  Future<List<Map<String, dynamic>>> fetchEntitiesCached({
    required String regionKey,
    required double lat,
    required double lon,
    double radiusKm = 100,
    int limit = 50,
    Duration ttl = const Duration(hours: 12),
    bool forceRefresh = false,
  }) async {
    final box = Hive.box(EntitiesCache.boxName);
    final cacheKey = 'entities::$regionKey::r$radiusKm::l$limit';

    final cached = EntitiesCache.read(box, cacheKey);
    if (!forceRefresh && cached != null && EntitiesCache.isFresh(cached, ttl)) {
      final items = EntitiesCache.items(cached);
      return items
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => e.cast<String, dynamic>())
          .toList();
    }

    final items = await fetchEntities(
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
      limit: limit,
    );

    await EntitiesCache.write(
      box,
      cacheKey,
      itemsJson: items,
      etag: null,
    );

    return items;
  }
}
