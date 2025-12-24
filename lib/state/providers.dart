import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';

import '../api/entities_api.dart';
import 'category_providers.dart';

// ✅ NEW (for device-based id)
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// -------------------------------
/// CONFIG
/// -------------------------------
const apiBaseUrl = 'https://6qipli13v7.execute-api.us-east-2.amazonaws.com/api';

/// -------------------------------
/// API
/// -------------------------------
final entitiesApiProvider = Provider<EntitiesApi>((ref) {
  //return EntitiesApi(apiBaseUrl);
  return EntitiesApi(baseUrl: apiBaseUrl);
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
/// DEVICE-BASED ENTITY ID (V1)
/// -------------------------------
/// Stable ID stored on device. This is what you pass as `entityId` to Stripe.
/// Later you can replace this with a real Business/Owner ID from your backend.
final currentEntityIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  const key = 'current_entity_id_v1';
  final existing = prefs.getString(key);
  if (existing != null && existing.trim().isNotEmpty) {
    return existing;
  }

  final id = const Uuid().v4();
  await prefs.setString(key, id);
  return id;
});

/// -------------------------------
/// FILTER HELPERS
/// -------------------------------
String _norm(dynamic v) => (v ?? '').toString().trim().toLowerCase();

List<String> _extractTags(dynamic tags) {
  if (tags is List) {
    return tags.map((e) => _norm(e)).where((s) => s.isNotEmpty).toList();
  }
  return const [];
}

bool _matchesByTagsOrText(Map<String, dynamic> e, List<String> catTags) {
  if (catTags.isEmpty) return true;

  // 1) Strong match: entity.tags intersection
  final entityTags = _extractTags(e['tags']);
  if (entityTags.isNotEmpty) {
    for (final t in catTags) {
      final nt = _norm(t);
      if (nt.isEmpty) continue;
      if (entityTags.contains(nt)) return true;
    }
  }

  // 2) Fallback: search in common fields
  final hay = [
    _norm(e['subtype']),
    _norm(e['type']),
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

/// -------------------------------
/// ENTITIES
/// -------------------------------
final entitiesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final loc = ref.watch(userLocationProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);

  debugPrint(
    'ENTITIES: provider fired. loc=$loc, cat=${selectedCategory?.id}',
  );

  if (loc == null || loc.latitude == null || loc.longitude == null) {
    debugPrint('ENTITIES: no location yet -> return []');
    return <Map<String, dynamic>>[];
  }

  final api = ref.watch(entitiesApiProvider);

  final results = await api.fetchEntities(
    lat: loc.latitude!,
    lon: loc.longitude!,
    radiusKm: 5000,
    limit: 200,
    serverSideGeo: false,
  );

  debugPrint('ENTITIES: got ${results.length} items (raw)');

  // If no category selected, return all
  if (selectedCategory == null) return results;

  // Filter by category tags
  final catTags = selectedCategory.tags;
  final filtered =
      results.where((e) => _matchesByTagsOrText(e, catTags)).toList();

  debugPrint(
    'ENTITIES: filtered ${filtered.length}/${results.length} for cat=${selectedCategory.id}',
  );

  return filtered;
});



// import 'package:flutter/foundation.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:location/location.dart';

// import '../api/entities_api.dart';
// import 'category_providers.dart';

// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:uuid/uuid.dart';

// /// -------------------------------
// /// CONFIG
// /// -------------------------------
// const apiBaseUrl = 'https://6qipli13v7.execute-api.us-east-2.amazonaws.com/api';

// /// -------------------------------
// /// API
// /// -------------------------------
// final entitiesApiProvider = Provider<EntitiesApi>((ref) {
//   return EntitiesApi(apiBaseUrl);
// });

// /// -------------------------------
// /// LOCATION STATE
// /// -------------------------------
// final userLocationProvider = StateProvider<LocationData?>((ref) => null);

// final locationControllerProvider = Provider<LocationController>((ref) {
//   return LocationController(ref);
// });

// class LocationController {
//   LocationController(this.ref);

//   final Ref ref;
//   final Location _location = Location();

//   Future<void> ensureLocationReady() async {
//     debugPrint('LC: enter ensureLocationReady');

//     bool serviceEnabled = await _location.serviceEnabled();
//     debugPrint('LC: serviceEnabled=$serviceEnabled');

