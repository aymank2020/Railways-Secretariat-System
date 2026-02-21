import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../models/sadir_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../services/documents_export_service.dart';
import '../../utils/helpers.dart';
import 'sadir_form_screen.dart';

class SadirListScreen extends StatefulWidget {
  const SadirListScreen({super.key});

  @override
  State<SadirListScreen> createState() => _SadirListScreenState();
}

class _SadirListScreenState extends State<SadirListScreen> {
  final _searchController = TextEditingController();
  final _documentsExportService = DocumentsExportService();
  final Set<int> _selectedSadirIds = <int>{};

  bool _hasAttachment(SadirModel sadir) {
    return (sadir.filePath != null && sadir.filePath!.trim().isNotEmpty) ||
        (sadir.fileName != null && sadir.fileName!.trim().isNotEmpty);
  }

  Future<void> _openAttachment(SadirModel sadir) async {
    final path = sadir.filePath?.trim() ?? '';
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
      Provider.of<DocumentProvider>(context, listen: false).loadSadir();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteSadir(SadirModel sadir) async {
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

    final success = await docProvider.deleteSadir(
      sadir.id!,
      authProvider.currentUser!.id!,
      authProvider.currentUser!.fullName,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      if (sadir.id != null) {
        setState(() => _selectedSadirIds.remove(sadir.id));
      }
      Helpers.showSnackBar(context, 'تم الحذ�? بنجاح');
    } else {
      Helpers.showSnackBar(context, docProvider.error ?? 'حدث خطأ',
          isError: true);
    }
  }

  void _performSearch(DocumentProvider docProvider) {
    setState(_selectedSadirIds.clear);
    docProvider.loadSadir(search: _searchController.text.trim());
  }

  bool _isSadirSelectable(SadirModel sadir) => sadir.id != null;

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

    await _exportSelectedSadir(format, selected);
  }

