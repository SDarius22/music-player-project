import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/providers/audio_provider.dart';
import 'package:music_player_frontend/core/providers/song_provider.dart';
import 'package:music_player_frontend/core/services/cover_service.dart';
import 'package:music_player_frontend/core/ui/components/tabs/queue_tab.dart';
import 'package:music_player_frontend/core/ui/components/widgets/search_header.dart';
import 'package:music_player_frontend/core/ui/screens/tracks.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

import 'player_controls_queue_widget_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<AudioProvider>(),
  MockSpec<SongProvider>(),
  MockSpec<AbstractAppStateProvider>(),
])
class _FakeCoverService extends Fake implements CoverService {
  @override
  Widget getWidget(
    BaseEntity entity, {
    ValueChanged<Uint8List>? onBytesLoaded,
  }) => Container(color: Colors.black);
}

Widget _wrapWithProviders({
  required Widget child,
  required AudioProvider audioProvider,
  required SongProvider songProvider,
  required CoverService coverService,
  required AbstractAppStateProvider appStateProvider,
}) {
  return MultiProvider(
    providers: [
      Provider<AudioProvider>.value(value: audioProvider),
      Provider<SongProvider>.value(value: songProvider),
      Provider<CoverService>.value(value: coverService),
      Provider<AbstractAppStateProvider>.value(value: appStateProvider),
    ],
    child: MaterialApp(home: Scaffold(body: SizedBox.expand(child: child))),
  );
}

void main() {
  Provider.debugCheckInvalidValueType = null;

  group('UI controls and queue interactions', () {
    late MockAudioProvider audioProvider;
    late MockSongProvider songProvider;
    late _FakeCoverService coverService;
    late MockAbstractAppStateProvider appStateProvider;
    late ValueNotifier<bool> playingNotifier;
    late ValueNotifier<bool> localOnlyNotifier;
    late Song songA;
    late Song songB;
    Song? currentSong;

    setUp(() {
      audioProvider = MockAudioProvider();
      songProvider = MockSongProvider();
      coverService = _FakeCoverService();
      appStateProvider = MockAbstractAppStateProvider();
      playingNotifier = ValueNotifier<bool>(false);
      localOnlyNotifier = ValueNotifier<bool>(false);

      songA = Song('song-a')..name = 'Song A';
      songB = Song('song-b')..name = 'Song B';
      currentSong = songA;

      when(audioProvider.playingNotifier).thenReturn(playingNotifier);
      when(audioProvider.normalQueue).thenReturn([songA, songB]);
      when(audioProvider.currentSong).thenAnswer((_) => currentSong);
      when(audioProvider.setCurrentSongAndPlay(songA)).thenAnswer((_) async {});
      when(audioProvider.setCurrentSongAndPlay(songB)).thenAnswer((_) async {});
      when(audioProvider.removeFromQueue(songA)).thenAnswer((_) async {});
      when(audioProvider.removeFromQueue(songB)).thenAnswer((_) async {});
      when(songProvider.enrichSong(songA)).thenAnswer((_) async => songA);
      when(songProvider.enrichSong(songB)).thenAnswer((_) async => songB);
      when(
        appStateProvider.shouldDisplayLocalOnly,
      ).thenReturn(localOnlyNotifier);
    });

    testWidgets('tracks main action shows play/pause based on provider state', (
      tester,
    ) async {
      final widget = Builder(
        builder: (context) {
          return Tracks(provider: songProvider).buildMainAction(songA, context);
        },
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          child: widget,
          audioProvider: audioProvider,
          songProvider: songProvider,
          coverService: coverService,
          appStateProvider: appStateProvider,
        ),
      );

      expect(find.byIcon(FluentIcons.play), findsOneWidget);
      expect(find.byIcon(FluentIcons.pause), findsNothing);

      playingNotifier.value = true;
      await tester.pump();

      expect(find.byIcon(FluentIcons.pause), findsOneWidget);
      expect(find.byIcon(FluentIcons.play), findsNothing);
    });

    testWidgets('search header play all button invokes callback', (
      tester,
    ) async {
      var playTapped = 0;

      await tester.pumpWidget(
        _wrapWithProviders(
          child: SearchHeader(
            title: 'Tracks',
            sortFields: const {'Title': null},
            initialSortField: 'Title',
            initialAscending: true,
            initialLocalOnly: false,
            onQuery: (_) {},
            onSortField: (_) {},
            onAscending: (_) {},
            onLocalOnly: (_) {},
            clickedPlayAll: () {
              playTapped++;
            },
          ),
          audioProvider: audioProvider,
          songProvider: songProvider,
          coverService: coverService,
          appStateProvider: appStateProvider,
        ),
      );

      await tester.tap(find.byTooltip('Play All'));
      await tester.pump();

      expect(playTapped, 1);
    });

    testWidgets('queue tab tap plays selected item and dropdown removes item', (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _wrapWithProviders(
          child: QueueTab(itemScrollController: scrollController),
          audioProvider: audioProvider,
          songProvider: songProvider,
          coverService: coverService,
          appStateProvider: appStateProvider,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Song A').first);
      await tester.pumpAndSettle();

      verify(audioProvider.setCurrentSongAndPlay(songA)).called(1);

      await tester.tap(find.byIcon(FluentIcons.moreVertical).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from queue').first);
      await tester.pumpAndSettle();

      verify(audioProvider.removeFromQueue(songA)).called(1);
    });

    testWidgets('queue tab renders enriched song metadata for placeholders', (
      tester,
    ) async {
      final placeholder = Song('queued-placeholder');
      final hydrated =
          Song('queued-placeholder')
            ..name = 'Hydrated Queue Song'
            ..fullyLoaded = true;

      when(audioProvider.normalQueue).thenReturn([placeholder]);
      when(audioProvider.currentSong).thenReturn(null);
      when(
        songProvider.enrichSong(placeholder),
      ).thenAnswer((_) async => hydrated);
      when(audioProvider.setCurrentSongAndPlay(any)).thenAnswer((_) async {});

      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        _wrapWithProviders(
          child: QueueTab(itemScrollController: scrollController),
          audioProvider: audioProvider,
          songProvider: songProvider,
          coverService: coverService,
          appStateProvider: appStateProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hydrated Queue Song'), findsOneWidget);
      expect(find.text('Unknown Song'), findsNothing);

      await tester.tap(find.text('Hydrated Queue Song'));
      await tester.pumpAndSettle();

      final played =
          verify(
                audioProvider.setCurrentSongAndPlay(captureAny),
              ).captured.single
              as Song;
      expect(identical(played, hydrated), isTrue);
    });
  });
}
