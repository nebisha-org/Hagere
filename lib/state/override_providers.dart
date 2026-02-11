import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/overrides_api.dart';
import '../models/category.dart';
import 'category_providers.dart';
import 'translation_provider.dart';

final overridesApiProvider = Provider<OverridesApi>((ref) {
  return OverridesApi();
});

final appTextOverridesLocalProvider =
    StateProvider<Map<String, Map<String, String>>>((ref) => {});

final appTextOverridesProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final api = ref.watch(overridesApiProvider);
  final lang = ref.watch(translationControllerProvider).language.code;
  try {
    return await api.fetchLatest(
      entityType: 'app',
      entityId: 'title',
      locale: lang,
    );
  } catch (_) {
    return <String, String>{};
  }
});

final resolvedAppTitleProvider = Provider<String>((ref) {
  final controller = ref.watch(translationControllerProvider);
  final lang = controller.language.code;
  final remote = ref.watch(appTextOverridesProvider).maybeWhen(
        data: (v) => v,
        orElse: () => const <String, String>{},
      );
  final localAll = ref.watch(appTextOverridesLocalProvider);
  final local = localAll[lang] ?? const <String, String>{};
  final merged = <String, String>{...remote, ...local};
  final overrideTitle = merged['title']?.trim();
  if (overrideTitle != null && overrideTitle.isNotEmpty) {
    return overrideTitle;
  }
  return controller.tr('All Habesha');
});

final categoryOverridesLocalProvider =
    StateProvider<Map<String, Map<String, Map<String, String>>>>(
        (ref) => {});

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
  final lang = ref.watch(translationControllerProvider).language.code;
  final overridesAsync = ref.watch(categoryOverridesProvider);
  final overrides =
      overridesAsync.maybeWhen(data: (v) => v, orElse: () => {});
  final localAll = ref.watch(categoryOverridesLocalProvider);
  final local = localAll[lang] ?? const <String, Map<String, String>>{};
  final merged = <String, Map<String, String>>{};

  for (final entry in overrides.entries) {
    merged[entry.key] = Map<String, String>.from(entry.value);
  }
  for (final entry in local.entries) {
    final existing = merged[entry.key] ?? <String, String>{};
    merged[entry.key] = {
      ...existing,
      ...entry.value,
    };
  }

  return cats.map((c) {
    final o = merged[c.id] ?? const <String, String>{};
    final title = o['title']?.toString().trim();
    final emoji = o['emoji']?.toString().trim();
    return c.copyWith(
      title: (title == null || title.isEmpty) ? c.title : title,
      emoji: (emoji == null || emoji.isEmpty) ? c.emoji : emoji,
    );
  }).toList();
});
