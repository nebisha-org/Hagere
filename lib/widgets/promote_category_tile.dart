import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../services/payments_api.dart';
import '../services/checkout_launcher.dart';
import '../state/payment_type_provider.dart';
import '../state/stripe_mode_provider.dart';
import '../widgets/tr_text.dart';
import '../state/translation_provider.dart';

const bool kShowHomeSponsor = false;

class PromoteCategoryTile extends ConsumerStatefulWidget {
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
  ConsumerState<PromoteCategoryTile> createState() =>
      _PromoteCategoryTileState();
}

class _PromoteCategoryTileState extends ConsumerState<PromoteCategoryTile> {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText('Promote your business here',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    TrText(r'$1.99/week · Top of this category',
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
      final stripeMode = ref.read(stripeModeProvider);
      final paymentType = ref.read(paymentTypeProvider);
      final checkoutBaseUrl = paymentType == PaymentType.subscription
          ? subscriptionPaymentsBaseUrl
          : widget.paymentsBaseUrl;
      final api = PaymentsApi(baseUrl: checkoutBaseUrl);

      final checkoutUrl = paymentType == PaymentType.subscription
          ? await api.createSubscriptionCheckoutSession(
              entityId: widget.entityId,
              promotionTier: 'categoryFeatured',
              categoryId: widget.categoryId,
              stripeMode: stripeMode.name,
              intervalDays: 7,
            )
          : await api.createCheckoutSession(
              entityId: widget.entityId,
              promotionTier: 'categoryFeatured',
              categoryId: widget.categoryId,
              stripeMode: stripeMode.name,
            );

      await CheckoutLauncher.openExternal(checkoutUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: TrText('Complete payment in browser, then return.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final translator = ref.read(translationControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${translator.tr('Failed to start promotion:')} ${e.toString()}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
