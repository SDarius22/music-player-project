import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';

class SelectionProvider with ChangeNotifier {
  final Set<BaseEntity> _selectedEntities = {};

  Set<BaseEntity> selectedEntities = const {};

  void refreshSelection() {
    selectedEntities = Set<BaseEntity>.unmodifiable(_selectedEntities);
    notifyListeners();
  }

  void selectEntity(BaseEntity entity) {
    _selectedEntities.add(entity);
    refreshSelection();
  }

  void deselectEntity(BaseEntity entity) {
    _selectedEntities.remove(entity);
    refreshSelection();
  }

  void clearSelection() {
    _selectedEntities.clear();
    refreshSelection();
  }

  bool isSelected(BaseEntity entity) {
    return _selectedEntities.contains(entity);
  }
}
