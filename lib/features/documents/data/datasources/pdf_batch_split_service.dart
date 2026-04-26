import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfSplitOutputFile {
  final String number;
  final String filePath;
  final int pageCount;

  const PdfSplitOutputFile({
    required this.number,
    required this.filePath,
    required this.pageCount,
  });
}

class PdfSplitResult {
  final List<int> separatorPages;
  final double similarityThreshold;
  final List<double> pageSimilarities;
  final List<PdfSplitOutputFile> files;

  const PdfSplitResult({
    required this.separatorPages,
    required this.similarityThreshold,
    required this.pageSimilarities,
    required this.files,
  });
}

class PdfBatchSplitService {
  static const int _vectorSize = 96;
  static const double _exportDpi = 210;

  Future<PdfSplitResult> splitBySeparatorImage({
    required String combinedPdfPath,
    required String separatorImagePath,
    required List<String> orderedNumbers,
    required String outputDirectoryPath,
    double minimumSimilarity = 0.88,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('تقسيم PDF بهذه الطريقة غير مدعوم على الويب.');
    }

    final normalizedNumbers = orderedNumbers
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (normalizedNumbers.isEmpty) {
      throw ArgumentError('يجب إدخال رقم واحد على الأقل لتسمية الملفات.');
    }

    final combinedFile = File(combinedPdfPath);
    if (!await combinedFile.exists()) {
      throw FileSystemException('ملف PDF غير موجود', combinedPdfPath);
    }

    final separatorFile = File(separatorImagePath);
    if (!await separatorFile.exists()) {
      throw FileSystemException('صورة الفاصل غير موجودة', separatorImagePath);
    }

    final outputDirectory = Directory(outputDirectoryPath);
    await outputDirectory.create(recursive: true);

    final pdfBytes = await combinedFile.readAsBytes();
    if (pdfBytes.isEmpty) {
      throw StateError('ملف PDF فارغ.');
    }

    final separatorImageBytes = await separatorFile.readAsBytes();
    final separatorImage = img.decodeImage(separatorImageBytes);
    if (separatorImage == null) {
      throw StateError('تعذر قراءة صورة الفاصل.');
    }

    final separatorVector = _buildNormalizedVector(separatorImage);
    final pageSimilarities = <double>[];

    await for (final page in Printing.raster(pdfBytes)) {
      final pagePng = await page.toPng();
      final pageImage = img.decodeImage(pagePng);
      if (pageImage == null) {
        pageSimilarities.add(0);
        continue;
      }

      final pageVector = _buildNormalizedVector(pageImage);
      final similarity = _cosineSimilarity(separatorVector, pageVector);
      pageSimilarities.add(similarity);
    }

    if (pageSimilarities.isEmpty) {
      throw StateError('لم يتم العثور على صفحات داخل ملف PDF.');
    }

    final detection = _selectBestDetection(
      scores: pageSimilarities,
      minimumSimilarity: minimumSimilarity,
      expectedSegments: normalizedNumbers.length,
    );
    final similarityThreshold = detection.threshold;
    final separatorPages = detection.separatorPages;
    if (separatorPages.isEmpty) {
      throw StateError(
        'لم يتم اكتشاف صفحات فاصلة. جرب صورة فاصلة أوضح أو قلل نسبة التطابق.',
      );
    }

    final segments = detection.segments;
    if (segments.isEmpty) {
      throw StateError('كل الصفحات تم اعتبارها فواصل. لا توجد ملفات للتقسيم.');
    }

    if (segments.length != normalizedNumbers.length) {
      throw StateError(
        'تعذر ضبط التقسيم ليطابق عدد الأرقام المدخلة. '
        'تم اكتشاف ${segments.length} ملف عند عتبة ${similarityThreshold.toStringAsFixed(3)} '
        'بدلاً من ${normalizedNumbers.length}.',
      );
    }

    final outputs = <PdfSplitOutputFile>[];
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final number = normalizedNumbers[index];
      final sanitizedName = _sanitizeFileName(number);
      final baseOutputPath = p.join(outputDirectory.path, '$sanitizedName.pdf');
      final outputPath = _uniquePath(baseOutputPath);
      final pageIndexes = <int>[
        for (var page = segment.start; page <= segment.end; page++) page,
      ];
      final outputPdf = await _buildPdfFromPages(
        sourcePdfBytes: pdfBytes,
        pageIndexes: pageIndexes,
      );

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(outputPdf, flush: true);

      outputs.add(
        PdfSplitOutputFile(
          number: number,
          filePath: outputFile.path,
          pageCount: segment.length,
        ),
      );
    }

