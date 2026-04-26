/// Shims for `package:path_provider/path_provider.dart` when compiling without Flutter.
/// On the server, these functions are never called because the database path
/// is resolved via environment variables or the current working directory.

import 'dart:io';

Future<Directory> getApplicationSupportDirectory() async {
  return Directory(Directory.current.path);
}

Future<Directory> getApplicationDocumentsDirectory() async {
  return Directory(Directory.current.path);
}
