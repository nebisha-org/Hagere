import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import 'translation_provider.dart';

const String _qcAdminKeyPrefsKey = 'qc_admin_api_key_v1';

final qcAdminApiKeyProvider =
    StateNotifierProvider<QcAdminApiKeyController, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return QcAdminApiKeyController(prefs);
});

class QcAdminApiKeyController extends StateNotifier<String> {
  QcAdminApiKeyController(this._prefs) : super(_loadInitial(_prefs));

  final SharedPreferences _prefs;

  static String _loadInitial(SharedPreferences prefs) {
    final stored = (prefs.getString(_qcAdminKeyPrefsKey) ?? '').trim();
    if (stored.isNotEmpty) return stored;
    final env = qcAdminApiKey.trim();
    if (env.isNotEmpty) return env;
    return '';
  }

  Future<void> setKey(String key) async {
    final trimmed = key.trim();
    state = trimmed;
    await _prefs.setString(_qcAdminKeyPrefsKey, trimmed);
  }

  Future<void> clear() async {
    state = '';
    await _prefs.remove(_qcAdminKeyPrefsKey);
  }
}