    return PdfSplitResult(
      separatorPages: separatorPages,
      similarityThreshold: similarityThreshold,
      pageSimilarities: pageSimilarities,
      files: outputs,
    );
  }

  List<double> _buildNormalizedVector(img.Image source) {
    final resized = img.copyResize(
      source,
      width: _vectorSize,
      height: _vectorSize,
      interpolation: img.Interpolation.linear,
    );

    final values = List<double>.filled(_vectorSize * _vectorSize, 0);
    var cursor = 0;
    for (var y = 0; y < _vectorSize; y++) {
      for (var x = 0; x < _vectorSize; x++) {
        final pixel = resized.getPixel(x, y);
        final red = pixel.r.toDouble();
        final green = pixel.g.toDouble();
        final blue = pixel.b.toDouble();
        values[cursor] = (0.299 * red + 0.587 * green + 0.114 * blue) / 255.0;
        cursor++;
      }
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((value) => (value - mean) * (value - mean))
            .reduce((a, b) => a + b) /
        values.length;
    final std = math.sqrt(variance);
    final safeStd = std < 1e-6 ? 1e-6 : std;
    return values
        .map((value) => (value - mean) / safeStd)
        .toList(growable: false);
  }

  double _cosineSimilarity(List<double> first, List<double> second) {
    if (first.length != second.length || first.isEmpty) {
      return 0;
    }

    var dot = 0.0;
    var firstNorm = 0.0;
    var secondNorm = 0.0;
    for (var i = 0; i < first.length; i++) {
      final a = first[i];
      final b = second[i];
      dot += a * b;
      firstNorm += a * a;
      secondNorm += b * b;
    }

    final denominator = math.sqrt(firstNorm) * math.sqrt(secondNorm);
    if (denominator <= 1e-9) {
      return 0;
    }

    final raw = dot / denominator;
    if (raw.isNaN || raw.isInfinite) {
      return 0;
    }
    return raw.clamp(-1.0, 1.0).toDouble();
  }

  double _resolveThreshold(List<double> scores, double minimumSimilarity) {
    final normalizedMin = minimumSimilarity.clamp(0.0, 0.99).toDouble();
    if (scores.length < 2) {
      return normalizedMin;
    }

    final mean = scores.reduce((a, b) => a + b) / scores.length;
    final variance = scores
            .map((value) => (value - mean) * (value - mean))
            .reduce((a, b) => a + b) /
        scores.length;
    final std = math.sqrt(variance);

    final adaptive = mean + (std * 1.2);
    return math.max(normalizedMin, math.min(adaptive, 0.995));
  }

  _DetectionResult _selectBestDetection({
    required List<double> scores,
    required double minimumSimilarity,
    required int expectedSegments,
  }) {
    final baseThreshold = _resolveThreshold(scores, minimumSimilarity);
    final candidateThresholds = _buildCandidateThresholds(
      scores: scores,
      minimumSimilarity: minimumSimilarity,
      baseThreshold: baseThreshold,
    );

    _DetectionResult? best;
    for (final threshold in candidateThresholds) {
      final separators = _detectSeparatorPages(scores, threshold);
      if (separators.isEmpty) {
        continue;
      }

      final segments = _buildSegments(
        pageCount: scores.length,
        separators: separators,
      );
      if (segments.isEmpty) {
        continue;
      }

      final candidate = _DetectionResult(
        threshold: threshold,
        separatorPages: separators,
        segments: segments,
      );

      if (best == null ||
          _isBetterDetection(
            candidate: candidate,
            best: best,
            expectedSegments: expectedSegments,
            baseThreshold: baseThreshold,
          )) {
        best = candidate;
      }

      if (candidate.segmentDiff(expectedSegments) == 0 &&
          threshold >= baseThreshold - 1e-9) {
        // Candidate thresholds are sorted high to low; this is the strictest exact match.
        break;
      }
    }

    if (best != null) {
      return best;
    }

    final fallbackSeparators = _detectSeparatorPages(scores, baseThreshold);
    final fallbackSegments = _buildSegments(
      pageCount: scores.length,
      separators: fallbackSeparators,
    );
    return _DetectionResult(
      threshold: baseThreshold,
      separatorPages: fallbackSeparators,
      segments: fallbackSegments,
    );
  }

  bool _isBetterDetection({
    required _DetectionResult candidate,
    required _DetectionResult best,
    required int expectedSegments,
    required double baseThreshold,
  }) {
    final candidateDiff = candidate.segmentDiff(expectedSegments);
    final bestDiff = best.segmentDiff(expectedSegments);

    final candidateIsExact = candidateDiff == 0;
    final bestIsExact = bestDiff == 0;
    if (candidateIsExact != bestIsExact) {
      return candidateIsExact;
    }

    if (candidateDiff != bestDiff) {
      return candidateDiff < bestDiff;
    }

    if (candidateIsExact) {
      if ((candidate.threshold - best.threshold).abs() > 1e-9) {
        return candidate.threshold > best.threshold;
      }
    } else {
      final candidateDistance = (candidate.threshold - baseThreshold).abs();
      final bestDistance = (best.threshold - baseThreshold).abs();
      if ((candidateDistance - bestDistance).abs() > 1e-9) {
        return candidateDistance < bestDistance;
      }
      if ((candidate.threshold - best.threshold).abs() > 1e-9) {
        return candidate.threshold > best.threshold;
      }
    }

    return candidate.separatorPages.length < best.separatorPages.length;
  }

  List<double> _buildCandidateThresholds({
    required List<double> scores,
    required double minimumSimilarity,
    required double baseThreshold,
  }) {
    final thresholds = <double>{};
    thresholds.add(_roundThreshold(baseThreshold));
    thresholds.add(
      _roundThreshold(minimumSimilarity.clamp(0.0, 0.99).toDouble()),
    );

    for (var threshold = 0.70; threshold <= 0.995; threshold += 0.005) {
      thresholds.add(_roundThreshold(threshold));
    }

    for (final score in scores) {
      final normalized = score.clamp(0.0, 0.995).toDouble();
      if (normalized >= 0.70) {
        thresholds.add(_roundThreshold(normalized));
      }
    }

    final sorted = thresholds.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  double _roundThreshold(double value) {
    return double.parse(value.toStringAsFixed(3));
  }

  List<int> _detectSeparatorPages(List<double> scores, double threshold) {
    final separators = <int>[];
    for (var index = 0; index < scores.length; index++) {
      final current = scores[index];
      if (current < threshold) {
        continue;
      }

      final left = index > 0 ? scores[index - 1] : -1.0;
      final right = index < scores.length - 1 ? scores[index + 1] : -1.0;
      if (current >= left && current >= right) {
        separators.add(index);
      }
    }

    return separators;
  }

  List<_PageSegment> _buildSegments({
    required int pageCount,
    required List<int> separators,
  }) {
    final sortedSeparators = separators.toSet().toList()..sort();
    final segments = <_PageSegment>[];

    var start = 0;
    for (final separator in sortedSeparators) {
      if (start <= separator - 1) {
        segments.add(_PageSegment(start: start, end: separator - 1));
      }
      start = separator + 1;
    }

    if (start <= pageCount - 1) {
      segments.add(_PageSegment(start: start, end: pageCount - 1));
    }

    return segments;
  }

  Future<Uint8List> _buildPdfFromPages({
    required Uint8List sourcePdfBytes,
    required List<int> pageIndexes,
  }) async {
    final document = pw.Document();
    var addedPages = 0;

    await for (final raster in Printing.raster(
      sourcePdfBytes,
      pages: pageIndexes,
      dpi: _exportDpi,
    )) {
      final png = await raster.toPng();
      final imageProvider = pw.MemoryImage(png);
      final pageWidth = (raster.width / _exportDpi) * PdfPageFormat.inch;
      final pageHeight = (raster.height / _exportDpi) * PdfPageFormat.inch;

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, pageHeight),
          build: (_) => pw.SizedBox.expand(
            child: pw.Image(imageProvider, fit: pw.BoxFit.fill),
          ),
        ),
      );
      addedPages++;
    }

    if (addedPages == 0) {
      throw StateError('تعذر إنشاء ملف ناتج لهذا الجزء.');
    }

    return document.save();
  }

  String _sanitizeFileName(String rawName) {
    final normalized = rawName.trim();
    if (normalized.isEmpty) {
      return 'document';
    }

    var sanitized = normalized.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
    sanitized = sanitized.trim();
    if (sanitized.isEmpty) {
      return 'document';
    }
    return sanitized;
  }

  String _uniquePath(String basePath) {
    if (!File(basePath).existsSync()) {
      return basePath;
    }

    final directory = p.dirname(basePath);
    final stem = p.basenameWithoutExtension(basePath);
    final extension = p.extension(basePath);
    var counter = 2;

    while (true) {
      final candidate = p.join(directory, '${stem}_$counter$extension');
      if (!File(candidate).existsSync()) {
        return candidate;
      }
      counter++;
    }
  }
}

class _PageSegment {
  final int start;
  final int end;

  const _PageSegment({
    required this.start,
    required this.end,
  });

  int get length => end - start + 1;
}

class _DetectionResult {
  final double threshold;
  final List<int> separatorPages;
  final List<_PageSegment> segments;

  const _DetectionResult({
    required this.threshold,
    required this.separatorPages,
    required this.segments,
  });

  int segmentDiff(int expectedSegments) {
    return (segments.length - expectedSegments).abs();
  }
}
