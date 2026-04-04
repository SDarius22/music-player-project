import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'objectbox.g.dart';

class ObjectBox {
  static late final Store store;

  static Future initialize() async {
    final docsDir = await getApplicationDocumentsDirectory();
    String dbPath = '${docsDir.path}/MusicPlayer${kDebugMode ? '_Debug' : ''}';
    final directory = Directory(dbPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    if (Store.isOpen(dbPath)) {
      store = Store.attach(getObjectBoxModel(), dbPath);
    } else {
      store = await openStore(directory: dbPath);
    }
  }
}
