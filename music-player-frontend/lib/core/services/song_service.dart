import 'package:logging/logging.dart';
import 'package:music_player_frontend/core/dtos/songs/song_dto.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/providers/abstract/queryable_provider.dart';
import 'package:music_player_frontend/core/repository/interfaces/album_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';
import 'package:music_player_frontend/core/repository/interfaces/song_repository.dart';
import 'package:music_player_frontend/core/rest_clients/song_rest_client.dart';

class SongService {
  static final _logger = Logger('SongService');

  final SongRepository _songRepository;
  final ArtistRepository _artistRepository;
  final AlbumRepository _albumRepository;
  final SongRestClient _songRestService;

  SongService(
    this._songRepository,
    this._artistRepository,
    this._albumRepository,
    this._songRestService,
  );

  Map<String, dynamic> get sortFields => _songRepository.sortFields;

  Stream<dynamic> get watchSongs => _songRepository.watchSongs();

  Song? getLocalSong(String songHash) {
    if (songHash.isEmpty) {
      throw ArgumentError('Song hash cannot be empty');
    }

    try {
      return _songRepository.getSongByFileHash(songHash);
    } catch (_) {
      return null;
    }
  }

  Song getOrCreateSong(String fileHash) {
    if (fileHash.isEmpty) {
      throw ArgumentError('File hash cannot be empty');
    }
    return _songRepository.getOrCreateSong(fileHash);
  }

  Future<Song?> fetchSongByFileHash(String fileHash) async {
    final local = _songRepository.getSongByFileHash(fileHash);
    if (local != null) return local;
    try {
      final serverSong = await _songRestService.getServerSong(fileHash);
      cacheServerSongs([serverSong]);
      return _songRepository.getSongByFileHash(fileHash);
    } catch (e) {
      _logger.fine(
        'SongService: failed to fetch song $fileHash from server: $e',
      );
      return null;
    }
  }

  Future<List<Song>> fullyFetchSongs(List<Song> songs) async {
    List<Song> fullyFetched = [];
    for (var song in songs) {
      fullyFetched.add(await fullyFetchSong(song));
    }
    return fullyFetched;
  }

  Future<Song> fullyFetchSong(Song song) async {
    if (song.fullyLoaded) return song;
    var localSong = _songRepository.getSongByFileHash(song.getHash());
    if (localSong != null && localSong.fullyLoaded) return localSong;

    _logger.fine('Fully fetching song ${song.getHash()} from server...');
    try {
      final serverSong = await _songRestService.getServerSong(song.getHash());
      return _cacheServerSong(serverSong);
    } catch (e) {
      _logger.fine(
        'SongService: failed to fully fetch song ${song.getHash()} from server: $e',
      );
      return song;
    }
  }

  Future<void> updateSong(Song song) async {
    try {
      await _songRestService.updateSongLibraryEntry(
        song.fileHash,
        song.likedByUser,
        song.lastPlayed,
        song.playCount,
      );
    } catch (e) {
      _logger.fine(
        'SongService: failed to update song lib entry ${song.getHash()} on server: $e',
      );
    }
    _songRepository.updateSong(song);
  }

  void updateSongsBatch(List<Song> songs) {
    _songRepository.updateSongs(songs);
  }

  void deleteSong(Song song) {
    _songRepository.deleteSong(song);
  }

  Future<PageResult<Song>> getSongsPage(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
    int page,
    int pageSize,
  ) async {
    int? serverTotalPages;
    try {
      if (localOnly) {
        throw Exception('Skipping server fetch due to localOnly=true');
      }
      final serverPage = await _songRestService.getSongsPage(
        query: query,
        page: page,
        size: pageSize,
        sort: _toServerSort(sortField, ascending),
      );
      serverTotalPages = serverPage.totalPages;
      cacheServerSongs(serverPage.content);
    } catch (e) {
      _logger.fine('SongService: server fetch failed for getSongsPage: $e');
    }
    final localSongs = _songRepository.getSongsPaged(
      query,
      sortField,
      ascending,
      localOnly,
      page * pageSize,
      pageSize,
    );

    final totalPages =
        (serverTotalPages != null && serverTotalPages > 0)
            ? serverTotalPages
            : ((_songRepository.getSongCount(query, localOnly) +
                        pageSize -
                        1) ~/
                    pageSize)
                .clamp(1, 999999);

    return PageResult(content: localSongs, totalPages: totalPages, page: page);
  }

