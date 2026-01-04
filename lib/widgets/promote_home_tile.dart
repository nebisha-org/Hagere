//

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/payments_api.dart';
import '../state/sponsored_providers.dart';

class PromoteHomeTile extends ConsumerStatefulWidget {
  const PromoteHomeTile({
    super.key,
    required this.entityId,
    required this.apiBaseUrl,
  });

  final String entityId;
  final String apiBaseUrl;

  @override
  ConsumerState<PromoteHomeTile> createState() => _PromoteHomeTileState();
}

class _PromoteHomeTileState extends ConsumerState<PromoteHomeTile>
    with WidgetsBindingObserver {
  bool _busy = false;
  StreamSubscription? _sub;

  // You must set these to match what your backend uses.
  // If you already use different values, change them here.
  static const String _promotionTier = 'homeSponsored';

  // Your backend must create success/cancel urls that return to the app
  // e.g. allhabesha://payments/success?entityId=...
  // We can’t catch deep links here unless you’ve set up a deep link handler.
  // But we can still refresh on app resume which works for V1.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user returns from browser after payment, app resumes.
    // Refresh sponsored data so the paid listing shows immediately.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(homeSponsoredProvider);
    }
  }

  Future<void> _startCheckout() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final api = PaymentsApi(baseUrl: widget.apiBaseUrl);

      // Your existing method name may be different.
      // This must call your backend which returns a Stripe Checkout URL.
      final checkoutUrl = await api.createCheckoutSession(
        entityId: widget.entityId,
        promotionTier: _promotionTier,
      );

      final uri =
          checkoutUrl is Uri ? checkoutUrl : Uri.parse(checkoutUrl.toString());

      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open checkout')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.star),
      title: const Text('Promote on Home'),
      subtitle: const Text('Paid placement on the home screen.'),
      trailing: _busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _busy ? null : _startCheckout,
    );
  }
}
