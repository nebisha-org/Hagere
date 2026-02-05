import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:agerelige_flutter_client/main.dart' as app;
import 'package:agerelige_flutter_client/screens/places_v2_list_screen.dart';

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitForPlacesList(WidgetTester tester,
    {Duration timeout = const Duration(seconds: 300)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));

    final enable = find.text('Enable Location');
    if (enable.evaluate().isNotEmpty) {
      await tester.tap(enable.first);
      await tester.pump();
    }

    final listTiles = find.descendant(
      of: find.byType(PlacesV2ListScreen),
      matching: find.byType(ListTile),
    );
    if (listTiles.evaluate().isNotEmpty) return;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('core flows screenshots', (tester) async {
    app.main();
    await tester.pump();
    await _pumpFor(tester, const Duration(seconds: 2));

    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }

    // Home categories
    await binding.takeScreenshot('home');

    // Tap a category to open Places list (if present)
    final restaurants = find.text('Restaurants');
    if (restaurants.evaluate().isNotEmpty) {
      await tester.tap(restaurants.first);
      await tester.pump();
      await _waitForPlacesList(tester);
      await binding.takeScreenshot('places_list');
      await tester.pageBack();
      await tester.pump();
      await _pumpFor(tester, const Duration(seconds: 1));
    }

    // Open Add Listing card
    final addListing = find.textContaining('Add your listing');
    if (addListing.evaluate().isNotEmpty) {
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(addListing.first, 200,
            scrollable: scrollable.first);
      }
      await tester.tap(addListing.first);
      await tester.pump();
      await _pumpFor(tester, const Duration(seconds: 2));
      await binding.takeScreenshot('add_listing_empty');

      // Select category from dropdown
      final dropdown = find.byType(DropdownButtonFormField);
      if (dropdown.evaluate().isNotEmpty) {
        await tester.tap(dropdown.first);
        await tester.pump();
        await _pumpFor(tester, const Duration(milliseconds: 500));
        final menuItem = find.textContaining('Restaurants');
        if (menuItem.evaluate().isNotEmpty) {
          await tester.tap(menuItem.last);
          await tester.pump();
          await _pumpFor(tester, const Duration(milliseconds: 500));
        }
      }

      // Fill fields (name, phone, address)
      final fields = find.byType(TextFormField);
      if (fields.evaluate().length >= 3) {
        await tester.enterText(fields.at(0), 'Test Business');
        await tester.enterText(fields.at(1), '2025550123');
        await tester.enterText(fields.at(2), '123 Main St');
        await tester.pump();
        await _pumpFor(tester, const Duration(milliseconds: 500));
      }

      final saveBtn = find.text('Save');
      if (saveBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(saveBtn.first);
      }
      await binding.takeScreenshot('add_listing_filled');
    }
  });
}
