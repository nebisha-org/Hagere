import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import 'providers.dart'; // where userLocationProvider lives

final locationNameProvider = FutureProvider<String>((ref) async {
  final loc = ref.watch(userLocationProvider);
  final lat = loc?.latitude;
  final lon = loc?.longitude;

  if (lat == null || lon == null) return 'Near you';

  final placemarks = await placemarkFromCoordinates(lat, lon);
  if (placemarks.isEmpty) return 'Near you';

  final p = placemarks.first;

  final city = (p.locality ?? p.subAdministrativeArea ?? '').trim();
  final state = (p.administrativeArea ?? '').trim();

  final label = [
    if (city.isNotEmpty) city,
    if (state.isNotEmpty) state,
  ].join(', ');

  return label.isEmpty ? 'Near you' : label;
});