  Future<List<Song>> getRecommendations() async {
    final page = await _songRestService.getRecommendations();
    return cacheServerSongs(page.content);
  }

  Future<List<Song>> getForgottenFavourites() async {
    final page = await _songRestService.getForgottenFavourites();
    return cacheServerSongs(page.content);
  }

  Future<List<Song>> getQuickDial() async {
    final page = await _songRestService.getQuickDial();
    return cacheServerSongs(page.content);
  }

  Future<List<Song>> getFavoriteSongs() async {
    final local = _songRepository.getFavoriteSongs();
    if (local.isNotEmpty) return local;

    try {
      final serverPage = await _songRestService.getFavourites();
      return cacheServerSongs(serverPage.content);
    } catch (e) {
      _logger.fine(
        'SongService: failed to fetch favorite songs from server: $e',
      );
      return [];
    }
  }

  Future<List<Song>> getMostPlayedSongs(int limit) async {
    final local = _songRepository.getMostPlayedSongs(limit);
    if (local.isNotEmpty) return local;

    try {
      final serverPage = await _songRestService.getMostPlayed(size: limit);
      return cacheServerSongs(serverPage.content);
    } catch (e) {
      _logger.fine('SongService: failed to fetch most played from server: $e');
      return [];
    }
  }

  Future<List<Song>> getRecentlyPlayedSongs(int limit) async {
    final local = _songRepository.getRecentlyPlayedSongs(limit);
    if (local.isNotEmpty) return local;

    try {
      final serverPage = await _songRestService.getRecentlyPlayed(size: limit);
      return cacheServerSongs(serverPage.content);
    } catch (e) {
      _logger.fine(
        'SongService: failed to fetch recently played from server: $e',
      );
      return [];
    }
  }

  List<Song> cacheServerSongs(List<SongDto> serverSongs) {
    List<Song> cached = [];
    for (var serverSong in serverSongs) {
      cached.add(_cacheServerSong(serverSong));
    }
    return cached;
  }

  Song _cacheServerSong(SongDto serverSong) {
    if (serverSong.fileHash.isEmpty) {
      throw Exception('Server song must have a file hash');
    }

    var cachedSong = _songRepository.getOrCreateSong(serverSong.fileHash);
    cachedSong.name = serverSong.name;
    cachedSong.durationInSeconds = serverSong.durationInSeconds;
    cachedSong.trackNumber = serverSong.trackNumber;
    cachedSong.discNumber = serverSong.discNumber;
    cachedSong.year = serverSong.releaseYear;
    cachedSong.lastPlayed = serverSong.lastPlayed;
    cachedSong.playCount = serverSong.playCount;
    cachedSong.likedByUser = serverSong.likedByUser;
    cachedSong.fullyLoaded = true;

    var artist = _artistRepository.getOrCreateArtist(
      serverSong.artist.hash,
      serverSong.artist.name,
    );
    cachedSong.artist.target = artist;

    var album = _albumRepository.getOrCreateAlbum(
      serverSong.album.hash,
      serverSong.album.name,
      artist,
    );
    cachedSong.album.target = album;

    var finalSong = _songRepository.saveSong(cachedSong);

    artist.addSong(finalSong);
    _artistRepository.updateArtist(artist);

    album.addSong(finalSong);
    _albumRepository.updateAlbum(album);

    return finalSong;
  }

  String _toServerSort(String sortField, bool ascending) {
    final normalized = sortField.trim().toLowerCase();

    final serverField = switch (normalized) {
      'title' || 'name' => 'name',
      'year' => 'year',
      'duration' || 'durationinseconds' => 'durationInSeconds',
      'track' || 'tracknumber' => 'trackNumber',
      'disc' || 'discnumber' => 'discNumber',
      _ => 'name',
    };

    return '$serverField,${ascending ? 'asc' : 'desc'}';
  }
}
