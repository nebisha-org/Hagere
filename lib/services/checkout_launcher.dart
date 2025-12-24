import 'package:url_launcher/url_launcher.dart';

class CheckoutLauncher {
  /// Backwards-compatible with your existing calls:
  /// promote_home_tile.dart and promote_category_tile.dart call this.
  static Future<void> openExternal(Uri checkoutUrl) async {
    await open(checkoutUrl);
  }

  /// Canonical implementation
  static Future<void> open(Uri checkoutUrl) async {
    final ok = await launchUrl(
      checkoutUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!ok) {
      throw Exception('Could not open checkout URL: $checkoutUrl');
    }
  }
}

// import 'package:url_launcher/url_launcher.dart';

// class CheckoutLauncher {
//   static Future<void> openExternal(Uri url) async {
//     debugPrint('SPONSOR TAP -> starting checkout');
//     final ok = await launchUrl(
//       url,
//       mode: LaunchMode.externalApplication,
//     );
//     if (!ok) {
//       throw Exception('Could not launch checkout URL');
//     }
//     debugPrint('SPONSOR TAP -> starting checkout');
//   }
// }
