import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.189.1:8000';

  static Future<PredictionResult> predict({
    required UserModel user,
    required BiometricSnapshot bio,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/predict'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(user.toApiBody(bio)),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 200) {
      return PredictionResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw Exception('API ${res.statusCode}: ${res.body}');
  }

  static Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getModelPerformance() async {
    final res = await http
        .get(Uri.parse('$baseUrl/model-performance'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('API error');
  }
}
