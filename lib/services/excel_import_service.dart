import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/sadir_model.dart';
import '../models/warid_model.dart';

class ExcelImportRowError {
  final int rowNumber;
  final String message;

  const ExcelImportRowError({
    required this.rowNumber,
    required this.message,
  });
}

class ParsedImportRow<T> {
  final int rowNumber;
  final T data;

  const ParsedImportRow({
    required this.rowNumber,
    required this.data,
  });
}

class ExcelImportParseResult<T> {
  final int totalRows;
  final List<ParsedImportRow<T>> validRows;
  final List<ExcelImportRowError> errors;

  const ExcelImportParseResult({
    required this.totalRows,
    required this.validRows,
    required this.errors,
  });

  bool get hasFatalError => totalRows == 0 && validRows.isEmpty;
}

class ExcelImportService {
  static const Map<String, List<String>> _waridHeaderAliases = {
    'qaid_number': [
      'رقم القيد',
      'qaid_number',
      'qaid number',
      'registration number'
    ],
    'qaid_date': ['تاريخ القيد', 'qaid_date', 'qaid date', 'registration date'],
    'source_administration': [
      'الجهة الوارد منها',
      'الجهة',
      'source_administration',
      'source administration',
      'source'
    ],
    'letter_number': ['رقم الخطاب', 'letter_number', 'letter number'],
    'letter_date': ['تاريخ الخطاب', 'letter_date', 'letter date'],
    'attachment_count': [
      'عدد المرفقات',
      'attachment_count',
      'attachment count',
      'attachments'
    ],
    'subject': ['الموضوع', 'subject'],
    'notes': ['ملاحظات', 'notes'],
    'recipient_1_name': [
      'المستلم 1',
      'المستلم1',
      'recipient_1_name',
      'recipient 1'
    ],
    'recipient_1_delivery_date': [
      'تاريخ تسليم 1',
      'تاريخ التسليم 1',
      'recipient_1_delivery_date',
      'recipient 1 delivery date'
    ],
    'recipient_2_name': [
      'المستلم 2',
      'المستلم2',
      'recipient_2_name',
      'recipient 2'
    ],
    'recipient_2_delivery_date': [
      'تاريخ تسليم 2',
      'تاريخ التسليم 2',
      'recipient_2_delivery_date',
      'recipient 2 delivery date'
    ],
    'recipient_3_name': [
      'المستلم 3',
      'المستلم3',
      'recipient_3_name',
      'recipient 3'
    ],
    'recipient_3_delivery_date': [
      'تاريخ تسليم 3',
      'تاريخ التسليم 3',
      'recipient_3_delivery_date',
      'recipient 3 delivery date'
    ],
    'is_ministry': ['الوزارة', 'is_ministry', 'ministry'],
    'is_authority': ['الهيئة', 'is_authority', 'authority'],
    'is_other': ['جهة اخرى', 'جهة أخرى', 'is_other', 'other'],
    'other_details': [
      'تفاصيل الجهة الاخرى',
      'تفاصيل الجهة الأخرى',
      'other_details',
      'other details'
    ],
    'file_name': ['اسم ملف الحفظ', 'file_name', 'file name'],
    'file_path': ['مسار الملف', 'file_path', 'file path'],
    'needs_followup': ['يحتاج لمتابعة', 'needs_followup', 'needs followup'],
    'followup_notes': ['ملاحظات المتابعة', 'followup_notes', 'followup notes'],
  };

