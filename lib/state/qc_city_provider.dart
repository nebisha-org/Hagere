import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translation_provider.dart';

class QcCityOption {
  const QcCityOption({
    required this.key,
    required this.label,
    required this.city,
    this.state,
  });

  final String key;
  final String label;
  final String city;
  final String? state;
}

const List<QcCityOption> qcCityOptions = [
  QcCityOption(
    key: 'alexandria_va',
    label: 'Alexandria, VA',
    city: 'Alexandria',
    state: 'VA',
  ),
  QcCityOption(
    key: 'dc',
    label: 'Washington, DC',
    city: 'Washington',
    state: 'DC',
  ),
  QcCityOption(
    key: 'silver_spring_md',
    label: 'Silver Spring, MD',
    city: 'Silver Spring',
    state: 'MD',
  ),
  QcCityOption(
    key: 'dubai',
    label: 'Dubai',
    city: 'Dubai',
    state: null,
  ),
];

QcCityOption? qcCityOptionForKey(String? key) {
  if (key == null || key.trim().isEmpty) return null;
  for (final option in qcCityOptions) {
    if (option.key == key) return option;
  }
  return null;
}

class QcCityOverrideController extends StateNotifier<String?> {
  QcCityOverrideController(this._prefs)
      : super(_prefs.getString(_prefsKey));

  static const _prefsKey = 'qc_city_override';

  final SharedPreferences _prefs;

  void setOverride(String? key) {
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      state = null;
      _prefs.remove(_prefsKey);
      return;
    }
    state = trimmed;
    _prefs.setString(_prefsKey, trimmed);
  }
}

final qcCityOverrideProvider =
    StateNotifierProvider<QcCityOverrideController, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return QcCityOverrideController(prefs);
});
