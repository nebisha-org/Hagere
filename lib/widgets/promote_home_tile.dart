import 'package:flutter/material.dart';

import '../services/payments_api.dart';
import '../services/checkout_launcher.dart';

class PromoteHomeTile extends StatefulWidget {
  const PromoteHomeTile({
    super.key,
    required this.entityId,
    required this.apiBaseUrl,
  });

  final String entityId;
  final String apiBaseUrl;

  @override
  State<PromoteHomeTile> createState() => _PromoteHomeTileState();
}

class _PromoteHomeTileState extends State<PromoteHomeTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _loading ? null : _onPromote,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue),
            color: Colors.blue.withOpacity(0.08),
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.blue),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sponsor on Home (Main Screen)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      r'$4.99 · Show on home for 7 days',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onPromote() async {
    setState(() => _loading = true);
    try {
      final api = PaymentsApi(baseUrl: widget.apiBaseUrl);

      // ✅ This is the $4.99 flow
      final checkoutUrl = await api.createCheckoutSession(
        entityId: widget.entityId,
        promotionTier: 'homeSponsored',
      );

      await CheckoutLauncher.openExternal(checkoutUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Complete payment in browser, then return.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start home sponsor: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
