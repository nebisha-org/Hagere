import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'qc_mode.dart';

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

  static bool get allowTest => kQcMode;
  bool _userSet = false;

  Future<void> _load() async {
    if (!allowTest) return;
    final prefs = await SharedPreferences.getInstance();
    if (_userSet) return;
    // Always boot with Live mode as the app default.
    state = StripeMode.live;
    await prefs.setString(_stripeModePrefsKey, StripeMode.live.name);
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
