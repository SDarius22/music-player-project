import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/album.dart';
import 'package:music_player_frontend/core/entities/playlist.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/core/services/album_service.dart';
import 'package:music_player_frontend/core/services/artist_service.dart';
import 'package:music_player_frontend/core/services/playlist_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/auth_service.dart';
import 'package:music_player_frontend/core/services/rest_clients/cover_rest_service.dart';
import 'package:music_player_frontend/core/services/song_service.dart';
import 'package:music_player_frontend/local_libs/cached_network_image/local_cached_network_image.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';

class CoverService {
  final AlbumService albumService;
  final SongService songService;
  final ArtistService artistService;
  final PlaylistService playlistService;

  final CoverRestService _coverRestService;
  final AuthService _authService;

  CoverService({
    required this.albumService,
    required this.songService,
    required this.artistService,
    required this.playlistService,
    required CoverRestService coverRestService,
    required AuthService authService,
  }) : _coverRestService = coverRestService,
       _authService = authService;

  Widget getWidget(BaseEntity entity) {
    final localBytes = entity.coverArt;
    if (localBytes != null && localBytes.isNotEmpty) {
      return Image.memory(localBytes, fit: BoxFit.cover);
    }

    final relativeUrl = entity.imageUrl;
    if (relativeUrl == null || relativeUrl.isEmpty) {
      return _placeholder();
    }

    return LocalCachedNetworkImage(
      imageUrl: '${_coverRestService.baseUrl}$relativeUrl',
      headers: {'Authorization': 'Bearer ${_authService.accessToken ?? ""}'},
      onBytesLoaded: _persistCallback(entity),
    );
  }

  void Function(Uint8List)? _persistCallback(BaseEntity entity) {
    if (entity is Album) {
      return (bytes) {
        entity.imageBytes = bytes;
        albumService.updateAlbum(entity);
      };
    }

    if (entity is Song) {
      final album = entity.album.target;
      if (album != null) {
        return (bytes) {
          album.imageBytes = bytes;
          albumService.updateAlbum(album);
        };
      }
      return null;
    }

    if (entity is Playlist) {
      return (bytes) {
        entity.imageBytes = bytes;
        playlistService.updatePlaylist(entity);
      };
    }

    // Artist has no local imageBytes field; nothing to persist.
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
