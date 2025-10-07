abstract class QueryableProvider {
  void setFlag(bool value);

  bool getFlag();

  void setSortField(String field);

  String getSortField();

  void setQuery(String query);

  Map<String, dynamic> get sortFields;
}
