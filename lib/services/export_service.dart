import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/inspection.dart';
import '../models/job.dart';

class ExportService {
  // ── PDF Export ──────────────────────────────────────────────────────────────

  static Future<void> exportPdf(Job job, Inspection insp) async {
    final pdf = pw.Document();

    // Load photos as images
    final photoData = <_PhotoData>[];
    for (int i = 0; i < insp.photos.length; i++) {
      final p = insp.photos[i];
      pw.MemoryImage? img;
      if (!kIsWeb) {
        try {
          final bytes = await File(p.imagePath).readAsBytes();
          img = pw.MemoryImage(bytes);
        } catch (_) {}
      }
      photoData.add(_PhotoData(
        image: img,
        index: i + 1,
        category: p.category,
        caption: p.caption,
        transcription: p.transcription,
        isFlagged: p.isFlagged,
      ));
    }

    // Group photos by location tag, preserving the inspection's tag order.
    final flagged = <_PhotoData>[];
    final byCategory = <String, List<_PhotoData>>{};
    for (final p in photoData) {
      if (p.isFlagged) flagged.add(p);
      byCategory.putIfAbsent(p.category, () => []).add(p);
    }
    final orderedCats = <String>[
      ...insp.categories.where(byCategory.containsKey),
      ...byCategory.keys.where((c) => !insp.categories.contains(c)),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(job, insp),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          // Summary stats
          pw.Row(children: [
            _statBox('PHOTOS', '${insp.photos.length}'),
            pw.SizedBox(width: 8),
            _statBox('FLAGGED', '${flagged.length}',
                highlight: flagged.isNotEmpty),
            pw.SizedBox(width: 8),
            _statBox('LOCATIONS', '${orderedCats.length}'),
          ]),
          pw.SizedBox(height: 16),
          // Inspection notes
          if (insp.notes.isNotEmpty) ...[
            _sectionLabel('INSPECTION NOTES'),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(insp.notes,
                  style: pw.TextStyle(fontSize: 11, lineSpacing: 4)),
            ),
            pw.SizedBox(height: 20),
          ],
          // Flagged items first — that's what reviewers act on
          if (flagged.isNotEmpty) ...[
            pw.Text('FLAGGED — NEEDS FOLLOW-UP',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red800,
                    letterSpacing: 0.8)),
            pw.SizedBox(height: 8),
            ..._photoRows(flagged),
            pw.SizedBox(height: 10),
          ],
          // Photos grouped by location tag
          ...orderedCats.expand((cat) {
            final photos = byCategory[cat]!;
            final note = insp.categoryNotes[cat];
            return <pw.Widget>[
              _sectionLabel('$cat  (${photos.length})'),
              if (note != null && note.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(note,
                    style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                        fontStyle: pw.FontStyle.italic)),
              ],
              pw.SizedBox(height: 8),
              ..._photoRows(photos),
              pw.SizedBox(height: 8),
            ];
          }),
        ],
      ),
    );

    final bytes = await pdf.save();
    await _shareFile(
      bytes: bytes,
      filename:
          '${_safe(job.name)}_${_safe(insp.title)}_${_dateStr(insp.date)}.pdf',
      mimeType: 'application/pdf',
    );
  }

  static pw.Widget _buildHeader(Job job, Inspection insp) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.amber700, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SITE MEMO',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.amber800,
                      letterSpacing: 1.5)),
              pw.SizedBox(height: 3),
              pw.Text(job.name,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(job.location,
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(insp.title,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(insp.dateLabel,
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              if (insp.inspector.isNotEmpty)
                pw.Text('Inspector: ${insp.inspector}',
                    style:
                        pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              pw.SizedBox(height: 3),
              _statusBadge(insp.status),
            ],
          ),
        ],
      ),
    );
  }

  /// Lays out photo cards two per row.
  static List<pw.Widget> _photoRows(List<_PhotoData> photos) {
    final rows = <pw.Widget>[];
    for (int i = 0; i < photos.length; i += 2) {
      final left = photos[i];
      final right = i + 1 < photos.length ? photos[i + 1] : null;
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _photoCard(left, left.index)),
            pw.SizedBox(width: 12),
            pw.Expanded(
                child: right != null
                    ? _photoCard(right, right.index)
                    : pw.SizedBox()),
          ],
        ),
      );
      rows.add(pw.SizedBox(height: 14));
    }
    return rows;
  }

  static pw.Widget _statBox(String label, String value,
      {bool highlight = false}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: pw.BoxDecoration(
          color: highlight ? PdfColors.red50 : PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: highlight ? PdfColors.red800 : PdfColors.grey600,
                    letterSpacing: 0.6)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: highlight ? PdfColors.red800 : PdfColors.grey800)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _photoCard(_PhotoData p, int index) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Photo image or placeholder
        pw.Container(
          height: 140,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: p.image != null
              ? pw.ClipRRect(
                  horizontalRadius: 4,
                  verticalRadius: 4,
                  child: pw.Image(p.image!, fit: pw.BoxFit.cover))
              : pw.Center(
                  child: pw.Text('Photo $index',
                      style: pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey500))),
        ),
        pw.SizedBox(height: 5),
        // Location tag + flag
        pw.Row(children: [
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber100,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(p.category,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.amber900)),
          ),
          if (p.isFlagged) ...[
            pw.SizedBox(width: 4),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColors.red100,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text('FLAGGED',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red800)),
            ),
          ],
        ]),
        if (p.caption != null && p.caption!.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(p.caption!,
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
        if (p.transcription != null && p.transcription!.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(p.transcription!,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              maxLines: 4),
        ],
      ],
    );
  }

  static pw.Widget _sectionLabel(String text) => pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey600,
            letterSpacing: 0.8),
      );

  static pw.Widget _statusBadge(String status) {
    final label = status == 'approved'
        ? 'APPROVED'
        : status == 'submitted'
            ? 'SUBMITTED'
            : 'IN PROGRESS';
    final color = status == 'approved'
        ? PdfColors.green800
        : status == 'submitted'
            ? PdfColors.blue800
            : PdfColors.amber800;
    final bg = status == 'approved'
        ? PdfColors.green100
        : status == 'submitted'
            ? PdfColors.blue100
            : PdfColors.amber100;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(99),
      ),
      child: pw.Text(label,
          style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold, color: color)),
    );
  }

  // ── ZIP Export ──────────────────────────────────────────────────────────────

  static Future<void> exportZip(Job job, Inspection insp) async {
    final archive = Archive();

    // Text report
    final report = _buildTextReport(job, insp);
    final reportBytes = Uint8List.fromList(report.codeUnits);
    archive.addFile(ArchiveFile('report.txt', reportBytes.length, reportBytes));

    // Photos
    for (int i = 0; i < insp.photos.length; i++) {
      final p = insp.photos[i];
      if (!kIsWeb) {
        try {
          final file = File(p.imagePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final name =
                'photos/${(i + 1).toString().padLeft(3, '0')}_${_safe(p.category)}.jpg';
            archive.addFile(ArchiveFile(name, bytes.length, bytes));
          }
        } catch (_) {}
      }
      // Audio intentionally excluded — text notes are in report.txt
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) return;

    await _shareFile(
      bytes: Uint8List.fromList(zipBytes),
      filename:
          '${_safe(job.name)}_${_safe(insp.title)}_${_dateStr(insp.date)}.zip',
      mimeType: 'application/zip',
    );
  }

  static String _buildTextReport(Job job, Inspection insp) {
    final buf = StringBuffer();
    buf.writeln('SITE MEMO — INSPECTION REPORT');
    buf.writeln('=' * 40);
    buf.writeln('Site:       ${job.name}');
    buf.writeln('Location:   ${job.location}');
    buf.writeln('Inspection: ${insp.title}');
    buf.writeln('Date:       ${insp.dateLabel}');
    if (insp.inspector.isNotEmpty) buf.writeln('Inspector:  ${insp.inspector}');
    buf.writeln('Status:     ${insp.status.replaceAll('_', ' ').toUpperCase()}');
    buf.writeln();
    if (insp.notes.isNotEmpty) {
      buf.writeln('INSPECTION NOTES');
      buf.writeln('-' * 40);
      buf.writeln(insp.notes);
      buf.writeln();
    }
    if (insp.categoryNotes.isNotEmpty) {
      buf.writeln('AREA NOTES');
      buf.writeln('-' * 40);
      insp.categoryNotes.forEach((cat, note) {
        buf.writeln('$cat: $note');
      });
      buf.writeln();
    }
    buf.writeln('PHOTOS (${insp.photos.length})');
    buf.writeln('-' * 40);
    for (int i = 0; i < insp.photos.length; i++) {
      final p = insp.photos[i];
      buf.writeln('[${i + 1}] ${p.category}${p.isFlagged ? ' ⚑ FLAGGED' : ''}');
      if (p.caption != null && p.caption!.isNotEmpty) {
        buf.writeln('    Label: ${p.caption}');
      }
      if (p.transcription != null && p.transcription!.isNotEmpty) {
        buf.writeln('    Note:  ${p.transcription}');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static Future<void> _shareFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: filename,
    );
  }

  static String _safe(String s) =>
      s.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_').toLowerCase();

  static String _dateStr(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';
}

class _PhotoData {
  final pw.MemoryImage? image;
  final int index;
  final String category;
  final String? caption;
  final String? transcription;
  final bool isFlagged;
  _PhotoData({
    required this.image,
    required this.index,
    required this.category,
    this.caption,
    this.transcription,
    required this.isFlagged,
  });
}
