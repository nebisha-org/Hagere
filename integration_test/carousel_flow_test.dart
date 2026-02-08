import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:agerelige_flutter_client/main.dart' as app;
import 'package:agerelige_flutter_client/screens/add_listing_screen.dart';

const int _flowDelaySeconds =
    int.fromEnvironment('FLOW_DELAY_SECONDS', defaultValue: 1);

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pause(WidgetTester tester, {int seconds = 2}) async {
  final totalSeconds = seconds * _flowDelaySeconds;
  if (totalSeconds <= 0) return;
  await _pumpFor(tester, Duration(seconds: totalSeconds));
}

Future<void> _waitForCategories(WidgetTester tester,
    {Duration timeout = const Duration(seconds: 90)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    final chevrons = find.descendant(
      of: find.byType(ListTile),
      matching: find.byIcon(Icons.chevron_right),
    );
    if (chevrons.evaluate().isNotEmpty) return;
  }
  throw Exception('Timed out waiting for categories.');
}

Future<void> _waitForAddListingForm(WidgetTester tester,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  final dropdown = find.byKey(const Key('add_listing_category'));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (dropdown.evaluate().isNotEmpty) return;
  }
  throw Exception('Timed out waiting for Add Listing form.');
}

Future<void> _toggleStripeTest(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  final stripeLabel = find.text('Stripe mode');
  if (scrollable.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(stripeLabel, 260,
        scrollable: scrollable.first);
  }
  await tester.pump();
  final toggle = find.byKey(const Key('stripe_mode_toggle'));
  if (toggle.evaluate().isNotEmpty) {
    await tester.tap(toggle.first);
    await tester.pump();
  }
  await _pause(tester, seconds: 1);
}

Future<void> _openAddListing(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  final addTile = find.byKey(const Key('add_listing_tile'));
  final pageView = find.byType(PageView);
  if (scrollable.evaluate().isNotEmpty && pageView.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(pageView.first, 200,
        scrollable: scrollable.first);
  }
  for (var i = 0; i < 12; i++) {
    if (addTile.evaluate().isNotEmpty) {
      await tester.ensureVisible(addTile.first);
      await tester.tap(addTile.first, warnIfMissed: false);
      await tester.pump();
      await _pause(tester, seconds: 2);
      return;
    }
    if (pageView.evaluate().isNotEmpty) {
      await tester.fling(pageView.first, const Offset(300, 0), 900);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    } else {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }
  throw Exception('Add listing tile not found in carousel.');
}

Future<void> _selectCategory(WidgetTester tester, String label) async {
  await _waitForAddListingForm(tester);
  final dropdown = find.byKey(const Key('add_listing_category'));
  if (dropdown.evaluate().isEmpty) {
    throw Exception('Category dropdown not found.');
  }
  await tester.tap(dropdown.first);
  await tester.pump();
  await _pause(tester, seconds: 1);
  final menuItem = find.textContaining(label);
  if (menuItem.evaluate().isEmpty) {
    throw Exception('Category "$label" not found.');
  }
  await tester.tap(menuItem.last);
  await tester.pump();
  await _pause(tester, seconds: 1);
}

Future<void> _fillRequiredFields(WidgetTester tester, String name) async {
  final field = find.byKey(const Key('add_listing_name'));
  if (field.evaluate().isEmpty) {
    throw Exception('Name field not found.');
  }
  await tester.enterText(field, name);
  await tester.pump();
  await _pause(tester, seconds: 1);
}

Future<void> _saveAndPromote(WidgetTester tester) async {
  final button = find.byKey(const Key('add_listing_save_promote'));
  if (button.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(button, 300,
          scrollable: scrollable.first);
      await tester.pump();
    }
  }
  if (button.evaluate().isEmpty) {
    throw Exception('Save & Promote button not found.');
  }
  await tester.ensureVisible(button.first);
  await tester.tap(button.first);
  await tester.pump();
  await _pause(tester, seconds: 4);
}

Future<void> _findInCarousel(WidgetTester tester, String name) async {
  await tester.pageBack();
  await tester.pump();
  await _pause(tester, seconds: 5);
  await _waitForCategories(tester);

  final scrollable = find.byType(Scrollable);
  final addListing = find.textContaining('Add your listing');
  if (addListing.evaluate().isNotEmpty && scrollable.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(addListing.first, 200,
        scrollable: scrollable.first);
    await tester.pump();
  }

  final pageView = find.byType(PageView);
  if (pageView.evaluate().isEmpty) {
    await _pause(tester, seconds: 2);
  }
  if (pageView.evaluate().isEmpty) {
    throw Exception('Carousel PageView not found.');
  }

  final tileText = find.text(name);
  for (var i = 0; i < 24; i++) {
    if (tileText.evaluate().isNotEmpty) {
      final tile = find.ancestor(
        of: tileText.first,
        matching: find.byType(InkWell),
      );
      try {
        if (tile.evaluate().isNotEmpty) {
          await tester.dragUntilVisible(
            tile.first,
            pageView.first,
            const Offset(-300, 0),
          );
        } else {
          await tester.dragUntilVisible(
            tileText.first,
            pageView.first,
            const Offset(-300, 0),
          );
        }
      } catch (_) {
        // ignore drag errors; we'll still attempt to tap.
      }
      await tester.pumpAndSettle(const Duration(seconds: 1));
      if (tile.evaluate().isNotEmpty) {
        await tester.tap(tile.first, warnIfMissed: false);
      } else {
        await tester.tap(tileText.first, warnIfMissed: false);
      }
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final share = find.text('Share');
      final detailScroll = find.byType(Scrollable);
      if (share.evaluate().isNotEmpty && detailScroll.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(share.first, 200,
            scrollable: detailScroll.first);
        await tester.pump();
      }
      if (share.evaluate().isEmpty) {
        throw Exception('Detail screen not opened for carousel item.');
      }
      return;
    }
    await tester.fling(pageView.first, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }
  throw Exception('Carousel item not found: $name');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('carousel flow (test stripe + auto listing)', (tester) async {
    app.main();
    await tester.pump();
    await _pause(tester, seconds: 2);

    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }

    await _waitForCategories(tester);
    await _pause(tester, seconds: 1);

    await _toggleStripeTest(tester);
    await _pause(tester, seconds: 1);

    await _openAddListing(tester);
    await _selectCategory(tester, 'Markets');

    final name = 'Auto Carousel ${DateTime.now().millisecondsSinceEpoch}';
    await _fillRequiredFields(tester, name);

    await _saveAndPromote(tester);
    await _findInCarousel(tester, name);
  });
}
