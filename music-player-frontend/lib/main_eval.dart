// Headless evaluation entrypoint for the Chapter 4 experiments.
//
// It wires ONLY the chunk-delivery pipeline (auth, streaming/stats REST clients,
// WebRTC signaling + peers, ChunkService) — no UI, no just_audio/media_kit, no
// ObjectBox. "Playback" is simulated by fetching every chunk in order, paced at
// the audio bitrate, which exercises the real prefix / peer / server logic and
// emits the same chunk_stats rows and [METRIC] log lines as the GUI app.
//
// Config is read from ENVIRONMENT VARIABLES first (so you can `flutter build`
// once and launch many instances with different env), then --dart-define, then
// a default. Keys:
//   API_BASE_URL   default http://localhost:9000/api/v1
//   WS_BASE_URL    default ws://localhost:9000/ws/signaling
//   AUTH_TOKEN     (required) a valid access JWT
//   REFRESH_TOKEN  (optional) defaults to AUTH_TOKEN; only needed for long runs
//   ROLE           seeder | listener        (default listener)
//   SONG_HASHES    comma-separated file hashes (required)
//   BITRATE_BPS    bytes/sec for pacing     (default 40960 = 320 kbps)
//   SPEED          playback speed multiplier, or "max" for no pacing
//                  (default: seeder=max, listener=1.0)
//   START_DELAY_MS delay before this client starts                (default 0)
//   SEED_HOLD_SECONDS  how long a seeder stays alive serving peers (default 120)
//
// A seeder warms its cache as fast as possible, does NOT report stats (so its
// origin warming never pollutes the swarm aggregate), then holds open to serve
// peers. A listener paces at real time and reports stats normally.
//
// Run examples:
//   flutter run -d macos -t lib/main_eval.dart \
//       --dart-define=AUTH_TOKEN=<jwt> --dart-define=SONG_HASHES=<hash>
//   # or build once, then launch with env:
//   flutter build macos -t lib/main_eval.dart
//   ROLE=listener AUTH_TOKEN=<jwt> SONG_HASHES=<hash> \
//       build/macos/Build/Products/Release/*.app/Contents/MacOS/<binary>

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/logging/app_logger.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_chunk_cache_repository.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/statistics_rest_client.dart';
import 'package:music_player_frontend/core/rest_clients/streaming_rest_client.dart';
import 'package:music_player_frontend/core/services/active_router_service.dart';
import 'package:music_player_frontend/core/services/chunk_service.dart';
import 'package:music_player_frontend/core/services/chunk_stats_service.dart';
import 'package:music_player_frontend/core/services/webrtc_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final _log = Logger('eval');

// --dart-define fallbacks (compile-time consts; empty if not provided).
const _ddApi = String.fromEnvironment('API_BASE_URL');
const _ddWs = String.fromEnvironment('WS_BASE_URL');
const _ddToken = String.fromEnvironment('AUTH_TOKEN');
const _ddRefresh = String.fromEnvironment('REFRESH_TOKEN');
const _ddRole = String.fromEnvironment('ROLE');
const _ddHashes = String.fromEnvironment('SONG_HASHES');
const _ddBitrate = String.fromEnvironment('BITRATE_BPS');
const _ddSpeed = String.fromEnvironment('SPEED');
const _ddStartDelay = String.fromEnvironment('START_DELAY_MS');
const _ddSeedHold = String.fromEnvironment('SEED_HOLD_SECONDS');

/// Resolve config: environment variable → --dart-define → default.
String _cfg(String envKey, String dartDefine, String fallback) {
  final env = Platform.environment[envKey];
  if (env != null && env.isNotEmpty) return env;
  if (dartDefine.isNotEmpty) return dartDefine;
  return fallback;
}

String _randomDeviceId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Future<void> main() async {
  configureAppLogging();
  await runWithLoggingZone(() async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const _EvalStatusApp());
    final code = await _runEval();
    // give the final stats POST time to land before tearing down
    await Future<void>.delayed(const Duration(seconds: 3));
    exit(code);
  });
}

