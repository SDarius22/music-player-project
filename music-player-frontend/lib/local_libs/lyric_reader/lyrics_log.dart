import 'dart:developer';

///debugPrint log control
class LyricsLog {
  ///debugPrint switch
  static var lyricEnableLog = false;

  static const _defaultTag = "LyricReader->";

  static logD(Object? obj) {
    _log(_defaultTag, obj);
  }

  static logW(Object? obj) {
    _log("$_defaultTag♦️WARN♦️->", obj);
  }

  static _log(String tag, Object? obj) {
    if (lyricEnableLog) log(tag + obj.toString());
  }
}
