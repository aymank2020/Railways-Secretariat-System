import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:railway_secretariat/features/documents/data/datasources/pdf_batch_split_service.dart';
import 'package:railway_secretariat/utils/helpers.dart';

class PdfBatchSplitScreen extends StatefulWidget {
  const PdfBatchSplitScreen({super.key});

  @override
  State<PdfBatchSplitScreen> createState() => _PdfBatchSplitScreenState();
}

class _PdfBatchSplitScreenState extends State<PdfBatchSplitScreen> {
  final PdfBatchSplitService _splitService = PdfBatchSplitService();
  final TextEditingController _numbersController = TextEditingController();

  String? _combinedPdfPath;
  String? _separatorImagePath;
  String? _outputDirectoryPath;
  double _minimumSimilarity = 0.88;
  bool _isProcessing = false;
  PdfSplitResult? _lastResult;
  String? _lastError;

  @override
  void dispose() {
    _numbersController.dispose();
    super.dispose();
  }

  Future<void> _pickCombinedPdf() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    setState(() {
      _combinedPdfPath = picked.files.single.path;
    });
  }

  Future<void> _pickSeparatorImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    setState(() {
      _separatorImagePath = picked.files.single.path;
    });
  }

  Future<void> _pickOutputDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مجلد حفظ الملفات الناتجة',
    );
    if (!mounted || path == null || path.trim().isEmpty) {
      return;
    }

    setState(() {
      _outputDirectoryPath = path.trim();
    });
  }

  Future<void> _runSplit() async {
    if (kIsWeb) {
      Helpers.showSnackBar(
        context,
        'الأداة غير مدعومة في نسخة الويب حاليًا',
        isError: true,
      );
      return;
    }

    final combinedPdfPath = _combinedPdfPath?.trim() ?? '';
    if (combinedPdfPath.isEmpty) {
      Helpers.showSnackBar(context, 'اختر ملف PDF المجمّع أولًا',
          isError: true);
      return;
    }

    final separatorImagePath = _separatorImagePath?.trim() ?? '';
    if (separatorImagePath.isEmpty) {
      Helpers.showSnackBar(context, 'اختر صورة الفاصل (note.jpeg)',
          isError: true);
      return;
    }

    final outputDirectoryPath = _outputDirectoryPath?.trim() ?? '';
    if (outputDirectoryPath.isEmpty) {
      Helpers.showSnackBar(context, 'اختر مجلد حفظ الملفات الناتجة',
          isError: true);
      return;
    }

    final numbers = _parseNumbers(_numbersController.text);
    if (numbers.isEmpty) {
      Helpers.showSnackBar(
        context,
        'أدخل أرقام الملفات (سطر لكل رقم أو مفصولة بفاصلة)',
        isError: true,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastError = null;
      _lastResult = null;
    });

    try {
      final result = await _splitService.splitBySeparatorImage(
        combinedPdfPath: combinedPdfPath,
        separatorImagePath: separatorImagePath,
        orderedNumbers: numbers,
        outputDirectoryPath: outputDirectoryPath,
        minimumSimilarity: _minimumSimilarity,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastResult = result;
      });
      Helpers.showSnackBar(
        context,
        'تم التقسيم بنجاح (${result.files.length} ملف)',
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastError = e.toString();
      });
      Helpers.showSnackBar(context, 'فشل التقسيم: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  List<String> _parseNumbers(String input) {
    final normalized = _normalizeDigits(input);
    return normalized
        .split(RegExp(r'[\n,;]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String _normalizeDigits(String input) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const easternDigits = '۰۱۲۳۴۵۶۷۸۹';
    var output = input;

    for (var i = 0; i < 10; i++) {
      output = output
          .replaceAll(arabicDigits[i], i.toString())
          .replaceAll(easternDigits[i], i.toString());
    }

    return output;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقسيم PDF بالفاصل'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ارفع ملف PDF المجمّع وصورة الفاصل، ثم أدخل أرقام الملفات بالترتيب.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildPathPickerTile(
              title: 'ملف PDF المجمّع',
              path: _combinedPdfPath,
              buttonLabel: 'اختيار PDF',
              icon: Icons.picture_as_pdf,
              onPick: _pickCombinedPdf,
            ),
            const SizedBox(height: 10),
            _buildPathPickerTile(
              title: 'صورة الفاصل (note.jpeg)',
              path: _separatorImagePath,
              buttonLabel: 'اختيار صورة',
              icon: Icons.image,
              onPick: _pickSeparatorImage,
            ),
            const SizedBox(height: 10),
            _buildPathPickerTile(
              title: 'مجلد الحفظ',
              path: _outputDirectoryPath,
              buttonLabel: 'اختيار مجلد',
              icon: Icons.folder_open,
              onPick: _pickOutputDirectory,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _numbersController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'أرقام الملفات بالترتيب',
                hintText: 'مثال:\n1063\n1064\n1065\nأو: 1063,1064,1065',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نسبة تطابق الفاصل: ${(_minimumSimilarity * 100).toStringAsFixed(0)}%',
                    ),
                    Slider(
                      value: _minimumSimilarity,
                      min: 0.70,
                      max: 0.98,
                      divisions: 28,
                      label: _minimumSimilarity.toStringAsFixed(2),
                      onChanged: _isProcessing
                          ? null
                          : (value) {
                              setState(() {
                                _minimumSimilarity = value;
                              });
                            },
                    ),
                    const Text(
                      'قلّل النسبة إذا لم يتعرف على الفاصل، وارفعها إذا التقط صفحات غير الفاصل. '
                      'وعند عدم تطابق عدد الملفات مع الأرقام، سيحاول النظام ضبط العتبة تلقائيًا.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _runSplit,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isProcessing ? 'جاري التقسيم...' : 'ابدأ التقسيم'),
            ),
            if (_lastError != null) ...[
              const SizedBox(height: 14),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _lastError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
            if (_lastResult != null) ...[
              const SizedBox(height: 14),
              _buildResultCard(_lastResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPathPickerTile({
    required String title,
    required String? path,
    required String buttonLabel,
    required IconData icon,
    required VoidCallback onPick,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SelectableText(
              path?.trim().isNotEmpty == true ? path! : 'لم يتم الاختيار بعد',
              style: TextStyle(
                color: path?.trim().isNotEmpty == true
                    ? Colors.black87
                    : Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isProcessing ? null : onPick,
              icon: Icon(icon),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(PdfSplitResult result) {
    final separatorsText =
        result.separatorPages.map((index) => (index + 1).toString()).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تم إنشاء ${result.files.length} ملف',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'صفحات الفواصل المكتشفة: $separatorsText',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              'عتبة التطابق المستخدمة: ${result.similarityThreshold.toStringAsFixed(3)}',
              style: const TextStyle(fontSize: 13),
            ),
            const Divider(height: 22),
            ...result.files.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${file.number}  ->  ${file.filePath}  (${file.pageCount} صفحة)',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