//     if (!serviceEnabled) {
//       debugPrint('LC: requesting service...');
//       serviceEnabled = await _location.requestService();
//       debugPrint('LC: requestService result=$serviceEnabled');
//       if (!serviceEnabled) throw Exception('Location service is disabled');
//     }

//     debugPrint('LC: checking permission...');
//     PermissionStatus permission = await _location.hasPermission();
//     debugPrint('LC: hasPermission=$permission');

//     if (permission == PermissionStatus.denied) {
//       debugPrint('LC: requesting permission...');
//       permission = await _location.requestPermission();
//       debugPrint('LC: requestPermission=$permission');
//     }

//     if (permission != PermissionStatus.granted &&
//         permission != PermissionStatus.grantedLimited) {
//       throw Exception('Location permission not granted: $permission');
//     }

//     debugPrint('LC: calling getLocation...');
//     final loc = await _location.getLocation();
//     debugPrint('LC: got location lat=${loc.latitude}, lon=${loc.longitude}');

//     if (loc.latitude == null || loc.longitude == null) {
//       throw Exception('Location unavailable (null lat/lon)');
//     }

//     ref.read(userLocationProvider.notifier).state = loc;
//     debugPrint('LC: state updated -> userLocationProvider');
//   }
// }


// // end of LOCATION STATE


// /// -------------------------------
// /// DEVICE-BASED ENTITY ID (V1)
// /// -------------------------------
// /// Stable ID stored on device. This is what you pass as `entityId` to Stripe.
// /// Later you can replace this with a real Business/Owner ID from your backend.
// final currentEntityIdProvider = FutureProvider<String>((ref) async {
//   final prefs = await SharedPreferences.getInstance();

//   const key = 'current_entity_id_v1';
//   final existing = prefs.getString(key);
//   if (existing != null && existing.trim().isNotEmpty) {
//     return existing;
//   }

//   final id = const Uuid().v4();
//   await prefs.setString(key, id);
//   return id;
// });

// /// -------------------------------
// /// FILTER HELPERS
// /// -------------------------------
// String _norm(dynamic v) => (v ?? '').toString().trim().toLowerCase();

// List<String> _extractTags(dynamic tags) {
//   if (tags is List) {
//     return tags.map((e) => _norm(e)).where((s) => s.isNotEmpty).toList();
//   }
//   return const [];
// }

// bool _matchesByTagsOrText(Map<String, dynamic> e, List<String> catTags) {
//   if (catTags.isEmpty) return true;

//   // 1) Strong match: entity.tags intersection
//   final entityTags = _extractTags(e['tags']);
//   if (entityTags.isNotEmpty) {
//     for (final t in catTags) {
//       final nt = _norm(t);
//       if (nt.isEmpty) continue;
//       if (entityTags.contains(nt)) return true;
//     }
//   }

//   // 2) Fallback: search in common fields
//   final hay = [
//     _norm(e['subtype']),
//     _norm(e['type']),
//     _norm(e['name']),
//     _norm(e['title']),
//     _norm(e['address']),
//   ].join(' ');

//   for (final t in catTags) {
//     final nt = _norm(t);
//     if (nt.isNotEmpty && hay.contains(nt)) return true;
//   }

//   return false;
// }

// /// -------------------------------
// /// ENTITIES
// /// -------------------------------
// final entitiesProvider =
//     FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
//   final loc = ref.watch(userLocationProvider);
//   final selectedCategory = ref.watch(selectedCategoryProvider);

//   debugPrint(
//     'ENTITIES: provider fired. loc=$loc, cat=${selectedCategory?.id}',
//   );

//   if (loc == null || loc.latitude == null || loc.longitude == null) {
//     debugPrint('ENTITIES: no location yet -> return []');
//     return <Map<String, dynamic>>[];
//   }

//   final api = ref.watch(entitiesApiProvider);

//   final results = await api.fetchEntities(
//     lat: loc.latitude!,
//     lon: loc.longitude!,
//     radiusKm: 5000,
//     limit: 200,
//     serverSideGeo: false,
//   );

//   debugPrint('ENTITIES: got ${results.length} items (raw)');

//   // If no category selected, return all
//   if (selectedCategory == null) return results;

//   // Filter by category tags
//   final catTags = selectedCategory.tags;
//   final filtered =
//       results.where((e) => _matchesByTagsOrText(e, catTags)).toList();

//   debugPrint(
//     'ENTITIES: filtered ${filtered.length}/${results.length} for cat=${selectedCategory.id}',
//   );

//   return filtered;
// });
