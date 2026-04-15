import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class CoverRestClient extends AbstractRestClient {
  static final _logger = Logger('CoverRestClient');

  CoverRestClient({required String baseUrl, required AuthService authService}) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  Future<Uint8List?> fetchCoverBytes(String relativeUrl) async {
    try {
      final response = await get(relativeUrl);
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (e) {
      _logger.warning('CoverRestService: failed to fetch $relativeUrl', e);
    }
    return null;
  }
}
