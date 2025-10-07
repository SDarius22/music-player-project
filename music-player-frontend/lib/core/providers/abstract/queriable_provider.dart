abstract class QueriableProvider<T> {
  void setFlag(bool value);

  bool getFlag();

  void setSortField(String field);

  String getSortField();

  void setQuery(String query);
}
