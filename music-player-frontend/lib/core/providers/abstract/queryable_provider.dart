import 'package:music_player_frontend/core/entities/abstract/base_entity.dart';

abstract class QueryableProvider {
  Map<String, dynamic> get sortFields;

  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    bool localOnly,
    int page,
    int size,
  );

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
