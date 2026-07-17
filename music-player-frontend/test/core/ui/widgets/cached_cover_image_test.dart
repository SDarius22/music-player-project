import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_player_frontend/core/ui/components/widgets/cached_cover_image.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  testWidgets('empty URL renders the music placeholder', (tester) async {
    await tester.pumpWidget(_host(const CachedCoverImage(imageUrl: '')));
    await tester.pump();
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('loads local bytes through the injected callback', (
    tester,
  ) async {
    var loaded = Uint8List(0);
    await tester.pumpWidget(
      _host(
        CachedCoverImage(
          imageUrl: 'local-key',
          path: '/music/cover.jpg',
          localImageLoader: (_) async => _png,
          onBytesLoaded: (bytes) => loaded = bytes,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(loaded, _png);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('downloads and reports network image bytes', (tester) async {
    await http.runWithClient(
      () async {
        var loaded = Uint8List(0);
        await tester.pumpWidget(
          _host(
            CachedCoverImage(
              imageUrl: 'http://test/playlists/1/cover',
              headers: const {'X-Test': 'yes'},
              onBytesLoaded: (bytes) => loaded = bytes,
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        expect(loaded, _png);
        expect(find.byType(Image), findsOneWidget);
      },
      () => MockClient((request) async {
        expect(request.headers['X-Test'], 'yes');
        return http.Response.bytes(_png, 200);
      }),
    );
  });

  testWidgets('failed local and network loads show the placeholder', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        _host(
          CachedCoverImage(
            imageUrl: 'http://test/missing',
            path: '/missing',
            localImageLoader: (_) async => null,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.byType(Icon), findsOneWidget);
    }, () => MockClient((_) async => http.Response('', 404)));
  });
}
