import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import 'package:railway_secretariat/features/ocr/data/models/ocr_field_definitions.dart';

class OcrService {
  static const Set<String> _supportedImageExtensions = <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.bmp',
    '.tif',
    '.tiff',
    '.webp',
  };

  static const String _defaultTesseractCommand = 'tesseract';
  static const String _defaultLanguage = 'ara+eng';

  static const List<String> _waridKeywords = <String>[
    '\u0648\u0627\u0631\u062f',
    '\u0627\u0644\u0648\u0627\u0631\u062f',
    '\u0627\u0644\u0642\u064a\u062f \u0627\u0644\u0648\u0627\u0631\u062f',
    '\u0627\u0644\u062c\u0647\u0629 \u0627\u0644\u0648\u0627\u0631\u062f \u0645\u0646\u0647\u0627',
    '\u0648\u0627\u0631\u062f \u0631\u0626\u064a\u0633 \u0627\u0644\u0647\u064a\u0626\u0629',
  ];

  static const List<String> _sadirKeywords = <String>[
    '\u0635\u0627\u062f\u0631',
    '\u0627\u0644\u0635\u0627\u062f\u0631',
    '\u0627\u0644\u0642\u064a\u062f \u0627\u0644\u0635\u0627\u062f\u0631',
    '\u0627\u0644\u062c\u0647\u0629 \u0627\u0644\u0645\u0631\u0633\u0644 \u0625\u0644\u064a\u0647\u0627',
    '\u0635\u0627\u062f\u0631 \u0631\u0626\u064a\u0633 \u0627\u0644\u0647\u064a\u0626\u0629',
  ];

  Future<String> extractTextFromFile({
    required String filePath,
    String? tesseractCommand,
    String? language,
    int maxPdfPages = 4,
  }) async {
    if (kIsWeb) {
      throw StateError(
        '\u004f\u0043\u0052 \u0627\u0644\u0645\u062d\u0644\u064a \u063a\u064a\u0631 \u0645\u062f\u0639\u0648\u0645 \u0639\u0644\u0649 \u0627\u0644\u0648\u064a\u0628 \u062d\u0627\u0644\u064a\u064b\u0627.',
      );
    }

    final extension = p.extension(filePath).toLowerCase().trim();
    final command = _resolveCommand(tesseractCommand);
    final lang = (language ?? _defaultLanguage).trim();

    if (extension == '.pdf') {
      return _extractTextFromPdf(
        filePath,
        tesseractCommand: command,
        language: lang,
        maxPages: maxPdfPages,
      );
    }

    if (_supportedImageExtensions.contains(extension)) {
      return _runTesseractOnImage(
        imagePath: filePath,
        tesseractCommand: command,
        language: lang,
      );
    }

    throw StateError(
      '\u0635\u064a\u063a\u0629 \u0627\u0644\u0645\u0644\u0641 \u063a\u064a\u0631 \u0645\u062f\u0639\u0648\u0645\u0629 \u0641\u064a OCR: $extension. \u0627\u0644\u0635\u064a\u063a \u0627\u0644\u0645\u0633\u0645\u0648\u062d\u0629: PDF \u0623\u0648 \u0635\u0648\u0631.',
    );
  }

  String detectDocumentType({
    required String text,
    String? fileName,
    String fallbackType = 'warid',
  }) {
    final fallback =
        fallbackType.trim().toLowerCase() == 'sadir' ? 'sadir' : 'warid';

    var waridScore = 0;
    var sadirScore = 0;

    final fromName = detectDocumentTypeByFileName(fileName);
    if (fromName == 'warid') {
      waridScore += 6;
    } else if (fromName == 'sadir') {
      sadirScore += 6;
    }

    final normalizedText = _normalizeForClassification(text);

    for (final keyword in _waridKeywords) {
      if (normalizedText.contains(_normalizeForClassification(keyword))) {
        waridScore += 2;
      }
    }

    for (final keyword in _sadirKeywords) {
      if (normalizedText.contains(_normalizeForClassification(keyword))) {
        sadirScore += 2;
      }
    }

    if (waridScore == sadirScore) {
      return fallback;
    }

    return waridScore > sadirScore ? 'warid' : 'sadir';
  }

  String? detectDocumentTypeByFileName(String? fileName) {
    final name = (fileName ?? '').trim();
    if (name.isEmpty) {
      return null;
    }

    final normalized = _normalizeForClassification(name);

    const waridNameTokens = <String>[
      'warid',
      'incoming',
      'inbound',
      '\u0648\u0627\u0631\u062f',
      '\u0627\u0644\u0648\u0627\u0631\u062f',
    ];

    const sadirNameTokens = <String>[
      'sadir',
      'outgoing',
      'outbound',
      '\u0635\u0627\u062f\u0631',
      '\u0627\u0644\u0635\u0627\u062f\u0631',
    ];

    for (final token in waridNameTokens) {
      if (normalized.contains(_normalizeForClassification(token))) {
        return 'warid';
      }
    }

    for (final token in sadirNameTokens) {
      if (normalized.contains(_normalizeForClassification(token))) {
        return 'sadir';
      }
    }

    return null;
  }

  Map<String, String> extractFields({
    required String text,
    required Map<String, List<String>> fieldAliases,
  }) {
    final normalizedText = _normalizeText(text);
    final lines = normalizedText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(
          (line) => _NormalizedOcrLine(
            original: line,
            normalized: _normalizeForMatching(line),
          ),
        )
        .toList(growable: false);

    final extracted = <String, String>{};

    for (final key in OcrFieldKeys.allKeys) {
      final aliases = fieldAliases[key] ?? const <String>[];
      if (aliases.isEmpty) {
        continue;
      }

      String? value;
      if (_isDateField(key)) {
        value = _extractDateValue(normalizedText, aliases, lines);
      } else if (_isNumberField(key)) {
        value = _extractNumberValue(normalizedText, aliases, lines);
      } else {
        value = _extractLineValue(normalizedText, aliases, lines);
      }

      final cleaned = value?.trim() ?? '';
      if (cleaned.isNotEmpty) {
        extracted[key] = cleaned;
      }
    }

    return extracted;
  }

  Future<String> _extractTextFromPdf(
    String pdfPath, {
    required String tesseractCommand,
    required String language,
    required int maxPages,
  }) async {
    final bytes = await File(pdfPath).readAsBytes();
    final tempDir = await getTemporaryDirectory();
    final textBuffer = StringBuffer();

    var pageCount = 0;
    await for (final page in Printing.raster(bytes, dpi: 220)) {
      if (pageCount >= maxPages) {
        break;
      }

      final imageBytes = await page.toPng();
      final imagePath = p.join(
        tempDir.path,
        'ocr_${DateTime.now().microsecondsSinceEpoch}_${pageCount + 1}.png',
      );
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes, flush: true);

      try {
        final pageText = await _runTesseractOnImage(
          imagePath: imagePath,
          tesseractCommand: tesseractCommand,
          language: language,
        );
        if (pageText.trim().isNotEmpty) {
          textBuffer.writeln(pageText);
        }
      } finally {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      }

      pageCount++;
    }

    final extracted = textBuffer.toString().trim();
    if (extracted.isEmpty) {
      throw StateError(
        '\u062a\u0639\u0630\u0631 \u0627\u0633\u062a\u062e\u0631\u0627\u062c \u0646\u0635 \u0645\u0646 \u0645\u0644\u0641 PDF. \u062a\u062d\u0642\u0642 \u0645\u0646 \u062a\u062b\u0628\u064a\u062a Tesseract \u0648\u062c\u0648\u062f\u0629 \u0627\u0644\u0645\u0644\u0641.',
      );
    }

    return extracted;
  }

  Future<String> _runTesseractOnImage({
    required String imagePath,
    required String tesseractCommand,
    required String language,
  }) async {
    ProcessResult result;
    try {
      result = await Process.run(
        tesseractCommand,
        <String>[
          imagePath,
          'stdout',
          '-l',
          language,
          '--psm',
          '6',
        ],
        runInShell: true,
      );
    } on ProcessException {
      throw StateError(
        '\u062a\u0639\u0630\u0631 \u062a\u0634\u063a\u064a\u0644 Tesseract. \u062b\u0628\u062a Tesseract OCR \u0623\u0648 \u062d\u062f\u062f \u0627\u0644\u0645\u0633\u0627\u0631 \u0627\u0644\u0643\u0627\u0645\u0644 \u0644\u0644\u0645\u0644\u0641 \u0627\u0644\u062a\u0646\u0641\u064a\u0630\u064a.',
      );
    }

    if (result.exitCode != 0) {
      final errorMessage = (result.stderr ?? '').toString().trim();
      throw StateError(
        errorMessage.isEmpty
            ? '\u0641\u0634\u0644 \u062a\u0646\u0641\u064a\u0630 Tesseract \u0623\u062b\u0646\u0627\u0621 OCR.'
            : '\u0641\u0634\u0644 \u062a\u0646\u0641\u064a\u0630 Tesseract: $errorMessage',
      );
    }

    return (result.stdout ?? '').toString();
  }

  String _resolveCommand(String? customCommand) {
    final command = customCommand?.trim() ?? '';
    if (command.isNotEmpty) {
      return command;
    }

    if (!kIsWeb && Platform.isWindows) {
      const candidates = <String>[
        r'C:\Program Files\Tesseract-OCR\tesseract.exe',
        r'C:\Program Files (x86)\Tesseract-OCR\tesseract.exe',
      ];
      for (final candidate in candidates) {
        if (File(candidate).existsSync()) {
          return candidate;
        }
      }
    }

    return _defaultTesseractCommand;
  }

  bool _isDateField(String key) {
    return key == OcrFieldKeys.qaidDate ||
        key == OcrFieldKeys.externalDate ||
        key == OcrFieldKeys.chairmanIncomingDate ||
        key == OcrFieldKeys.chairmanReturnDate;
  }

  bool _isNumberField(String key) {
    return key == OcrFieldKeys.qaidNumber ||
        key == OcrFieldKeys.externalNumber ||
        key == OcrFieldKeys.chairmanIncomingNumber ||
        key == OcrFieldKeys.chairmanReturnNumber;
  }

  String _normalizeText(String raw) {
    final normalizedDigits = _normalizeDigits(raw);
    return normalizedDigits
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _normalizeDigits(String value) {
    const arabicDigits = '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669';
    const easternDigits = '\u06f0\u06f1\u06f2\u06f3\u06f4\u06f5\u06f6\u06f7\u06f8\u06f9';
    var output = value;

    for (var i = 0; i < 10; i++) {
      output = output
          .replaceAll(arabicDigits[i], i.toString())
          .replaceAll(easternDigits[i], i.toString());
    }

    return output;
  }

  String _normalizeForClassification(String value) {
    return _normalizeForMatching(value)
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeForMatching(String value) {
    return _normalizeDigits(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('\u0623', '\u0627')
        .replaceAll('\u0625', '\u0627')
        .replaceAll('\u0622', '\u0627')
        .replaceAll('\u0629', '\u0647')
        .replaceAll('\u0649', '\u064a')
        .replaceAll('\u0624', '\u0648')
        .replaceAll('\u0626', '\u064a')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _extractLineValue(
    String text,
    List<String> aliases,
    List<_NormalizedOcrLine> lines,
  ) {
    for (final alias in aliases) {
      final aliasTrimmed = alias.trim();
      if (aliasTrimmed.isEmpty) {
        continue;
      }

      final normalizedAlias = _normalizeForMatching(aliasTrimmed);
      if (normalizedAlias.isEmpty) {
        continue;
      }

      for (final line in lines) {
        if (!_lineContainsAlias(line.normalized, normalizedAlias)) {
          continue;
        }

        final fromSeparator = _cleanupCapturedValue(
          _extractAfterSeparator(line.original),
        );
        if (fromSeparator != null &&
            _normalizeForMatching(fromSeparator) != normalizedAlias) {
          return fromSeparator;
        }

        final strictPattern = RegExp(
          '${RegExp.escape(aliasTrimmed)}\\s*[:\\-]?\\s*([^\\n]{1,180})',
          caseSensitive: false,
        );
        final strictMatch = strictPattern.firstMatch(line.original);
        final strictValue = _cleanupCapturedValue(strictMatch?.group(1));
        if (strictValue != null &&
            _normalizeForMatching(strictValue) != normalizedAlias) {
          return strictValue;
        }
      }
    }

    for (final alias in aliases) {
      final escaped = RegExp.escape(alias.trim());
      if (escaped.isEmpty) {
        continue;
      }

      final pattern = RegExp(
        '$escaped\\s*[:\\-]?\\s*([^\\n]{1,180})',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(text);
      if (match != null) {
        final candidate = _cleanupCapturedValue(match.group(1));
        if (candidate != null) {
          return candidate;
        }
      }
    }

    return null;
  }

  String? _extractNumberValue(
    String text,
    List<String> aliases,
    List<_NormalizedOcrLine> lines,
  ) {
    final lineValue = _extractLineValue(text, aliases, lines);
    if (lineValue == null) {
      return null;
    }

    final match =
        RegExp(r'[\u0600-\u06FFA-Za-z0-9/\-]{2,}').firstMatch(lineValue);
    final normalized = _normalizeDigits(match?.group(0) ?? lineValue).trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _extractDateValue(
    String text,
    List<String> aliases,
    List<_NormalizedOcrLine> lines,
  ) {
    final datePattern = RegExp(
      r'([0-3]?\d\s*[\/\-.]\s*[0-1]?\d\s*[\/\-.]\s*(?:\d{4}|\d{2}))',
      caseSensitive: false,
    );

    for (final alias in aliases) {
      final escaped = RegExp.escape(alias.trim());
      if (escaped.isEmpty) {
        continue;
      }

      final linePattern = RegExp(
        '$escaped[^\\n]{0,70}?${datePattern.pattern}',
        caseSensitive: false,
      );
      final lineMatch = linePattern.firstMatch(text);
      if (lineMatch != null) {
        final parsed = _parseDateToken(lineMatch.group(1) ?? '');
        if (parsed != null) {
          return parsed;
        }
      }
    }

    final lineValue = _extractLineValue(text, aliases, lines);
    if (lineValue == null) {
      return null;
    }
    return _parseDateToken(lineValue);
  }

  bool _lineContainsAlias(String normalizedLine, String normalizedAlias) {
    if (!normalizedLine.contains(normalizedAlias)) {
      return false;
    }

    final bounded = RegExp(
      '(^|\\s)${RegExp.escape(normalizedAlias)}(\\s|\\b)',
      caseSensitive: false,
    );
    return bounded.hasMatch(normalizedLine) ||
        normalizedLine.contains(normalizedAlias);
  }

  String? _extractAfterSeparator(String line) {
    final match = RegExp(r'[:\-\|]\s*(.+)$').firstMatch(line);
    return match?.group(1);
  }

  String? _cleanupCapturedValue(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    final withoutTail = normalized
        .replaceAll(RegExp(r'[|]+$'), '')
        .replaceAll(RegExp(r'[:\-]+$'), '')
        .trim();

    return withoutTail.isEmpty ? null : withoutTail;
  }

  String? _parseDateToken(String raw) {
    var value = _normalizeDigits(raw).trim();
    if (value.isEmpty) {
      return null;
    }

    final tokenMatch = RegExp(
      r'[0-3]?\d\s*[\/\-.]\s*[0-1]?\d\s*[\/\-.]\s*(?:\d{4}|\d{2})',
    ).firstMatch(value);
    if (tokenMatch == null) {
      return null;
    }

    value = tokenMatch
        .group(0)!
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('-', '/')
        .replaceAll('.', '/');

    final parts = value.split('/');
    if (parts.length != 3) {
      return null;
    }

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    var year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }

    if (year < 100) {
      year += year >= 70 ? 1900 : 2000;
    }

    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final parsed = DateTime.tryParse(
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    );
    if (parsed == null) {
      return null;
    }

    return '${parsed.year.toString().padLeft(4, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.day.toString().padLeft(2, '0')}';
  }
}

class _NormalizedOcrLine {
  final String original;
  final String normalized;

  const _NormalizedOcrLine({
    required this.original,
    required this.normalized,
  });
}
