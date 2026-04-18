import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/rest_clients/health_rest_client.dart';

class HealthService {
  final HealthRestClient healthRestClient;

  final ValueNotifier<bool> isHealthy = ValueNotifier(true);

  Timer? _timer;
  bool _checking = false;
  bool _disposed = false;

  HealthService(this.healthRestClient) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _runHealthCheck();

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _runHealthCheck();
    });
  }

  Future<void> _runHealthCheck() async {
    if (_checking || _disposed) return;
    _checking = true;

    try {
      final healthy = await healthRestClient.checkHealth();
      if (!_disposed && isHealthy.value != healthy) {
        isHealthy.value = healthy;
      }
    } finally {
      _checking = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    isHealthy.dispose();
  }
}
