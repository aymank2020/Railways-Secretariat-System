import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/warid_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../utils/helpers.dart';

class WaridFormScreen extends StatefulWidget {
  final WaridModel? editWarid;

  const WaridFormScreen({super.key, this.editWarid});

  @override
  State<WaridFormScreen> createState() => _WaridFormScreenState();
}

class _WaridFormScreenState extends State<WaridFormScreen> {
  static const String _classificationMinistry = 'الوزارة';
  static const String _classificationAuthority = 'الهيئة';

  final _formKey = GlobalKey<FormState>();

  final _qaidNumberController = TextEditingController();
  DateTime _qaidDate = DateTime.now();
  final _sourceAdminController = TextEditingController();
  final _letterNumberController = TextEditingController();
  DateTime? _letterDate;
  final _attachmentCountController = TextEditingController(text: '0');
  final _subjectController = TextEditingController();
  final _notesController = TextEditingController();

  final _recipient1Controller = TextEditingController();
  DateTime? _recipient1Date;
  final _recipient2Controller = TextEditingController();
  DateTime? _recipient2Date;
  final _recipient3Controller = TextEditingController();
  DateTime? _recipient3Date;

  bool _isMinistry = false;
  bool _isAuthority = false;
  bool _isOther = false;
  final _otherDetailsController = TextEditingController();
  final _newClassificationController = TextEditingController();
  List<String> _classificationOptions = <String>[];
  String? _selectedClassification;
  bool _isLoadingClassifications = true;

  String? _fileName;
  String? _filePath;

  bool _needsFollowup = false;
  final _followupNotesController = TextEditingController();

