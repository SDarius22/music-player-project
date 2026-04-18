import 'package:music_player_frontend/core/rest_clients/abstract_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';

class HealthRestClient extends AbstractRestClient {
  HealthRestClient({
    required String baseUrl,
    required AuthService authService,
  }) {
    super.baseUrl = baseUrl;
    super.authService = authService;
  }

  Future<bool> checkHealth() async {
    try {
      final response = await get("/health");
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