  static const Map<String, List<String>> _sadirHeaderAliases = {
    'qaid_number': [
      'رقم القيد',
      'qaid_number',
      'qaid number',
      'registration number'
    ],
    'qaid_date': ['تاريخ القيد', 'qaid_date', 'qaid date', 'registration date'],
    'destination_administration': [
      'الجهة المرسل اليها',
      'الجهة المرسل إليها',
      'الجهة',
      'destination_administration',
      'destination administration',
      'destination'
    ],
    'letter_number': ['رقم الخطاب', 'letter_number', 'letter number'],
    'letter_date': ['تاريخ الخطاب', 'letter_date', 'letter date'],
    'attachment_count': [
      'عدد المرفقات',
      'attachment_count',
      'attachment count',
      'attachments'
    ],
    'subject': ['الموضوع', 'subject'],
    'notes': ['ملاحظات', 'notes'],
    'signature_status': [
      'حالة التوقيع',
      'signature_status',
      'signature status'
    ],
    'signature_date': ['تاريخ التوقيع', 'signature_date', 'signature date'],
    'sent_to_1_name': [
      'المرسل اليه 1',
      'المرسل إليه 1',
      'sent_to_1_name',
      'sent to 1'
    ],
    'sent_to_1_delivery_date': [
      'تاريخ تسليم 1',
      'تاريخ التسليم 1',
      'sent_to_1_delivery_date',
      'sent to 1 delivery date'
    ],
    'sent_to_2_name': [
      'المرسل اليه 2',
      'المرسل إليه 2',
      'sent_to_2_name',
      'sent to 2'
    ],
    'sent_to_2_delivery_date': [
      'تاريخ تسليم 2',
      'تاريخ التسليم 2',
      'sent_to_2_delivery_date',
      'sent to 2 delivery date'
    ],
    'sent_to_3_name': [
      'المرسل اليه 3',
      'المرسل إليه 3',
      'sent_to_3_name',
      'sent to 3'
    ],
    'sent_to_3_delivery_date': [
      'تاريخ تسليم 3',
      'تاريخ التسليم 3',
      'sent_to_3_delivery_date',
      'sent to 3 delivery date'
    ],
    'is_ministry': ['الوزارة', 'is_ministry', 'ministry'],
    'is_authority': ['الهيئة', 'is_authority', 'authority'],
    'is_other': ['جهة اخرى', 'جهة أخرى', 'is_other', 'other'],
    'other_details': [
      'تفاصيل الجهة الاخرى',
      'تفاصيل الجهة الأخرى',
      'other_details',
      'other details'
    ],
    'file_name': ['اسم ملف الحفظ', 'file_name', 'file name'],
    'file_path': ['مسار الملف', 'file_path', 'file path'],
    'needs_followup': ['يحتاج لمتابعة', 'needs_followup', 'needs followup'],
    'followup_notes': ['ملاحظات المتابعة', 'followup_notes', 'followup notes'],
  };

  static const List<String> _requiredWaridFields = [
    'qaid_number',
    'qaid_date',
    'source_administration',
    'subject',
  ];

  static const List<String> _requiredSadirFields = [
    'qaid_number',
    'qaid_date',
    'subject',
  ];

