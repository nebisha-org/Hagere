import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentsApi {
  PaymentsApi({required this.baseUrl});

  final String baseUrl; // e.g. https://api.yourdomain.com

  Future<Uri> createCheckoutSession({
    required String entityId,
    required String promotionTier, // "homeSponsored" or "categoryFeatured"
    String? categoryId, // required if categoryFeatured
  }) async {
    final uri = Uri.parse('$baseUrl/payments/checkout-session');

    final body = <String, dynamic>{
      'entityId': entityId,
      'promotionTier': promotionTier,
      if (categoryId != null) 'categoryId': categoryId,
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
          'Checkout session failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception('Checkout session not ok: ${res.body}');
    }

    final url = (data['checkoutUrl'] as String?)?.trim();
    if (url == null || url.isEmpty) {
      throw Exception('Missing checkoutUrl: ${res.body}');
    }

    return Uri.parse(url);
  }
}
