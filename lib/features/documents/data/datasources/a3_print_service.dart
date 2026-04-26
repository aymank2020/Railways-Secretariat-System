import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/documents/data/models/warid_model.dart';

enum PrintPaperSize {
  a4,
  a3,
  letter,
  legal,
}

extension PrintPaperSizeExtension on PrintPaperSize {
  String get displayName {
    switch (this) {
      case PrintPaperSize.a4:
        return 'A4';
      case PrintPaperSize.a3:
        return 'A3';
      case PrintPaperSize.letter:
        return 'Letter';
      case PrintPaperSize.legal:
        return 'Legal';
    }
  }
}

enum WaridPrintType {
  postalDelivery,
  followupReport,
}

extension WaridPrintTypeExtension on WaridPrintType {
  String get displayName {
    switch (this) {
      case WaridPrintType.postalDelivery:
        return 'تسليم البوسطة';
      case WaridPrintType.followupReport:
        return 'تقرير المتابعة';
    }
  }
}

class A3PrintService {
  static final DateFormat _dateFormat = DateFormat('yyyy/MM/dd', 'ar');
  static final DateFormat _dateTimeFormat =
      DateFormat('yyyy/MM/dd HH:mm', 'ar');
  static const String _waridTemplateAssetPath =
      'assets/templates/warid_a3_template.png';
  static const double _waridTemplateWidthPx = 1050;
  static const double _waridTemplateHeightPx = 1500;
  static const double _waridRowsTopPx = 74;
  static const double _waridRowsBottomPx = 1450;
  static const int _waridRowsPerPage = 24;
  static const List<double> _waridColumnBoundariesPx = <double>[
    70,
    137,
    199,
    267,
    333,
    443,
    532,
    612,
    672,
    735,
    796,
    855,
    915,
    975,
  ];
  static const PdfColor _sheetBackgroundColor = PdfColor(0.97, 0.99, 1.00);
  static const PdfColor _sheetBorderColor = PdfColor(0.78, 0.84, 0.90);
  static const PdfColor _sheetHeaderColor = PdfColor(0.08, 0.25, 0.40);
  static const PdfColor _sectionHeaderColor = PdfColor(0.86, 0.93, 0.98);
  static const PdfColor _labelCellColor = PdfColor(0.95, 0.97, 1.00);
  static const PdfColor _valueCellColor = PdfColors.white;

  Future<String> exportWaridRecordsToA3Template(
    List<WaridModel> records,
  ) async {
    if (records.isEmpty) {
      throw StateError('لا توجد سجلات وارد للتصدير');
    }

    final templateImage = await _loadWaridTemplateImage();
    if (templateImage == null) {
      throw StateError(
        'تعذر تحميل نموذج A3. تأكد من وجود الملف assets/templates/warid_a3_template.png',
      );
    }

    final theme = await _buildTheme();
    final document = pw.Document(theme: theme);
    final pages = _chunkWaridRecords(records, _waridRowsPerPage);

    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final pageRecords = pages[pageIndex];
      document.addPage(
        pw.Page(
          pageTheme: const pw.PageTheme(
            pageFormat: PdfPageFormat.a3,
            margin: pw.EdgeInsets.zero,
            textDirection: pw.TextDirection.rtl,
          ),
          build: (context) => _buildWaridTemplatePage(
            pageRecords: pageRecords,
            templateImage: templateImage,
            pageNumber: pageIndex + 1,
            totalPages: pages.length,
          ),
        ),
      );
    }

