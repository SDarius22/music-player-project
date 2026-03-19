class PageResult {
  final List<dynamic> content;
  final int totalPages;
  final int page;

  const PageResult({
    required this.content,
    required this.totalPages,
    required this.page,
  });
}

abstract class QueryableProvider {
  Map<String, dynamic> get sortFields;

  Future<PageResult> fetchPage(
    String query,
    String sortField,
    bool ascending,
    int page,
    int size,
  );

  Future<void> refresh();
}
