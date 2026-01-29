import 'dart:math' as math;

/// Safely convert dynamic values to double.
/// Accepts: num, String ("37.1"), null -> returns double?
double? toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

double? extractCoord(Map<String, dynamic> e, String key) {
  final loc = e['location'];

  // Normal API shape: location.lat / location.lon
  if (loc is Map) {
    if (loc[key] != null) {
      return toDouble(loc[key]);
    }
    if (key == 'lon' && loc['lng'] != null) {
      return toDouble(loc['lng']);
    }
  }

  // Fallback if API ever returns flat lat/lon
  if (e[key] != null) {
    return toDouble(e[key]);
  }
  if (key == 'lon' && e['lng'] != null) {
    return toDouble(e['lng']);
  }

  return null;
}

/// Haversine distance between two lat/lon points in meters.
double distanceMeters({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const earthRadiusMeters = 6371000.0;

  double degToRad(double deg) => deg * (math.pi / 180.0);

  final dLat = degToRad(lat2 - lat1);
  final dLon = degToRad(lon2 - lon1);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(degToRad(lat1)) *
          math.cos(degToRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}
