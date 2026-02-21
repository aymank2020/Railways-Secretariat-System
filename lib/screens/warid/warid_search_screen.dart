import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../models/warid_model.dart';
import '../../providers/document_provider.dart';
import '../../services/documents_export_service.dart';
import '../../utils/helpers.dart';
import 'warid_form_screen.dart';

class WaridSearchScreen extends StatefulWidget {
  const WaridSearchScreen({super.key});

  @override
  State<WaridSearchScreen> createState() => _WaridSearchScreenState();
}

class _WaridSearchScreenState extends State<WaridSearchScreen> {
  final _searchController = TextEditingController();
  final _documentsExportService = DocumentsExportService();
  final Set<int> _selectedWaridIds = <int>{};
  DateTime? _fromDate;
  DateTime? _toDate;

  bool _hasAttachment(WaridModel warid) {
    return (warid.filePath != null && warid.filePath!.trim().isNotEmpty) ||
        (warid.fileName != null && warid.fileName!.trim().isNotEmpty);
  }

  Future<void> _openAttachment(WaridModel warid) async {
    final path = warid.filePath?.trim() ?? '';
    if (path.isEmpty) {
      Helpers.showSnackBar(context, 'لا يوجد ملف مرفق لهذا السجل',
          isError: true);
      return;
    }

    if (kIsWeb) {
      Helpers.showSnackBar(
        context,
        'فتح الملفات المحلية غير مدعوم من نسخة الويب. استخدم نسخة Windows أو Android.',
        isError: true,
      );
      return;
    }

    final result = await OpenFilex.open(path);
    if (!mounted) {
      return;
    }

    if (result.type != ResultType.done) {
      Helpers.showSnackBar(
        context,
        'تعذر فتح الملف: ${result.message}',
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

  void _search() {
    final docProvider = Provider.of<DocumentProvider>(context, listen: false);
    setState(_selectedWaridIds.clear);
    docProvider.loadWarid(
      search: _searchController.text.isEmpty ? null : _searchController.text,
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  void _clear() {
    setState(() {
      _searchController.clear();
      _fromDate = null;
      _toDate = null;
      _selectedWaridIds.clear();
    });
    final docProvider = Provider.of<DocumentProvider>(context, listen: false);
    docProvider.loadWarid();
  }

  bool _isWaridSelected(WaridModel warid) {
    final id = warid.id;
    return id != null && _selectedWaridIds.contains(id);
  }

  List<WaridModel> _getSelectedWarid(List<WaridModel> waridList) {
    return waridList.where(_isWaridSelected).toList();
  }

  void _toggleWaridSelection(WaridModel warid, bool? selected) {
    final id = warid.id;
    if (id == null) {
      return;
    }
    setState(() {
      if (selected ?? false) {
        _selectedWaridIds.add(id);
      } else {
        _selectedWaridIds.remove(id);
      }
    });
  }

  void _toggleSelectAllWarid(List<WaridModel> waridList, bool selectAll) {
    setState(() {
      _selectedWaridIds.clear();
      if (selectAll) {
        _selectedWaridIds.addAll(
          waridList.map((warid) => warid.id).whereType<int>(),
        );
      }
    });
  }

  Future<void> _showExportOptions(List<WaridModel> waridList) async {
    final selected = _getSelectedWarid(waridList);
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
      final outputPath = await _documentsExportService.exportWarid(
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

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context);
    final waridList = docProvider.waridList;
    final selectableCount = waridList.where((warid) => warid.id != null).length;
    final selectedCount = _getSelectedWarid(waridList).length;
    final allSelected = selectableCount > 0 && selectedCount == selectableCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث في الوارد'),
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
                        hintText: 'رقم القيد، الموضوع، الجهة...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
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
                              : () => _toggleSelectAllWarid(
                                  waridList, !allSelected),
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
                              : () => _showExportOptions(waridList),
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
                : waridList.isEmpty
                    ? const Center(child: Text('لا توجد نتائج'))
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          child: DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            minWidth: 1100,
                            onSelectAll: (selected) => _toggleSelectAllWarid(
                                waridList, selected ?? false),
                            columns: const [
                              DataColumn2(
                                  label: Text('رقم القيد'), size: ColumnSize.S),
                              DataColumn2(
                                  label: Text('التاريخ'), size: ColumnSize.S),
                              DataColumn2(
                                  label: Text('الجهة'), size: ColumnSize.L),
                              DataColumn2(
                                  label: Text('الموضوع'), size: ColumnSize.L),
                              DataColumn2(label: Text('إجراءات')),
                            ],
                            rows: waridList.map((warid) {
                              return DataRow2(
                                selected: _isWaridSelected(warid),
                                onSelectChanged: warid.id == null
                                    ? null
                                    : (selected) =>
                                        _toggleWaridSelection(warid, selected),
                                cells: [
                                  DataCell(Text(warid.qaidNumber)),
                                  DataCell(
                                      Text(Helpers.formatDate(warid.qaidDate))),
                                  DataCell(Text(warid.sourceAdministration)),
                                  DataCell(Text(warid.subject)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_hasAttachment(warid))
                                          IconButton(
                                            icon: const Icon(Icons.attach_file,
                                                color: Colors.teal),
                                            tooltip: 'فتح المرفق',
                                            onPressed: () =>
                                                _openAttachment(warid),
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => WaridFormScreen(
                                                    editWarid: warid),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.visibility,
                                              color: Colors.green),
                                          onPressed: () {
                                            _showDetails(warid);
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
        ],
      ),
    );
  }

  void _showDetails(WaridModel warid) {
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
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mark_email_read,
                            color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'تفاصيل الوارد',
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
                      _buildDetailRow('رقم القيد', warid.qaidNumber),
                      _buildDetailRow(
                          'تاريخ القيد', Helpers.formatDate(warid.qaidDate)),
                      _buildDetailRow(
                          'الجهة الوارد منها', warid.sourceAdministration),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'الموضوع والملخص',
                    icon: Icons.subject,
                    children: [
                      Text(
                        warid.subject,
                        style: const TextStyle(height: 1.5, fontSize: 15),
                      ),
                      if ((warid.notes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'ملاحظات: ${warid.notes}',
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
                          'عدد المرفقات', warid.attachmentCount.toString()),
                      _buildDetailRow(
                          'المتابعة',
                          warid.needsFollowup
                              ? 'يحتاج متابعة'
                              : 'لا يحتاج متابعة'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'المستلمون',
                    icon: Icons.groups_outlined,
                    children: [
                      if ((warid.recipient1Name ?? '').trim().isNotEmpty)
                        _buildDetailRow('المستلم 1', warid.recipient1Name!),
                      if ((warid.recipient2Name ?? '').trim().isNotEmpty)
                        _buildDetailRow('المستلم 2', warid.recipient2Name!),
                      if ((warid.recipient3Name ?? '').trim().isNotEmpty)
                        _buildDetailRow('المستلم 3', warid.recipient3Name!),
                      if ((warid.recipient1Name ?? '').trim().isEmpty &&
                          (warid.recipient2Name ?? '').trim().isEmpty &&
                          (warid.recipient3Name ?? '').trim().isEmpty)
                        Text(
                          'لا يوجد مستلمون مسجلون',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                  if (_hasAttachment(warid)) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      title: 'المرفق',
                      icon: Icons.attach_file,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                warid.fileName?.isNotEmpty == true
                                    ? warid.fileName!
                                    : 'ملف مرفق',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _openAttachment(warid),
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
              Icon(icon, size: 18, color: Colors.blue),
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
