import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/entities_api.dart';
import 'providers.dart';

final homeSponsoredProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = EntitiesApi();
    return api.getHomeSponsored();
});
