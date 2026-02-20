import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../api/entities_api.dart';
import '../api/carousel_api.dart';
import 'category_providers.dart';
import '../models/category.dart';
import '../utils/category_filter.dart';
import '../utils/geo.dart';
import '../utils/posted_date.dart';
import '../models/carousel_item.dart';
import 'translation_provider.dart';
import 'override_providers.dart';
import 'qc_city_provider.dart';
import 'qc_mode.dart';

final entitiesApiProvider = Provider<EntitiesApi>((ref) {
  return EntitiesApi();
});

final carouselApiProvider = Provider<CarouselApi>((ref) {
  return CarouselApi();
});

final userLocationProvider = StateProvider<LocationData?>((ref) => null);

enum LocationBlockReason {
  serviceDisabled,
  permissionDenied,
  unavailable,
}

final locationBlockReasonProvider =
    StateProvider<LocationBlockReason?>((ref) => null);

LocationData _locationDataFromLatLon(double lat, double lon) {
  return LocationData.fromMap({
    'latitude': lat,
    'longitude': lon,
  });
}

final effectiveLocationProvider = Provider<LocationData?>((ref) {
  final qcCityKey = ref.watch(qcCityOverrideProvider);
  if (kQcMode) {
    final option = qcCityOptionForKey(qcCityKey);
    if (option != null) {
      return _locationDataFromLatLon(option.lat, option.lon);
    }
  }
  return ref.watch(userLocationProvider);
});

final entitiesRefreshProvider = StateProvider<int>((ref) => 0);
final entitiesLimitProvider = StateProvider<int>((ref) => 1000);
final entitiesSyncIntervalProvider =
    Provider<Duration>((ref) => const Duration(seconds: 45));

class EntitiesSyncDriver with WidgetsBindingObserver {
  EntitiesSyncDriver({
    required this.ref,
    required Duration interval,
  }) : _interval = interval;

  final Ref ref;
  final Duration _interval;
  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_started) {
        _triggerRevalidate();
      }
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _triggerRevalidate());
  }

  void _triggerRevalidate() {
    ref.invalidate(entitiesRawProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerRevalidate();
      _startTimer();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
    }
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

final entitiesSyncDriverProvider = Provider<EntitiesSyncDriver>((ref) {
  final interval = ref.watch(entitiesSyncIntervalProvider);
  final driver = EntitiesSyncDriver(ref: ref, interval: interval);
  driver.start();
  ref.onDispose(driver.dispose);
  return driver;
});

final carouselItemsProvider =
    FutureProvider.autoDispose<List<CarouselItem>>((ref) async {
  ref.watch(entitiesRefreshProvider);
  final api = ref.watch(carouselApiProvider);
  final loc = ref.watch(effectiveLocationProvider);
  final lat = loc?.latitude;
  final lon = loc?.longitude;

  return api.fetchCarousel(lat: lat, lon: lon);
});

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

  Future<void> _saveLastLocation(LocationData loc) async {
    final lat = loc.latitude;
    final lon = loc.longitude;
    if (lat == null || lon == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_location_lat', lat);
    await prefs.setDouble('last_location_lon', lon);
  }

  Future<void> ensureLocationReady() async {
    ref.read(locationBlockReasonProvider.notifier).state = null;

    bool serviceEnabled = false;
    try {
      serviceEnabled = await _location.serviceEnabled();
    } catch (_) {
      serviceEnabled = false;
    }
    if (!serviceEnabled) {
      try {
        serviceEnabled = await _location
            .requestService()
            .timeout(const Duration(seconds: 6));
      } catch (_) {
        // iOS may not allow programmatic service prompts.
      }
      if (!serviceEnabled) {
        ref.read(locationBlockReasonProvider.notifier).state =
            LocationBlockReason.serviceDisabled;
        ref.read(userLocationProvider.notifier).state = null;
        throw Exception('Location service is disabled');
      }
    }

    PermissionStatus permission = PermissionStatus.denied;
    try {
      permission = await _location.hasPermission();
    } catch (_) {
      permission = PermissionStatus.denied;
    }
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
      ref.read(locationBlockReasonProvider.notifier).state =
          LocationBlockReason.permissionDenied;
      ref.read(userLocationProvider.notifier).state = null;
      throw Exception(
        'Location permission permanently denied. Enable it in iOS Settings > Privacy > Location Services.',
      );
    }

    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      ref.read(locationBlockReasonProvider.notifier).state =
          LocationBlockReason.permissionDenied;
      ref.read(userLocationProvider.notifier).state = null;
      throw Exception('Location permission not granted: $permission');
    }

    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 0,
    );

    final loc = await _getLocationWithRetry();
    if (loc?.latitude == null || loc?.longitude == null) {
      ref.read(locationBlockReasonProvider.notifier).state =
          LocationBlockReason.unavailable;
      ref.read(userLocationProvider.notifier).state = null;
      throw Exception('Location unavailable (null lat/lon)');
    }
    await _saveLastLocation(loc!);
    if (kDebugMode) {
      debugPrint('[Location] lat=${loc.latitude} lon=${loc.longitude}');
    }

    ref.read(locationBlockReasonProvider.notifier).state = null;
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
  final cats = ref.watch(resolvedCategoriesProvider);
  return AsyncValue.data(cats);
});

String _regionKey(double lat, double lon) {
  return '${lat.toStringAsFixed(2)}:${lon.toStringAsFixed(2)}';
}

final entitiesRawProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(effectiveLocationProvider);
  final refresh = ref.watch(entitiesRefreshProvider);
  final lang = ref.watch(translationControllerProvider).language.code;
  final limit = ref.watch(entitiesLimitProvider);

  if (loc == null || loc.latitude == null || loc.longitude == null) {
    return <Map<String, dynamic>>[];
  }

  final api = ref.watch(entitiesApiProvider);
  final results = await api.fetchEntitiesCached(
    regionKey: _regionKey(loc.latitude!, loc.longitude!),
    lat: loc.latitude!,
    lon: loc.longitude!,
    limit: limit,
    forceRefresh: refresh > 0,
    locale: lang,
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
  final loc = ref.watch(effectiveLocationProvider);
  final locLat = loc?.latitude;
  final locLon = loc?.longitude;
  final selectedCategoryId = selectedCategory?.id;

  return rawAsync.whenData((items) {
    final filtered = selectedCategory == null
        ? items
        : items
            .where((e) => matchesCategoryForEntity(e, selectedCategory))
            .toList();

    if (isPostedDateCategoryId(selectedCategoryId)) {
      final sorted = List<Map<String, dynamic>>.from(filtered);
      sorted.sort(compareEntitiesByPostedDateDesc);
      return sorted;
    }

    if (locLat == null || locLon == null) {
      return filtered;
    }

    final withDistance = filtered.map((e) {
      final lat = extractCoord(e, 'lat');
      final lon = extractCoord(e, 'lon');
      final dist = (lat != null && lon != null)
          ? distanceMeters(
              lat1: locLat,
              lon1: locLon,
              lat2: lat,
              lon2: lon,
            )
          : double.infinity;
      return MapEntry(e, dist);
    }).toList();

    withDistance.sort((a, b) => a.value.compareTo(b.value));
    return withDistance.map((e) => e.key).toList();
  });
});
