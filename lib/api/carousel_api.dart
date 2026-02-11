import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/carousel_item.dart';

class CarouselApi {
  final String baseUrl = carouselBaseUrl;

  Future<List<CarouselItem>> fetchCarousel({
    double? lat,
    double? lon,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
    };
    if (lat != null && lon != null) {
      params['lat'] = lat.toString();
      params['lon'] = lon.toString();
    }

    final uri =
        Uri.parse('$baseUrl/carousel').replace(queryParameters: params);
    final res = await http.get(uri, headers: {'Accept': 'application/json'});
    if (res.statusCode != 200) throw Exception(res.body);

    final decoded = jsonDecode(res.body);
    final List items = decoded is Map && decoded['items'] is List
        ? decoded['items']
        : (decoded is List ? decoded : const []);

    return items
        .whereType<Map>()
        .map<CarouselItem>(
            (e) => CarouselItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
