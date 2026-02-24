import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';

const String kFavoritesCategoryId = 'favorites';
const AppCategory kFavoritesCategory = AppCategory(
  id: kFavoritesCategoryId,
  title: 'Favorites',
  emoji: '❤️',
  tags: [],
);

String favoriteEntityId(Map<String, dynamic> entity) {
  final id = (entity['id'] ?? entity['place_id'] ?? entity['PK'] ?? '')
      .toString()
      .trim();
  if (id.isNotEmpty) return id;

  final name = (entity['name'] ?? '').toString().trim();
  final lat = (entity['lat'] ?? entity['latitude'] ?? '').toString().trim();
  final lon = (entity['lon'] ?? entity['longitude'] ?? '').toString().trim();
  return '$name|$lat|$lon';
}

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super(<String>{}) {
    unawaited(_load());
  }

  static const String _prefsKey = 'favorite_places';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_prefsKey) ?? const <String>[];
    state = values.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  bool isFavorite(Map<String, dynamic> entity) {
    return state.contains(favoriteEntityId(entity));
  }

  Future<void> toggleForEntity(Map<String, dynamic> entity) async {
    final id = favoriteEntityId(entity);
    if (id.isEmpty) return;

    final next = <String>{...state};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, next.toList()..sort());
  }
}

final favoriteIdsProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});
