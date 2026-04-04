class NegotiationResponseDto {
  final String fileHash;
  final List<int> missingIndices;

  NegotiationResponseDto({required this.fileHash, required this.missingIndices});

  factory NegotiationResponseDto.fromJson(Map<String, dynamic> json) {
    return NegotiationResponseDto(
      fileHash: json['fileHash'] as String,
      missingIndices: List<int>.from(json['missingIndices']),
    );
  }
}
