import 'dart:convert';

final class SignalingPayloadParser {
  const SignalingPayloadParser._();

  static Map<String, dynamic>? normalizePayload(dynamic payload) {
    if (payload is! Map) return null;
    return payload.map((k, v) => MapEntry(k.toString(), v));
  }

  static Map<String, Set<int>> normalizePeerBufferMap(dynamic payload) {
    final map = _asStringMap(payload);
    if (map == null) return const {};

    final result = <String, Set<int>>{};
    for (final entry in map.entries) {
      final chunks = _normalizeChunkIndexSet(entry.value);
      if (chunks.isNotEmpty) {
        result[entry.key] = chunks;
      }
    }
    return result;
  }

  static String? nonEmptyString(dynamic value) {
    if (value is! String) return null;
    final s = value.trim();
    return s.isEmpty ? null : s;
  }

  static ({String sdp, String type, String? offerId})? parseSdpPayload(
    dynamic payload,
  ) {
    final map = _asStringMap(payload);
    if (map == null) return null;

    final sdp = _canonicalizeSdp(map['sdp']);
    final type = nonEmptyString(map['type'])?.toLowerCase();
    if (sdp == null || type == null) return null;

    const valid = {'offer', 'answer', 'pranswer', 'rollback'};
    if (!valid.contains(type) || !sdp.startsWith('v=')) return null;

    return (sdp: sdp, type: type, offerId: nonEmptyString(map['offerId']));
  }

  static Set<int> _normalizeChunkIndexSet(dynamic value) {
    if (value is String) {
      try {
        return _normalizeChunkIndexSet(jsonDecode(value));
      } catch (_) {
        return const {};
      }
    }

    if (value is! Iterable) return const {};

    final chunks = <int>{};
    for (final raw in value) {
      final chunk = switch (raw) {
        int value => value,
        num value => value.toInt(),
        String value => int.tryParse(value),
        _ => null,
      };
      if (chunk != null && chunk >= 0) {
        chunks.add(chunk);
      }
    }
    return chunks;
  }

  static Map<String, dynamic>? _asStringMap(dynamic payload) {
    if (payload is Map) {
      return payload.map((k, v) => MapEntry(k.toString(), v));
    }
    final s = nonEmptyString(payload);
    if (s == null) return null;
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  static String? _canonicalizeSdp(dynamic value) {
    var sdp = nonEmptyString(value);
    if (sdp == null) return null;

    if (sdp.startsWith('"') && sdp.endsWith('"') && sdp.length >= 2) {
      sdp = sdp.substring(1, sdp.length - 1);
    }

    sdp =
        sdp
            .replaceAll(r'\r\n', '\n')
            .replaceAll(r'\n', '\n')
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .replaceAll('\u0000', '')
            .trim();

    if (sdp.isEmpty) return null;

    final lines =
        sdp
            .split('\n')
            .map((line) => line.trimRight())
            .where((line) => line.isNotEmpty)
            .toList();
    return lines.isEmpty ? null : '${lines.join('\r\n')}\r\n';
  }
}
