import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:railway_secretariat/core/di/app_dependencies.dart';
import 'package:railway_secretariat/core/services/document_scan_service.dart';
import 'package:railway_secretariat/features/ocr/domain/usecases/ocr_template_use_cases.dart';
import 'package:railway_secretariat/features/ocr/data/models/ocr_field_definitions.dart';
import 'package:railway_secretariat/features/ocr/data/models/ocr_template_model.dart';
import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/documents/data/models/warid_model.dart';
import 'package:railway_secretariat/features/ocr/data/datasources/ocr_service.dart';
import 'package:railway_secretariat/utils/helpers.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/sadir_form_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/warid_form_screen.dart';

class OcrAutomationScreen extends StatefulWidget {
  const OcrAutomationScreen({super.key});

  @override
  State<OcrAutomationScreen> createState() => _OcrAutomationScreenState();
}

class _OcrAutomationScreenState extends State<OcrAutomationScreen> {
  late final OcrTemplateUseCases _ocrTemplateUseCases;
  final OcrService _ocrService = OcrService();
  final DocumentScanService _documentScanService = DocumentScanService();
  bool _isDependenciesReady = false;

  final TextEditingController _templateNameController = TextEditingController();
  final TextEditingController _tesseractCommandController =
      TextEditingController(text: 'tesseract');
  final TextEditingController _languageController =
      TextEditingController(text: 'ara+eng');

  final Map<String, TextEditingController> _aliasControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _waridValueControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _sadirValueControllers =
      <String, TextEditingController>{};

  String _documentType = 'warid';
  String? _autoDetectedType;
  List<OcrTemplateModel> _templates = <OcrTemplateModel>[];
  OcrTemplateModel? _selectedTemplate;

  bool _isLoadingTemplates = true;
  bool _isSavingTemplate = false;
  bool _isExtracting = false;

  String? _selectedFilePath;
  String? _selectedFileName;
  String _rawText = '';

