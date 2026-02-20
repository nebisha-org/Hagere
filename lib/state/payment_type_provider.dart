import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PaymentType { oneTime, subscription }

const String _paymentTypePrefsKey = 'payment_type_mode';

final paymentTypeProvider =
    StateNotifierProvider<PaymentTypeController, PaymentType>(
  (ref) => PaymentTypeController(),
);

class PaymentTypeController extends StateNotifier<PaymentType> {
  PaymentTypeController() : super(PaymentType.subscription) {
    _load();
  }

  bool _userSet = false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_userSet) return;
    // Always boot with Subscription as the app default.
    state = PaymentType.subscription;
    await prefs.setString(_paymentTypePrefsKey, PaymentType.subscription.name);
  }

  Future<void> setType(PaymentType type) async {
    _userSet = true;
    state = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paymentTypePrefsKey, type.name);
  }

  Future<void> toggle() async {
    await setType(
      state == PaymentType.oneTime
          ? PaymentType.subscription
          : PaymentType.oneTime,
    );
  }
}
