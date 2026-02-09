import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'translation_provider.dart';
import 'category_providers.dart';

final categoryOverridesProvider =
    FutureProvider<Map<String, Map<String, String>>>((ref) async {
  final api = ref.watch(overridesApiProvider);
  final lang = ref.watch(translationControllerProvider).language.code;
  final cats = ref.watch(categoriesProvider);

  final Map<String, Map<String, String>> out = {};
  for (final cat in cats) {
    try {
      final overrides = await api.fetchLatest(
        entityType: 'category',
        entityId: cat.id,
        locale: lang,
      );
      if (overrides.isNotEmpty) {
        out[cat.id] = overrides;
      }
    } catch (_) {
      // ignore per-category failures
    }
  }
  return out;
});
