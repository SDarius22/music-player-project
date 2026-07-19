import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/entities/song.dart';
import 'package:music_player_frontend/features/library/presentation/providers/selection_provider.dart';

void main() {
  group('SelectionProvider', () {
    test('selectEntity adds entity and notifies listeners', () {
      final provider = SelectionProvider();
      final song = Song('song-1');
      var notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      provider.selectEntity(song);

      expect(provider.isSelected(song), isTrue);
      expect(provider.selectedEntities, contains(song));
      expect(notifyCount, 1);
    });

    test('deselectEntity removes selected entity and notifies listeners', () {
      final provider = SelectionProvider();
      final song = Song('song-1');
      provider.selectEntity(song);
      var notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      provider.deselectEntity(song);

      expect(provider.isSelected(song), isFalse);
      expect(provider.selectedEntities, isNot(contains(song)));
      expect(notifyCount, 1);
    });

    test('clearSelection removes all selected entities', () {
      final provider = SelectionProvider();
      provider.selectEntity(Song('a'));
      provider.selectEntity(Song('b'));

      provider.clearSelection();

      expect(provider.selectedEntities, isEmpty);
    });
  });
}
