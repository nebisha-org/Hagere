import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StripeMode { live, test }

const String _stripeModePrefsKey = 'stripe_mode';

final stripeModeProvider =
    StateNotifierProvider<StripeModeController, StripeMode>(
  (ref) => StripeModeController(),
);

class StripeModeController extends StateNotifier<StripeMode> {
  StripeModeController() : super(StripeMode.live) {
    _load();
  }

  static bool get allowTest => !kReleaseMode;
  bool _userSet = false;

  Future<void> _load() async {
    if (!allowTest) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_stripeModePrefsKey);
    if (_userSet) return;
    if (stored == StripeMode.test.name) {
      state = StripeMode.test;
    } else {
      state = StripeMode.live;
    }
  }

  Future<void> setMode(StripeMode mode) async {
    if (!allowTest) return;
    _userSet = true;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stripeModePrefsKey, mode.name);
  }

  Future<void> toggle() async {
    await setMode(state == StripeMode.live ? StripeMode.test : StripeMode.live);
  }
}
