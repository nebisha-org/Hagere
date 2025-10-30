import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/user.dart';

class ApiClient {
  ApiClient({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: _baseUrl, connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)));

  static const String _baseUrl = 'https://6qipli13v7.execute-api.us-east-2.amazonaws.com/api/';

  final Dio _dio;

  /// GET /users -> {"users": [ ... ]}
  Future<List<User>> listUsers() async {
    final res = await _dio.get<Map<String, dynamic>>('users');
    final usersJson = (res.data?['users'] as List<dynamic>? ?? []);
    return usersJson.map((e) => User.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// GET /users/{id} -> Item
  Future<User?> getUserById(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('users/$id');
    final data = res.data;
    if (data == null || data.isEmpty) return null;
    return User.fromJson(data);
  }

  /// POST /users -> {"user_id": "..."}
  Future<String> createUser({
    required String name,
    String age = '',
    String gender = '',
    String bio = '',
    String imageUrl = '',
    String latitude = '',
    String longitude = '',
    String city = '',
    String state = '',
  }) async {
    final body = {
      'name': name,
      'age': age,
      'gender': gender,
      'bio': bio,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'state': state,
    };
    final res = await _dio.post<Map<String, dynamic>>('users', data: body);
    final id = res.data?['user_id'] as String?;
    if (id == null || id.isEmpty) {
      throw Exception('Backend did not return user_id');
    }
    return id;
  }

  /// POST /upload-url -> {"uploadURL": "...", "fileKey": "user-images/....jpg"}
  /// After obtaining the URL, PUT the bytes to S3 with Content-Type: image/jpeg.
  Future<(String uploadUrl, String fileKey)> createImageUploadUrl() async {
    final res = await _dio.post<Map<String, dynamic>>('upload-url');
    final url = res.data?['uploadURL'] as String?;
    final key = res.data?['fileKey'] as String?;
    if (url == null || key == null) throw Exception('upload-url response invalid');
    return (url, key);
  }

  /// Upload raw JPEG bytes to the presigned S3 URL
  Future<void> uploadJpegToPresignedUrl(String url, Uint8List jpegBytes) async {
    await _dio.put<void>(
      url,
      data: Stream.fromIterable(jpegBytes.map((b) => [b])),
      options: Options(
        headers: {'Content-Type': 'image/jpeg'},
        // Important: full URL; disable baseUrl resolving & follow redirects
        followRedirects: true,
        validateStatus: (code) => code != null && code >= 200 && code < 400,
      ),
    );
  }
}
