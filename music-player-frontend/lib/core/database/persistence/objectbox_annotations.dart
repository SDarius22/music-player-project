/// Conditional re-export of ObjectBox annotations/types.
///
/// On non-web (dart:io) this exports `package:objectbox/objectbox.dart`.
/// On web it exports minimal stub types so entity files can compile.
export 'package:objectbox/objectbox.dart'
    if (dart.library.js_interop) 'objectbox_annotations_stub.dart'
    if (dart.library.html) 'objectbox_annotations_stub.dart';
