class PlaylistSongPositionDto {
  final String songFileHash;
  final int position;

  PlaylistSongPositionDto({required this.songFileHash, required this.position});

  Map<String, dynamic> toJson() {
    return {'songFileHash': songFileHash, 'position': position};
  }
}
