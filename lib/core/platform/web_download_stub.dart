/// Stub implementation of [triggerBrowserDownload] for non-web targets.
///
/// On native platforms (Android, iOS, Windows, macOS, Linux, server) the app
/// opens attachments via `OpenFilex` against the local filesystem, so this
/// helper is never invoked. The function exists only so a single
/// cross-platform import works under conditional compilation.
library;

import 'dart:typed_data';

void triggerBrowserDownload({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) {
  throw UnsupportedError(
    'triggerBrowserDownload is only available on Flutter Web.',
  );
}
