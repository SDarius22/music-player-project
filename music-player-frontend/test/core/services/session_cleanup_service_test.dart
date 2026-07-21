import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/app_settings.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/audio_settings.dart';
import 'package:music_player_frontend/core/entities/chunk_stat.dart';
import 'package:music_player_frontend/core/entities/local_track.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/repository/interfaces/settings_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_album_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_artist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_chunk_cache_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_chunk_stat_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_local_track_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_playlist_repository.dart';
import 'package:music_player_frontend/core/repository/memory/in_memory_song_repository.dart';
import 'package:music_player_frontend/core/services/session_cleanup_service.dart';

class _MemorySettingsRepository implements SettingsRepository {
  AppSettings? appSettings;
  AudioSettings? audioSettings;

  @override
  AppSettings getAppSettings() => appSettings ??= AppSettings();

  @override
  AudioSettings getAudioSettings() => audioSettings ??= AudioSettings();

  @override
  AppSettings saveAppSettings(AppSettings settings) => appSettings = settings;

  @override
  AudioSettings saveAudioSettings(AudioSettings settings) =>
      audioSettings = settings;

  @override
  void clearAll() {
    appSettings = null;
    audioSettings = null;
  }
}

void main() {
  test('logout cleanup resets playback and every repository', () async {
    final albums = InMemoryAlbumRepository();
    final artists = InMemoryArtistRepository();
    final songs = InMemorySongRepository();
    final playlists = InMemoryPlaylistRepository();
    final localTracks = InMemoryLocalTrackRepository();
    final chunks = InMemoryChunkCacheRepository();
    final stats = InMemoryChunkStatRepository();
    final settings = _MemorySettingsRepository();
    var playbackReset = false;
    var backgroundStopped = false;
    var selectionReset = false;

    artists.saveArtist(Artist('artist', 'Artist'));
    albums.saveAlbum(Album('album', 'Album'));
    songs.saveSong(Song('song'));
    playlists.savePlaylist(Playlist('Playlist'));
    localTracks.save(
      LocalTrack(
        sourceKey: 'source',
        sourceUri: '/music/song.flac',
        potentialIdentityKey: 'identity',
      ),
    );
    await chunks.configureSong('hash', 1, 1, 1);
    stats.saveStat(ChunkStat(songFileHash: 'song', songName: 'Song'));
    settings.saveAppSettings(AppSettings()..firstTime = false);
    settings.saveAudioSettings(AudioSettings()..sliderInSeconds = 42);

    final service = SessionCleanupService(
      resetPlayback: () async {
        playbackReset = true;
      },
      stopBackgroundWork: () async {
        backgroundStopped = true;
      },
      resetSelection: () {
        selectionReset = true;
      },
      albumRepository: albums,
      artistRepository: artists,
      songRepository: songs,
      playlistRepository: playlists,
      localTrackRepository: localTracks,
      chunkCacheRepository: chunks,
      chunkStatRepository: stats,
      settingsRepository: settings,
    );

    await service.clear();

    expect(playbackReset, isTrue);
    expect(backgroundStopped, isTrue);
    expect(selectionReset, isTrue);
    expect(albums.getAlbumCount('', false), 0);
    expect(artists.getArtistCount('', false), 0);
    expect(songs.getAllSongs(), isEmpty);
    expect(playlists.getAllPlaylists(), isEmpty);
    expect(localTracks.getAll(), isEmpty);
    expect(await chunks.getCachedFileHashes(), isEmpty);
    expect(stats.getAllStats(), isEmpty);
    expect(settings.appSettings, isNull);
    expect(settings.audioSettings, isNull);
  });

  test('cleanup attempts every source and reports partial failures', () async {
    final playlists =
        InMemoryPlaylistRepository()
          ..savePlaylist(Playlist('Still must be cleared'));
    final settings =
        _MemorySettingsRepository()
          ..saveAppSettings(AppSettings()..firstTime = false);

    final service = SessionCleanupService(
      resetPlayback: () async => throw StateError('player failed'),
      stopBackgroundWork: () async {},
      resetSelection: () {},
      albumRepository: InMemoryAlbumRepository(),
      artistRepository: InMemoryArtistRepository(),
      songRepository: InMemorySongRepository(),
      playlistRepository: playlists,
      localTrackRepository: InMemoryLocalTrackRepository(),
      chunkCacheRepository: InMemoryChunkCacheRepository(),
      chunkStatRepository: InMemoryChunkStatRepository(),
      settingsRepository: settings,
    );

    await expectLater(service.clear(), throwsStateError);
    expect(playlists.getAllPlaylists(), isEmpty);
    expect(settings.appSettings, isNull);
  });
}