  bool get isEditing => widget.editWarid != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadWaridData();
    }
    _loadClassificationOptions();
  }

  void _loadWaridData() {
    final w = widget.editWarid!;
    _qaidNumberController.text = w.qaidNumber;
    _qaidDate = w.qaidDate;
    _sourceAdminController.text = w.sourceAdministration;
    _letterNumberController.text = w.letterNumber ?? '';
    _letterDate = w.letterDate;
    _attachmentCountController.text = w.attachmentCount.toString();
    _subjectController.text = w.subject;
    _notesController.text = w.notes ?? '';

    _recipient1Controller.text = w.recipient1Name ?? '';
    _recipient1Date = w.recipient1DeliveryDate;
    _recipient2Controller.text = w.recipient2Name ?? '';
    _recipient2Date = w.recipient2DeliveryDate;
    _recipient3Controller.text = w.recipient3Name ?? '';
    _recipient3Date = w.recipient3DeliveryDate;

    _isMinistry = w.isMinistry;
    _isAuthority = w.isAuthority;
    _isOther = w.isOther;
    _otherDetailsController.text = w.otherDetails ?? '';
    _selectedClassification = _buildClassificationFromFlags();

    _fileName = w.fileName;
    _filePath = w.filePath;

    _needsFollowup = w.needsFollowup;
    _followupNotesController.text = w.followupNotes ?? '';
  }

  @override
  void dispose() {
    _qaidNumberController.dispose();
    _sourceAdminController.dispose();
    _letterNumberController.dispose();
    _attachmentCountController.dispose();
    _subjectController.dispose();
    _notesController.dispose();
    _recipient1Controller.dispose();
    _recipient2Controller.dispose();
    _recipient3Controller.dispose();
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _fileName = result.files.single.name;
        _filePath = result.files.single.path;
      });
    }
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

    bool containsIgnoreCase(String value) =>
        merged.any((item) => item.toLowerCase() == value.toLowerCase());

    for (final option in options) {
      final value = option.trim();
      if (value.isEmpty || containsIgnoreCase(value)) {
        continue;
      }
      merged.add(value);
    }

    return merged;
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
    final options = await docProvider.getClassificationOptions('warid');

    if (!mounted) {
      return;
    }

    setState(() {
      _classificationOptions = _mergeClassificationOptions(options);
      if (_selectedClassification != null &&
          !_classificationOptions.contains(_selectedClassification)) {
        _classificationOptions = <String>[
          ..._classificationOptions,
          _selectedClassification!,
        ];
      }
      _isLoadingClassifications = false;
    });
  }

  Future<void> _showAddClassificationDialog() async {
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
      documentType: 'warid',
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
      _applyClassificationSelection(value);
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

    final warid = WaridModel(
      id: isEditing ? widget.editWarid!.id : null,
      qaidNumber: _qaidNumberController.text.trim(),
      qaidDate: _qaidDate,
      sourceAdministration: _sourceAdminController.text.trim(),
      letterNumber: _letterNumberController.text.trim().isEmpty
          ? null
          : _letterNumberController.text.trim(),
      letterDate: _letterDate,
      attachmentCount: int.tryParse(_attachmentCountController.text) ?? 0,
      subject: _subjectController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      recipient1Name: _recipient1Controller.text.trim().isEmpty
          ? null
          : _recipient1Controller.text.trim(),
      recipient1DeliveryDate: _recipient1Date,
      recipient2Name: _recipient2Controller.text.trim().isEmpty
          ? null
          : _recipient2Controller.text.trim(),
      recipient2DeliveryDate: _recipient2Date,
      recipient3Name: _recipient3Controller.text.trim().isEmpty
          ? null
          : _recipient3Controller.text.trim(),
      recipient3DeliveryDate: _recipient3Date,
      isMinistry: _isMinistry,
      isAuthority: _isAuthority,
      isOther: _isOther,
      otherDetails: _otherDetailsController.text.trim().isEmpty
          ? null
          : _otherDetailsController.text.trim(),
      fileName: _fileName,
      filePath: _filePath,
      needsFollowup: _needsFollowup,
      followupNotes: _followupNotesController.text.trim().isEmpty
          ? null
          : _followupNotesController.text.trim(),
      createdAt: isEditing ? widget.editWarid!.createdAt : DateTime.now(),
      createdBy: authProvider.currentUser?.id,
      createdByName: authProvider.currentUser?.fullName,
    );

    bool success;
    if (isEditing) {
      success = await docProvider.updateWarid(
        warid,
        authProvider.currentUser!.id!,
        authProvider.currentUser!.fullName,
      );
    } else {
      success = await docProvider.addWarid(warid);
    }

    if (!mounted) {
      return;
    }

    if (success) {
      Helpers.showSnackBar(
        context,
        isEditing ? 'تم تحديث البيانات بنجاح' : 'تم إضافة البيانات بنجاح',
      );
      Navigator.of(context).pop();
      return;
    }

    Helpers.showSnackBar(context, docProvider.error ?? 'حدث خطأ',
        isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.canManageWarid && !authProvider.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text(
            'ليس لديك صلاحية إدارة الوارد',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل وارد' : 'وارد جديد'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('حفظ', style: TextStyle(color: Colors.white)),
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
                    _buildTextField(
                      controller: _sourceAdminController,
                      label: 'الإدارة الوارد منها',
                      required: true,
                    ),
                    const SizedBox(height: 16),
                    _buildResponsiveRow(
                      first: _buildTextField(
                        controller: _letterNumberController,
                        label: 'رقم الخطاب',
                      ),
                      second: _buildDateField(
                        label: 'تاريخ الخطاب',
                        value: _letterDate,
                        onSelect: (date) => setState(() => _letterDate = date),
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
                      firstFlex: 1,
                      secondFlex: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('المستلمون'),
              _buildCard(
                child: Column(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      _buildResponsiveRow(
                        first: _buildTextField(
                          controller: [
                            _recipient1Controller,
                            _recipient2Controller,
                            _recipient3Controller,
                          ][i],
                          label: 'المستلم ${i + 1}',
                        ),
                        second: _buildDateField(
                          label: 'تاريخ التسليم',
                          value: [
                            _recipient1Date,
                            _recipient2Date,
                            _recipient3Date,
                          ][i],
                          onSelect: (date) {
                            setState(() {
                              if (i == 0) {
                                _recipient1Date = date;
                              } else if (i == 1) {
                                _recipient2Date = date;
                              } else {
                                _recipient3Date = date;
                              }
                            });
                          },
                        ),
                        firstFlex: 2,
                        secondFlex: 1,
                      ),
                      if (i < 2) const SizedBox(height: 12),
                    ],
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
                            label: const Text('اختيار ملف'),
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
                              onPressed: () => setState(() {
                                _fileName = null;
                                _filePath = null;
                              }),
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
                          label: const Text('اختيار ملف'),
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
                              onPressed: () => setState(() {
                                _fileName = null;
                                _filePath = null;
                              }),
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
                    isEditing ? 'تحديث' : 'حفظ',
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
          color: Colors.blue,
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
