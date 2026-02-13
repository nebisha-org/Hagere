import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final deviceTag = Platform.environment['DEVICE_TAG'] ?? 'unknown_device';
  // Allow choosing an output directory without editing this file every time.
  // Example:
  //   SCREENSHOT_OUT_DIR=/.../_screenshots_automation_YYYY-MM-DD DEVICE_TAG=iphone_16e flutter drive ...
  final outBaseDir = Platform.environment['SCREENSHOT_OUT_DIR'] ??
      '/Users/nebsha/FlutterProjects/AllHabesha/_screenshots_automation_2026-01-30';
  final outDir = Directory('$outBaseDir/$deviceTag');
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
