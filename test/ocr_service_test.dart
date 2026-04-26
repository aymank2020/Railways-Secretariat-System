import 'package:flutter_test/flutter_test.dart';

import 'package:railway_secretariat/features/ocr/data/datasources/ocr_service.dart';
import 'package:railway_secretariat/features/ocr/data/models/ocr_field_definitions.dart';

void main() {
  final service = OcrService();

  group('OcrService type detection', () {
    test('detects incoming document by filename token', () {
      final result = service.detectDocumentTypeByFileName('incoming_1063.pdf');
      expect(result, 'warid');
    });

    test('detects outgoing document from OCR text', () {
      const text = '''
      القيد الصادر
      الجهة المرسل إليها: وزارة النقل
      ''';
      final result = service.detectDocumentType(
        text: text,
      );
      expect(result, 'sadir');
    });
  });

  group('OcrService field extraction', () {
    test('extracts key warid fields and normalizes date/digits', () {
      const text = '''
      رقم القيد : ١٢٣/أ
      تاريخ القيد : 05-03-2026
      الجهة الوارد منها : وزارة النقل
      الموضوع - متابعة التشغيل
      ''';

      final extracted = service.extractFields(
        text: text,
        fieldAliases: defaultOcrFieldAliases('warid'),
      );

      expect(extracted[OcrFieldKeys.qaidNumber], contains('123'));
      expect(extracted[OcrFieldKeys.qaidDate], '2026/03/05');
      expect(extracted[OcrFieldKeys.entity], 'وزارة النقل');
      expect(extracted[OcrFieldKeys.subject], 'متابعة التشغيل');
    });

    test('matches aliases with Arabic normalization variants', () {
      const text = 'الجهة الوارد منها : هيئة النقل';
      final extracted = service.extractFields(
        text: text,
        fieldAliases: <String, List<String>>{
          OcrFieldKeys.entity: <String>['الجهه الوارد منها'],
        },
      );

      expect(extracted[OcrFieldKeys.entity], 'هيئة النقل');
    });
  });
}
