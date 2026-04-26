/// Shims for `package:flutter/foundation.dart` when compiling without Flutter.
/// Used via conditional imports so `dart compile exe` works on the server.

const bool kIsWeb = false;
const bool kDebugMode = false;

void debugPrint(String? message, {int? wrapWidth}) {
  if (message != null) {
    // ignore: avoid_print
    print(message);
  }
}