  ExcelImportParseResult<WaridModel> parseWarid({
    required Uint8List fileBytes,
    int? createdBy,
    String? createdByName,
  }) {
    final sheetRows = _decodeFirstSheetRows(fileBytes);
    if (sheetRows == null) {
      return const ExcelImportParseResult(
        totalRows: 0,
        validRows: [],
        errors: [
          ExcelImportRowError(
              rowNumber: 0, message: 'تعذر قراءة ملف Excel أو الملف فارغ.')
        ],
      );
    }

    final headers = sheetRows.first;
    final columnMap = _buildColumnMap(headers, _waridHeaderAliases);
    final missing = _requiredWaridFields
        .where((key) => !columnMap.containsKey(key))
        .toList();

    if (missing.isNotEmpty) {
      return ExcelImportParseResult(
        totalRows: 0,
        validRows: const [],
        errors: [
          ExcelImportRowError(
            rowNumber: 0,
            message: 'الأعمدة المطلوبة غير موجودة: ${missing.join(', ')}',
          ),
        ],
      );
    }

    final records = <ParsedImportRow<WaridModel>>[];
    final errors = <ExcelImportRowError>[];
    int totalRows = 0;

    for (var i = 1; i < sheetRows.length; i++) {
      final row = sheetRows[i];
      if (_isRowEmpty(row)) {
        continue;
      }

      totalRows++;
      final rowNumber = i + 1;

      try {
        final qaidNumber = _readText(row, columnMap['qaid_number']);
        final qaidDate = _readDate(row, columnMap['qaid_date']);
        final sourceAdministration =
            _readText(row, columnMap['source_administration']);
        final subject = _readText(row, columnMap['subject']);

        if (qaidNumber.isEmpty) {
          throw const FormatException('رقم القيد مطلوب');
        }
        if (qaidDate == null) {
          throw const FormatException('تاريخ القيد غير صالح أو فارغ');
        }
        if (sourceAdministration.isEmpty) {
          throw const FormatException('الجهة الوارد منها مطلوبة');
        }
        if (subject.isEmpty) {
          throw const FormatException('الموضوع مطلوب');
        }

        final warid = WaridModel(
          qaidNumber: qaidNumber,
          qaidDate: qaidDate,
          sourceAdministration: sourceAdministration,
          letterNumber:
              _nullableText(_readText(row, columnMap['letter_number'])),
          letterDate: _readDate(row, columnMap['letter_date']),
          attachmentCount: _readInt(row, columnMap['attachment_count']),
          subject: subject,
          notes: _nullableText(_readText(row, columnMap['notes'])),
          recipient1Name:
              _nullableText(_readText(row, columnMap['recipient_1_name'])),
          recipient1DeliveryDate:
              _readDate(row, columnMap['recipient_1_delivery_date']),
          recipient2Name:
              _nullableText(_readText(row, columnMap['recipient_2_name'])),
          recipient2DeliveryDate:
              _readDate(row, columnMap['recipient_2_delivery_date']),
          recipient3Name:
              _nullableText(_readText(row, columnMap['recipient_3_name'])),
          recipient3DeliveryDate:
              _readDate(row, columnMap['recipient_3_delivery_date']),
          isMinistry: _readBool(row, columnMap['is_ministry']),
          isAuthority: _readBool(row, columnMap['is_authority']),
          isOther: _readBool(row, columnMap['is_other']),
          otherDetails:
              _nullableText(_readText(row, columnMap['other_details'])),
          needsFollowup: _readBool(row, columnMap['needs_followup']),
          followupNotes:
              _nullableText(_readText(row, columnMap['followup_notes'])),
          createdAt: DateTime.now(),
          createdBy: createdBy,
          createdByName: createdByName,
        );

        records.add(ParsedImportRow(rowNumber: rowNumber, data: warid));
      } catch (e) {
        errors.add(ExcelImportRowError(
            rowNumber: rowNumber,
            message: e.toString().replaceFirst('FormatException: ', '')));
      }
    }

    return ExcelImportParseResult(
      totalRows: totalRows,
      validRows: records,
      errors: errors,
    );
  }

