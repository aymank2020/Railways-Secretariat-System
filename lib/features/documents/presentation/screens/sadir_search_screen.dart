import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/documents/presentation/providers/document_provider.dart';
import 'package:railway_secretariat/core/services/attachment_opener_service.dart';
import 'package:railway_secretariat/features/documents/data/datasources/documents_export_service.dart';
import 'package:railway_secretariat/utils/helpers.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/sadir_form_screen.dart';

class SadirSearchScreen extends StatefulWidget {
  const SadirSearchScreen({super.key});

  @override
  State<SadirSearchScreen> createState() => _SadirSearchScreenState();
}

class _SadirSearchScreenState extends State<SadirSearchScreen> {
  final _searchController = TextEditingController();
  final _externalNumberController = TextEditingController();
  final _chairmanIncomingNumberController = TextEditingController();
  final _chairmanReturnNumberController = TextEditingController();
  final _documentsExportService = DocumentsExportService();
  final AttachmentOpenerService _attachmentOpener = AttachmentOpenerService();
  final Set<int> _selectedSadirIds = <int>{};
  DateTime? _fromDate;
  DateTime? _toDate;
  DateTime? _externalDate;
  DateTime? _chairmanIncomingDate;
  DateTime? _chairmanReturnDate;
  bool _showAdvancedFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    _externalNumberController.dispose();
    _chairmanIncomingNumberController.dispose();
    _chairmanReturnNumberController.dispose();
    super.dispose();
  }

  bool _hasAttachment(SadirModel sadir) {
    return (sadir.filePath != null && sadir.filePath!.trim().isNotEmpty) ||
        (sadir.fileName != null && sadir.fileName!.trim().isNotEmpty);
  }

  Future<void> _openAttachment(SadirModel sadir) async {
    final result = await _attachmentOpener.open(
      storedPath: sadir.filePath,
      originalFileName: sadir.fileName,
    );
    if (!mounted) {
      return;
    }
    if (!result.ok) {
      Helpers.showSnackBar(
        context,
        result.errorMessage ?? 'تعذر فتح الملف',
        isError: true,
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _selectSpecificDate({
    required DateTime? currentValue,
    required void Function(DateTime?) onSelect,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentValue ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => onSelect(picked));
    }
  }

  void _search() {
    final docProvider = Provider.of<DocumentProvider>(context, listen: false);
    setState(_selectedSadirIds.clear);
    docProvider.loadSadir(
      search: _searchController.text.isEmpty ? null : _searchController.text,
      fromDate: _fromDate,
      toDate: _toDate,
      externalNumber: _externalNumberController.text.trim().isEmpty
          ? null
          : _externalNumberController.text.trim(),
      externalDate: _externalDate,
      chairmanIncomingNumber:
          _chairmanIncomingNumberController.text.trim().isEmpty
              ? null
              : _chairmanIncomingNumberController.text.trim(),
      chairmanIncomingDate: _chairmanIncomingDate,
      chairmanReturnNumber: _chairmanReturnNumberController.text.trim().isEmpty
          ? null
          : _chairmanReturnNumberController.text.trim(),
      chairmanReturnDate: _chairmanReturnDate,
    );
  }

  void _clear() {
    setState(() {
      _searchController.clear();
      _externalNumberController.clear();
      _chairmanIncomingNumberController.clear();
      _chairmanReturnNumberController.clear();
      _fromDate = null;
      _toDate = null;
      _externalDate = null;
      _chairmanIncomingDate = null;
      _chairmanReturnDate = null;
      _selectedSadirIds.clear();
    });
    final docProvider = Provider.of<DocumentProvider>(context, listen: false);
    docProvider.loadSadir();
  }

  Widget _buildDateFilterRow({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
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
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: value == null ? null : onClear,
          icon: const Icon(Icons.clear),
          tooltip: 'مسح التاريخ',
        ),
      ],
    );
  }

  Widget _buildAdvancedFilters() {
    return ExpansionTile(
      initiallyExpanded: _showAdvancedFilters,
      onExpansionChanged: (expanded) {
        setState(() {
          _showAdvancedFilters = expanded;
        });
      },
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 4),
      title: const Text(
        'فلاتر متقدمة',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        TextField(
          controller: _externalNumberController,
          decoration: const InputDecoration(
            labelText: 'رقم الوزارة / الجهة الخارجية',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        _buildDateFilterRow(
          label: 'تاريخ الوزارة / الجهة الخارجية',
          value: _externalDate,
          onTap: () => _selectSpecificDate(
            currentValue: _externalDate,
            onSelect: (value) => _externalDate = value,
          ),
          onClear: () => setState(() => _externalDate = null),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _chairmanIncomingNumberController,
          decoration: const InputDecoration(
            labelText: 'رقم وارد رئيس الهيئة',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        _buildDateFilterRow(
          label: 'تاريخ وارد رئيس الهيئة',
          value: _chairmanIncomingDate,
          onTap: () => _selectSpecificDate(
            currentValue: _chairmanIncomingDate,
            onSelect: (value) => _chairmanIncomingDate = value,
          ),
          onClear: () => setState(() => _chairmanIncomingDate = null),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _chairmanReturnNumberController,
          decoration: const InputDecoration(
            labelText: 'رقم عائد رئيس الهيئة بعد التوقيع',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        _buildDateFilterRow(
          label: 'تاريخ عائد رئيس الهيئة بعد التوقيع',
          value: _chairmanReturnDate,
          onTap: () => _selectSpecificDate(
            currentValue: _chairmanReturnDate,
            onSelect: (value) => _chairmanReturnDate = value,
          ),
          onClear: () => setState(() => _chairmanReturnDate = null),
        ),
      ],
    );
  }

  bool _isSadirSelected(SadirModel sadir) {
    final id = sadir.id;
    return id != null && _selectedSadirIds.contains(id);
  }

  List<SadirModel> _getSelectedSadir(List<SadirModel> sadirList) {
    return sadirList.where(_isSadirSelected).toList();
  }

  void _toggleSadirSelection(SadirModel sadir, bool? selected) {
    final id = sadir.id;
    if (id == null) {
      return;
    }
    setState(() {
      if (selected ?? false) {
        _selectedSadirIds.add(id);
      } else {
        _selectedSadirIds.remove(id);
      }
    });
  }

  void _toggleSelectAllSadir(List<SadirModel> sadirList, bool selectAll) {
    setState(() {
      _selectedSadirIds.clear();
      if (selectAll) {
        _selectedSadirIds.addAll(
          sadirList.map((sadir) => sadir.id).whereType<int>(),
        );
      }
    });
  }

  Future<void> _showExportOptions(List<SadirModel> sadirList) async {
    final selected = _getSelectedSadir(sadirList);
    if (selected.isEmpty) {
      Helpers.showSnackBar(context, 'يرجى تحديد سجل واحد على الأقل',
          isError: true);
      return;
    }

    final format = await showModalBottomSheet<ExportFormat>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const ListTile(
                title: Text(
                  'اختر صيغة التصدير',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Excel (.xlsx)'),
                onTap: () => Navigator.of(sheetContext).pop(ExportFormat.excel),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Word (.doc)'),
                onTap: () => Navigator.of(sheetContext).pop(ExportFormat.word),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('JSON (.json)'),
                onTap: () => Navigator.of(sheetContext).pop(ExportFormat.json),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (format == null || !mounted) {
      return;
    }

    Helpers.showLoadingDialog(context, message: 'جاري تجهيز ملف التصدير...');
    try {
      final outputPath = await _documentsExportService.exportSadir(
        records: selected,
        format: format,
      );
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(context, 'تم حفظ الملف: $outputPath',
          duration: const Duration(seconds: 4));
    } catch (e) {
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(context, 'تعذر تصدير البيانات: $e', isError: true);
    } finally {
      if (mounted) {
        Helpers.hideLoadingDialog(context);
      }
    }
  }

  Widget _buildLoadMoreFooter(DocumentProvider docProvider) {
    if (!docProvider.hasMoreSadir && !docProvider.isLoadingMoreSadir) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Align(
        child: OutlinedButton.icon(
          onPressed: docProvider.isLoadingMoreSadir
              ? null
              : () => docProvider.loadMoreSadir(),
          icon: docProvider.isLoadingMoreSadir
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more),
          label: Text(
            docProvider.isLoadingMoreSadir ? 'Loading more...' : 'Load more',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context);
    final sadirList = docProvider.sadirList;
    final selectableCount = sadirList.where((sadir) => sadir.id != null).length;
    final selectedCount = _getSelectedSadir(sadirList).length;
    final allSelected = selectableCount > 0 && selectedCount == selectableCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث في الصادر'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'كلمة البحث',
                        hintText:
                            'رقم القيد، الموضوع، الجهة، رقم الوزارة/الجهة الخارجية، رقم رئيس الهيئة...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAdvancedFilters(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'من تاريخ',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _fromDate != null
                                    ? Helpers.formatDate(_fromDate)
                                    : 'اختر التاريخ',
                                style: TextStyle(
                                  color: _fromDate != null ? null : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'إلى تاريخ',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _toDate != null
                                    ? Helpers.formatDate(_toDate)
                                    : 'اختر التاريخ',
                                style: TextStyle(
                                  color: _toDate != null ? null : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _search,
                            icon: const Icon(Icons.search),
                            label: const Text('بحث'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clear,
                            icon: const Icon(Icons.clear),
                            label: const Text('مسح'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: selectableCount == 0
                              ? null
                              : () => _toggleSelectAllSadir(
                                  sadirList, !allSelected),
                          icon: Icon(
                            allSelected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                          ),
                          label: Text(
                              allSelected ? 'إلغاء التحديد' : 'تحديد الكل'),
                        ),
                        ElevatedButton.icon(
                          onPressed: selectedCount == 0
                              ? null
                              : () => _showExportOptions(sadirList),
                          icon: const Icon(Icons.download),
                          label: const Text('تصدير'),
                        ),
                        if (selectedCount > 0)
                          Chip(
                            avatar: const Icon(Icons.check, size: 16),
                            label: Text('تم تحديد $selectedCount'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: docProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : sadirList.isEmpty
                    ? const Center(child: Text('لا توجد نتائج'))
                    : Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Card(
                                child: DataTable2(
                                  columnSpacing: 12,
                                  horizontalMargin: 12,
                                  minWidth: 1100,
                                  onSelectAll: (selected) =>
                                      _toggleSelectAllSadir(
                                          sadirList, selected ?? false),
                                  columns: const [
                                    DataColumn2(
                                        label: Text('رقم القيد'),
                                        size: ColumnSize.S),
                                    DataColumn2(
                                        label: Text('التاريخ'),
                                        size: ColumnSize.S),
                                    DataColumn2(
                                        label: Text('الجهة'),
                                        size: ColumnSize.L),
                                    DataColumn2(
                                        label: Text('الموضوع'),
                                        size: ColumnSize.L),
                                    DataColumn2(label: Text('إجراءات')),
                                  ],
                                  rows: sadirList.map((sadir) {
                                    return DataRow2(
                                      selected: _isSadirSelected(sadir),
                                      onSelectChanged: sadir.id == null
                                          ? null
                                          : (selected) => _toggleSadirSelection(
                                              sadir, selected),
                                      cells: [
                                        DataCell(Text(sadir.qaidNumber)),
                                        DataCell(Text(Helpers.formatDate(
                                            sadir.qaidDate))),
                                        DataCell(Text(
                                            sadir.destinationAdministration ??
                                                '-')),
                                        DataCell(Text(sadir.subject)),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_hasAttachment(sadir))
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.attach_file,
                                                      color: Colors.teal),
                                                  tooltip: 'فتح المرفق',
                                                  onPressed: () =>
                                                      _openAttachment(sadir),
                                                ),
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    color: Colors.blue),
                                                onPressed: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          SadirFormScreen(
                                                              editSadir: sadir),
                                                    ),
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.visibility,
                                                    color: Colors.green),
                                                onPressed: () {
                                                  _showDetails(sadir);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                          _buildLoadMoreFooter(docProvider),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  void _showDetails(SadirModel sadir) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.outbox, color: Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'تفاصيل الصادر',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'بيانات القيد',
                    icon: Icons.numbers,
                    children: [
                      _buildDetailRow('رقم القيد', sadir.qaidNumber),
                      _buildDetailRow(
                          'تاريخ القيد', Helpers.formatDate(sadir.qaidDate)),
                      _buildDetailRow('الجهة المرسل إليها',
                          sadir.destinationAdministration ?? '-'),
                      _buildDetailRow(
                          'رقم الوزارة / الجهة الخارجية',
                          sadir.letterNumber?.trim().isNotEmpty == true
                              ? sadir.letterNumber!
                              : '-'),
                      _buildDetailRow(
                          'تاريخ الوزارة / الجهة الخارجية',
                          sadir.letterDate != null
                              ? Helpers.formatDate(sadir.letterDate!)
                              : '-'),
                      _buildDetailRow(
                          'رقم وارد رئيس الهيئة',
                          sadir.chairmanIncomingNumber?.trim().isNotEmpty ==
                                  true
                              ? sadir.chairmanIncomingNumber!
                              : '-'),
                      _buildDetailRow(
                          'تاريخ وارد رئيس الهيئة',
                          sadir.chairmanIncomingDate != null
                              ? Helpers.formatDate(sadir.chairmanIncomingDate!)
                              : '-'),
                      _buildDetailRow(
                          'رقم عائد رئيس الهيئة بعد التوقيع',
                          sadir.chairmanReturnNumber?.trim().isNotEmpty == true
                              ? sadir.chairmanReturnNumber!
                              : '-'),
                      _buildDetailRow(
                          'تاريخ عائد رئيس الهيئة بعد التوقيع',
                          sadir.chairmanReturnDate != null
                              ? Helpers.formatDate(sadir.chairmanReturnDate!)
                              : '-'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'الموضوع والملخص',
                    icon: Icons.subject,
                    children: [
                      Text(
                        sadir.subject,
                        style: const TextStyle(height: 1.5, fontSize: 15),
                      ),
                      if ((sadir.notes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'ملاحظات: ${sadir.notes}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'الحالة',
                    icon: Icons.info_outline,
                    children: [
                      _buildDetailRow(
                          'حالة التوقيع',
                          Helpers.getSignatureStatusName(
                              sadir.signatureStatus)),
                      _buildDetailRow(
                          'عدد المرفقات', sadir.attachmentCount.toString()),
                      _buildDetailRow(
                          'المتابعة',
                          sadir.needsFollowup
                              ? 'يحتاج متابعة'
                              : 'لا يحتاج متابعة'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'الجهات المستلمة',
                    icon: Icons.groups_outlined,
                    children: [
                      if ((sadir.sentTo1Name ?? '').trim().isNotEmpty)
                        _buildDetailRow('المرسل إليه 1', sadir.sentTo1Name!),
                      if ((sadir.sentTo2Name ?? '').trim().isNotEmpty)
                        _buildDetailRow('المرسل إليه 2', sadir.sentTo2Name!),
                      if ((sadir.sentTo3Name ?? '').trim().isNotEmpty)
                        _buildDetailRow('المرسل إليه 3', sadir.sentTo3Name!),
                      if ((sadir.sentTo1Name ?? '').trim().isEmpty &&
                          (sadir.sentTo2Name ?? '').trim().isEmpty &&
                          (sadir.sentTo3Name ?? '').trim().isEmpty)
                        Text(
                          'لا يوجد مرسل إليهم مسجلون',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                  if (_hasAttachment(sadir)) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      title: 'المرفق',
                      icon: Icons.attach_file,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                sadir.fileName?.isNotEmpty == true
                                    ? sadir.fileName!
                                    : 'ملف مرفق',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _openAttachment(sadir),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('فتح'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