    final fileName =
        'warid_a3_template_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final bytes = await document.save();

    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return fileName;
    }

    final outputPath = await _resolvePdfOutputPath(fileName);
    final outputFile = File(outputPath);
    await outputFile.create(recursive: true);
    await outputFile.writeAsBytes(bytes, flush: true);
    return outputFile.path;
  }

  Future<String> exportWaridFullA3Pdf(List<WaridModel> records) async {
    if (records.isEmpty) {
      throw StateError('لا توجد سجلات وارد للتصدير');
    }

    final theme = await _buildTheme();
    final document = pw.Document(theme: theme);

    for (var index = 0; index < records.length; index++) {
      final warid = records[index];
      document.addPage(
        pw.MultiPage(
          pageTheme: const pw.PageTheme(
            pageFormat: PdfPageFormat.a3,
            margin: pw.EdgeInsets.all(18),
            textDirection: pw.TextDirection.rtl,
          ),
          build: (_) => _buildWaridFullRecordWidgets(
            warid: warid,
            index: index + 1,
            total: records.length,
          ),
        ),
      );
    }

    final fileName =
        'warid_full_a3_${DateTime.now().millisecondsSinceEpoch}.pdf';
    return _savePdfToLocation(
      fileName: fileName,
      bytes: await document.save(),
    );
  }

  Future<String> exportSadirFullA3Pdf(List<SadirModel> records) async {
    if (records.isEmpty) {
      throw StateError('لا توجد سجلات صادر للتصدير');
    }

    final theme = await _buildTheme();
    final document = pw.Document(theme: theme);

    for (var index = 0; index < records.length; index++) {
      final sadir = records[index];
      document.addPage(
        pw.MultiPage(
          pageTheme: const pw.PageTheme(
            pageFormat: PdfPageFormat.a3,
            margin: pw.EdgeInsets.all(18),
            textDirection: pw.TextDirection.rtl,
          ),
          build: (_) => _buildSadirFullRecordWidgets(
            sadir: sadir,
            index: index + 1,
            total: records.length,
          ),
        ),
      );
    }

    final fileName =
        'sadir_full_a3_${DateTime.now().millisecondsSinceEpoch}.pdf';
    return _savePdfToLocation(
      fileName: fileName,
      bytes: await document.save(),
    );
  }

  Future<void> printWaridRecords(List<WaridModel> records) async {
    if (records.isEmpty) {
      throw StateError('لا توجد سجلات وارد للطباعة');
    }

    final theme = await _buildTheme();
    final document = pw.Document(theme: theme);
    final rows = <List<String>>[
      for (var i = 0; i < records.length; i++)
        [
          '${i + 1}',
          _valueOrDash(records[i].qaidNumber),
          _formatDate(records[i].qaidDate),
          _valueOrDash(records[i].sourceAdministration),
          _valueOrDash(records[i].letterNumber),
          _formatDate(records[i].letterDate),
          _valueOrDash(records[i].subject),
          records[i].attachmentCount.toString(),
          _valueOrDash(records[i].notes),
        ],
    ];

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a3.landscape,
          margin: const pw.EdgeInsets.all(18),
          textDirection: pw.TextDirection.rtl,
        ),
        build: (context) => [
          _buildHeader(
            title: 'بيان الوارد',
            totalRows: records.length,
          ),
          pw.SizedBox(height: 8),
          _buildTable(
            context: context,
            headers: const [
              'م',
              'رقم القيد',
              'تاريخ القيد',
              'الجهة الوارد منها',
              'رقم الخطاب',
              'تاريخه',
              'الموضوع',
              'المرفقات',
              'ملاحظات',
            ],
            rows: rows,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'warid_a3_${DateTime.now().millisecondsSinceEpoch}.pdf',
      format: PdfPageFormat.a3.landscape,
      onLayout: (format) async => document.save(),
    );
  }

  Future<void> printWaridByType(
    List<WaridModel> records, {
    WaridPrintType type = WaridPrintType.postalDelivery,
    PrintPaperSize paperSize = PrintPaperSize.a3,
  }) async {
    if (records.isEmpty) {
      throw StateError('لا توجد سجلات وارد للطباعة');
    }

    final pageFormat = _resolvePaperFormat(paperSize, landscape: true);
    final theme = await _buildTheme();
    final document = pw.Document(theme: theme);
    final filePrefix = type == WaridPrintType.postalDelivery
        ? 'postal_delivery'
        : 'followup_report';

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(16),
          textDirection: pw.TextDirection.rtl,
        ),
        build: (context) => [
          _buildHeader(
            title: type.displayName,
            totalRows: records.length,
            subtitle: 'حجم الورق: ${paperSize.displayName}',
          ),
          pw.SizedBox(height: 8),
          _buildWaridCustomTable(records: records, type: type),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'warid_${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      format: pageFormat,
      onLayout: (format) async => document.save(),
    );
  }

  pw.Widget _buildWaridCustomTable({
    required List<WaridModel> records,
    required WaridPrintType type,
  }) {
    final columns = <_WaridPrintColumn>[
      const _WaridPrintColumn('م', 0.9),
      const _WaridPrintColumn('رقم القيد', 1.4),
      const _WaridPrintColumn('الجهة الوارد منها الخطاب', 2.2),
      const _WaridPrintColumn('رقم الوزارة / الجهة الخارجية', 1.8),
      const _WaridPrintColumn('تاريخ الوزارة / الجهة الخارجية', 1.8),
      const _WaridPrintColumn('رقم وارد رئيس الهيئة', 1.7),
      const _WaridPrintColumn('تاريخ وارد رئيس الهيئة', 1.7),
      const _WaridPrintColumn('المرفقات', 1.2),
      const _WaridPrintColumn('الموضوع', 2.4),
      const _WaridPrintColumn('المستلمون', 4.2),
      if (type == WaridPrintType.followupReport)
        const _WaridPrintColumn('الموقف النهائي للموضوع', 1.9),
      if (type == WaridPrintType.followupReport)
        const _WaridPrintColumn('رقم / مسار المرفق PDF', 2.4),
      const _WaridPrintColumn('ملاحظات', 2.1),
    ];

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: const pw.TableBorder(
          left: pw.BorderSide(color: PdfColors.grey700, width: 0.6),
          right: pw.BorderSide(color: PdfColors.grey700, width: 0.6),
          top: pw.BorderSide(color: PdfColors.grey700, width: 0.6),
          bottom: pw.BorderSide(color: PdfColors.grey700, width: 0.6),
          horizontalInside: pw.BorderSide(color: PdfColors.grey500, width: 0.4),
          verticalInside: pw.BorderSide(color: PdfColors.grey500, width: 0.4),
        ),
        columnWidths: {
          for (var i = 0; i < columns.length; i++)
            i: pw.FlexColumnWidth(columns[i].flex),
        },
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              for (final column in columns)
                _buildCustomHeaderCell(column.title),
            ],
          ),
          for (var i = 0; i < records.length; i++)
            _buildWaridCustomRow(
              index: i + 1,
              warid: records[i],
              type: type,
            ),
        ],
      ),
    );
  }

  pw.TableRow _buildWaridCustomRow({
    required int index,
    required WaridModel warid,
    required WaridPrintType type,
  }) {
    final rowCells = <pw.Widget>[
      _buildCompactTextCell('$index'),
      _buildCompactTextCell(_valueOrDash(warid.qaidNumber)),
      _buildCompactTextCell(_valueOrDash(warid.sourceAdministration)),
      _buildCompactTextCell(_valueOrDash(warid.letterNumber)),
      _buildCompactTextCell(_formatDate(warid.letterDate)),
      _buildCompactTextCell(_valueOrDash(warid.chairmanIncomingNumber)),
      _buildCompactTextCell(_formatDate(warid.chairmanIncomingDate)),
      _buildCompactTextCell(warid.attachmentCount.toString()),
      _buildCompactTextCell(_valueOrDash(warid.subject), alignRight: true),
      _buildRecipientsCell(warid),
      if (type == WaridPrintType.followupReport)
        _buildCompactTextCell(_followupLabel(warid.followupStatus)),
      if (type == WaridPrintType.followupReport)
        _buildCompactTextCell(_buildAttachmentPdfReference(warid),
            alignRight: true),
      _buildCompactTextCell(_valueOrDash(warid.notes), alignRight: true),
    ];

    return pw.TableRow(children: rowCells);
  }

  pw.Widget _buildCustomHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Text(
        _valueOrDash(text),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7.8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _buildCompactTextCell(
    String text, {
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Text(
        _valueOrDash(text),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 7.2),
      ),
    );
  }

  pw.Widget _buildRecipientsCell(WaridModel warid) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Table(
        border: const pw.TableBorder(
          left: pw.BorderSide(color: PdfColors.grey500, width: 0.4),
          right: pw.BorderSide(color: PdfColors.grey500, width: 0.4),
          top: pw.BorderSide(color: PdfColors.grey500, width: 0.4),
          bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.4),
          horizontalInside: pw.BorderSide(color: PdfColors.grey400, width: 0.3),
          verticalInside: pw.BorderSide(color: PdfColors.grey400, width: 0.3),
        ),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.4),
          1: pw.FlexColumnWidth(1.6),
          2: pw.FlexColumnWidth(1.6),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _RecipientHeaderCell('الجهة المستلمة'),
              _RecipientHeaderCell('توقيع المستلم'),
              _RecipientHeaderCell('التاريخ'),
            ],
          ),
          _buildRecipientRow(
            recipient: warid.recipient1Name,
            date: warid.recipient1DeliveryDate,
          ),
          _buildRecipientRow(
            recipient: warid.recipient2Name,
            date: warid.recipient2DeliveryDate,
          ),
          _buildRecipientRow(
            recipient: warid.recipient3Name,
            date: warid.recipient3DeliveryDate,
          ),
        ],
      ),
    );
  }

  pw.TableRow _buildRecipientRow({
    required String? recipient,
    required DateTime? date,
  }) {
    return pw.TableRow(
      children: [
        _buildRecipientCell(_valueOrDash(recipient), alignRight: true),
        _buildRecipientCell(' ', alignRight: false),
        _buildRecipientCell(_formatDate(date), alignRight: false),
      ],
    );
  }

  pw.Widget _buildRecipientCell(
    String text, {
    required bool alignRight,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: pw.Text(
        _valueOrDash(text),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 6.6),
      ),
    );
  }

  String _buildAttachmentPdfReference(WaridModel warid) {
    final path = _normalizeTextForPrint(warid.filePath);
    final fileName = _normalizeTextForPrint(warid.fileName);
    if (path.isEmpty && fileName.isEmpty) {
      return '-';
    }

    var name = fileName;
    if (name.isNotEmpty && !name.toLowerCase().endsWith('.pdf')) {
      name = '$name.pdf';
    }

    if (path.isEmpty) {
      return name;
    }
    if (name.isEmpty) {
      return path;
    }

    final hasTrailingSeparator = path.endsWith('/') || path.endsWith('\\');
    return hasTrailingSeparator ? '$path$name' : '$path/$name';
  }

  PdfPageFormat _resolvePaperFormat(
    PrintPaperSize paperSize, {
    required bool landscape,
  }) {
    final format = switch (paperSize) {
      PrintPaperSize.a4 => PdfPageFormat.a4,
      PrintPaperSize.a3 => PdfPageFormat.a3,
      PrintPaperSize.letter => PdfPageFormat.letter,
      PrintPaperSize.legal => PdfPageFormat.legal,
    };
    return landscape ? format.landscape : format;
  }

  Future<void> printSadirRecords(List<SadirModel> records) async {
    if (records.isEmpty) {
      throw StateError('لا توجد سجلات صادر للطباعة');
    }

    final theme = await _buildTheme();
    final document = pw.Document(theme: theme);
    final rows = <List<String>>[
      for (var i = 0; i < records.length; i++)
        [
          '${i + 1}',
          _valueOrDash(records[i].qaidNumber),
          _formatDate(records[i].qaidDate),
          _valueOrDash(records[i].destinationAdministration),
          _valueOrDash(records[i].letterNumber),
          _formatDate(records[i].letterDate),
          _valueOrDash(records[i].subject),
          _signatureLabel(records[i].signatureStatus),
          _valueOrDash(records[i].notes),
        ],
    ];

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a3.landscape,
          margin: const pw.EdgeInsets.all(18),
          textDirection: pw.TextDirection.rtl,
        ),
        build: (context) => [
          _buildHeader(
            title: 'بيان الصادر',
            totalRows: records.length,
          ),
          pw.SizedBox(height: 8),
          _buildTable(
            context: context,
            headers: const [
              'م',
              'رقم القيد',
              'تاريخ القيد',
              'الجهة المرسل إليها',
              'رقم الخطاب',
              'تاريخه',
              'الموضوع',
              'التوقيع',
              'ملاحظات',
            ],
            rows: rows,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'sadir_a3_${DateTime.now().millisecondsSinceEpoch}.pdf',
      format: PdfPageFormat.a3.landscape,
      onLayout: (format) async => document.save(),
    );
  }

  List<pw.Widget> _buildWaridFullRecordWidgets({
    required WaridModel warid,
    required int index,
    required int total,
  }) {
    return [
      _buildRecordHeader(
        title: 'نموذج الوارد الشامل (A3)',
        subtitle: 'سجل وارد رقم ${warid.qaidNumber}',
        index: index,
        total: total,
      ),
      pw.SizedBox(height: 8),
      _buildLongTextSection(
        title: 'الموضوع',
        value: _valueOrDash(warid.subject),
      ),
      _buildLongTextSection(
        title: 'ملاحظات',
        value: _valueOrDash(warid.notes),
      ),
      _buildFieldSection(
        title: 'بيانات القيد الأساسية',
        fields: [
          _PdfField('معرف السجل', warid.id?.toString() ?? '-'),
          _PdfField('رقم القيد', warid.qaidNumber),
          _PdfField('تاريخ القيد', _formatDate(warid.qaidDate)),
          _PdfField(
              'الجهة الوارد منها', _valueOrDash(warid.sourceAdministration)),
          _PdfField('رقم الخطاب', _valueOrDash(warid.letterNumber)),
          _PdfField('تاريخ الخطاب', _formatDate(warid.letterDate)),
          _PdfField('عدد المرفقات', warid.attachmentCount.toString()),
        ],
      ),
      _buildFieldSection(
        title: 'أرقام رئيس الهيئة',
        fields: [
          _PdfField('رقم وارد رئيس الهيئة',
              _valueOrDash(warid.chairmanIncomingNumber)),
          _PdfField('تاريخ وارد رئيس الهيئة',
              _formatDate(warid.chairmanIncomingDate)),
          _PdfField(
              'رقم رد رئيس الهيئة', _valueOrDash(warid.chairmanReturnNumber)),
          _PdfField(
              'تاريخ رد رئيس الهيئة', _formatDate(warid.chairmanReturnDate)),
        ],
      ),
      _buildFieldSection(
        title: 'التوزيع',
        fields: [
          _PdfField('المستلم الأول', _valueOrDash(warid.recipient1Name)),
          _PdfField(
              'تاريخ تسليم الأول', _formatDate(warid.recipient1DeliveryDate)),
          _PdfField('المستلم الثاني', _valueOrDash(warid.recipient2Name)),
          _PdfField(
              'تاريخ تسليم الثاني', _formatDate(warid.recipient2DeliveryDate)),
          _PdfField('المستلم الثالث', _valueOrDash(warid.recipient3Name)),
          _PdfField(
              'تاريخ تسليم الثالث', _formatDate(warid.recipient3DeliveryDate)),
        ],
      ),
      _buildFieldSection(
        title: 'التصنيف والمرفقات',
        fields: [
          _PdfField('وزارة', _boolLabel(warid.isMinistry)),
          _PdfField('هيئة', _boolLabel(warid.isAuthority)),
          _PdfField('أخرى', _boolLabel(warid.isOther)),
          _PdfField('تفاصيل أخرى', _valueOrDash(warid.otherDetails)),
          _PdfField('اسم الملف', _valueOrDash(warid.fileName)),
          _PdfField('مسار الملف', _valueOrDash(warid.filePath)),
        ],
      ),
      _buildFieldSection(
        title: 'المتابعة',
        fields: [
          _PdfField('تحتاج متابعة', _boolLabel(warid.needsFollowup)),
          _PdfField('حالة المتابعة', _followupLabel(warid.followupStatus)),
          _PdfField('اسم ملف المتابعة', _valueOrDash(warid.followupFileName)),
          _PdfField('مسار ملف المتابعة', _valueOrDash(warid.followupFilePath)),
        ],
      ),
      _buildLongTextSection(
        title: 'ملاحظات المتابعة',
        value: _valueOrDash(warid.followupNotes),
      ),
      _buildFieldSection(
        title: 'بيانات الإنشاء والتحديث',
        fields: [
          _PdfField('تاريخ الإنشاء', _formatDateTime(warid.createdAt)),
          _PdfField('آخر تحديث', _formatDateTime(warid.updatedAt)),
          _PdfField('معرف المستخدم المنشئ', warid.createdBy?.toString() ?? '-'),
          _PdfField('اسم المستخدم المنشئ', _valueOrDash(warid.createdByName)),
        ],
      ),
    ];
  }

  List<pw.Widget> _buildSadirFullRecordWidgets({
    required SadirModel sadir,
    required int index,
    required int total,
  }) {
    return [
      _buildRecordHeader(
        title: 'نموذج الصادر الشامل (A3)',
        subtitle: 'سجل صادر رقم ${sadir.qaidNumber}',
        index: index,
        total: total,
      ),
      pw.SizedBox(height: 8),
      _buildLongTextSection(
        title: 'الموضوع',
        value: _valueOrDash(sadir.subject),
      ),
      _buildLongTextSection(
        title: 'ملاحظات',
        value: _valueOrDash(sadir.notes),
      ),
      _buildFieldSection(
        title: 'بيانات القيد الأساسية',
        fields: [
          _PdfField('معرف السجل', sadir.id?.toString() ?? '-'),
          _PdfField('رقم القيد', sadir.qaidNumber),
          _PdfField('تاريخ القيد', _formatDate(sadir.qaidDate)),
          _PdfField('الجهة المرسل إليها',
              _valueOrDash(sadir.destinationAdministration)),
          _PdfField('رقم الخطاب', _valueOrDash(sadir.letterNumber)),
          _PdfField('تاريخ الخطاب', _formatDate(sadir.letterDate)),
          _PdfField('عدد المرفقات', sadir.attachmentCount.toString()),
        ],
      ),
      _buildFieldSection(
        title: 'أرقام رئيس الهيئة',
        fields: [
          _PdfField('رقم وارد رئيس الهيئة',
              _valueOrDash(sadir.chairmanIncomingNumber)),
          _PdfField('تاريخ وارد رئيس الهيئة',
              _formatDate(sadir.chairmanIncomingDate)),
          _PdfField(
              'رقم رد رئيس الهيئة', _valueOrDash(sadir.chairmanReturnNumber)),
          _PdfField(
              'تاريخ رد رئيس الهيئة', _formatDate(sadir.chairmanReturnDate)),
        ],
      ),
      _buildFieldSection(
        title: 'التوقيع',
        fields: [
          _PdfField('حالة التوقيع', _signatureLabel(sadir.signatureStatus)),
          _PdfField('تاريخ التوقيع', _formatDate(sadir.signatureDate)),
        ],
      ),
      _buildFieldSection(
        title: 'جهات الإرسال',
        fields: [
          _PdfField('المرسل إليه الأول', _valueOrDash(sadir.sentTo1Name)),
          _PdfField(
              'تاريخ تسليم الأول', _formatDate(sadir.sentTo1DeliveryDate)),
          _PdfField('المرسل إليه الثاني', _valueOrDash(sadir.sentTo2Name)),
          _PdfField(
              'تاريخ تسليم الثاني', _formatDate(sadir.sentTo2DeliveryDate)),
          _PdfField('المرسل إليه الثالث', _valueOrDash(sadir.sentTo3Name)),
          _PdfField(
              'تاريخ تسليم الثالث', _formatDate(sadir.sentTo3DeliveryDate)),
        ],
      ),
      _buildFieldSection(
        title: 'التصنيف والمرفقات',
        fields: [
          _PdfField('وزارة', _boolLabel(sadir.isMinistry)),
          _PdfField('هيئة', _boolLabel(sadir.isAuthority)),
          _PdfField('أخرى', _boolLabel(sadir.isOther)),
          _PdfField('تفاصيل أخرى', _valueOrDash(sadir.otherDetails)),
          _PdfField('اسم الملف', _valueOrDash(sadir.fileName)),
          _PdfField('مسار الملف', _valueOrDash(sadir.filePath)),
        ],
      ),
      _buildFieldSection(
        title: 'المتابعة',
        fields: [
          _PdfField('تحتاج متابعة', _boolLabel(sadir.needsFollowup)),
          _PdfField('حالة المتابعة', _followupLabel(sadir.followupStatus)),
          _PdfField('اسم ملف المتابعة', _valueOrDash(sadir.followupFileName)),
          _PdfField('مسار ملف المتابعة', _valueOrDash(sadir.followupFilePath)),
        ],
      ),
      _buildLongTextSection(
        title: 'ملاحظات المتابعة',
        value: _valueOrDash(sadir.followupNotes),
      ),
      _buildFieldSection(
        title: 'بيانات الإنشاء والتحديث',
        fields: [
          _PdfField('تاريخ الإنشاء', _formatDateTime(sadir.createdAt)),
          _PdfField('آخر تحديث', _formatDateTime(sadir.updatedAt)),
          _PdfField('معرف المستخدم المنشئ', sadir.createdBy?.toString() ?? '-'),
          _PdfField('اسم المستخدم المنشئ', _valueOrDash(sadir.createdByName)),
        ],
      ),
    ];
  }

  pw.Widget _buildWaridTemplatePage({
    required List<WaridModel> pageRecords,
    required pw.MemoryImage templateImage,
    required int pageNumber,
    required int totalPages,
  }) {
    final pageWidth = PdfPageFormat.a3.width;
    final pageHeight = PdfPageFormat.a3.height;
    final rowHeightPx =
        (_waridRowsBottomPx - _waridRowsTopPx) / _waridRowsPerPage;

    double scaleX(double px) => (px / _waridTemplateWidthPx) * pageWidth;
    double scaleY(double px) => (px / _waridTemplateHeightPx) * pageHeight;

    final overlay = <pw.Widget>[
      pw.Positioned(
        right: scaleX(24),
        top: scaleY(24),
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: PdfColors.grey700, width: 0.4),
          ),
          child: pw.Text(
            'صفحة $pageNumber من $totalPages',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      ),
    ];

    for (var index = 0; index < pageRecords.length; index++) {
      final warid = pageRecords[index];
      final topPx = _waridRowsTopPx + (index * rowHeightPx);
      final bottomPx = topPx + rowHeightPx;

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[0],
          rightPx: _waridColumnBoundariesPx[1],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[1],
          rightPx: _waridColumnBoundariesPx[2],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: _truncate(warid.subject, 44),
          fontSize: 7.2,
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[2],
          rightPx: _waridColumnBoundariesPx[3],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: _truncate(warid.sourceAdministration, 20),
          fontSize: 6.6,
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[3],
          rightPx: _waridColumnBoundariesPx[4],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: _formatDate(warid.letterDate),
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[4],
          rightPx: _waridColumnBoundariesPx[5],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: warid.letterNumber ?? '-',
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[5],
          rightPx: _waridColumnBoundariesPx[6],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: _truncate(warid.recipient1Name ?? '-', 16),
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[6],
          rightPx: _waridColumnBoundariesPx[7],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: _formatDate(warid.recipient1DeliveryDate),
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[7],
          rightPx: _waridColumnBoundariesPx[8],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: warid.chairmanIncomingNumber ?? '-',
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[8],
          rightPx: _waridColumnBoundariesPx[9],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: _formatDate(warid.chairmanIncomingDate),
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[9],
          rightPx: _waridColumnBoundariesPx[10],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: warid.chairmanReturnNumber ?? '-',
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[10],
          rightPx: _waridColumnBoundariesPx[11],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: _formatDate(warid.chairmanReturnDate),
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[11],
          rightPx: _waridColumnBoundariesPx[12],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: _formatDate(warid.qaidDate),
        ),
      );

      overlay.addAll(
        _buildWaridTemplateRow(
          leftPx: _waridColumnBoundariesPx[12],
          rightPx: _waridColumnBoundariesPx[13],
          topPx: topPx,
          bottomPx: bottomPx,
          scaleX: scaleX,
          scaleY: scaleY,
          value: warid.qaidNumber,
        ),
      );
    }

    return pw.Stack(
      children: [
        pw.Positioned.fill(
          child: pw.Image(templateImage, fit: pw.BoxFit.fill),
        ),
        ...overlay,
      ],
    );
  }

  List<pw.Widget> _buildWaridTemplateRow({
    required double leftPx,
    required double rightPx,
    required double topPx,
    required double bottomPx,
    required double Function(double px) scaleX,
    required double Function(double px) scaleY,
    String? value,
    double fontSize = 7.0,
  }) {
    final resolved = value ?? '-';
    final text = _valueOrDash(resolved);
    return [
      pw.Positioned(
        left: scaleX(leftPx + 2),
        top: scaleY(topPx + 2),
        child: pw.SizedBox(
          width: scaleX((rightPx - leftPx) - 4),
          height: scaleY((bottomPx - topPx) - 4),
          child: pw.Align(
            child: pw.Text(
              text,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        ),
      ),
    ];
  }

  Future<pw.MemoryImage?> _loadWaridTemplateImage() async {
    try {
      final byteData = await rootBundle.load(_waridTemplateAssetPath);
      return pw.MemoryImage(
        Uint8List.view(
          byteData.buffer,
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
    } catch (_) {
      // Fallback to local file path when asset bundle is unavailable.
    }

    if (kIsWeb) {
      return null;
    }

    try {
      final file = File(_waridTemplateAssetPath);
      if (await file.exists()) {
        return pw.MemoryImage(await file.readAsBytes());
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  List<List<WaridModel>> _chunkWaridRecords(
      List<WaridModel> records, int size) {
    final pages = <List<WaridModel>>[];
    for (var i = 0; i < records.length; i += size) {
      final end = (i + size < records.length) ? i + size : records.length;
      pages.add(records.sublist(i, end));
    }
    return pages;
  }

  Future<String> _resolvePdfOutputPath(String fileName) async {
    String? selectedPath;
    try {
      selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ نموذج A3',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
    } catch (_) {
      selectedPath = null;
    }

    if (selectedPath == null || selectedPath.trim().isEmpty) {
      final directory = await getApplicationDocumentsDirectory();
      selectedPath = p.join(directory.path, fileName);
    }

    var normalized = selectedPath.trim();
    if (p.extension(normalized).toLowerCase() != '.pdf') {
      normalized = '$normalized.pdf';
    }
    return normalized;
  }

  pw.Widget _buildHeader({
    required String title,
    required int totalRows,
    String? subtitle,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          title,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            _valueOrDash(subtitle),
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('إجمالي السجلات: $totalRows'),
            pw.Text('تاريخ الطباعة: ${_dateTimeFormat.format(DateTime.now())}'),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTable({
    required pw.Context context,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return pw.TableHelper.fromTextArray(
      context: context,
      headers: headers,
      data: rows,
      tableDirection: pw.TextDirection.rtl,
      headerStyle: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerRight,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    );
  }

  pw.Widget _buildRecordHeader({
    required String title,
    required String subtitle,
    required int index,
    required int total,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _sheetBackgroundColor,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _sheetBorderColor),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: _sheetHeaderColor,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            subtitle,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: _sheetHeaderColor,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('صفحة السجل: $index من $total',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text(
                  'تاريخ التصدير: ${_dateTimeFormat.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFieldSection({
    required String title,
    required List<_PdfField> fields,
    int columns = 2,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        color: _valueCellColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _sheetBorderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const pw.BoxDecoration(
              color: _sectionHeaderColor,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _sheetHeaderColor,
              ),
            ),
          ),
          _buildFieldsTable(fields: fields, columns: columns),
        ],
      ),
    );
  }

  pw.Widget _buildFieldsTable({
    required List<_PdfField> fields,
    required int columns,
  }) {
    final rows = <List<_PdfField?>>[];
    for (var i = 0; i < fields.length; i += columns) {
      final row = <_PdfField?>[];
      for (var c = 0; c < columns; c++) {
        final index = i + c;
        row.add(index < fields.length ? fields[index] : null);
      }
      rows.add(row);
    }

    return pw.Table(
      border: const pw.TableBorder(
        left: pw.BorderSide(color: _sheetBorderColor, width: 0.6),
        right: pw.BorderSide(color: _sheetBorderColor, width: 0.6),
        bottom: pw.BorderSide(color: _sheetBorderColor, width: 0.6),
        horizontalInside: pw.BorderSide(color: _sheetBorderColor, width: 0.4),
        verticalInside: pw.BorderSide(color: _sheetBorderColor, width: 0.4),
      ),
      columnWidths: {
        for (var i = 0; i < columns; i++) (i * 2): const pw.FlexColumnWidth(2),
        for (var i = 0; i < columns; i++)
          (i * 2 + 1): const pw.FlexColumnWidth(3),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              for (final field in row) ...[
                _buildFieldCell(
                  text: field?.label ?? '',
                  isLabel: true,
                ),
                _buildFieldCell(
                  text: field?.value ?? '-',
                  isLabel: false,
                ),
              ],
            ],
          ),
      ],
    );
  }

  pw.Widget _buildFieldCell({
    required String text,
    required bool isLabel,
  }) {
    return pw.Container(
      color: isLabel ? _labelCellColor : _valueCellColor,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        _valueOrDash(text),
        textAlign: isLabel ? pw.TextAlign.center : pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: isLabel ? 9 : 8.6,
          fontWeight: isLabel ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isLabel ? _sheetHeaderColor : PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _buildLongTextSection({
    required String title,
    required String value,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        color: _valueCellColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _sheetBorderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const pw.BoxDecoration(
              color: _sectionHeaderColor,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _sheetHeaderColor,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              _valueOrDash(value),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _savePdfToLocation({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return fileName;
    }

    final outputPath = await _resolvePdfOutputPath(fileName);
    final outputFile = File(outputPath);
    await outputFile.create(recursive: true);
    await outputFile.writeAsBytes(bytes, flush: true);
    return outputFile.path;
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return _dateFormat.format(value);
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return _dateTimeFormat.format(value);
  }

  String _valueOrDash(String? value) {
    final normalized = _normalizeTextForPrint(value);
    return normalized.isEmpty ? '-' : normalized;
  }

  String _normalizeTextForPrint(String? value) {
    var normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return '';
    }

    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(normalized);
    if (hasArabic) {
      normalized = normalized.replaceFirst(RegExp(r'[xX]+$'), '').trimRight();
    }

    return normalized;
  }

  String _boolLabel(bool value) => value ? 'نعم' : 'لا';

  String _followupLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case WaridModel.followupStatusWaitingReply:
        return 'في انتظار الرد';
      case WaridModel.followupStatusCompleted:
        return 'تم الانتهاء من الموضوع';
      default:
        return _valueOrDash(value);
    }
  }

  String _signatureLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'saved':
        return 'حفظ';
      case 'pending':
        return 'انتظار';
      default:
        return _valueOrDash(status);
    }
  }

  String _truncate(String text, int maxChars) {
    final normalized = _normalizeTextForPrint(text);
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 1)}…';
  }

  Future<pw.ThemeData> _buildTheme() async {
    final regular = await _loadRegularFont();
    if (regular == null) {
      return pw.ThemeData.base();
    }

    final bold = await _loadBoldFont() ?? regular;
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
    );
  }

  Future<pw.Font?> _loadRegularFont() async {
    final local = await _loadFirstExistingFont(const [
      r'C:\Windows\Fonts\arial.ttf',
      r'C:\Windows\Fonts\tahoma.ttf',
      '/usr/share/fonts/truetype/noto/NotoNaskhArabic-Regular.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    ]);
    if (local != null) {
      return local;
    }

    try {
      return await PdfGoogleFonts.notoNaskhArabicRegular();
    } catch (_) {
      return null;
    }
  }

  Future<pw.Font?> _loadBoldFont() async {
    final local = await _loadFirstExistingFont(const [
      r'C:\Windows\Fonts\arialbd.ttf',
      r'C:\Windows\Fonts\tahomabd.ttf',
      '/usr/share/fonts/truetype/noto/NotoNaskhArabic-Bold.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
      '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
    ]);
    if (local != null) {
      return local;
    }

    try {
      return await PdfGoogleFonts.notoNaskhArabicBold();
    } catch (_) {
      return null;
    }
  }

  Future<pw.Font?> _loadFirstExistingFont(List<String> candidates) async {
    if (kIsWeb) {
      return null;
    }

    for (final path in candidates) {
      try {
        final file = File(path);
        if (!await file.exists()) {
          continue;
        }

        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          continue;
        }

        return pw.Font.ttf(ByteData.view(bytes.buffer));
      } catch (_) {
        // Try next candidate.
      }
    }

    return null;
  }
}

class _WaridPrintColumn {
  final String title;
  final double flex;

  const _WaridPrintColumn(this.title, this.flex);
}

class _RecipientHeaderCell extends pw.StatelessWidget {
  final String text;

  _RecipientHeaderCell(this.text);

  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 6.4,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }
}

class _PdfField {
  final String label;
  final String value;

  const _PdfField(this.label, this.value);
}
