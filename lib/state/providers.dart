import '../config/env.dart'; 
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/entities_api.dart';
import 'category_providers.dart';
import '../utils/category_filter.dart';
import '../models/category.dart';



final entitiesApiProvider = Provider<EntitiesApi>((ref) {
  return EntitiesApi();
});

final userLocationProvider = StateProvider<LocationData?>((ref) => null);

final entitiesRefreshProvider = StateProvider<int>((ref) => 0);


final locationControllerProvider = Provider<LocationController>((ref) {
  return LocationController(ref);
});

class LocationController {
  LocationController(this.ref);

  final Ref ref;
  final Location _location = Location();

  Future<LocationData?> _getLocationOnce({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      return await _location.getLocation().timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  Future<LocationData?> _getLocationWithRetry({
    int attempts = 4,
    Duration delay = const Duration(seconds: 1),
  }) async {
    LocationData? loc;
    for (int i = 0; i < attempts; i++) {
      loc = await _getLocationOnce();
      if (loc?.latitude != null && loc?.longitude != null) {
        return loc;
      }
      await Future.delayed(delay);
    }
    try {
      return await _waitForLocation();
    } catch (_) {
      return loc;
    }
  }

  Future<LocationData> _waitForLocation({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final completer = Completer<LocationData>();
    late final StreamSubscription<LocationData> sub;
    sub = _location.onLocationChanged.listen((loc) {
      if (loc.latitude != null && loc.longitude != null) {
        if (!completer.isCompleted) {
          completer.complete(loc);
        }
        sub.cancel();
      }
    });

    try {
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  LocationData _locationFromLatLon(double lat, double lon) {
    return LocationData.fromMap({
      'latitude': lat,
      'longitude': lon,
    });
  }

  Future<void> _saveLastLocation(LocationData loc) async {
    final lat = loc.latitude;
    final lon = loc.longitude;
    if (lat == null || lon == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_location_lat', lat);
    await prefs.setDouble('last_location_lon', lon);
  }

  Future<LocationData?> _loadFallbackLocation() async {
    if (kDebugMode) {
      const debugLat = 25.2048;
      const debugLon = 55.2708;
      return _locationFromLatLon(debugLat, debugLon);
    }

    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('last_location_lat');
    final lon = prefs.getDouble('last_location_lon');
    if (lat != null && lon != null) {
      return _locationFromLatLon(lat, lon);
    }

    return null;
  }

  Future<void> ensureLocationReady() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      try {
        serviceEnabled = await _location
            .requestService()
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        // iOS may not allow programmatic service prompts.
      }
      if (!serviceEnabled && !Platform.isIOS) {
        throw Exception('Location service is disabled');
      }
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      try {
        permission = await _location
            .requestPermission()
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        permission = PermissionStatus.denied;
      }
    }

    if (permission == PermissionStatus.deniedForever) {
      if (kDebugMode) {
        final fallback = await _loadFallbackLocation();
        if (fallback != null) {
          ref.read(userLocationProvider.notifier).state = fallback;
          return;
        }
      }
      throw Exception(
        'Location permission permanently denied. Enable it in iOS Settings > Privacy > Location Services.',
      );
    }

    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      if (kDebugMode) {
        final fallback = await _loadFallbackLocation();
        if (fallback != null) {
          ref.read(userLocationProvider.notifier).state = fallback;
          return;
        }
      }
      throw Exception('Location permission not granted: $permission');
    }

    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 0,
    );

    final loc = await _getLocationWithRetry();
    if (loc?.latitude == null || loc?.longitude == null) {
      final fallback = await _loadFallbackLocation();
      if (fallback != null) {
        if (kDebugMode) {
          debugPrint(
            '[Location] fallback lat=${fallback.latitude} lon=${fallback.longitude}',
          );
        }
        ref.read(userLocationProvider.notifier).state = fallback;
        return;
      }
      throw Exception('Location unavailable (null lat/lon)');
    }
    await _saveLastLocation(loc!);
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

final availableCategoriesProvider =
    Provider<AsyncValue<List<AppCategory>>>((ref) {
  final cats = ref.watch(categoriesProvider);
  final rawAsync = ref.watch(entitiesRawProvider);

  return rawAsync.whenData((items) {
    if (items.isEmpty) return <AppCategory>[];

    final filtered = <AppCategory>[];
    for (final cat in cats) {
      final hasAny = items.any((e) => matchesCategoryForEntity(e, cat));
      if (hasAny) filtered.add(cat);
    }
    return filtered;
  });
});

String _regionKey(double lat, double lon) {
  return '${lat.toStringAsFixed(2)}:${lon.toStringAsFixed(2)}';
}

final entitiesRawProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(userLocationProvider);
  final refresh = ref.watch(entitiesRefreshProvider);

  if (loc == null || loc.latitude == null || loc.longitude == null) {
    return <Map<String, dynamic>>[];
  }

  final api = ref.watch(entitiesApiProvider);
  final results = await api.fetchEntitiesCached(
    regionKey: _regionKey(loc.latitude!, loc.longitude!),
    lat: loc.latitude!,
    lon: loc.longitude!,
    radiusKm: 50,
    limit: null,
    ttl: const Duration(days: 3),
    forceRefresh: refresh > 0,
  );

  if (refresh > 0) {
    Future.microtask(
      () => ref.read(entitiesRefreshProvider.notifier).state = 0,
    );
  }

  return results;
});

final entitiesProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final rawAsync = ref.watch(entitiesRawProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);

  return rawAsync.whenData((items) {
    if (selectedCategory == null) return items;
    return items
        .where((e) => matchesCategoryForEntity(e, selectedCategory))
        .toList();
  });
});
