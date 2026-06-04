import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation: wrap the buffer in a Blob and trigger a download
/// via a hidden anchor click. Same trick every "Export CSV" button on
/// the web uses. MIME is derived from the filename extension; pass
/// [mimeOverride] only if you need to force a specific type.
Future<void> saveXlsx(
  Uint8List bytes,
  String filename, {
  String? mimeOverride,
}) async {
  final mime = mimeOverride ?? _mimeFor(filename);
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

String _mimeFor(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.csv')) return 'text/csv;charset=utf-8';
  if (lower.endsWith('.json')) return 'application/json';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
}
