/// Web implementation of [triggerBrowserDownload].
///
/// Builds an in-memory `Blob` from the supplied bytes, creates a temporary
/// object URL, programmatically clicks an `<a download>` element to ask the
/// browser to save the file, and finally revokes the object URL.
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void triggerBrowserDownload({
  required Uint8List bytes,
  required String fileName,
  String mimeType = 'application/octet-stream',
}) {
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