Future<int> _runEval() async {
  final api = _cfg('API_BASE_URL', _ddApi, 'http://localhost:9000/api/v1');
  final ws = _cfg('WS_BASE_URL', _ddWs, 'ws://localhost:9000/ws/signaling');
  final token = _cfg('AUTH_TOKEN', _ddToken, '');
  final refresh = _cfg('REFRESH_TOKEN', _ddRefresh, token);
  final role = _cfg('ROLE', _ddRole, 'listener').toLowerCase();
  final hashes = _cfg('SONG_HASHES', _ddHashes, '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final bitrate = int.tryParse(_cfg('BITRATE_BPS', _ddBitrate, '40960')) ?? 40960;
  final speedStr = _cfg('SPEED', _ddSpeed, role == 'seeder' ? 'max' : '1.0');
  final isMaxSpeed = speedStr.toLowerCase() == 'max';
  final speed = isMaxSpeed ? 0.0 : (double.tryParse(speedStr) ?? 1.0);
  final startDelayMs = int.tryParse(_cfg('START_DELAY_MS', _ddStartDelay, '0')) ?? 0;
  final seedHold = int.tryParse(_cfg('SEED_HOLD_SECONDS', _ddSeedHold, '120')) ?? 120;

  if (token.isEmpty) {
    _log.severe('AUTH_TOKEN is required (env var or --dart-define). Aborting.');
    return 2;
  }
  if (hashes.isEmpty) {
    _log.severe('SONG_HASHES is required (comma-separated). Aborting.');
    return 2;
  }

  final isSeeder = role == 'seeder';
  _log.info(
    '[eval] role=$role songs=${hashes.length} speed=${isMaxSpeed ? 'max' : speed} '
    'bitrate=$bitrate api=$api ws=$ws',
  );

  // --- wire the minimal pipeline -------------------------------------------
  final auth = AuthService(baseUrl: api);
  try {
    await auth.saveTokens(token, refresh); // sets in-memory token + persists
  } catch (e) {
    // Secure storage can be unavailable in an ad-hoc-signed eval build (no
    // keychain entitlement, error -34018). saveTokens sets the in-memory access
    // token before the persistence write, so REST/WebRTC still work for a run.
    _log.warning('[eval] token persistence failed (continuing in-memory): $e');
  }
  if (auth.accessToken == null) {
    _log.severe('[eval] access token not set; aborting.');
    return 2;
  }

  final streaming = StreamingRestClient(baseUrl: api, authService: auth);
  final statsClient = StatisticsRestClient(baseUrl: api, authService: auth);
  ChunkStatsService.instance.configure(statsClient); // no local repo needed

  final cache = InMemoryChunkCacheRepository();
  final router = ActiveChunkRouter(cache);
  final webrtc = WebRTCService(
    myDeviceId: _randomDeviceId(),
    authService: auth,
    connectSignaling: () => WebSocketChannel.connect(Uri.parse(ws)),
    onChunkReceived: router.routeChunk,
    onChunkRequested: router.getLocalChunk,
  );

  // let the signaling socket connect + authenticate
  await Future<void>.delayed(const Duration(seconds: 2));

  if (startDelayMs > 0) {
    _log.info('[eval] waiting START_DELAY_MS=$startDelayMs before playback');
    await Future<void>.delayed(Duration(milliseconds: startDelayMs));
  }

  // --- drive each song ------------------------------------------------------
  for (final hash in hashes) {
    final cs = ChunkService(
      fileHash: hash,
      cacheRepo: cache,
      streamingClient: streaming,
      webrtcManager: webrtc,
    );
    router.registerManager(cs);
    // Seeders pass a null reporter so their origin warming is not counted.
    cs.configureSongInfo(
      hash,
      isSeeder ? null : ChunkStatsService.instance.reportSilently,
    );

    try {
      await cs.loadManifest();
    } catch (e) {
      _log.severe('[eval] failed to load manifest for $hash: $e');
      continue;
    }
    final total = cs.totalChunks;
    if (total <= 0) {
      _log.warning('[eval] song $hash has no chunks; skipping');
      continue;
    }

    // per-chunk pacing: average chunk duration / speed (zero if max speed)
    final avgChunkBytes = cs.totalBytes / total;
    final perChunk = (isMaxSpeed || speed <= 0)
        ? Duration.zero
        : Duration(
            microseconds: ((avgChunkBytes / bitrate / speed) * 1e6).round(),
          );

    _log.info(
      '[eval] ${isSeeder ? 'warming' : 'playing'} $hash chunks=$total '
      'perChunk=${perChunk.inMilliseconds}ms',
    );
    final started = DateTime.now();
    for (var i = 0; i < total; i++) {
      try {
        await cs.getChunk(i);
      } catch (e) {
        _log.warning('[eval] chunk $i of $hash failed: $e');
      }
      if (perChunk > Duration.zero) {
        await Future<void>.delayed(perChunk);
      }
    }
    cs.flushStats();
    final secs = DateTime.now().difference(started).inMilliseconds / 1000.0;
    _log.info('[eval] finished $hash in ${secs.toStringAsFixed(1)}s');
  }

  if (isSeeder) {
    _log.info('[eval] seeder warmed; holding for ${seedHold}s to serve peers');
    await Future<void>.delayed(Duration(seconds: seedHold));
    _log.info('[eval] seeder hold elapsed; exiting');
  } else {
    _log.info('[eval] listener done; flushing stats');
  }

  webrtc.dispose();
  return 0;
}

/// Tiny on-screen status so the window (if any) shows what the process is doing.
class _EvalStatusApp extends StatelessWidget {
  const _EvalStatusApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'Headless eval runner — see terminal logs',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
