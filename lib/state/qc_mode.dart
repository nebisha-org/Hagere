import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translation_provider.dart';

const bool kQcMode = bool.fromEnvironment('QC_MODE', defaultValue: false);

@immutable
class QcEditState {
  const QcEditState({required this.visible, required this.editing});

  final bool visible;
  final bool editing;

  QcEditState copyWith({bool? visible, bool? editing}) {
    return QcEditState(
      visible: visible ?? this.visible,
      editing: editing ?? this.editing,
    );
  }
}

class QcEditStateController extends StateNotifier<QcEditState> {
  QcEditStateController(this._prefs) : super(_load(_prefs));

  static const _visibleKey = 'qc_edit_visible';
  static const _editingKey = 'qc_edit_enabled';

  final SharedPreferences _prefs;

  static QcEditState _load(SharedPreferences prefs) {
    final visible = prefs.getBool(_visibleKey) ?? false;
    final editing = prefs.getBool(_editingKey) ?? false;
    return QcEditState(visible: visible, editing: visible ? editing : false);
  }

  void _persist(QcEditState next) {
    _prefs.setBool(_visibleKey, next.visible);
    _prefs.setBool(_editingKey, next.editing);
  }

  void showControls() {
    final next = const QcEditState(visible: true, editing: false);
    state = next;
    _persist(next);
  }

  void hideControls() {
    final next = const QcEditState(visible: false, editing: false);
    state = next;
    _persist(next);
  }

  void startEditing() {
    final next = const QcEditState(visible: true, editing: true);
    state = next;
    _persist(next);
  }

  void stopEditing() {
    final next = const QcEditState(visible: true, editing: false);
    state = next;
    _persist(next);
  }

  void toggleEditing() {
    if (!state.visible) {
      startEditing();
      return;
    }
    state.editing ? stopEditing() : startEditing();
  }
}

final qcEditStateProvider =
    StateNotifierProvider<QcEditStateController, QcEditState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return QcEditStateController(prefs);
});
