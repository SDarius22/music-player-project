import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';

abstract class DetailedEntity {
  List<BaseEntity> getDisplayableDetails();
}
