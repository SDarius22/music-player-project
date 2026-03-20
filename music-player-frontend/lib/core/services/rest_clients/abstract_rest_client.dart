import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';

abstract class AbstractRestService {
  late final String baseUrl;
  late final AuthService authService;

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    String? token = authService.accessToken;

    Future<http.Response> perform(String t) {
      return http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $t',
        },
        body: jsonEncode(body),
      );
    }

    var response = await perform(token ?? "");

    if (response.statusCode == 401 || response.statusCode == 403) {
      final newToken = await authService.refreshAccessToken();
      if (newToken != null) {
        response = await perform(newToken);
      }
    }
    return response;
  }

  Future<http.Response> get(String endpoint) async {
    String? token = authService.accessToken;

    Future<http.Response> perform(String t) {
      return http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $t',
        },
      );
    }

    var response = await perform(token ?? "");

    if (response.statusCode == 401 || response.statusCode == 403) {
      final newToken = await authService.refreshAccessToken();
      if (newToken != null) {
        response = await perform(newToken);
      }
    }
    return response;
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    String? token = authService.accessToken;

    Future<http.Response> perform(String t) {
      return http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $t',
        },
        body: jsonEncode(body),
      );
    }

    var response = await perform(token ?? "");

    if (response.statusCode == 401 || response.statusCode == 403) {
      final newToken = await authService.refreshAccessToken();
      if (newToken != null) {
        response = await perform(newToken);
      }
    }
    return response;
  }

  Future<http.Response> delete(String endpoint) async {
    String? token = authService.accessToken;

    Future<http.Response> perform(String t) {
      return http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $t',
        },
      );
    }

    var response = await perform(token ?? "");

    if (response.statusCode == 401 || response.statusCode == 403) {
      final newToken = await authService.refreshAccessToken();
      if (newToken != null) {
        response = await perform(newToken);
      }
    }
    return response;
  }

  Future<http.Response> multipartRequest(
    String method,
    String endpoint, {
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    String? token = authService.accessToken;

    Future<http.Response> perform(String t) async {
      var request = http.MultipartRequest(
        method,
        Uri.parse('$baseUrl$endpoint'),
      );
      request.headers['Authorization'] = 'Bearer $t';
      if (fields != null) request.fields.addAll(fields);
      if (files != null) request.files.addAll(files);
      return http.Response.fromStream(await request.send());
    }

    var streamedResponse = await perform(token ?? "");

    if (streamedResponse.statusCode == 401 ||
        streamedResponse.statusCode == 403) {
      final newToken = await authService.refreshAccessToken();
      if (newToken != null) {
        streamedResponse = await perform(newToken);
      }
    }
    return streamedResponse;
  }

  Future<http.Response> multipartRequestWithProgress(
    String method,
    String endpoint,
    File file,
    Map<String, String> fields,
    void Function(int sentBytes, int totalBytes) onProgress,
  ) async {
    String? token = authService.accessToken;
    final totalBytes = await file.length();

    Future<http.Response> perform(String t) async {
      var sent = 0;

      final stream = http.ByteStream(
        file.openRead().transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              sent += data.length;
              onProgress(sent, totalBytes);
              sink.add(data);
            },
          ),
        ),
      );

      var request = http.MultipartRequest(
        method,
        Uri.parse('$baseUrl$endpoint'),
      );
      request.headers['Authorization'] = 'Bearer $t';
      request.fields.addAll(fields);

      request.files.add(
        http.MultipartFile(
          'file',
          stream,
          totalBytes,
          filename: file.path.split(Platform.pathSeparator).last,
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return response;
    }

    var streamedResponse = await perform(token ?? "");

    if (streamedResponse.statusCode == 401 ||
        streamedResponse.statusCode == 403) {
      final newToken = await authService.refreshAccessToken();
      if (newToken != null) {
        streamedResponse = await perform(newToken);
      }
    }
    return streamedResponse;
  }
}
