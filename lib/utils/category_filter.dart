import '../models/category.dart';

String _norm(dynamic v) => (v ?? '').toString().trim().toLowerCase();

String _flatten(dynamic v) {
  if (v is List) {
    return v.map(_norm).where((s) => s.isNotEmpty).join(' ');
  }
  return _norm(v);
}

List<String> _extractTags(dynamic tags) {
  if (tags is List) {
    return tags.map(_norm).where((s) => s.isNotEmpty).toList();
  }
  return const [];
}

bool _hasCategoryId(Map<String, dynamic> e, AppCategory category) {
  final catId = _norm(category.id);
  if (catId.isEmpty) return false;

  final direct =
      _norm(e['categoryId'] ?? e['category']);
  if (direct == catId) return true;

  final ids = e['category_ids'] ?? e['categoryIds'] ?? e['categories'];
  if (ids is List) {
    for (final id in ids) {
      if (_norm(id) == catId) return true;
    }
  }

  return false;
}

bool _matchesByTagsOrText(Map<String, dynamic> e, List<String> catTags) {
  if (catTags.isEmpty) return true;

  final entityTags = _extractTags(e['tags']);
  if (entityTags.isNotEmpty) {
    for (final t in catTags) {
      final nt = _norm(t);
      if (nt.isNotEmpty && entityTags.contains(nt)) return true;
    }
  }

  final hay = [
    _norm(e['subtype']),
    _norm(e['type']),
    _norm(e['categoryId']),
    _norm(e['category']),
    _flatten(e['category_ids']),
    _flatten(e['matched_terms']),
    _norm(e['name']),
    _norm(e['title']),
    _norm(e['address']),
    _norm(e['formatted_address']),
  ].join(' ');

  for (final t in catTags) {
    final nt = _norm(t);
    if (nt.isNotEmpty && hay.contains(nt)) return true;
  }

  return false;
}

bool matchesCategoryForEntity(
  Map<String, dynamic> e,
  AppCategory? category,
) {
  if (category == null) return true;

  if (_hasCategoryId(e, category)) return true;

  return _matchesByTagsOrText(e, category.tags);
}
