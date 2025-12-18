import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';

import '../api/entities_api.dart';

/// -------------------------------
/// CONFIG
/// -------------------------------
const apiBaseUrl = 'https://6qipli13v7.execute-api.us-east-2.amazonaws.com/api';

/// -------------------------------
/// API
/// -------------------------------
final entitiesApiProvider = Provider<EntitiesApi>((ref) {
  return EntitiesApi(apiBaseUrl);
});

/// -------------------------------
/// LOCATION STATE
/// -------------------------------
final userLocationProvider = StateProvider<LocationData?>((ref) => null);

final locationControllerProvider = Provider<LocationController>((ref) {
  return LocationController(ref);
});

class LocationController {
  LocationController(this.ref);

  final Ref ref;
  final Location _location = Location();

  Future<void> ensureLocationReady() async {
    debugPrint('LC: enter ensureLocationReady');

    debugPrint('LC: checking serviceEnabled');
    bool serviceEnabled = await _location.serviceEnabled();
    debugPrint('LC: serviceEnabled=$serviceEnabled');

    if (!serviceEnabled) {
      debugPrint('LC: requesting service...');
      serviceEnabled = await _location.requestService();
      debugPrint('LC: requestService result=$serviceEnabled');
      if (!serviceEnabled) throw Exception('Location service is disabled');
    }

    debugPrint('LC: checking permission...');
    PermissionStatus permission = await _location.hasPermission();
    debugPrint('LC: hasPermission=$permission');

    if (permission == PermissionStatus.denied) {
      debugPrint('LC: requesting permission...');
      permission = await _location.requestPermission();
      debugPrint('LC: requestPermission=$permission');
    }

    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      throw Exception('Location permission not granted: $permission');
    }

    debugPrint('LC: calling getLocation...');
    final loc = await _location.getLocation();
    debugPrint('LC: got location lat=${loc.latitude}, lon=${loc.longitude}');

    if (loc.latitude == null || loc.longitude == null) {
      throw Exception('Location unavailable (null lat/lon)');
    }

    ref.read(userLocationProvider.notifier).state = loc;
    debugPrint('LC: state updated -> userLocationProvider');
  }
}

/// -------------------------------
/// ENTITIES
/// -------------------------------
final entitiesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(userLocationProvider);

  debugPrint('ENTITIES: provider fired. loc=$loc');

  if (loc == null || loc.latitude == null || loc.longitude == null) {
    debugPrint('ENTITIES: no location yet -> return []');
    return <Map<String, dynamic>>[];
  }

  final api = ref.watch(entitiesApiProvider);

  debugPrint(
    'ENTITIES: calling API lat=${loc.latitude}, lon=${loc.longitude}',
  );

  final results = await api.fetchEntities(
    lat: loc.latitude!,
    lon: loc.longitude!,
    radiusKm: 5000,
    limit: 200,
    serverSideGeo: false,
  );

  debugPrint('ENTITIES: got ${results.length} items');
  return results;
});