  Future<void> _exportSelectedSadir(
      ExportFormat format, List<SadirModel> selected) async {
    Helpers.showLoadingDialog(context, message: 'جاري تجهيز مل�? التصدير...');

    try {
      final outputPath = await _documentsExportService.exportSadir(
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

  Future<void> _importSadirExcel() async {
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
    final importResult = await docProvider.importSadirFromExcel(
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
    _showImportSummary(importResult, 'نتيجة استيراد الصادر');
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
                    _selectedSadirIds.clear();
                  });
                  docProvider.loadSadir();
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
      DocumentProvider docProvider, List<SadirModel> sadirList) {
    final selectableCount =
        sadirList.where((sadir) => _isSadirSelectable(sadir)).length;
    final selectedCount = _getSelectedSadir(sadirList).length;
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
            onPressed: _importSadirExcel,
            icon: const Icon(Icons.upload_file),
            label: const Text('\u0631\u0641\u0639 Excel'),
          ),
        OutlinedButton.icon(
          onPressed: selectableCount == 0
              ? null
              : () => _toggleSelectAllSadir(sadirList, !allSelected),
          icon: Icon(
            allSelected ? Icons.check_box : Icons.check_box_outline_blank,
          ),
          label: Text(allSelected
              ? '\u0625\u0644\u063A\u0627\u0621 \u0627\u0644\u062A\u062D\u062F\u064A\u062F'
              : '\u062A\u062D\u062F\u064A\u062F \u0627\u0644\u0643\u0644'),
        ),
        ElevatedButton.icon(
          onPressed:
              selectedCount == 0 ? null : () => _showExportOptions(sadirList),
          icon: const Icon(Icons.download),
          label: const Text('\u062A\u0635\u062F\u064A\u0631'),
        ),
        if (selectedCount > 0)
          Chip(
            avatar: const Icon(Icons.check, size: 16),
            label: Text(
                '\u062A\u0645 \u062A\u062D\u062F\u064A\u062F $selectedCount'),
          ),
        if (authProvider.canManageSadir)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SadirFormScreen()),
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

  Widget _buildCompactCard(SadirModel sadir, AuthProvider authProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _isSadirSelected(sadir),
                  onChanged: _isSadirSelectable(sadir)
                      ? (value) => _toggleSadirSelection(sadir, value)
                      : null,
                ),
                Expanded(
                  child: Text(
                    'رقم القيد: ${sadir.qaidNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(Helpers.formatDate(sadir.qaidDate)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sadir.destinationAdministration ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              sadir.subject,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                      Helpers.getSignatureStatusName(sadir.signatureStatus)),
                  visualDensity: VisualDensity.compact,
                ),
                _buildFollowupBadge(sadir.needsFollowup),
              ],
            ),
            if (_hasAttachment(sadir)) ...[
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
                        sadir.fileName?.isNotEmpty == true
                            ? sadir.fileName!
                            : 'مل�? مر�?ق',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openAttachment(sadir),
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
                if (_hasAttachment(sadir))
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.teal),
                    onPressed: () => _openAttachment(sadir),
                    tooltip: '�?تح المر�?ق',
                  ),
                if (authProvider.canManageSadir)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SadirFormScreen(editSadir: sadir),
                        ),
                      );
                    },
                  ),
                if (authProvider.isAdmin || authProvider.canManageSadir)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteSadir(sadir),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideTable(
      List<SadirModel> sadirList, AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: DataTable2(
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: 1000,
          onSelectAll: (selected) =>
              _toggleSelectAllSadir(sadirList, selected ?? false),
          columns: const [
            DataColumn2(label: Text('رقم القيد'), size: ColumnSize.S),
            DataColumn2(label: Text('التاريخ'), size: ColumnSize.S),
            DataColumn2(label: Text('الجهة'), size: ColumnSize.L),
            DataColumn2(label: Text('الموضوع'), size: ColumnSize.L),
            DataColumn2(label: Text('التوقيع'), size: ColumnSize.S),
            DataColumn2(label: Text('المل�?')),
            DataColumn2(label: Text('متابعة')),
            DataColumn2(label: Text('إجراءات')),
          ],
          rows: sadirList.map((sadir) {
            return DataRow2(
              selected: _isSadirSelected(sadir),
              onSelectChanged: _isSadirSelectable(sadir)
                  ? (selected) => _toggleSadirSelection(sadir, selected)
                  : null,
              cells: [
                DataCell(Text(sadir.qaidNumber)),
                DataCell(Text(Helpers.formatDate(sadir.qaidDate))),
                DataCell(Text(sadir.destinationAdministration ?? '-')),
                DataCell(
                  Text(
                    sadir.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sadir.signatureStatus == 'saved'
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      Helpers.getSignatureStatusName(sadir.signatureStatus),
                      style: TextStyle(
                        color: sadir.signatureStatus == 'saved'
                            ? Colors.green
                            : Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    sadir.fileName?.isNotEmpty == true ? sadir.fileName! : '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(_buildFollowupBadge(sadir.needsFollowup)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_hasAttachment(sadir))
                        IconButton(
                          icon:
                              const Icon(Icons.attach_file, color: Colors.teal),
                          onPressed: () => _openAttachment(sadir),
                          tooltip: '�?تح المر�?ق',
                        ),
                      if (authProvider.canManageSadir)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SadirFormScreen(editSadir: sadir),
                              ),
                            );
                          },
                        ),
                      if (authProvider.isAdmin || authProvider.canManageSadir)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteSadir(sadir),
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
    final sadirList = docProvider.sadirList;
    final isCompact = MediaQuery.of(context).size.width < 1100;

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
                            authProvider, docProvider, sadirList),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildSearchField(docProvider)),
                      const SizedBox(width: 8),
                      _buildActionButtons(authProvider, docProvider, sadirList),
                    ],
                  ),
          ),
          Expanded(
            child: docProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : sadirList.isEmpty
                    ? const Center(child: Text('لا توجد بيانات'))
                    : isCompact
                        ? ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: sadirList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) => _buildCompactCard(
                                sadirList[index], authProvider),
                          )
                        : _buildWideTable(sadirList, authProvider),
          ),
        ],
      ),
    );
  }
}
