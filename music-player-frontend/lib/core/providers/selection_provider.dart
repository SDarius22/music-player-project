import 'package:flutter/cupertino.dart';
import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';

class SelectionProvider with ChangeNotifier {
  final Set<BaseEntity> _selectedEntities = {};

  Set<BaseEntity> get selectedEntities => _selectedEntities;

  void selectEntity(BaseEntity entity) {
    _selectedEntities.add(entity);
    notifyListeners();
  }

  void deselectEntity(BaseEntity entity) {
    _selectedEntities.remove(entity);
    notifyListeners();
  }

  void clearSelection() {
    _selectedEntities.clear();
    notifyListeners();
  }

  bool isSelected(BaseEntity entity) {
    return _selectedEntities.contains(entity);
  }
}
