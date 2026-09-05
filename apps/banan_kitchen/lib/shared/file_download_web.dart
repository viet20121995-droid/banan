import 'dart:html' as html;
import 'dart:typed_data';

/// Web: a PDF opens in a new tab (the browser's viewer prints it); other
/// types download through a hidden anchor. If the popup is blocked the
/// PDF falls back to a download as well.
Future<void> openOrSaveFile(
  Uint8List bytes,
  String filename,
  String mime,
) async {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  if (mime == 'application/pdf') {
    html.window.open(url, '_blank');
    // Give the tab time to load before the URL is revoked.
    Future<void>.delayed(
      const Duration(minutes: 1),
      () => html.Url.revokeObjectUrl(url),
    );
    return;
  }
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