  ExcelImportParseResult<SadirModel> parseSadir({
    required Uint8List fileBytes,
    int? createdBy,
    String? createdByName,
  }) {
    final sheetRows = _decodeFirstSheetRows(fileBytes);
    if (sheetRows == null) {
      return const ExcelImportParseResult(
        totalRows: 0,
        validRows: [],
        errors: [
          ExcelImportRowError(
              rowNumber: 0, message: 'تعذر قراءة ملف Excel أو الملف فارغ.')
        ],
      );
    }

    final headers = sheetRows.first;
    final columnMap = _buildColumnMap(headers, _sadirHeaderAliases);
    final missing = _requiredSadirFields
        .where((key) => !columnMap.containsKey(key))
        .toList();

    if (missing.isNotEmpty) {
      return ExcelImportParseResult(
        totalRows: 0,
        validRows: const [],
        errors: [
          ExcelImportRowError(
            rowNumber: 0,
            message: 'الأعمدة المطلوبة غير موجودة: ${missing.join(', ')}',
          ),
        ],
      );
    }

    final records = <ParsedImportRow<SadirModel>>[];
    final errors = <ExcelImportRowError>[];
    int totalRows = 0;

    for (var i = 1; i < sheetRows.length; i++) {
      final row = sheetRows[i];
      if (_isRowEmpty(row)) {
        continue;
      }

      totalRows++;
      final rowNumber = i + 1;

      try {
        final qaidNumber = _readText(row, columnMap['qaid_number']);
        final qaidDate = _readDate(row, columnMap['qaid_date']);
        final subject = _readText(row, columnMap['subject']);

        if (qaidNumber.isEmpty) {
          throw const FormatException('رقم القيد مطلوب');
        }
        if (qaidDate == null) {
          throw const FormatException('تاريخ القيد غير صالح أو فارغ');
        }
        if (subject.isEmpty) {
          throw const FormatException('الموضوع مطلوب');
        }

        final sadir = SadirModel(
          qaidNumber: qaidNumber,
          qaidDate: qaidDate,
          destinationAdministration: _nullableText(
              _readText(row, columnMap['destination_administration'])),
          letterNumber:
              _nullableText(_readText(row, columnMap['letter_number'])),
          letterDate: _readDate(row, columnMap['letter_date']),
          attachmentCount: _readInt(row, columnMap['attachment_count']),
          subject: subject,
          notes: _nullableText(_readText(row, columnMap['notes'])),
          signatureStatus: _normalizeSignatureStatus(
              _readText(row, columnMap['signature_status'])),
          signatureDate: _readDate(row, columnMap['signature_date']),
          sentTo1Name:
              _nullableText(_readText(row, columnMap['sent_to_1_name'])),
          sentTo1DeliveryDate:
              _readDate(row, columnMap['sent_to_1_delivery_date']),
          sentTo2Name:
              _nullableText(_readText(row, columnMap['sent_to_2_name'])),
          sentTo2DeliveryDate:
              _readDate(row, columnMap['sent_to_2_delivery_date']),
          sentTo3Name:
              _nullableText(_readText(row, columnMap['sent_to_3_name'])),
          sentTo3DeliveryDate:
              _readDate(row, columnMap['sent_to_3_delivery_date']),
          isMinistry: _readBool(row, columnMap['is_ministry']),
          isAuthority: _readBool(row, columnMap['is_authority']),
          isOther: _readBool(row, columnMap['is_other']),
          otherDetails:
              _nullableText(_readText(row, columnMap['other_details'])),
          needsFollowup: _readBool(row, columnMap['needs_followup']),
          followupNotes:
              _nullableText(_readText(row, columnMap['followup_notes'])),
          createdAt: DateTime.now(),
          createdBy: createdBy,
          createdByName: createdByName,
        );

        records.add(ParsedImportRow(rowNumber: rowNumber, data: sadir));
      } catch (e) {
        errors.add(ExcelImportRowError(
            rowNumber: rowNumber,
            message: e.toString().replaceFirst('FormatException: ', '')));
      }
    }

    return ExcelImportParseResult(
      totalRows: totalRows,
      validRows: records,
      errors: errors,
    );
  }

  List<List<Data?>>? _decodeFirstSheetRows(Uint8List fileBytes) {
    try {
      final excel = Excel.decodeBytes(fileBytes);
      if (excel.tables.isEmpty) {
        return null;
      }
      final firstSheet = excel.tables.values.first;
      if (firstSheet.rows.isEmpty) {
        return null;
      }
      return firstSheet.rows;
    } catch (_) {
      return null;
    }
  }

  Map<String, int> _buildColumnMap(
      List<Data?> headerRow, Map<String, List<String>> aliases) {
    final headersIndex = <String, int>{};

    for (var i = 0; i < headerRow.length; i++) {
      final normalized = _normalizeHeader(_cellToText(headerRow[i]));
      if (normalized.isNotEmpty && !headersIndex.containsKey(normalized)) {
        headersIndex[normalized] = i;
      }
    }

    final result = <String, int>{};
    aliases.forEach((key, values) {
      for (final alias in values) {
        final index = headersIndex[_normalizeHeader(alias)];
        if (index != null) {
          result[key] = index;
          break;
        }
      }
    });
    return result;
  }

