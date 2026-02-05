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

Future<void> _waitForPlacesList(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 300),
}) async {
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
  throw Exception('Timed out waiting for Places list.');
}

Future<void> _tapAllCategories(WidgetTester tester) async {
  final chevrons = find.descendant(
    of: find.byType(ListTile),
    matching: find.byIcon(Icons.chevron_right),
  );
  final count = chevrons.evaluate().length;
  if (count == 0) {
    throw Exception('No category tiles found.');
  }

  for (int i = 0; i < count; i++) {
    final icon = chevrons.at(i);
    await tester.ensureVisible(icon);
    await tester.pump();

    final tile = find.ancestor(of: icon, matching: find.byType(ListTile));
    await tester.tap(tile.first);
    await tester.pump();

    await _waitForPlacesList(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('tap all categories', (tester) async {
    app.main();
    await tester.pump();
    await _pumpFor(tester, const Duration(seconds: 2));

    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }

    await _tapAllCategories(tester);
  });
}
