import 'package:shared_preferences/shared_preferences.dart';

class PostedEntitiesStore {
  PostedEntitiesStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _guestKey = 'posted_entity_ids_guest_v1';
  static const String _userKeyPrefix = 'posted_entity_ids_user_v1_';
  static const String _localUserPrefix = 'local_';
  static const int _maxSavedIds = 200;

  List<String> readGuestEntityIds() {
    return _readList(_guestKey);
  }

  List<String> readUserEntityIds(String userId) {
    return _readList(_userKeyFor(userId));
  }

  List<String> readAllLocalEntityIds() {
    const localKeyPrefix = '$_userKeyPrefix$_localUserPrefix';
    final keys = _prefs
        .getKeys()
        .where((key) => key.startsWith(localKeyPrefix))
        .toList()
      ..sort();

    final merged = <String>[];
    final seen = <String>{};
    for (final key in keys) {
      for (final id in _readList(key)) {
        if (seen.contains(id)) continue;
        seen.add(id);
        merged.add(id);
      }
    }
    return merged;
  }

  Future<void> addGuestEntityId(String entityId) async {
    await _addToList(_guestKey, entityId);
  }

  Future<void> addUserEntityId({
    required String userId,
    required String entityId,
  }) async {
    await _addToList(_userKeyFor(userId), entityId);
  }

  Future<void> mergeUserEntityIds({
    required String userId,
    required Iterable<String> entityIds,
  }) async {
    final key = _userKeyFor(userId);
    final merged = _mergeExisting(_readList(key), entityIds);
    await _prefs.setStringList(key, merged);
  }

  List<String> _readList(String key) {
    final raw = _prefs.getStringList(key) ?? const <String>[];
    return raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _addToList(String key, String entityId) async {
    final cleanId = entityId.trim();
    if (cleanId.isEmpty) return;
    final next = _mergeExisting(_readList(key), [cleanId]);
    await _prefs.setStringList(key, next);
  }

  List<String> _mergeExisting(
      List<String> existing, Iterable<String> incoming) {
    final next =
        existing.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    for (final id in incoming) {
      final cleanId = id.trim();
      if (cleanId.isEmpty) continue;
      next.remove(cleanId);
      next.insert(0, cleanId);
    }
    if (next.length > _maxSavedIds) {
      next.removeRange(_maxSavedIds, next.length);
    }
    return next;
  }

  String _userKeyFor(String userId) => '$_userKeyPrefix${userId.trim()}';
}
