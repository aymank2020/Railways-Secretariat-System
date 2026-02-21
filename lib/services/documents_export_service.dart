import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/sadir_model.dart';
import '../models/warid_model.dart';

enum ExportFormat { excel, word, json }

extension ExportFormatExtension on ExportFormat {
  String get extension {
    switch (this) {
      case ExportFormat.excel:
        return 'xlsx';
      case ExportFormat.word:
        return 'doc';
      case ExportFormat.json:
        return 'json';
    }
  }

  String get displayName {
    switch (this) {
      case ExportFormat.excel:
        return 'Excel';
      case ExportFormat.word:
        return 'Word';
      case ExportFormat.json:
        return 'JSON';
    }
  }
}

class DocumentsExportService {
  static final DateFormat _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');
  static final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm');

  Future<String> exportWarid({
    required List<WaridModel> records,
    required ExportFormat format,
  }) async {
    final rows = records
        .map((warid) => <String>[
              warid.qaidNumber,
              _formatDate(warid.qaidDate),
              warid.sourceAdministration,
              warid.letterNumber ?? '',
              _formatNullableDate(warid.letterDate),
              warid.attachmentCount.toString(),
              warid.subject,
              warid.notes ?? '',
              warid.needsFollowup ? 'Yes' : 'No',
              warid.followupNotes ?? '',
              warid.fileName ?? '',
              warid.createdByName ?? '',
              _formatDateTime(warid.createdAt),
            ])
        .toList();

    final jsonRows = records.map((warid) {
      return <String, dynamic>{
        'id': warid.id,
        'qaid_number': warid.qaidNumber,
        'qaid_date': warid.qaidDate.toIso8601String(),
        'source_administration': warid.sourceAdministration,
        'letter_number': warid.letterNumber,
        'letter_date': warid.letterDate?.toIso8601String(),
        'attachment_count': warid.attachmentCount,
        'subject': warid.subject,
        'notes': warid.notes,
        'needs_followup': warid.needsFollowup,
        'followup_notes': warid.followupNotes,
        'file_name': warid.fileName,
        'file_path': warid.filePath,
        'created_by_name': warid.createdByName,
        'created_at': warid.createdAt.toIso8601String(),
      };
    }).toList();

    return _exportRecords(
      baseName: 'warid_export_${_fileDateFormat.format(DateTime.now())}',
      title: 'Warid Records',
      headers: const [
        'Qaid Number',
        'Qaid Date',
        'Source Administration',
        'Letter Number',
        'Letter Date',
        'Attachments',
        'Subject',
        'Notes',
        'Needs Followup',
        'Followup Notes',
        'File Name',
        'Created By',
        'Created At',
      ],
      rows: rows,
      jsonRows: jsonRows,
      format: format,
    );
  }

  Future<String> exportSadir({
    required List<SadirModel> records,
    required ExportFormat format,
  }) async {
    final rows = records
        .map((sadir) => <String>[
              sadir.qaidNumber,
              _formatDate(sadir.qaidDate),
              sadir.destinationAdministration ?? '',
              sadir.letterNumber ?? '',
              _formatNullableDate(sadir.letterDate),
              sadir.attachmentCount.toString(),
              sadir.subject,
              sadir.notes ?? '',
              sadir.signatureStatus,
              _formatNullableDate(sadir.signatureDate),
              sadir.needsFollowup ? 'Yes' : 'No',
              sadir.followupNotes ?? '',
              sadir.fileName ?? '',
              sadir.createdByName ?? '',
              _formatDateTime(sadir.createdAt),
            ])
        .toList();

    final jsonRows = records.map((sadir) {
      return <String, dynamic>{
        'id': sadir.id,
        'qaid_number': sadir.qaidNumber,
        'qaid_date': sadir.qaidDate.toIso8601String(),
        'destination_administration': sadir.destinationAdministration,
        'letter_number': sadir.letterNumber,
        'letter_date': sadir.letterDate?.toIso8601String(),
        'attachment_count': sadir.attachmentCount,
        'subject': sadir.subject,
        'notes': sadir.notes,
        'signature_status': sadir.signatureStatus,
        'signature_date': sadir.signatureDate?.toIso8601String(),
        'needs_followup': sadir.needsFollowup,
        'followup_notes': sadir.followupNotes,
        'file_name': sadir.fileName,
        'file_path': sadir.filePath,
        'created_by_name': sadir.createdByName,
        'created_at': sadir.createdAt.toIso8601String(),
      };
    }).toList();

    return _exportRecords(
      baseName: 'sadir_export_${_fileDateFormat.format(DateTime.now())}',
      title: 'Sadir Records',
      headers: const [
        'Qaid Number',
        'Qaid Date',
        'Destination Administration',
        'Letter Number',
        'Letter Date',
        'Attachments',
        'Subject',
        'Notes',
        'Signature Status',
        'Signature Date',
        'Needs Followup',
        'Followup Notes',
        'File Name',
        'Created By',
        'Created At',
      ],
      rows: rows,
      jsonRows: jsonRows,
      format: format,
    );
  }

