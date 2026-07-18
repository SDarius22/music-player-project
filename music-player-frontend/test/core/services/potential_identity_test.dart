import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/services/potential_identity.dart';

void main() {
  test('normalizes harmless metadata differences', () {
    final first = PotentialIdentity.create(
      title: '  Get   Lucky! ',
      artist: 'DAFT PUNK',
      durationInSeconds: 248,
    );
    final second = PotentialIdentity.create(
      title: 'get lucky',
      artist: 'daft punk',
      durationInSeconds: 249,
    );

    expect(first, second);
  });

  test('does not group materially different durations', () {
    final studio = PotentialIdentity.create(
      title: 'Song',
      artist: 'Artist',
      durationInSeconds: 180,
    );
    final live = PotentialIdentity.create(
      title: 'Song',
      artist: 'Artist',
      durationInSeconds: 240,
    );

    expect(studio, isNot(live));
  });
}
