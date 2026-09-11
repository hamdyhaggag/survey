// lib/web_utils_web.dart
// Web-specific implementation using dart:html

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';

String getUrlSearch() {
  try {
    return html.window.location.search ?? '';
  } catch (_) {
    return '';
  }
}

void pushUrlState(String query) {
  try {
    html.window.history.pushState(null, '', '/$query');
  } catch (_) {}
}

void downloadCsvFile(String filename, String csvContent) {
  try {
    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  } catch (_) {}
}
