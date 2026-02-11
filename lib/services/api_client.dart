import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';

class ApiClient {
  final http.Client _c = http.Client();

  Future<List<dynamic>> getEntities() async {
    final r = await _c.get(Uri.parse('$entitiesBaseUrl/entities'));
    if (r.statusCode != 200) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createEntity(Map<String, dynamic> body) async {
    final r = await _c.post(
      Uri.parse('$entitiesBaseUrl/entities'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