  Future<String> _exportRecords({
    required String baseName,
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    required List<Map<String, dynamic>> jsonRows,
    required ExportFormat format,
  }) async {
    final outputPath = await _resolveOutputPath(
      baseName: baseName,
      format: format,
    );

    late final Uint8List fileBytes;
    switch (format) {
      case ExportFormat.excel:
        fileBytes = _buildExcelBytes(headers: headers, rows: rows);
        break;
      case ExportFormat.word:
        fileBytes = _buildTextBytes(_buildWordContent(
          title: title,
          headers: headers,
          rows: rows,
        ));
        break;
      case ExportFormat.json:
        const encoder = JsonEncoder.withIndent('  ');
        fileBytes = _buildTextBytes(encoder.convert(jsonRows));
        break;
    }

    final file = File(outputPath);
    await file.create(recursive: true);
    await file.writeAsBytes(fileBytes, flush: true);
    return file.path;
  }

  Uint8List _buildExcelBytes({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'Data';
    final sheet = excel[sheetName];
    sheet.appendRow(headers.map((header) => TextCellValue(header)).toList());

    for (final row in rows) {
      sheet.appendRow(row.map((cell) => TextCellValue(cell)).toList());
    }

    if (excel.tables.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('Failed to generate Excel file.');
    }
    return Uint8List.fromList(encoded);
  }

  Uint8List _buildTextBytes(String content) {
    final encoded = utf8.encode(content);
    return Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...encoded]);
  }

  String _buildWordContent({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(title);
    buffer.writeln('Exported At: ${_formatDateTime(DateTime.now())}');
    buffer.writeln('Total Records: ${rows.length}');
    buffer.writeln();
    buffer.writeln(headers.join('\t'));

    for (final row in rows) {
      buffer.writeln(row.join('\t'));
    }
    return buffer.toString();
  }

  Future<String> _resolveOutputPath({
    required String baseName,
    required ExportFormat format,
  }) async {
    final suggestedName = '$baseName.${format.extension}';
    String? selectedPath;

    try {
      selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export ${format.displayName}',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: [format.extension],
      );
    } catch (_) {
      selectedPath = null;
    }

    if (selectedPath == null || selectedPath.trim().isEmpty) {
      final directory = await getApplicationDocumentsDirectory();
      selectedPath = p.join(directory.path, suggestedName);
    }

    var normalizedPath = selectedPath.trim();
    if (p.extension(normalizedPath).toLowerCase() != '.${format.extension}') {
      normalizedPath = '$normalizedPath.${format.extension}';
    }
    return normalizedPath;
  }

  static String _formatDate(DateTime date) => _dateFormat.format(date);

  static String _formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  static String _formatNullableDate(DateTime? date) {
    if (date == null) {
      return '';
    }
    return _dateFormat.format(date);
  }
}
