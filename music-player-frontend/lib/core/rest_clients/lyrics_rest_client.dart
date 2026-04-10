import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:music_player_frontend/core/entities/song.dart';

class LyricsRestClient {
  Future<String?> fetchLyrics(Song? song) async {
    if (song == null) return null;
    var param =
        'track_name=${Uri.encodeComponent(song.name)}${song.artist.target != null ? '&artist_name=${Uri.encodeComponent(song.artist.target!.name)}' : ''}';
    try {
      final response = await http.get(
        Uri.parse('https://lrclib.net/api/search?$param'),
      );
      if (response.statusCode == 200) {
        var lyricsList = jsonDecode(response.body) as List<dynamic>;
        if (lyricsList.isNotEmpty) {
          var firstResult = lyricsList.first as Map<String, dynamic>;
          return firstResult['syncedLyrics'] as String?;
        }
      }
      throw Exception('Failed to fetch lyrics: ${response.statusCode}');
    } catch (e) {
      debugPrint('LyricsRestClient.fetchLyrics error: $e');
      return null;
    }
  }
}
