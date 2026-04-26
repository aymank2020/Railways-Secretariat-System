import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:railway_secretariat/core/services/document_scan_service.dart';
import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/auth/presentation/providers/auth_provider.dart';
import 'package:railway_secretariat/features/documents/presentation/providers/document_provider.dart';
import 'package:railway_secretariat/features/documents/data/datasources/attachment_storage_service.dart';
import 'package:railway_secretariat/utils/helpers.dart';

class SadirFormScreen extends StatefulWidget {
  final SadirModel? editSadir;
  final SadirModel? initialSadir;
  final int? restoreDeletedRecordId;
  final SadirModel? prefillSadir;

  const SadirFormScreen({
    super.key,
    this.editSadir,
    this.initialSadir,
    this.restoreDeletedRecordId,
    this.prefillSadir,
  }) : assert(
          editSadir == null ||
              (initialSadir == null &&
                  restoreDeletedRecordId == null &&
                  prefillSadir == null),
          'Cannot edit existing record and restore deleted record at the same time.',
        );

  @override
  State<SadirFormScreen> createState() => _SadirFormScreenState();
}

class _SadirFormScreenState extends State<SadirFormScreen> {
  static const String _classificationMinistry = 'الوزارة';
  static const String _classificationAuthority = 'الهيئة';

  final _formKey = GlobalKey<FormState>();

  final _qaidNumberController = TextEditingController();
  DateTime _qaidDate = DateTime.now();
  final _destAdminController = TextEditingController();
  final _letterNumberController = TextEditingController();
  DateTime? _letterDate;
  final _chairmanIncomingNumberController = TextEditingController();
  DateTime? _chairmanIncomingDate;
  final _chairmanReturnNumberController = TextEditingController();
  DateTime? _chairmanReturnDate;
  final _attachmentCountController = TextEditingController(text: '0');
  final _subjectController = TextEditingController();
  final _notesController = TextEditingController();

  String _signatureStatus = 'pending';
  DateTime? _signatureDate;

  final _sentTo1Controller = TextEditingController();
  DateTime? _sentTo1Date;
  final _sentTo2Controller = TextEditingController();
  DateTime? _sentTo2Date;
  final _sentTo3Controller = TextEditingController();
  DateTime? _sentTo3Date;

  bool _isMinistry = false;
  bool _isAuthority = false;
  bool _isOther = false;
  final _otherDetailsController = TextEditingController();
  final _newClassificationController = TextEditingController();
  List<String> _classificationOptions = <String>[];
  String? _selectedClassification;
  bool _isLoadingClassifications = true;
  final DocumentScanService _documentScanService = DocumentScanService();
  final AttachmentStorageService _attachmentStorage =
      AttachmentStorageService();

  String? _fileName;
  String? _filePath;

  bool _needsFollowup = false;
  final _followupNotesController = TextEditingController();

