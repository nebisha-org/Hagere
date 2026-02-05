import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final deviceTag = Platform.environment['DEVICE_TAG'] ?? 'unknown_device';
  final outDir = Directory(
    '/Users/nebsha/FlutterProjects/AllHabesha/_screenshots_automation_2026-01-30/$deviceTag',
  );
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes,
        [Map<String, Object?>? args]) async {
      final file = File('${outDir.path}/$screenshotName.png');
      file.writeAsBytesSync(screenshotBytes);
      return true;
    },
  );
}
