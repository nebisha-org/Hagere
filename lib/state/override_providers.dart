import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/overrides_api.dart';
import '../models/category.dart';
import 'category_providers.dart';
import 'translation_provider.dart';

final overridesApiProvider = Provider<OverridesApi>((ref) {
  return OverridesApi();
});

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

final resolvedCategoriesProvider = Provider<List<AppCategory>>((ref) {
  final cats = ref.watch(categoriesProvider);
  final overridesAsync = ref.watch(categoryOverridesProvider);
  final overrides =
      overridesAsync.maybeWhen(data: (v) => v, orElse: () => {});

  return cats.map((c) {
    final o = overrides[c.id] ?? const <String, String>{};
    final title = o['title']?.toString().trim();
    final emoji = o['emoji']?.toString().trim();
    return c.copyWith(
      title: (title == null || title.isEmpty) ? c.title : title,
      emoji: (emoji == null || emoji.isEmpty) ? c.emoji : emoji,
    );
  }).toList();
});
