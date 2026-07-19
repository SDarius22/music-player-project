import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/features/library/presentation/providers/queryable_provider.dart';

class EntitySongOrder {
  // The server clamps song pages to 200. Keeping the client at the same size
  // prevents repository offsets from skipping songs between remote pages.
  static const int _pageSize = 200;
  static const int _maxPages = 10000;

  static Future<List<Song>> load(
    BaseEntity entity,
    QueryableProvider provider,
  ) async {
    if (entity is Song) return [entity];

    final sourceHashes = <String>{
      entity.getHash(),
      if (entity is Album) ...entity.remoteSourceHashes,
      if (entity is Artist) ...entity.remoteSourceHashes,
    };
    final songs = <Song>[];
    for (final sourceHash in sourceHashes) {
      var page = 0;
      var totalPages = 1;
      do {
        final result = await provider.getSongsPage(
          sourceHash,
          page: page,
          size: _pageSize,
        );
        songs.addAll(result.content);
        totalPages = result.totalPages.clamp(1, _maxPages);
        page++;
      } while (page < totalPages && page < _maxPages);
    }

    final unique = <String, Song>{};
    for (final song in songs) {
      unique.putIfAbsent(song.getHash(), () => song);
    }
    final ordered = unique.values.toList();
    if (entity is Album) {
      ordered.sort(_compareAlbumTrackOrder);
    } else if (entity is Artist) {
      ordered.sort(_compareArtistTrackOrder);
    } else if (entity is Playlist) {
      final positions = <String, int>{
        for (var index = 0; index < entity.songFileHashes.length; index++)
          entity.songFileHashes[index]: index,
      };
      ordered.sort(
        (a, b) => (positions[a.getHash()] ?? _maxPages).compareTo(
          positions[b.getHash()] ?? _maxPages,
        ),
      );
    }
    return ordered;
  }

  static int _compareAlbumTrackOrder(Song a, Song b) {
    final disc = _number(a.discNumber).compareTo(_number(b.discNumber));
    if (disc != 0) return disc;
    final track = _number(a.trackNumber).compareTo(_number(b.trackNumber));
    if (track != 0) return track;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static int _compareArtistTrackOrder(Song a, Song b) {
    final albumYear = _number(a.year).compareTo(_number(b.year));
    if (albumYear != 0) return albumYear;
    final album = (a.album.target?.name ?? '').toLowerCase().compareTo(
      (b.album.target?.name ?? '').toLowerCase(),
    );
    if (album != 0) return album;
    return _compareAlbumTrackOrder(a, b);
  }

  static int _number(int value) => value > 0 ? value : 1 << 30;
}
