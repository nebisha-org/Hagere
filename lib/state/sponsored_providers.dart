import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'translation_provider.dart';

final homeSponsoredProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
    final api = ref.watch(entitiesApiProvider);
    final lang = ref.watch(translationControllerProvider).language.code;
    return api.getHomeSponsored(locale: lang);
});
