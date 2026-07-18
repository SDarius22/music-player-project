import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';
import 'package:music_player_frontend/core/entities/song.dart';

abstract class QueryableProvider {
  Map<String, dynamic> get sortFields;

  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
    int page,
    int size, {
    bool streamOnly = false,
  });

  Future<PageResult<Song>> getSongsPage(
    String hash, {
    bool localOnly = false,
    int page = 0,
    int size = 10,
  });

  Future<BaseEntity?> fetchEntity(BaseEntity entity);

  Future<void> refresh();
}

class PageResult<T extends BaseEntity> {
  final List<T> content;
  final int totalPages;
  final int page;

  const PageResult({
    required this.content,
    required this.totalPages,
    required this.page,
  });
}