  bool get isEditing => widget.editSadir != null;
  bool get isRestoring =>
      widget.initialSadir != null && widget.restoreDeletedRecordId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadSadirData(widget.editSadir!);
    } else if (isRestoring) {
      _loadSadirData(widget.initialSadir!);
    } else if (widget.prefillSadir != null) {
      _loadSadirData(widget.prefillSadir!);
    }
    _loadClassificationOptions();
  }

  void _loadSadirData(SadirModel s) {
    _qaidNumberController.text = s.qaidNumber;
    _qaidDate = s.qaidDate;
    _destAdminController.text = s.destinationAdministration ?? '';
    _letterNumberController.text = s.letterNumber ?? '';
    _letterDate = s.letterDate;
    _chairmanIncomingNumberController.text = s.chairmanIncomingNumber ?? '';
    _chairmanIncomingDate = s.chairmanIncomingDate;
    _chairmanReturnNumberController.text = s.chairmanReturnNumber ?? '';
    _chairmanReturnDate = s.chairmanReturnDate;
    _attachmentCountController.text = s.attachmentCount.toString();
    _subjectController.text = s.subject;
    _notesController.text = s.notes ?? '';

    _signatureStatus = s.signatureStatus;
    _signatureDate = s.signatureDate;

    _sentTo1Controller.text = s.sentTo1Name ?? '';
    _sentTo1Date = s.sentTo1DeliveryDate;
    _sentTo2Controller.text = s.sentTo2Name ?? '';
    _sentTo2Date = s.sentTo2DeliveryDate;
    _sentTo3Controller.text = s.sentTo3Name ?? '';
    _sentTo3Date = s.sentTo3DeliveryDate;

    _isMinistry = s.isMinistry;
    _isAuthority = s.isAuthority;
    _isOther = s.isOther;
    _otherDetailsController.text = s.otherDetails ?? '';
    _selectedClassification = _buildClassificationFromFlags();

    _fileName = s.fileName;
    _filePath = s.filePath;

    _needsFollowup = s.needsFollowup;
    _followupNotesController.text = s.followupNotes ?? '';
  }

  @override
  void dispose() {
    _qaidNumberController.dispose();
    _destAdminController.dispose();
    _letterNumberController.dispose();
    _chairmanIncomingNumberController.dispose();
    _chairmanReturnNumberController.dispose();
    _attachmentCountController.dispose();
    _subjectController.dispose();
    _notesController.dispose();
    _sentTo1Controller.dispose();
    _sentTo2Controller.dispose();
    _sentTo3Controller.dispose();
    _otherDetailsController.dispose();
    _newClassificationController.dispose();
    _followupNotesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime? initialDate,
    void Function(DateTime?) onSelect,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      onSelect(picked);
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
                leading: const Icon(Icons.attach_file),
                title: const Text('اختيار ملف'),
                onTap: () => Navigator.of(sheetContext).pop('file'),
              ),
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

    ScannedDocument? picked;
    try {
      if (source == 'camera') {
        picked = await _documentScanService.scanFromCamera(
          fileNamePrefix: 'sadir_scan',
        );
      } else {
        picked = await _documentScanService.pickFile(
          allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
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

    if (picked == null) {
      return;
    }
    final selectedFile = picked;

    final storedPath = await _attachmentStorage.storeAttachment(
      sourcePath: selectedFile.path.trim(),
      originalFileName: selectedFile.name,
      documentType: 'sadir',
    );

    if (!mounted) {
      return;
    }

    if (storedPath == null) {
      Helpers.showSnackBar(
        context,
        'تعذر حفظ المرفق في مسار التخزين الحالي',
        isError: true,
      );
      return;
    }

    setState(() {
      _fileName = selectedFile.name;
      _filePath = storedPath;
    });
  }

  Future<void> _clearSelectedFile() async {
    final oldPath = _filePath;
    setState(() {
      _fileName = null;
      _filePath = null;
    });
    await _attachmentStorage.deleteManagedFileIfOwned(oldPath);
  }

  String? _buildClassificationFromFlags() {
    if (_isMinistry) {
      return _classificationMinistry;
    }
    if (_isAuthority) {
      return _classificationAuthority;
    }
    if (_isOther) {
      final other = _otherDetailsController.text.trim();
      if (other.isNotEmpty) {
        return other;
      }
    }
    return null;
  }

  List<String> _mergeClassificationOptions(List<String> options) {
    final merged = <String>[_classificationMinistry, _classificationAuthority];

    for (final option in options) {
      final value = option.trim();
      if (value.isEmpty || _containsIgnoreCase(merged, value)) {
        continue;
      }
      merged.add(value);
    }

    return merged;
  }

  bool _containsIgnoreCase(List<String> values, String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return values.any((item) => item.trim().toLowerCase() == normalized);
  }

  void _addOptionIfMissing(List<String> options, String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty || _containsIgnoreCase(options, normalized)) {
      return;
    }
    options.add(normalized);
  }

  void _applyClassificationSelection(String? value) {
    final selected = value?.trim();
    _selectedClassification =
        (selected == null || selected.isEmpty) ? null : selected;
    _isMinistry = _selectedClassification == _classificationMinistry;
    _isAuthority = _selectedClassification == _classificationAuthority;
    _isOther = _selectedClassification != null && !_isMinistry && !_isAuthority;
    _otherDetailsController.text = _isOther ? _selectedClassification! : '';
  }

  Future<void> _loadClassificationOptions() async {
    final docProvider = Provider.of<DocumentProvider>(context, listen: false);
    final options = await docProvider.getClassificationOptions('sadir');

    if (!mounted) {
      return;
    }

    setState(() {
      _classificationOptions = _mergeClassificationOptions(options);
      _addOptionIfMissing(_classificationOptions, _selectedClassification);
      _addOptionIfMissing(_classificationOptions, _destAdminController.text);
      _addOptionIfMissing(_classificationOptions, _sentTo1Controller.text);
      _addOptionIfMissing(_classificationOptions, _sentTo2Controller.text);
      _addOptionIfMissing(_classificationOptions, _sentTo3Controller.text);
      _isLoadingClassifications = false;
    });
  }

  Future<void> _showAddClassificationDialog({
    void Function(String value)? onOptionAdded,
  }) async {
    _newClassificationController.clear();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('إضافة جهة'),
          content: TextField(
            controller: _newClassificationController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'اسم الجهة',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_newClassificationController.text.trim()),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    final value = result?.trim() ?? '';
    if (value.isEmpty || !mounted) {
      return;
    }

    final docProvider = Provider.of<DocumentProvider>(context, listen: false);
    final saved = await docProvider.addClassificationOption(
      documentType: 'sadir',
      optionName: value,
    );

    if (!mounted) {
      return;
    }

    if (!saved) {
      Helpers.showSnackBar(
        context,
        docProvider.error ?? 'حدث خطأ أثناء إضافة الجهة',
        isError: true,
      );
      return;
    }

    await _loadClassificationOptions();
    if (!mounted) {
      return;
    }

    setState(() {
      if (onOptionAdded != null) {
        onOptionAdded(value);
      } else {
        _applyClassificationSelection(value);
      }
    });

    Helpers.showSnackBar(context, 'تم إضافة الجهة بنجاح');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final docProvider = Provider.of<DocumentProvider>(context, listen: false);

    _applyClassificationSelection(_selectedClassification);

    final destinationAdministration = _destAdminController.text.trim();
    final sentTo1 = _sentTo1Controller.text.trim();
    final sentTo2 = _sentTo2Controller.text.trim();
    final sentTo3 = _sentTo3Controller.text.trim();
    final sadir = SadirModel(
      id: isEditing ? widget.editSadir!.id : null,
      qaidNumber: _qaidNumberController.text.trim(),
      qaidDate: _qaidDate,
      destinationAdministration:
          destinationAdministration.isEmpty ? null : destinationAdministration,
      letterNumber: _letterNumberController.text.trim().isEmpty
          ? null
          : _letterNumberController.text.trim(),
      letterDate: _letterDate,
      chairmanIncomingNumber:
          _chairmanIncomingNumberController.text.trim().isEmpty
              ? null
              : _chairmanIncomingNumberController.text.trim(),
      chairmanIncomingDate: _chairmanIncomingDate,
      chairmanReturnNumber: _chairmanReturnNumberController.text.trim().isEmpty
          ? null
          : _chairmanReturnNumberController.text.trim(),
      chairmanReturnDate: _chairmanReturnDate,
      attachmentCount: int.tryParse(_attachmentCountController.text) ?? 0,
      subject: _subjectController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      signatureStatus: _signatureStatus,
      signatureDate: _signatureDate,
      sentTo1Name: sentTo1.isEmpty ? null : sentTo1,
      sentTo1DeliveryDate: _sentTo1Date,
      sentTo2Name: sentTo2.isEmpty ? null : sentTo2,
      sentTo2DeliveryDate: _sentTo2Date,
      sentTo3Name: sentTo3.isEmpty ? null : sentTo3,
      sentTo3DeliveryDate: _sentTo3Date,
      isMinistry: _isMinistry,
      isAuthority: _isAuthority,
      isOther: _isOther,
      otherDetails: _otherDetailsController.text.trim().isEmpty
          ? null
          : _otherDetailsController.text.trim(),
      fileName: _fileName,
      filePath: _filePath,
      needsFollowup: _needsFollowup,
      followupStatus: _needsFollowup
          ? SadirModel.followupStatusWaitingReply
          : SadirModel.followupStatusCompleted,
      followupFileName: isEditing
          ? widget.editSadir!.followupFileName
          : (isRestoring ? widget.initialSadir?.followupFileName : null),
      followupFilePath: isEditing
          ? widget.editSadir!.followupFilePath
          : (isRestoring ? widget.initialSadir?.followupFilePath : null),
      followupNotes: _followupNotesController.text.trim().isEmpty
          ? null
          : _followupNotesController.text.trim(),
      createdAt: isEditing
          ? widget.editSadir!.createdAt
          : (isRestoring ? widget.initialSadir!.createdAt : DateTime.now()),
      updatedAt: isEditing
          ? widget.editSadir!.updatedAt
          : (isRestoring ? widget.initialSadir?.updatedAt : null),
      createdBy: authProvider.currentUser?.id,
      createdByName: authProvider.currentUser?.fullName,
    );

    bool success;
    if (isEditing) {
      success = await docProvider.updateSadir(
        sadir,
        authProvider.currentUser!.id!,
        authProvider.currentUser!.fullName,
      );
    } else if (isRestoring) {
      success = await docProvider.restoreSadirFromDeletedWithEdits(
        deletedRecordId: widget.restoreDeletedRecordId!,
        sadir: sadir,
        userId: authProvider.currentUser!.id!,
        userName: authProvider.currentUser!.fullName,
      );
    } else {
      success = await docProvider.addSadir(sadir);
    }

    if (!mounted) {
      return;
    }

    if (success) {
      if (isEditing) {
        await _attachmentStorage.deleteManagedFileIfOwned(
          widget.editSadir!.filePath,
          exceptPath: _filePath,
        );
      }
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        isEditing
            ? 'تم تحديث البيانات بنجاح'
            : (isRestoring
                ? 'تم استرجاع السجل بعد التعديل بنجاح'
                : 'تم إضافة البيانات بنجاح'),
      );
      Navigator.of(context).pop(true);
      return;
    }

    Helpers.showSnackBar(context, docProvider.error ?? 'حدث خطأ',
        isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.canManageSadir && !authProvider.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text(
            'ليس لديك صلاحية إدارة الصادر',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'تعديل صادر'
              : (isRestoring ? 'استرجاع صادر مع تعديل' : 'صادر جديد'),
        ),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, color: Colors.white),
            label: Text(
              isRestoring ? 'استرجاع' : 'حفظ',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('المعلومات الأساسية'),
              _buildCard(
                child: Column(
                  children: [
                    _buildResponsiveRow(
                      first: _buildTextField(
                        controller: _qaidNumberController,
                        label: 'رقم القيد',
                        required: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9٠-٩۰-۹]'),
                          ),
                        ],
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) {
                            return 'هذا الحقل مطلوب';
                          }
                          if (!RegExp(r'^[0-9٠-٩۰-۹]+$').hasMatch(v)) {
                            return 'رقم القيد يجب أن يحتوي على أرقام فقط';
                          }
                          return null;
                        },
                      ),
                      second: _buildDateField(
                        label: 'تاريخ القيد',
                        value: _qaidDate,
                        onSelect: (date) => setState(() => _qaidDate = date!),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingClassifications)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      )
                    else ...[
                      _buildEntityDropdownField(
                        label:
                            '\u0627\u0644\u062c\u0647\u0629 \u0627\u0644\u0645\u0631\u0633\u0644 \u0625\u0644\u064a\u0647\u0627',
                        value: _destAdminController.text.trim().isEmpty
                            ? null
                            : _destAdminController.text.trim(),
                        onChanged: (value) {
                          setState(() {
                            _destAdminController.text = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddClassificationDialog(
                            onOptionAdded: (value) {
                              _destAdminController.text = value;
                            },
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text(
                              '\u0625\u0636\u0627\u0641\u0629 \u062c\u0647\u0629'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildResponsiveRow(
                      first: _buildTextField(
                        controller: _letterNumberController,
                        label:
                            '\u0631\u0642\u0645 \u0627\u0644\u0648\u0632\u0627\u0631\u0629 / \u0627\u0644\u062c\u0647\u0629 \u0627\u0644\u062e\u0627\u0631\u062c\u064a\u0629',
                      ),
                      second: _buildDateField(
                        label:
                            '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u0648\u0632\u0627\u0631\u0629 / \u0627\u0644\u062c\u0647\u0629 \u0627\u0644\u062e\u0627\u0631\u062c\u064a\u0629',
                        value: _letterDate,
                        onSelect: (date) => setState(() => _letterDate = date),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildResponsiveRow(
                      first: _buildTextField(
                        controller: _chairmanIncomingNumberController,
                        label:
                            '\u0631\u0642\u0645 \u0648\u0627\u0631\u062f \u0631\u0626\u064a\u0633 \u0627\u0644\u0647\u064a\u0626\u0629',
                      ),
                      second: _buildDateField(
                        label:
                            '\u062a\u0627\u0631\u064a\u062e \u0648\u0627\u0631\u062f \u0631\u0626\u064a\u0633 \u0627\u0644\u0647\u064a\u0626\u0629',
                        value: _chairmanIncomingDate,
                        onSelect: (date) =>
                            setState(() => _chairmanIncomingDate = date),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildResponsiveRow(
                      first: _buildTextField(
                        controller: _attachmentCountController,
                        label: 'عدد المرفقات',
                        keyboardType: TextInputType.number,
                      ),
                      second: _buildTextField(
                        controller: _subjectController,
                        label: 'الموضوع',
                        required: true,
                        maxLines: 2,
                      ),
                      secondFlex: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('حالة التوقيع'),
              _buildCard(
                child: Column(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'pending',
                          label: Text('انتظار'),
                          icon: Icon(Icons.schedule),
                        ),
                        ButtonSegment<String>(
                          value: 'saved',
                          label: Text('حفظ'),
                          icon: Icon(Icons.check_circle_outline),
                        ),
                      ],
                      selected: <String>{_signatureStatus},
                      onSelectionChanged: (selected) {
                        setState(() {
                          _signatureStatus = selected.first;
                        });
                      },
                    ),
                    if (_signatureStatus == 'saved') ...[
                      const SizedBox(height: 12),
                      _buildDateField(
                        label: 'تاريخ التوقيع',
                        value: _signatureDate,
                        onSelect: (date) =>
                            setState(() => _signatureDate = date),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('المرسل إليهم'),
              _buildCard(
                child: Column(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      _buildResponsiveRow(
                        first: _buildEntityDropdownField(
                          label:
                              '\u0627\u0644\u062c\u0647\u0629 \u0627\u0644\u0645\u0631\u0633\u0644 \u0625\u0644\u064a\u0647\u0627 ${i + 1}',
                          value: [
                            _sentTo1Controller.text,
                            _sentTo2Controller.text,
                            _sentTo3Controller.text,
                          ][i]
                                  .trim()
                                  .isEmpty
                              ? null
                              : [
                                  _sentTo1Controller.text,
                                  _sentTo2Controller.text,
                                  _sentTo3Controller.text,
                                ][i],
                          onChanged: (value) {
                            setState(() {
                              final normalized = value ?? '';
                              if (i == 0) {
                                _sentTo1Controller.text = normalized;
                              } else if (i == 1) {
                                _sentTo2Controller.text = normalized;
                              } else {
                                _sentTo3Controller.text = normalized;
                              }
                            });
                          },
                        ),
                        second: _buildDateField(
                          label:
                              '\u062a\u0627\u0631\u064a\u062e \u0627\u0644\u062a\u0633\u0644\u064a\u0645',
                          value: [
                            _sentTo1Date,
                            _sentTo2Date,
                            _sentTo3Date,
                          ][i],
                          onSelect: (date) {
                            setState(() {
                              if (i == 0) {
                                _sentTo1Date = date;
                              } else if (i == 1) {
                                _sentTo2Date = date;
                              } else {
                                _sentTo3Date = date;
                              }
                            });
                          },
                        ),
                        firstFlex: 2,
                      ),
                      if (i < 2) const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddClassificationDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text(
                            '\u0625\u0636\u0627\u0641\u0629 \u062c\u0647\u0629 \u0645\u0633\u062a\u0644\u0645\u0629'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildResponsiveRow(
                      first: _buildTextField(
                        controller: _chairmanReturnNumberController,
                        label:
                            '\u0631\u0642\u0645 \u0639\u0627\u0626\u062f \u0631\u0626\u064a\u0633 \u0627\u0644\u0647\u064a\u0626\u0629 \u0628\u0639\u062f \u0627\u0644\u062a\u0648\u0642\u064a\u0639',
                      ),
                      second: _buildDateField(
                        label:
                            '\u062a\u0627\u0631\u064a\u062e \u0639\u0627\u0626\u062f \u0631\u0626\u064a\u0633 \u0627\u0644\u0647\u064a\u0626\u0629 \u0628\u0639\u062f \u0627\u0644\u062a\u0648\u0642\u064a\u0639',
                        value: _chairmanReturnDate,
                        onSelect: (date) =>
                            setState(() => _chairmanReturnDate = date),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('التصنيف'),
              _buildCard(
                child: Column(
                  children: [
                    if (_isLoadingClassifications)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final dropdown = DropdownButtonFormField<String>(
                            initialValue: _selectedClassification,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'التصنيف',
                              border: OutlineInputBorder(),
                            ),
                            items: _classificationOptions
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(
                                      item,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _applyClassificationSelection(value);
                              });
                            },
                          );

                          final addButton = OutlinedButton.icon(
                            onPressed: _showAddClassificationDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة جهة'),
                          );

                          if (constraints.maxWidth >= 620) {
                            return Row(
                              children: [
                                Expanded(child: dropdown),
                                const SizedBox(width: 12),
                                addButton,
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              dropdown,
                              const SizedBox(height: 12),
                              addButton,
                            ],
                          );
                        },
                      ),
                    if (_isOther && _selectedClassification != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'الجهة المختارة: ${_selectedClassification!}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('الملف المرفق'),
              _buildCard(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 620) {
                      return Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('إرفاق / اسكان'),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _fileName ?? 'لم يتم اختيار ملف',
                              style: TextStyle(
                                color: _fileName != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          if (_fileName != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: _clearSelectedFile,
                            ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('إرفاق / اسكان'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _fileName ?? 'لم يتم اختيار ملف',
                          style: TextStyle(
                            color:
                                _fileName != null ? Colors.green : Colors.grey,
                          ),
                        ),
                        if (_fileName != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: _clearSelectedFile,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('المتابعة'),
              _buildCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('يحتاج لمتابعة'),
                      value: _needsFollowup,
                      onChanged: (value) =>
                          setState(() => _needsFollowup = value),
                    ),
                    if (_needsFollowup)
                      _buildTextField(
                        controller: _followupNotesController,
                        label: 'ملاحظات المتابعة',
                        maxLines: 3,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(
                    isEditing ? 'تحديث' : (isRestoring ? 'استرجاع' : 'حفظ'),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildResponsiveRow({
    required Widget first,
    required Widget second,
    int firstFlex = 1,
    int secondFlex = 1,
    double spacing = 16,
  }) {
    final isWideLayout = MediaQuery.of(context).size.width >= 900;

    if (isWideLayout) {
      return Row(
        children: [
          Expanded(flex: firstFlex, child: first),
          SizedBox(width: spacing),
          Expanded(flex: secondFlex, child: second),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: validator ??
          (required
              ? (value) => (value == null || value.trim().isEmpty)
                  ? 'هذا الحقل مطلوب'
                  : null
              : null),
    );
  }

  Widget _buildEntityDropdownField({
    required String label,
    required String? value,
    required void Function(String? value) onChanged,
    bool required = false,
    bool allowEmpty = true,
  }) {
    final currentValue = value?.trim();
    final normalizedValue =
        currentValue == null || currentValue.isEmpty ? null : currentValue;

    final options = <String>[..._classificationOptions];
    if (normalizedValue != null &&
        !_containsIgnoreCase(options, normalizedValue)) {
      options.add(normalizedValue);
    }

    final items = <DropdownMenuItem<String>>[];
    if (allowEmpty) {
      items.add(
        const DropdownMenuItem<String>(
          value: '',
          child:
              Text('\u0628\u062f\u0648\u0646 \u062a\u062d\u062f\u064a\u062f'),
        ),
      );
    }
    items.addAll(
      options.map(
        (item) => DropdownMenuItem<String>(
          value: item,
          child: Text(item, overflow: TextOverflow.ellipsis),
        ),
      ),
    );

    return DropdownButtonFormField<String>(
      key: ValueKey(
          '$label-${normalizedValue ?? ''}-${options.length}-$allowEmpty'),
      initialValue: normalizedValue ?? (allowEmpty ? '' : null),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ''}',
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: (selected) {
        final normalized = (selected == null || selected.trim().isEmpty)
            ? null
            : selected.trim();
        onChanged(normalized);
      },
      validator: required
          ? (selected) => (selected == null || selected.trim().isEmpty)
              ? '\u0647\u0630\u0627 \u0627\u0644\u062d\u0642\u0644 \u0645\u0637\u0644\u0648\u0628'
              : null
          : null,
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required void Function(DateTime?) onSelect,
  }) {
    return InkWell(
      onTap: () => _selectDate(context, value, onSelect),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          value != null ? Helpers.formatDate(value) : 'اختر التاريخ',
          style: TextStyle(color: value != null ? null : Colors.grey),
        ),
      ),
    );
  }
}
