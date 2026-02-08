import 'package:flutter/material.dart';
import '../services/payments_api.dart';
import '../services/checkout_launcher.dart';

const bool kShowHomeSponsor = false;

class PromoteCategoryTile extends StatefulWidget {
  const PromoteCategoryTile({
    super.key,
    required this.categoryId,
    required this.entityId,
    required this.paymentsBaseUrl,
  });

  final String categoryId;
  final String entityId;
  final String paymentsBaseUrl;

  @override
  State<PromoteCategoryTile> createState() => _PromoteCategoryTileState();
}

class _PromoteCategoryTileState extends State<PromoteCategoryTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (!kShowHomeSponsor) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _loading ? null : _onPromote,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange),
            color: Colors.orange.withOpacity(0.08),
          ),
          child: Row(
            children: [
              const Icon(Icons.campaign, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Promote your business here',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(r'$2.99 · Top of this category for 7 days',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              if (_loading)
                const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
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
      final api = PaymentsApi(baseUrl: widget.paymentsBaseUrl);

      final checkoutUrl = await api.createCheckoutSession(
        entityId: widget.entityId,
        promotionTier: 'categoryFeatured',
        categoryId: widget.categoryId,
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
          SnackBar(content: Text('Failed to start promotion: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
