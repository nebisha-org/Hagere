import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class EntitiesApi {
  EntitiesApi(this.baseUrl);

  /// Base URL like:
  /// https://6qipli13v7.execute-api.us-east-2.amazonaws.com/api
  /// (NO trailing slash)
  final String baseUrl;

  /// Fetch entities near a given point.
  ///
  /// - If [serverSideGeo] is true, query params lat/lon/radiusKm will be sent
  ///   and the server is expected to filter.
  /// - If [serverSideGeo] is false (default), we fetch up to [limit] items
  ///   and filter/sort locally by distance (MVP friendly).
  Future<List<Map<String, dynamic>>> fetchEntities({
    required double lat,
    required double lon,
    double radiusKm = 20,
    String? type,
    int limit = 200,
    bool serverSideGeo = false,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      if (serverSideGeo) ...{
        'lat': lat.toString(),
        'lon': lon.toString(),
        'radiusKm': radiusKm.toString(),
      },
    };

    final uri = Uri.parse('$baseUrl/entities').replace(queryParameters: qp);

    // ignore: avoid_print
    print('GET $uri');
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    // ignore: avoid_print
    print('STATUS ${res.statusCode} BODY ${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('API ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    List<Map<String, dynamic>> items;
    if (decoded is Map && decoded['items'] is List) {
      items = List<Map<String, dynamic>>.from(decoded['items'] as List);
    } else if (decoded is List) {
      items = List<Map<String, dynamic>>.from(decoded);
    } else {
      throw Exception('Unexpected response shape: ${res.body}');
    }

    // MVP: if server isn't filtering by geo yet, do it here.
    if (!serverSideGeo) {
      final filtered = <Map<String, dynamic>>[];

      for (final e in items) {
        final loc = e['location'];
        if (loc is! Map) continue;

        final alat = loc['lat'];
        final alon = loc['lon'];
        if (alat is! num || alon is! num) continue;

        final d = _haversineKm(lat, lon, alat.toDouble(), alon.toDouble());
        if (d <= radiusKm) {
          // attach distance for UI sorting/display
          e['distanceKm'] = d;
          filtered.add(e);
        }
      }

      filtered.sort((a, b) {
        final da = (a['distanceKm'] as num?)?.toDouble() ?? 1e9;
        final db = (b['distanceKm'] as num?)?.toDouble() ?? 1e9;
        return da.compareTo(db);
      });

      return filtered;
    }

    return items;
  }

  // Great-circle distance in kilometers
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);
}
