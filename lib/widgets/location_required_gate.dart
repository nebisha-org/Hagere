import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/providers.dart';
import 'tr_text.dart';

class LocationRequiredGate extends ConsumerWidget {
  const LocationRequiredGate({super.key});

  static const String _message =
      'This app wont operate properly with out enableing location service';

  Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
    var opened = false;
    final location = Location();

    try {
      final serviceOpened = await location.requestService();
      opened = opened || serviceOpened;
    } catch (_) {
      // no-op
    }

    try {
      await location.requestPermission();
    } catch (_) {
      // no-op
    }

    try {
      final appSettings = Uri.parse('app-settings:');
      if (await canLaunchUrl(appSettings)) {
        final appOpened = await launchUrl(
          appSettings,
          mode: LaunchMode.externalApplication,
        );
        opened = opened || appOpened;
      }
    } catch (_) {
      // no-op
    }

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TrText('Could not open settings'),
        ),
      );
    }

    try {
      await ref.read(locationControllerProvider).ensureLocationReady();
    } catch (_) {
      // Keep gate visible until user enables location and permission.
    }
  }

  Future<void> _exitApp() async {
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 52,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const TrText(
              _message,
              translate: false,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _exitApp,
                  child: const TrText('Exit', translate: false),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => _openSettings(context, ref),
                  child: const TrText('Setting', translate: false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
