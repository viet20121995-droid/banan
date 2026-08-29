import 'dart:typed_data';

/// Non-web stub — downloads/printing only exist in the browser build.
void saveBytesAsFile(Uint8List bytes, String filename, String mimeType) {}

void printHtml(String html, String title) {}

void writeSessionValue(String key, String value) {}

String? readSessionValue(String key) => null;

void removeSessionValue(String key) {}

void writeLocalValue(String key, String value) {}

String? readLocalValue(String key) => null;

void openExternalUrl(String url) {}
