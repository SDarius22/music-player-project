/// [SongModel] that contains all [Song] Information.
class SongModel {
  SongModel(this._info);

  //The type dynamic is used for both but, the map is always based in [String, dynamic]
  final Map<dynamic, dynamic> _info;

  /// Return song [id]
  int get id => _info["_id"];

  /// Return song [data]
  String get data => _info["_data"];

  /// Return song [album]
  String? get album => _info["album"];

  /// Return song [artist]
  String? get artist => _info["artist"];

  /// Return song [duration]
  int? get duration => _info["duration"];

  /// Return song [title]
  String get title => _info["title"];

  /// Return song [track]
  int? get track => _info["track"];

  String? get disc => _info["disc_number"];

  int? get year => _info["year"];

  String get fileHash => _info["file_hash"];

  /// Return a map with all [keys] and [values] from specific song.
  Map get getMap => _info;

  @override
  String toString() {
    return _info.toString();
  }
}
