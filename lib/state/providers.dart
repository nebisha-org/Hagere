import '../config/env.dart'; 
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/entities_api.dart';
import 'category_providers.dart';



final entitiesApiProvider = Provider<EntitiesApi>((ref) {
  return EntitiesApi();
});

final userLocationProvider = StateProvider<LocationData?>((ref) => null);



final locationControllerProvider = Provider<LocationController>((ref) {
  return LocationController(ref);
});

class LocationController {
  LocationController(this.ref);

  final Ref ref;
  final Location _location = Location();

  Future<void> ensureLocationReady() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled && !Platform.isIOS) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) throw Exception('Location service is disabled');
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }

    if (permission == PermissionStatus.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Enable it in iOS Settings > Privacy > Location Services.',
      );
    }

    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      throw Exception('Location permission not granted: $permission');
    }

    final loc = await _location.getLocation();
    if (loc.latitude == null || loc.longitude == null) {
      throw Exception('Location unavailable (null lat/lon)');
    }
    if (kDebugMode) {
      debugPrint('[Location] lat=${loc.latitude} lon=${loc.longitude}');
    }

    ref.read(userLocationProvider.notifier).state = loc;
  }
}

/// Stable device-based entity id (for Stripe V1)
final currentEntityIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  const key = 'current_entity_id_v1';

  final existing = prefs.getString(key);
  if (existing != null && existing.trim().isNotEmpty) return existing;

  final id = const Uuid().v4();
  await prefs.setString(key, id);
  return id;
});

String _norm(dynamic v) => (v ?? '').toString().trim().toLowerCase();

List<String> _extractTags(dynamic tags) {
  if (tags is List) {
    return tags.map((e) => _norm(e)).where((s) => s.isNotEmpty).toList();
  }
  return const [];
}

bool _matchesByTagsOrText(Map<String, dynamic> e, List<String> catTags) {
  if (catTags.isEmpty) return true;

  final entityTags = _extractTags(e['tags']);
  if (entityTags.isNotEmpty) {
    for (final t in catTags) {
      final nt = _norm(t);
      if (nt.isNotEmpty && entityTags.contains(nt)) return true;
    }
  }

  final hay = [
    _norm(e['subtype']),
    _norm(e['type']),
    _norm(e['categoryId']),
    _norm(e['category']),
    _norm(e['name']),
    _norm(e['title']),
    _norm(e['address']),
  ].join(' ');

  for (final t in catTags) {
    final nt = _norm(t);
    if (nt.isNotEmpty && hay.contains(nt)) return true;
  }

  return false;
}

final entitiesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(userLocationProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  debugPrint('ENTITIES params lat=${loc?.latitude} lon=${loc?.longitude} radiusKm=100 limit=80');

  if (loc == null || loc.latitude == null || loc.longitude == null) {
    return <Map<String, dynamic>>[];
  }

  final api = ref.watch(entitiesApiProvider);
  final results = await api.fetchEntities(
    lat: loc.latitude!,
    lon: loc.longitude!,
    radiusKm: 100,
    limit: 80,
    serverSideGeo: true,
  );
  debugPrint('ENTITIES count=${results.length} first=${results.isEmpty ? "none" : results.first}');

  // final lat0 = loc.latitude!;
  // final lon0 = loc.longitude!;

  // bool near(Map<String, dynamic> e) {
  //   final lat = e['lat'] ?? e['latitude'];
  //   final lon = e['lon'] ?? e['lng'] ?? e['longitude'];
  //   if (lat == null || lon == null) return false;

  //   // ~111km per degree → 50km ≈ 0.45°
  //   return (lat0 - lat).abs() <= 0.45 && (lon0 - lon).abs() <= 0.45;
  // }

  // final filtered = results.where(near).toList();

 if (selectedCategory == null) return results;

  final catTags = selectedCategory.tags;
  return results.where((e) => _matchesByTagsOrText(e, catTags)).toList();

});
