// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

void exportCsv(String filename, List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return;
  final keys = rows.first.keys.toList();
  String escape(dynamic v) {
    final s = v == null ? '' : v.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  final lines = <String>[
    keys.map(escape).join(','),
    for (final row in rows) keys.map((key) => escape(row[key])).join(','),
  ];
  final bytes = utf8.encode(lines.join('\n'));
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();

  html.Url.revokeObjectUrl(url);
}
