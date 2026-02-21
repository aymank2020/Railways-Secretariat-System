import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../models/warid_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../services/documents_export_service.dart';
import '../../utils/helpers.dart';
import 'warid_form_screen.dart';

class WaridListScreen extends StatefulWidget {
  const WaridListScreen({super.key});

  @override
  State<WaridListScreen> createState() => _WaridListScreenState();
}

class _WaridListScreenState extends State<WaridListScreen> {
  final _searchController = TextEditingController();
  final _documentsExportService = DocumentsExportService();
  final Set<int> _selectedWaridIds = <int>{};

  bool _hasAttachment(WaridModel warid) {
    return (warid.filePath != null && warid.filePath!.trim().isNotEmpty) ||
        (warid.fileName != null && warid.fileName!.trim().isNotEmpty);
  }

  Future<void> _openAttachment(WaridModel warid) async {
    final path = warid.filePath?.trim() ?? '';
    if (path.isEmpty) {
      Helpers.showSnackBar(context, 'لا يوجد مل�? مر�?ق لهذا السجل',
          isError: true);
      return;
    }

    if (kIsWeb) {
      Helpers.showSnackBar(
        context,
        '�?تح المل�?ات المحلية غير مدعوم من نسخة الويب. استخدم نسخة Windows أو Android.',
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
        'تعذر �?تح المل�?: ${result.message}',
        isError: true,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DocumentProvider>(context, listen: false).loadWarid();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteWarid(WaridModel warid) async {
    final confirmed = await Helpers.showConfirmationDialog(
      context,
      title: 'تأكيد الحذ�?',
      message: 'هل أنت متأكد من حذ�? هذا السجل؟',
      isDangerous: true,
    );

    if (!mounted || !confirmed) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final docProvider = Provider.of<DocumentProvider>(context, listen: false);

    final success = await docProvider.deleteWarid(
      warid.id!,
      authProvider.currentUser!.id!,
      authProvider.currentUser!.fullName,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      if (warid.id != null) {
        setState(() => _selectedWaridIds.remove(warid.id));
      }
      Helpers.showSnackBar(context, 'تم الحذ�? بنجاح');
    } else {
      Helpers.showSnackBar(context, docProvider.error ?? 'حدث خطأ',
          isError: true);
    }
  }

  void _performSearch(DocumentProvider docProvider) {
    setState(_selectedWaridIds.clear);
    docProvider.loadWarid(search: _searchController.text.trim());
  }

  bool _isWaridSelectable(WaridModel warid) => warid.id != null;

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

    await _exportSelectedWarid(format, selected);
  }

  Future<void> _exportSelectedWarid(
      ExportFormat format, List<WaridModel> selected) async {
    Helpers.showLoadingDialog(context, message: 'جاري تجهيز مل�? التصدير...');

    try {
      final outputPath = await _documentsExportService.exportWarid(
        records: selected,
        format: format,
      );

      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(context, 'تم ح�?ظ المل�?: $outputPath',
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

  Future<void> _importWaridExcel() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.canImportExcel) {
      Helpers.showSnackBar(context, 'ليس لديك صلاحية استيراد Excel',
          isError: true);
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls'],
      withData: true,
    );

    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.single;
    final fileBytes = file.bytes;
    if (fileBytes == null) {
      Helpers.showSnackBar(
          context, 'تعذر قراءة المل�?. يرجى المحاولة مرة أخرى.',
          isError: true);
      return;
    }

    final docProvider = Provider.of<DocumentProvider>(context, listen: false);

    Helpers.showLoadingDialog(context, message: 'جاري استيراد مل�? Excel...');
    final importResult = await docProvider.importWaridFromExcel(
      fileBytes: fileBytes,
      fileName: file.name,
      filePath: file.path,
      userId: authProvider.currentUser?.id,
      userName: authProvider.currentUser?.fullName,
    );

    if (!mounted) {
      return;
    }

    Helpers.hideLoadingDialog(context);
    _showImportSummary(importResult, 'نتيجة استيراد الوارد');
  }

  void _showImportSummary(DocumentImportResult result, String title) {
    final hasErrors = result.errors.isNotEmpty;
    final firstErrors = result.errors.take(5).toList();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي الص�?و�?: ${result.totalRows}'),
                const SizedBox(height: 8),
                Text('تم الاستيراد: ${result.importedRows}'),
                const SizedBox(height: 8),
                Text('�?شل: ${result.failedRows}'),
                const SizedBox(height: 12),
                const Text(
                  'ملاحظة: المر�?قات لا ت�?ستورد من Excel ويجب ر�?عها يدويًا لكل سجل.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (hasErrors) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'أخطاء (أول 5):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final error in firstErrors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('- سطر ${error.rowNumber}: ${error.message}'),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchField(DocumentProvider docProvider) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'بحث...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedWaridIds.clear();
                  });
                  docProvider.loadWarid();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _performSearch(docProvider),
    );
  }

  Widget _buildActionButtons(AuthProvider authProvider,
      DocumentProvider docProvider, List<WaridModel> waridList) {
    final selectableCount =
        waridList.where((warid) => _isWaridSelectable(warid)).length;
    final selectedCount = _getSelectedWarid(waridList).length;
    final allSelected = selectableCount > 0 && selectedCount == selectableCount;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: () => _performSearch(docProvider),
          icon: const Icon(Icons.search),
          label: const Text('\u0628\u062D\u062B'),
        ),
        if (authProvider.canImportExcel)
          ElevatedButton.icon(
            onPressed: _importWaridExcel,
            icon: const Icon(Icons.upload_file),
            label: const Text('\u0631\u0641\u0639 Excel'),
          ),
        OutlinedButton.icon(
          onPressed: selectableCount == 0
              ? null
              : () => _toggleSelectAllWarid(waridList, !allSelected),
          icon: Icon(
            allSelected ? Icons.check_box : Icons.check_box_outline_blank,
          ),
          label: Text(allSelected
              ? '\u0625\u0644\u063A\u0627\u0621 \u0627\u0644\u062A\u062D\u062F\u064A\u062F'
              : '\u062A\u062D\u062F\u064A\u062F \u0627\u0644\u0643\u0644'),
        ),
        ElevatedButton.icon(
          onPressed:
              selectedCount == 0 ? null : () => _showExportOptions(waridList),
          icon: const Icon(Icons.download),
          label: const Text('\u062A\u0635\u062F\u064A\u0631'),
        ),
        if (selectedCount > 0)
          Chip(
            avatar: const Icon(Icons.check, size: 16),
            label: Text(
                '\u062A\u0645 \u062A\u062D\u062F\u064A\u062F $selectedCount'),
          ),
        if (authProvider.canManageWarid)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WaridFormScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('\u062C\u062F\u064A\u062F'),
          ),
      ],
    );
  }

  Widget _buildFollowupBadge(bool needsFollowup) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: needsFollowup
            ? Colors.red.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        needsFollowup ? 'يحتاج متابعة' : 'لا يحتاج متابعة',
        style: TextStyle(
          color: needsFollowup ? Colors.red : Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCompactCard(WaridModel warid, AuthProvider authProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _isWaridSelected(warid),
                  onChanged: _isWaridSelectable(warid)
                      ? (value) => _toggleWaridSelection(warid, value)
                      : null,
                ),
                Expanded(
                  child: Text(
                    'رقم القيد: ${warid.qaidNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(Helpers.formatDate(warid.qaidDate)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              warid.sourceAdministration,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              warid.subject,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('المر�?قات: ${warid.attachmentCount}'),
                  visualDensity: VisualDensity.compact,
                ),
                _buildFollowupBadge(warid.needsFollowup),
              ],
            ),
            if (_hasAttachment(warid)) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, size: 18, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        warid.fileName?.isNotEmpty == true
                            ? warid.fileName!
                            : 'مل�? مر�?ق',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openAttachment(warid),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('�?تح'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_hasAttachment(warid))
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.teal),
                    onPressed: () => _openAttachment(warid),
                    tooltip: '�?تح المر�?ق',
                  ),
                if (authProvider.canManageWarid)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WaridFormScreen(editWarid: warid),
                        ),
                      );
                    },
                  ),
                if (authProvider.isAdmin || authProvider.canManageWarid)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteWarid(warid),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideTable(
      List<WaridModel> waridList, AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: DataTable2(
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: 1000,
          onSelectAll: (selected) =>
              _toggleSelectAllWarid(waridList, selected ?? false),
          columns: const [
            DataColumn2(label: Text('رقم القيد'), size: ColumnSize.S),
            DataColumn2(label: Text('التاريخ'), size: ColumnSize.S),
            DataColumn2(label: Text('الجهة'), size: ColumnSize.L),
            DataColumn2(label: Text('الموضوع'), size: ColumnSize.L),
            DataColumn2(label: Text('المر�?قات'), size: ColumnSize.S),
            DataColumn2(label: Text('المل�?')),
            DataColumn2(label: Text('متابعة')),
            DataColumn2(label: Text('إجراءات')),
          ],
          rows: waridList.map((warid) {
            return DataRow2(
              selected: _isWaridSelected(warid),
              onSelectChanged: _isWaridSelectable(warid)
                  ? (selected) => _toggleWaridSelection(warid, selected)
                  : null,
              cells: [
                DataCell(Text(warid.qaidNumber)),
                DataCell(Text(Helpers.formatDate(warid.qaidDate))),
                DataCell(Text(warid.sourceAdministration)),
                DataCell(
                  Text(
                    warid.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(Text(warid.attachmentCount.toString())),
                DataCell(
                  Text(
                    warid.fileName?.isNotEmpty == true ? warid.fileName! : '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(_buildFollowupBadge(warid.needsFollowup)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_hasAttachment(warid))
                        IconButton(
                          icon:
                              const Icon(Icons.attach_file, color: Colors.teal),
                          onPressed: () => _openAttachment(warid),
                          tooltip: '�?تح المر�?ق',
                        ),
                      if (authProvider.canManageWarid)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    WaridFormScreen(editWarid: warid),
                              ),
                            );
                          },
                        ),
                      if (authProvider.isAdmin || authProvider.canManageWarid)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteWarid(warid),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final waridList = docProvider.waridList;
    final isCompact = MediaQuery.of(context).size.width < 1100;

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: isCompact
                ? Column(
                    children: [
                      _buildSearchField(docProvider),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildActionButtons(
                            authProvider, docProvider, waridList),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildSearchField(docProvider)),
                      const SizedBox(width: 8),
                      _buildActionButtons(authProvider, docProvider, waridList),
                    ],
                  ),
          ),
          Expanded(
            child: docProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : waridList.isEmpty
                    ? const Center(child: Text('لا توجد بيانات'))
                    : isCompact
                        ? ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: waridList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) => _buildCompactCard(
                                waridList[index], authProvider),
                          )
                        : _buildWideTable(waridList, authProvider),
          ),
        ],
      ),
    );
  }
}
