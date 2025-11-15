abstract class QueryableProvider {
  void setFlag(bool value);

  bool getFlag();

  void setSortField(String field);

  String getSortField();

  void setQuery(String query);

  Future get query;

  Map<String, dynamic> get sortFields;
}
