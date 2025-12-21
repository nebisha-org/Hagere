import 'package:url_launcher/url_launcher.dart';

class CheckoutLauncher {
  static Future<void> openExternal(Uri url) async {
    final ok = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      throw Exception('Could not launch checkout URL');
    }
  }
}
