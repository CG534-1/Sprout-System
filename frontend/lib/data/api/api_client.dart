import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sprout/core/app_exception.dart';

class ApiClient {
  ApiClient({required this.baseUrl, required this.token});

  final String baseUrl;
  final Future<String?> Function() token;

  Future<dynamic> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final access = await token();
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Authorization': 'Bearer ${access ?? ''}',
        'Content-Type': 'application/json',
        'X-Utc-Offset-Minutes': DateTime.now().timeZoneOffset.inMinutes.toString(),
      });
    if (body != null) request.body = jsonEncode(body);
    final streamed = await request.send();
    final text = await streamed.stream.bytesToString();
    if (streamed.statusCode == 204 || text.isEmpty) {
      if (streamed.statusCode >= 400) {
        throw const AppException('Something went wrong.');
      }
      return null;
    }
    final decoded = jsonDecode(text);
    if (streamed.statusCode >= 400) {
      final message = decoded is Map && decoded['message'] is String
          ? decoded['message'] as String
          : 'Something went wrong.';
      throw AppException(message);
    }
    return decoded;
  }
}
