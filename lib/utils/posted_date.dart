const Set<String> _postedDateCategoryIds = {
  'jobs',
  'rentals',
  'announcements',
};

const List<String> _postedDateKeys = [
  'postedAt',
  'posted_at',
  'datePosted',
  'date_posted',
  'publishedAt',
  'published_at',
  'createdAt',
  'created_at',
  'created',
  'timestamp',
];

String _norm(dynamic value) => (value ?? '').toString().trim().toLowerCase();

Map<String, dynamic>? _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

dynamic _firstNonEmpty(Map<String, dynamic>? map, List<String> keys) {
  if (map == null) return null;
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return value;
  }
  return null;
}

DateTime? _fromEpoch(num raw) {
  final n = raw.toInt();
  final abs = n.abs();
  final milliseconds = abs >= 1000000000000 ? n : n * 1000;
  try {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  } catch (_) {
    return null;
  }
}

DateTime? _parseDateValue(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.isUtc ? value : value.toUtc();
  if (value is num) return _fromEpoch(value);

  final text = value.toString().trim();
  if (text.isEmpty) return null;

  final asInt = int.tryParse(text);
  if (asInt != null) return _fromEpoch(asInt);

  final parsed = DateTime.tryParse(text);
  if (parsed != null) {
    return parsed.isUtc ? parsed : parsed.toUtc();
  }
  return null;
}

bool isPostedDateCategoryId(String? categoryId) {
  return _postedDateCategoryIds.contains(_norm(categoryId));
}

bool isPostedDateEntity(
  Map<String, dynamic> entity, {
  String? selectedCategoryId,
}) {
  if (isPostedDateCategoryId(selectedCategoryId)) return true;

  if (isPostedDateCategoryId(entity['categoryId']?.toString())) return true;
  if (isPostedDateCategoryId(entity['category']?.toString())) return true;

  final listKeys = ['category_ids', 'categoryIds', 'categories'];
  for (final listKey in listKeys) {
    final values = entity[listKey];
    if (values is List) {
      for (final value in values) {
        if (isPostedDateCategoryId(value?.toString())) return true;
      }
    }
  }

  return false;
}

DateTime? extractPostedDate(Map<String, dynamic> entity) {
  final direct = _firstNonEmpty(entity, _postedDateKeys);
  final directDate = _parseDateValue(direct);
  if (directDate != null) return directDate;

  final raw = _asStringMap(entity['raw']);
  final rawValue = _firstNonEmpty(raw, _postedDateKeys);
  return _parseDateValue(rawValue);
}

String formatPostedDate(DateTime postedDate) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = postedDate.toLocal();
  final month = months[local.month - 1];
  return '$month ${local.day}, ${local.year}';
}

String? extractPostedDateText(Map<String, dynamic> entity) {
  final postedDate = extractPostedDate(entity);
  if (postedDate != null) return formatPostedDate(postedDate);

  final direct = _firstNonEmpty(entity, _postedDateKeys);
  if (direct != null) return direct.toString().trim();

  final raw = _asStringMap(entity['raw']);
  final rawValue = _firstNonEmpty(raw, _postedDateKeys);
  if (rawValue != null) return rawValue.toString().trim();

  return null;
}

int compareEntitiesByPostedDateDesc(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final aDate = extractPostedDate(a);
  final bDate = extractPostedDate(b);
  if (aDate == null && bDate == null) return 0;
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  return bDate.compareTo(aDate);
}
