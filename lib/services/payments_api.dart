import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PaymentsApi {
  PaymentsApi({required this.baseUrl});

  final String
      baseUrl; // ex: https://xxxxx.execute-api.us-east-2.amazonaws.com/api

  Future<Uri> createCheckoutSession({
    required String entityId,
    required String promotionTier, // "homeSponsored" or "categoryFeatured"
    String? categoryId,
  }) async {
    final uri = Uri.parse('$baseUrl/payments/checkout-session');

    final body = <String, dynamic>{
      'entityId': entityId,
      'promotionTier': promotionTier,
      if (categoryId != null) 'categoryId': categoryId,
    };

    debugPrint('CHECKOUT POST => $uri');
    debugPrint('CHECKOUT BODY => ${jsonEncode(body)}');

    final res = await http.post(
      uri,
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    debugPrint('CHECKOUT RES status=${res.statusCode} body=${res.body}');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
          'Checkout session failed (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    final url = (decoded is Map && decoded['url'] is String)
        ? decoded['url'] as String
        : null;

    if (url == null || url.trim().isEmpty) {
      throw Exception('Backend did not return checkout url: ${res.body}');
    }

    return Uri.parse(url);
  }
}


// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;

// class PaymentsApi {
//   PaymentsApi({required this.baseUrl});

//   final String
//       baseUrl; // e.g. https://xxxx.execute-api.region.amazonaws.com/api

//   Future<Uri> createCheckoutSession({
//     required String entityId,
//     required String promotionTier, // "homeSponsored" or "categoryFeatured"
//     String? categoryId,
//   }) async {
//     final uri = Uri.parse('$baseUrl/checkout');

//     final body = <String, dynamic>{
//       'entityId': entityId,
//       'promotionTier': promotionTier,
//       if (categoryId != null) 'categoryId': categoryId,
//     };

//     debugPrint('CHECKOUT URI => $uri');
//     debugPrint('CHECKOUT BODY => ${jsonEncode(body)}');

//     final res = await http.post(
//       uri,
//       headers: const {'Content-Type': 'application/json'},
//       body: jsonEncode(body),
//     );

//     debugPrint('STATUS => ${res.statusCode}');
//     debugPrint('RESP => ${res.body}');

//     if (res.statusCode < 200 || res.statusCode >= 300) {
//       throw Exception(
//           'Checkout session failed (${res.statusCode}): ${res.body}');
//     }

//     final data = jsonDecode(res.body) as Map<String, dynamic>;
//     final checkoutUrl = data['checkoutUrl'];

//     if (checkoutUrl is! String || checkoutUrl.isEmpty) {
//       throw Exception('Missing checkoutUrl in response: ${res.body}');
//     }

//     return Uri.parse(checkoutUrl);
//   }
// }



// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter/foundation.dart'; // <-- add this

// class PaymentsApi {
//   PaymentsApi({required this.baseUrl});

//   final String baseUrl; // e.g. https://api.yourdomain.com

//   Future<Uri> createCheckoutSession({
//     required String entityId,
//     required String promotionTier, // "homeSponsored" or "categoryFeatured"
//     String? categoryId, // required if categoryFeatured
//   }) async {
//     final uri = Uri.parse('$baseUrl/checkout');
//     print('CHECKOUT URI => $uri');

//     final body = <String, dynamic>{
//       'entityId': entityId,
//       'promotionTier': promotionTier,
//       if (categoryId != null) 'categoryId': categoryId,
//     };
//     debugPrint('CHECKOUT URI => $uri');
//     debugPrint('CHECKOUT BODY => ${jsonEncode({
//           'entityId': entityId,
//           'promotionTier': promotionTier,
//           if (categoryId != null) 'categoryId': categoryId,
//         })}');

//     final res = await http.post(
//       uri,
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode(body),
//     );

//   if (res.statusCode < 200 || res.statusCode >= 300) {
//   debugPrint('❌ CHECKOUT FAILED');
//   debugPrint('STATUS: ${res.statusCode}');
//   debugPrint('BODY: ${res.body}');
//   debugPrint('URL: $uri');

//   throw Exception('Checkout session failed');
// }
  
//   else {

//     final data = jsonDecode(res.body) as Map<String, dynamic>;
//     if (data['ok'] != true) {
//       throw Exception('Checkout session not ok: ${res.body}');
//     }

//     final url = (data['checkoutUrl'] as String?)?.trim();
//     if (url == null || url.isEmpty) {
//       throw Exception('Missing checkoutUrl: ${res.body}');
//     }

//     return Uri.parse(url);
//   }
// }
