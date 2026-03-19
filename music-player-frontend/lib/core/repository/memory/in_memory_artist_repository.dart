import 'dart:async';

import 'package:music_player_frontend/core/entities/artist.dart';
import 'package:music_player_frontend/core/repository/interfaces/artist_repository.dart';

class InMemoryArtistRepository implements ArtistRepository {
  final Map<int, Artist> _byId = {};
  int _nextId = 1;

  final StreamController<List<Artist>> _controller =
      StreamController<List<Artist>>.broadcast();

  void _emit() => _controller.add(getAllArtists());

  @override
  Stream watchArtists() {
    return _controller.stream.transform(
      StreamTransformer.fromHandlers(
        handleData: (artists, sink) {
          sink.add(artists);
        },
        handleDone: (sink) {
          sink.close();
        },
      ),
    );
  }

  @override
  Map<String, dynamic> get sortFields => const {'Name': null};

  @override
  Artist saveArtist(Artist artist) {
    if (artist.id == 0) {
      artist.id = _nextId++;
    }
    _byId[artist.id] = artist;
    _emit();
    return artist;
  }

  @override
  Artist? getArtist(int artistId) => _byId[artistId];

  @override
  Artist? getArtistByName(String artistName) {
    for (final a in _byId.values) {
      if (a.name == artistName) return a;
    }
    return null;
  }

  @override
  Artist? getArtistByServerId(int serverId) {
    for (final a in _byId.values) {
      if (a.serverId == serverId) return a;
    }
    return null;
  }

  @override
  List<Artist> getArtists(String query, String sortField, bool ascending) {
    final q = query.toLowerCase();
    final list =
        _byId.values.where((a) => a.name.toLowerCase().contains(q)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    if (!ascending) list.reversed;
    return list;
  }

  @override
  List<Artist> getArtistsPaged(
    String query,
    String sortField,
    bool ascending,
    int offset,
    int limit,
  ) {
    final all = getArtists(query, sortField, ascending);
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + limit).clamp(0, all.length));
  }

  @override
  List<Artist> getAllArtists() {
    final list = _byId.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  void updateArtist(Artist artist) {
    _byId[artist.id] = artist;
    _emit();
  }
}