  @override
  void initState() {
    super.initState();
    for (final field in ocrFieldDefinitions) {
      _aliasControllers[field.key] = TextEditingController();
      _waridValueControllers[field.key] = TextEditingController();
      _sadirValueControllers[field.key] = TextEditingController();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isDependenciesReady) {
      return;
    }
    _ocrTemplateUseCases = context.read<AppDependencies>().ocrTemplateUseCases;
    _isDependenciesReady = true;
    _loadTemplates();
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    _tesseractCommandController.dispose();
    _languageController.dispose();
    for (final controller in _aliasControllers.values) {
      controller.dispose();
    }
    for (final controller in _waridValueControllers.values) {
      controller.dispose();
    }
    for (final controller in _sadirValueControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplates({int? preferredTemplateId}) async {
    setState(() {
      _isLoadingTemplates = true;
    });

    try {
      final templates =
          await _ocrTemplateUseCases.getTemplates(documentType: _documentType);
      OcrTemplateModel? selected;
      if (templates.isNotEmpty) {
        if (preferredTemplateId == null) {
          selected = templates.first;
        } else {
          selected = templates.firstWhere(
            (item) => item.id == preferredTemplateId,
            orElse: () => templates.first,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _templates = templates;
        _selectedTemplate = selected;
        _isLoadingTemplates = false;
      });
      _applyTemplateToControllers(selected);
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('[OcrAutomationScreen] Failed to load templates: $e\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingTemplates = false;
      });
      Helpers.showSnackBar(
        context,
        'تعذر تحميل قوالب OCR.',
        isError: true,
      );
      _applyTemplateToControllers(null);
    }
  }

  void _applyTemplateToControllers(OcrTemplateModel? template) {
    final fallbackAliases = defaultOcrFieldAliases(_documentType);
    _templateNameController.text = template?.name ?? '';
    final languageValue = template?.tesseractLanguage.trim() ?? '';
    _languageController.text =
        languageValue.isEmpty ? 'ara+eng' : languageValue;

    for (final field in ocrFieldDefinitions) {
      final aliases =
          template?.fieldAliases[field.key] ?? fallbackAliases[field.key] ?? [];
      _aliasControllers[field.key]?.text = aliases.join('، ');
    }
  }

  void _onTemplateChanged(int? templateId) {
    if (templateId == null) {
      setState(() {
        _selectedTemplate = null;
      });
      _applyTemplateToControllers(null);
      return;
    }

    final template = _templates.firstWhere((item) => item.id == templateId);
    setState(() {
      _selectedTemplate = template;
    });
    _applyTemplateToControllers(template);
  }

  Future<void> _changeDocumentType(
    String type, {
    bool autoDetected = false,
    bool showMessage = false,
  }) async {
    final normalized = type.trim().toLowerCase();
    if (normalized != 'warid' && normalized != 'sadir') {
      return;
    }

    final changed = normalized != _documentType;
    if (!changed && !autoDetected) {
      return;
    }

    setState(() {
      _documentType = normalized;
      _selectedTemplate = null;
      if (autoDetected) {
        _autoDetectedType = normalized;
      }
    });

    if (changed) {
      await _loadTemplates();
      if (showMessage && mounted) {
        Helpers.showSnackBar(
          context,
          'تم اختيار قسم ${_documentTypeName(normalized)} تلقائيًا.',
        );
      }
    }
  }

  Future<void> _pickFile() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('اختيار ملف'),
                onTap: () => Navigator.of(sheetContext).pop('file'),
              ),
              if (DocumentScanService.isCameraSupported)
                ListTile(
                  leading: const Icon(Icons.document_scanner_outlined),
                  title: const Text('اسكان بالكاميرا'),
                  onTap: () => Navigator.of(sheetContext).pop('camera'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || source == null) {
      return;
    }

    ScannedDocument? file;
    try {
      if (source == 'camera') {
        file = await _documentScanService.scanFromCamera(
          fileNamePrefix: 'ocr_scan',
        );
      } else {
        file = await _documentScanService.pickFile(
          allowedExtensions: <String>[
            'pdf',
            'png',
            'jpg',
            'jpeg',
            'bmp',
            'tif',
            'tiff',
            'webp',
          ],
        );
      }
    } catch (_) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'تعذر تنفيذ الاسكان. تأكد من السماح للكاميرا أو اختر ملفًا يدويًا.',
          isError: true,
        );
      }
      return;
    }

    if (file == null) {
      return;
    }
    final selectedFile = file;

    setState(() {
      _selectedFilePath = selectedFile.path;
      _selectedFileName = selectedFile.name;
    });

    final byName = _ocrService.detectDocumentTypeByFileName(selectedFile.name);
    if (byName != null) {
      await _changeDocumentType(
        byName,
        autoDetected: true,
        showMessage: byName != _documentType,
      );
    }
  }

  Future<void> _runExtraction() async {
    if (_selectedFilePath == null) {
      Helpers.showSnackBar(
        context,
        'اختر ملف PDF أو صورة أولًا.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isExtracting = true;
    });

    try {
      final templateBeforeExtraction =
          _buildTemplateFromInputs(id: _selectedTemplate?.id);

      final rawText = await _ocrService.extractTextFromFile(
        filePath: _selectedFilePath!,
        tesseractCommand: _tesseractCommandController.text.trim(),
        language: templateBeforeExtraction.tesseractLanguage,
      );

      final detectedType = _ocrService.detectDocumentType(
        text: rawText,
        fileName: _selectedFileName,
        fallbackType: _documentType,
      );

      if (detectedType != _documentType) {
        await _changeDocumentType(
          detectedType,
          autoDetected: true,
          showMessage: true,
        );
      } else {
        setState(() {
          _autoDetectedType = detectedType;
        });
      }

      final template = _buildTemplateFromInputs(id: _selectedTemplate?.id);
      final extracted = _ocrService.extractFields(
        text: rawText,
        fieldAliases: template.fieldAliases,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _rawText = rawText;
      });
      _fillExtractedValuesForType(_documentType, extracted);

      Helpers.showSnackBar(
        context,
        'تم استخراج ${extracted.length} حقل في قسم ${_documentTypeName(_documentType)}.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        e.toString().replaceFirst('StateError: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExtracting = false;
        });
      }
    }
  }

  void _fillExtractedValuesForType(
      String documentType, Map<String, String> values) {
    final controllers = _controllersForType(documentType);
    for (final field in ocrFieldDefinitions) {
      controllers[field.key]?.text = values[field.key] ?? '';
    }
  }

  Future<void> _saveTemplate() async {
    final name = _templateNameController.text.trim();
    if (name.isEmpty) {
      Helpers.showSnackBar(
        context,
        'اكتب اسم القالب أولًا.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSavingTemplate = true;
    });

    try {
      final template = _buildTemplateFromInputs(id: _selectedTemplate?.id);
      final savedId = await _ocrTemplateUseCases.saveTemplate(template);
      await _loadTemplates(preferredTemplateId: savedId);
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        'تم حفظ القالب لقسم ${_documentTypeName(_documentType)} بنجاح.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        e.toString().replaceFirst('StateError: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingTemplate = false;
        });
      }
    }
  }

  Future<void> _deleteSelectedTemplate() async {
    final id = _selectedTemplate?.id;
    if (id == null) {
      Helpers.showSnackBar(
        context,
        'اختر قالبًا محفوظًا للحذف.',
        isError: true,
      );
      return;
    }

    final confirmed = await Helpers.showConfirmationDialog(
      context,
      title: 'حذف القالب',
      message: 'هل تريد حذف القالب "${_selectedTemplate!.name}"؟',
      isDangerous: true,
      confirmText: 'حذف',
    );
    if (!confirmed) {
      return;
    }

    try {
      await _ocrTemplateUseCases.deleteTemplate(id);
      if (!mounted) {
        return;
      }
      await _loadTemplates();
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(context, 'تم حذف القالب.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        'تعذر حذف القالب.',
        isError: true,
      );
    }
  }

  OcrTemplateModel _buildTemplateFromInputs({int? id}) {
    final aliases = <String, List<String>>{};
    final fallback = defaultOcrFieldAliases(_documentType);

    for (final field in ocrFieldDefinitions) {
      final raw = _aliasControllers[field.key]?.text ?? '';
      final parsed = _parseAliases(raw);
      aliases[field.key] =
          parsed.isEmpty ? (fallback[field.key] ?? []) : parsed;
    }

    return OcrTemplateModel(
      id: id,
      name: _templateNameController.text.trim(),
      documentType: _documentType,
      tesseractLanguage: _languageController.text.trim().isEmpty
          ? 'ara+eng'
          : _languageController.text.trim(),
      fieldAliases: aliases,
      createdAt: _selectedTemplate?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  List<String> _parseAliases(String raw) {
    return raw
        .split(RegExp(r'[,،;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _openWaridForm() async {
    final model = WaridModel(
      qaidNumber: _textOf(OcrFieldKeys.qaidNumber, documentType: 'warid'),
      qaidDate: _dateOf(OcrFieldKeys.qaidDate, documentType: 'warid') ??
          DateTime.now(),
      sourceAdministration: _textOf(OcrFieldKeys.entity, documentType: 'warid'),
      letterNumber:
          _nullableTextOf(OcrFieldKeys.externalNumber, documentType: 'warid'),
      letterDate: _dateOf(OcrFieldKeys.externalDate, documentType: 'warid'),
      chairmanIncomingNumber: _nullableTextOf(
        OcrFieldKeys.chairmanIncomingNumber,
        documentType: 'warid',
      ),
      chairmanIncomingDate: _dateOf(
        OcrFieldKeys.chairmanIncomingDate,
        documentType: 'warid',
      ),
      chairmanReturnNumber: _nullableTextOf(
        OcrFieldKeys.chairmanReturnNumber,
        documentType: 'warid',
      ),
      chairmanReturnDate: _dateOf(
        OcrFieldKeys.chairmanReturnDate,
        documentType: 'warid',
      ),
      subject: _textOf(OcrFieldKeys.subject, documentType: 'warid').isEmpty
          ? 'بدون موضوع'
          : _textOf(OcrFieldKeys.subject, documentType: 'warid'),
      createdAt: DateTime.now(),
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WaridFormScreen(prefillWarid: model),
      ),
    );
  }

  Future<void> _openSadirForm() async {
    final destination =
        _nullableTextOf(OcrFieldKeys.entity, documentType: 'sadir');
    final subjectText = _textOf(OcrFieldKeys.subject, documentType: 'sadir');

    final model = SadirModel(
      qaidNumber: _textOf(OcrFieldKeys.qaidNumber, documentType: 'sadir'),
      qaidDate: _dateOf(OcrFieldKeys.qaidDate, documentType: 'sadir') ??
          DateTime.now(),
      destinationAdministration: destination,
      letterNumber:
          _nullableTextOf(OcrFieldKeys.externalNumber, documentType: 'sadir'),
      letterDate: _dateOf(OcrFieldKeys.externalDate, documentType: 'sadir'),
      chairmanIncomingNumber: _nullableTextOf(
        OcrFieldKeys.chairmanIncomingNumber,
        documentType: 'sadir',
      ),
      chairmanIncomingDate: _dateOf(
        OcrFieldKeys.chairmanIncomingDate,
        documentType: 'sadir',
      ),
      chairmanReturnNumber: _nullableTextOf(
        OcrFieldKeys.chairmanReturnNumber,
        documentType: 'sadir',
      ),
      chairmanReturnDate: _dateOf(
        OcrFieldKeys.chairmanReturnDate,
        documentType: 'sadir',
      ),
      subject: subjectText.isEmpty ? 'بدون موضوع' : subjectText,
      createdAt: DateTime.now(),
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SadirFormScreen(prefillSadir: model),
      ),
    );
  }

  Map<String, TextEditingController> _controllersForType(String documentType) {
    return documentType == 'sadir'
        ? _sadirValueControllers
        : _waridValueControllers;
  }

  String _textOf(String key, {required String documentType}) {
    return (_controllersForType(documentType)[key]?.text ?? '').trim();
  }

  String? _nullableTextOf(String key, {required String documentType}) {
    final value = _textOf(key, documentType: documentType);
    return value.isEmpty ? null : value;
  }

  DateTime? _dateOf(String key, {required String documentType}) {
    final raw = _textOf(key, documentType: documentType);
    if (raw.isEmpty) {
      return null;
    }
    final normalized = _normalizeDigits(raw).replaceAll('-', '/');
    final token = RegExp(r'([0-3]?\d)[/\.]([0-1]?\d)[/\.]?(\d{2,4})')
        .firstMatch(normalized);
    if (token == null) {
      return null;
    }

    final day = int.tryParse(token.group(1)!);
    final month = int.tryParse(token.group(2)!);
    var year = int.tryParse(token.group(3)!);
    if (day == null || month == null || year == null) {
      return null;
    }

    if (year < 100) {
      year += year >= 70 ? 1900 : 2000;
    }

    return DateTime.tryParse(
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    );
  }

  String _normalizeDigits(String value) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const easternDigits = '۰۱۲۳۴۵۶۷۸۹';
    var output = value;

    for (var i = 0; i < 10; i++) {
      output = output
          .replaceAll(arabicDigits[i], i.toString())
          .replaceAll(easternDigits[i], i.toString());
    }

    return output;
  }

  String _documentTypeName(String type) {
    return type == 'sadir' ? 'الصادر' : 'الوارد';
  }

  String _fieldLabelForType(String key, String documentType) {
    final isWarid = documentType == 'warid';
    switch (key) {
      case OcrFieldKeys.qaidNumber:
        return 'رقم القيد';
      case OcrFieldKeys.qaidDate:
        return isWarid ? 'تاريخ القيد الوارد' : 'تاريخ القيد الصادر';
      case OcrFieldKeys.entity:
        return isWarid ? 'الجهة الوارد منها الخطاب' : 'الجهة المرسل إليها';
      case OcrFieldKeys.externalNumber:
        return 'رقم الوزارة / الجهة الخارجية';
      case OcrFieldKeys.externalDate:
        return 'تاريخ الوزارة / الجهة الخارجية';
      case OcrFieldKeys.chairmanIncomingNumber:
        return isWarid ? 'رقم وارد رئيس الهيئة' : 'رقم صادر رئيس الهيئة';
      case OcrFieldKeys.chairmanIncomingDate:
        return isWarid ? 'تاريخ وارد رئيس الهيئة' : 'تاريخ صادر رئيس الهيئة';
      case OcrFieldKeys.chairmanReturnNumber:
        return 'رقم عائد رئيس الهيئة بعد التوقيع';
      case OcrFieldKeys.chairmanReturnDate:
        return 'تاريخ عائد رئيس الهيئة بعد التوقيع';
      case OcrFieldKeys.subject:
        return 'الموضوع';
      default:
        final fallback = ocrFieldDefinitions.firstWhere(
          (field) => field.key == key,
          orElse: () => const OcrFieldDefinition(key: '', label: ''),
        );
        return fallback.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR والتعبئة التلقائية'),
      ),
      body: _isLoadingTemplates
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSetupCard(),
                  const SizedBox(height: 16),
                  _buildExtractedValuesCard(),
                  const SizedBox(height: 16),
                  _buildTemplateTrainingCard(),
                  const SizedBox(height: 16),
                  _buildRawTextCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSetupCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إعدادات OCR',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'القسم النشط:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(
                      value: 'warid',
                      label: Text('وارد'),
                    ),
                    ButtonSegment<String>(
                      value: 'sadir',
                      label: Text('صادر'),
                    ),
                  ],
                  selected: <String>{_documentType},
                  onSelectionChanged: (selection) {
                    final value = selection.first;
                    _changeDocumentType(value);
                  },
                ),
              ],
            ),
            if (_autoDetectedType != null) ...[
              const SizedBox(height: 8),
              Text(
                'التصنيف التلقائي الحالي: ${_documentTypeName(_autoDetectedType!)}',
                style: TextStyle(color: Colors.green.shade700),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _selectedTemplate?.id,
              decoration: InputDecoration(
                labelText: 'القالب (${_documentTypeName(_documentType)})',
                border: const OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  child: Text('قالب جديد'),
                ),
                ..._templates.map(
                  (template) => DropdownMenuItem<int?>(
                    value: template.id,
                    child: Text(template.name),
                  ),
                ),
              ],
              onChanged: _onTemplateChanged,
            ),
            const SizedBox(height: 12),
            _buildResponsiveRow(
              first: TextField(
                controller: _templateNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم القالب',
                  border: OutlineInputBorder(),
                ),
              ),
              second: TextField(
                controller: _languageController,
                decoration: const InputDecoration(
                  labelText: 'لغة Tesseract',
                  hintText: 'ara+eng',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tesseractCommandController,
              decoration: const InputDecoration(
                labelText: 'أمر Tesseract أو المسار الكامل',
                hintText:
                    r'tesseract أو C:\Program Files\Tesseract-OCR\tesseract.exe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _buildResponsiveRow(
              first: ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('اختيار / اسكان'),
              ),
              second: ElevatedButton.icon(
                onPressed: _isExtracting ? null : _runExtraction,
                icon: _isExtracting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner),
                label: Text(_isExtracting ? 'جارٍ الاستخراج...' : 'تشغيل OCR'),
              ),
            ),
            if (_selectedFileName != null) ...[
              const SizedBox(height: 8),
              Text(
                'الملف المحدد: $_selectedFileName',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedValuesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نتائج الاستخراج',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDocumentSection(
              type: 'warid',
              title: 'قسم الوارد',
              accentColor: Colors.blue,
              onOpenForm: _openWaridForm,
            ),
            const SizedBox(height: 14),
            _buildDocumentSection(
              type: 'sadir',
              title: 'قسم الصادر',
              accentColor: Colors.orange,
              onOpenForm: _openSadirForm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSection({
    required String type,
    required String title,
    required Color accentColor,
    required VoidCallback onOpenForm,
  }) {
    final isActive = _documentType == type;
    final controllers = _controllersForType(type);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isActive ? accentColor : Colors.grey.shade300,
          width: isActive ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isActive
            ? accentColor.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive ? accentColor : Colors.black87,
                ),
              ),
              const Spacer(),
              if (isActive)
                Chip(
                  label: const Text('نشط'),
                  backgroundColor: accentColor.withValues(alpha: 0.15),
                  side: BorderSide.none,
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _changeDocumentType(type),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('تفعيل القسم'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final field in ocrFieldDefinitions) ...[
            TextField(
              controller: controllers[field.key],
              decoration: InputDecoration(
                labelText: _fieldLabelForType(field.key, type),
                border: const OutlineInputBorder(),
              ),
            ),
            if (field != ocrFieldDefinitions.last) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onOpenForm,
            icon: const Icon(Icons.open_in_new),
            label: Text('فتح نموذج ${_documentTypeName(type)}'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateTrainingCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تدريب قالب ${_documentTypeName(_documentType)} (الكلمات الدلالية)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'اكتب لكل حقل كلمات أو عناوين متوقعة في الملف، وافصل بينها بفاصلة.',
            ),
            const SizedBox(height: 12),
            for (final field in ocrFieldDefinitions) ...[
              TextField(
                controller: _aliasControllers[field.key],
                maxLines: 2,
                decoration: InputDecoration(
                  labelText:
                      '${_fieldLabelForType(field.key, _documentType)} - كلمات البحث',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (field != ocrFieldDefinitions.last) const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSavingTemplate ? null : _saveTemplate,
                  icon: _isSavingTemplate
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label:
                      Text(_isSavingTemplate ? 'جارٍ الحفظ...' : 'حفظ القالب'),
                ),
                OutlinedButton.icon(
                  onPressed: _deleteSelectedTemplate,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('حذف القالب'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawTextCard() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        title: const Text(
          'النص الخام المستخرج',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: _rawText.isNotEmpty,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SelectableText(
            _rawText.isEmpty ? 'لم يتم استخراج نص بعد.' : _rawText,
            style: const TextStyle(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveRow({
    required Widget first,
    required Widget second,
  }) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    if (isWide) {
      return Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      );
    }

    return Column(
      children: [
        first,
        const SizedBox(height: 12),
        second,
      ],
    );
  }
}
