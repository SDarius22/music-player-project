import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/rest_clients/cover_rest_client.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/abstract/file_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/core/ui/components/widgets/cached_cover_image.dart';
import 'package:fluenticons/fluenticons.dart';

class CoverService {
  final AlbumService albumService;
  final SongService songService;
  final ArtistService artistService;
  final PlaylistService playlistService;
  final AbstractFileService _fileService;

  final CoverRestClient _coverRestService;
  final AuthService _authService;

  CoverService({
    required this.albumService,
    required this.songService,
    required this.artistService,
    required this.playlistService,
    required AbstractFileService fileService,
    required CoverRestClient coverRestService,
    required AuthService authService,
  }) : _fileService = fileService,
       _coverRestService = coverRestService,
       _authService = authService;

  Widget getWidget(
    BaseEntity entity, {
    ValueChanged<Uint8List>? onBytesLoaded,
  }) {
    if (entity is Playlist &&
        entity.name == 'Create New Playlist' &&
        entity.indestructible) {
      return Image.asset('assets/create_playlist.png', fit: BoxFit.cover);
    }

    final localBytes = entity.getCoverArt();
    if (localBytes != null && localBytes.isNotEmpty) {
      onBytesLoaded?.call(localBytes);
      return Image.memory(localBytes, fit: BoxFit.cover);
    }

    final relativeUrl = _imageUrlFor(entity);
    final localPath = _localCoverPath(entity);
    if (relativeUrl.isEmpty && localPath == null) {
      return _placeholder();
    }

    final persist = _persistCallback(entity);
    final bytesLoaded =
        persist == null && onBytesLoaded == null
            ? null
            : (Uint8List bytes) {
              persist?.call(bytes);
              onBytesLoaded?.call(bytes);
            };

    return CachedCoverImage(
      imageUrl:
          relativeUrl.isEmpty ? '' : '${_coverRestService.baseUrl}$relativeUrl',
      cacheKey: _cacheKeyFor(entity),
      headers: {'Authorization': 'Bearer ${_authService.accessToken ?? ""}'},
      onBytesLoaded: bytesLoaded,
      localImageLoader: _fileService.getImage,
      path: localPath,
    );
  }

  String _imageUrlFor(BaseEntity entity) {
    if (entity is Album) {
      if (entity.remoteSourceHashes.isNotEmpty) {
        return '/albums/${entity.remoteSourceHashes.first}/cover';
      }
      return entity.hash.startsWith('local-album:') ? '' : entity.getImageUrl();
    }
    if (entity is Artist) {
      if (entity.remoteSourceHashes.isNotEmpty) {
        return '/artists/${entity.remoteSourceHashes.first}/cover';
      }
      return entity.hash.startsWith('local-artist:')
          ? ''
          : entity.getImageUrl();
    }
    return entity.getImageUrl();
  }

  String? _localCoverPath(BaseEntity entity) {
    if (entity is Song) return entity.hasLocalFile ? entity.path : null;
    final songs = switch (entity) {
      Album album => album.songs,
      Artist artist => artist.songs,
      _ => const <Song>[],
    };
    for (final song in songs) {
      if (song.hasLocalFile) return song.path;
    }
    return null;
  }

  void Function(Uint8List)? _persistCallback(BaseEntity entity) {
    if (entity is Album) {
      if (entity.id == 0) return null;
      return (bytes) {
        if (entity.imageBytes == null || entity.imageBytes!.isEmpty) {
          entity.imageBytes = bytes;
          albumService.updateAlbum(entity);
        }
      };
    }

    if (entity is Artist) {
      if (entity.id == 0) return null;
      return (bytes) {
        if (entity.imageBytes == null || entity.imageBytes!.isEmpty) {
          entity.imageBytes = bytes;
          artistService.updateArtist(entity);
        }
      };
    }

    if (entity is Song) {
      final album = entity.album.target;
      if (album != null && album.id != 0) {
        return (bytes) {
          if (album.imageBytes == null || album.imageBytes!.isEmpty) {
            album.imageBytes = bytes;
            albumService.updateAlbum(album);
          }
        };
      }
      return null;
    }

    return null;
  }

  String? _cacheKeyFor(BaseEntity entity) {
    final album = switch (entity) {
      Song song => song.album.target,
      Album album => album,
      _ => null,
    };
    final albumName = album?.name.trim();
    if (albumName != null &&
        albumName.isNotEmpty &&
        albumName.toLowerCase() != 'unknown album') {
      return 'album:${albumName.toLowerCase()}';
    }
    if (entity is Artist) {
      return 'artist:${entity.name.trim().toLowerCase()}';
    }
    return null;
  }

  Widget _placeholder() {
    return Container(
      color: Colors.black,
      child: Icon(
        FluentIcons.music,
        color: Colors.white.withValues(alpha: 0.25),
        size: 64,
      ),
    );
  }
}
