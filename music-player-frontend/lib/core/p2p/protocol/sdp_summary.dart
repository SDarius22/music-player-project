final class SdpSummary {
  SdpSummary.fromSdp({required this.type, required String sdp})
    : length = sdp.length,
      mediaSections =
          RegExp(r'(^|\r\n)m=', multiLine: true).allMatches(sdp).length,
      hasDataChannel =
          sdp.contains('sctp-port') || sdp.contains('webrtc-datachannel'),
      hasIceUfrag = sdp.contains('a=ice-ufrag:'),
      hasFingerprint = sdp.contains('a=fingerprint:');

  final String type;
  final int length;
  final int mediaSections;
  final bool hasDataChannel;
  final bool hasIceUfrag;
  final bool hasFingerprint;

  @override
  String toString() =>
      'type=$type len=$length m=$mediaSections '
      'data=$hasDataChannel ufrag=$hasIceUfrag fp=$hasFingerprint';
}
