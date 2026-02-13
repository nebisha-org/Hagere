import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:agerelige_flutter_client/config/env.dart';
import 'package:agerelige_flutter_client/services/payments_api.dart';
import 'package:agerelige_flutter_client/widgets/tr_text.dart';
import 'package:agerelige_flutter_client/main.dart' as app;

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 200),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw StateError('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Payment toggle + Stripe endpoints return checkout urls',
    (tester) async {
      // These prints are intentional: we want visible progress in simulator runs.
      // ignore: avoid_print
      print('TEST: starting app');
      await app.main();

      // Initial render. Avoid pumpAndSettle here because spinners animate and never "settle".
      await tester.pump(const Duration(milliseconds: 200));

      // The home screen blocks on location sometimes; wait for the language toggle.
      // ("EN" is not translated)
      // ignore: avoid_print
      print('TEST: waiting for CategoriesScreen (EN toggle)');
      await _pumpUntilFound(
        tester,
        find.text('EN'),
        timeout: const Duration(seconds: 90),
      );
      // ignore: avoid_print
      print('TEST: CategoriesScreen visible');

      // Scroll until the Payment option toggle is visible and flip it to Subscription.
      final paymentToggle = find.byKey(const Key('payment_type_toggle'));
      // ignore: avoid_print
      print('TEST: scrolling to payment toggle');
      await tester.scrollUntilVisible(
        paymentToggle,
        320,
        scrollable: find.byType(Scrollable).first,
      );

      // Ensure we can toggle it on (switch value = true).
      // ignore: avoid_print
      print('TEST: payment toggle visible; switching ON if needed');

      // Bring it slightly above the bottom edge so taps reliably hit-test.
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -160),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final tileBefore = tester.widget<SwitchListTile>(paymentToggle);
      // ignore: avoid_print
      print('TEST: payment toggle initial value => ${tileBefore.value}');

      if (tileBefore.value != true) {
        final switchFinder =
            find.descendant(of: paymentToggle, matching: find.byType(Switch));
        expect(switchFinder, findsOneWidget);
        await tester.tap(switchFinder);
        await tester.pump(const Duration(milliseconds: 400));
      }

      final tileAfter = tester.widget<SwitchListTile>(paymentToggle);
      // ignore: avoid_print
      print('TEST: payment toggle final value => ${tileAfter.value}');
      expect(tileAfter.value, isTrue);

      // Verify the subscription endpoint works from Dart.
      await tester.runAsync(() async {
        final subscriptionApi =
            PaymentsApi(baseUrl: subscriptionPaymentsBaseUrl);
        // ignore: avoid_print
        print('TEST: calling subscription checkout');
        final subUri = await subscriptionApi
            .createSubscriptionCheckoutSession(
              entityId: 'ENTITY#integration_test',
              promotionTier: 'homeSponsored',
              stripeMode: 'test',
              intervalDays: 7,
            )
            .timeout(const Duration(seconds: 25));
        // ignore: avoid_print
        print('TEST: subscription checkoutUrl => $subUri');
        expect(subUri.toString(), contains('checkout.stripe.com'));
      });

      // Verify the existing one-time endpoint still works (uses your existing backend).
      await tester.runAsync(() async {
        final oneTimeApi = PaymentsApi(baseUrl: paymentsBaseUrl);
        // ignore: avoid_print
        print('TEST: calling one-time checkout');
        final oneTimeUri = await oneTimeApi
            .createCheckoutSession(
              // This id exists in EthCommunityEntities (queried during setup).
              entityId: '2a816572-9b0b-44b7-826d-3c6ee6f72a7b',
              promotionTier: 'homeSponsored',
              stripeMode: 'test',
            )
            .timeout(const Duration(seconds: 25));
        // ignore: avoid_print
        print('TEST: one-time checkoutUrl => $oneTimeUri');
        expect(oneTimeUri.toString(), contains('checkout.stripe.com'));
      });

      // Sanity: translation widget still builds (quick smoke).
      expect(find.byType(TrText), findsWidgets);
      // ignore: avoid_print
      print('TEST: completed successfully');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
