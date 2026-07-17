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

    final relativeUrl = entity.getImageUrl();
    if (relativeUrl.isEmpty) {
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
      imageUrl: '${_coverRestService.baseUrl}$relativeUrl',
      headers: {'Authorization': 'Bearer ${_authService.accessToken ?? ""}'},
      onBytesLoaded: bytesLoaded,
      localImageLoader: _fileService.getImage,
      path: (entity is Song && entity.isLocal) ? entity.path : null,
    );
  }

  void Function(Uint8List)? _persistCallback(BaseEntity entity) {
    if (entity is Album) {
      return (bytes) {
        if (entity.imageBytes == null || entity.imageBytes!.isEmpty) {
          entity.imageBytes = bytes;
          albumService.updateAlbum(entity);
        }
      };
    }

    if (entity is Artist) {
      return (bytes) {
        if (entity.imageBytes == null || entity.imageBytes!.isEmpty) {
          entity.imageBytes = bytes;
          artistService.updateArtist(entity);
        }
      };
    }

    if (entity is Song) {
      final album = entity.album.target;
      if (album != null) {
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
