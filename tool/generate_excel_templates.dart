import 'dart:io';

import 'package:excel/excel.dart';

void main() {
  final templatesDir = Directory('templates');
  if (!templatesDir.existsSync()) {
    templatesDir.createSync(recursive: true);
  }

  _createWaridTemplate(
    'templates/warid_import_template.xlsx',
  );
  _createSadirTemplate(
    'templates/sadir_import_template.xlsx',
  );

  File('templates/README_IMPORT_TEMPLATES.txt').writeAsStringSync(
    [
      'Excel Import Templates',
      '',
      '1) warid_import_template.xlsx',
      '2) sadir_import_template.xlsx',
      '',
      'Notes:',
      '- Keep the first row as headers exactly as provided.',
      '- Required columns for Warid: رقم القيد, تاريخ القيد, الجهة الوارد منها, الموضوع',
      '- Required columns for Sadir: رقم القيد, تاريخ القيد, الموضوع',
      '- Date format recommended: YYYY-MM-DD',
      '- Boolean fields accept: 1/0, true/false, نعم/لا',
      '- Attachments are uploaded manually after import.',
    ].join('\n'),
  );

  stdout.writeln('Templates created in: ${templatesDir.path}');
}

void _createWaridTemplate(String path) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  final sheetName = 'Warid';
  if (defaultSheet != null && defaultSheet != sheetName) {
    excel.rename(defaultSheet, sheetName);
  } else if (defaultSheet == null) {
    excel[sheetName];
  }

  final sheet = excel[sheetName];

  final headers = <String>[
    'رقم القيد',
    'تاريخ القيد',
    'الجهة الوارد منها',
    'رقم الخطاب',
    'تاريخ الخطاب',
    'عدد المرفقات',
    'الموضوع',
    'ملاحظات',
    'المستلم 1',
    'تاريخ التسليم 1',
    'المستلم 2',
    'تاريخ التسليم 2',
    'المستلم 3',
    'تاريخ التسليم 3',
    'الوزارة',
    'الهيئة',
    'جهة أخرى',
    'تفاصيل الجهة الأخرى',
    'يحتاج لمتابعة',
    'ملاحظات المتابعة',
  ];

  final sampleRow = <String>[
    '1001',
    '2026-02-19',
    'هيئة السكك الحديدية',
    'و/12',
    '2026-02-18',
    '2',
    'طلب اعتماد ميزانية',
    'ملاحظات تجريبية',
    'إدارة الشؤون المالية',
    '2026-02-20',
    '',
    '',
    '',
    '',
    '1',
    '0',
    '0',
    '',
    '1',
    'متابعة بعد أسبوع',
  ];

  sheet.appendRow(headers.map(TextCellValue.new).toList());
  sheet.appendRow(sampleRow.map(TextCellValue.new).toList());

  final bytes = excel.save();
  if (bytes != null) {
    File(path).writeAsBytesSync(bytes, flush: true);
  }
}

void _createSadirTemplate(String path) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  final sheetName = 'Sadir';
  if (defaultSheet != null && defaultSheet != sheetName) {
    excel.rename(defaultSheet, sheetName);
  } else if (defaultSheet == null) {
    excel[sheetName];
  }

  final sheet = excel[sheetName];

  final headers = <String>[
    'رقم القيد',
    'تاريخ القيد',
    'الجهة المرسل إليها',
    'رقم الخطاب',
    'تاريخ الخطاب',
    'عدد المرفقات',
    'الموضوع',
    'ملاحظات',
    'حالة التوقيع',
    'تاريخ التوقيع',
    'المرسل إليه 1',
    'تاريخ التسليم 1',
    'المرسل إليه 2',
    'تاريخ التسليم 2',
    'المرسل إليه 3',
    'تاريخ التسليم 3',
    'الوزارة',
    'الهيئة',
    'جهة أخرى',
    'تفاصيل الجهة الأخرى',
    'يحتاج لمتابعة',
    'ملاحظات المتابعة',
  ];

  final sampleRow = <String>[
    '2001',
    '2026-02-19',
    'وزارة النقل',
    'ص/55',
    '2026-02-19',
    '1',
    'إفادة بخصوص خطة التشغيل',
    'ملاحظات تجريبية',
    'حفظ',
    '2026-02-19',
    'الإدارة القانونية',
    '2026-02-20',
    '',
    '',
    '',
    '',
    '0',
    '1',
    '0',
    '',
    '0',
    '',
  ];

  sheet.appendRow(headers.map(TextCellValue.new).toList());
  sheet.appendRow(sampleRow.map(TextCellValue.new).toList());

  final bytes = excel.save();
  if (bytes != null) {
    File(path).writeAsBytesSync(bytes, flush: true);
  }
}
