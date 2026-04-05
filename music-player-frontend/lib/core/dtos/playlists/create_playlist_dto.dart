class CreatePlaylistDto {
  final String name;
  final List<String> songFileHashes;
  final String coverImageBase64;

  CreatePlaylistDto({
    required this.name,
    required this.songFileHashes,
    required this.coverImageBase64,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'songFileHashes': songFileHashes,
      'coverImage': coverImageBase64,
    };
  }
}
