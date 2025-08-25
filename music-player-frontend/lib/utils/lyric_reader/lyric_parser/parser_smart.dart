import 'lyrics_parse.dart';
import 'parser_lrc.dart';
import 'parser_qrc.dart';
import '../lyrics_reader_model.dart';

///smart parser
///Parser is automatically selected
class ParserSmart extends LyricsParse {
  ParserSmart(super.lyric);

  @override
  List<LyricsLineModel> parseLines({bool isMain = true}) {
    var qrc = ParserQrc(lyric);
    if (qrc.isOK()) {
      return qrc.parseLines(isMain: isMain);
    }
    return ParserLrc(lyric).parseLines(isMain: isMain);
  }
}