  bool _isRowEmpty(List<Data?> row) {
    for (final cell in row) {
      if (_cellToText(cell).isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  String _readText(List<Data?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) {
      return '';
    }
    return _cellToText(row[index]);
  }

  int _readInt(List<Data?> row, int? index) {
    final raw = _readText(row, index);
    if (raw.isEmpty) {
      return 0;
    }
    final normalized = raw.replaceAll(',', '.');
    final asInt = int.tryParse(normalized);
    if (asInt != null) {
      return asInt;
    }
    final asDouble = double.tryParse(normalized);
    if (asDouble != null) {
      return asDouble.round();
    }
    return 0;
  }

  bool _readBool(List<Data?> row, int? index) {
    final value = _normalizeHeader(_readText(row, index));
    if (value.isEmpty) {
      return false;
    }
    const trueValues = {
      '1',
      'true',
      'yes',
      'y',
      'on',
      'نعم',
      'صح',
      'مفعل',
      'مطلوب',
      'تم',
    };
    return trueValues.contains(value);
  }

  DateTime? _readDate(List<Data?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) {
      return null;
    }
    final cell = row[index];
    final value = cell?.value;
    if (value == null) {
      return null;
    }

    if (value is DateCellValue) {
      return value.asDateTimeLocal();
    }
    if (value is DateTimeCellValue) {
      return value.asDateTimeLocal();
    }
    if (value is IntCellValue) {
      if (value.value >= 25000 && value.value <= 80000) {
        return _excelSerialToDate(value.value.toDouble());
      }
      return _parseDateFromText(value.value.toString());
    }
    if (value is DoubleCellValue) {
      if (value.value >= 25000 && value.value <= 80000) {
        return _excelSerialToDate(value.value);
      }
      return _parseDateFromText(value.value.toString());
    }

    return _parseDateFromText(_cellToText(cell));
  }

  DateTime _excelSerialToDate(double serial) {
    final wholeDays = serial.floor();
    final dayFraction = serial - wholeDays;
    final milliseconds = (dayFraction * Duration.millisecondsPerDay).round();
    final base = DateTime.utc(1899, 12, 30);
    final result = base
        .add(Duration(days: wholeDays, milliseconds: milliseconds))
        .toLocal();
    return DateTime(result.year, result.month, result.day, result.hour,
        result.minute, result.second);
  }

  DateTime? _parseDateFromText(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return null;
    }

    final isoDate = DateTime.tryParse(raw);
    if (isoDate != null) {
      return isoDate;
    }

    final normalized = raw.replaceAll('.', '/').replaceAll('-', '/');
    final parts = normalized.split('/');
    if (parts.length == 3) {
      final a = int.tryParse(parts[0].trim());
      final b = int.tryParse(parts[1].trim());
      final c = int.tryParse(parts[2].trim());
      if (a != null && b != null && c != null) {
        int day;
        int month;
        int year;

        if (a > 31) {
          year = a;
          month = b;
          day = c;
        } else {
          day = a;
          month = b;
          year = c;
        }

        if (year < 100) {
          year += 2000;
        }

        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateTime(year, month, day);
        }
      }
    }

    return null;
  }

  String _cellToText(Data? cell) {
    final value = cell?.value;
    if (value == null) {
      return '';
    }
    if (value is TextCellValue) {
      return value.value.toString().trim();
    }
    if (value is IntCellValue) {
      return value.value.toString();
    }
    if (value is DoubleCellValue) {
      return value.value % 1 == 0
          ? value.value.toInt().toString()
          : value.value.toString();
    }
    if (value is BoolCellValue) {
      return value.value ? 'true' : 'false';
    }
    if (value is DateCellValue) {
      return value.asDateTimeLocal().toIso8601String();
    }
    if (value is DateTimeCellValue) {
      return value.asDateTimeLocal().toIso8601String();
    }
    if (value is TimeCellValue) {
      return value.toString();
    }
    if (value is FormulaCellValue) {
      return value.formula.trim();
    }
    return value.toString().trim();
  }

  String _normalizeHeader(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[\s_\-]+'), '');
  }

  String _normalizeSignatureStatus(String raw) {
    final value = _normalizeHeader(raw);
    if (value.isEmpty) {
      return 'pending';
    }
    const savedValues = {
      'saved',
      'signed',
      'completed',
      'حفظ',
      'محفوظ',
      'تمالتوقيع',
      'موقع'
    };
    return savedValues.contains(value) ? 'saved' : 'pending';
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

