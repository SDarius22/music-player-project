class NegotiationResponseDto {
  final int songId;
  final List<int> missingIndices;

  NegotiationResponseDto({required this.songId, required this.missingIndices});

  factory NegotiationResponseDto.fromJson(Map<String, dynamic> json) {
    return NegotiationResponseDto(
      songId: json['songId'],
      missingIndices: List<int>.from(json['missingIndices']),
    );
  }
}
