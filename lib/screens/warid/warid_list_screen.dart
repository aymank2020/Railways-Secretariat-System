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
  final _horizontalScrollController = ScrollController();
  final _verticalScrollController = ScrollController();
  final _documentsExportService = DocumentsExportService();
  final Set<int> _selectedWaridIds = <int>{};
  static const Map<String, String> _followupStatusLabels = {
    WaridModel.followupStatusWaitingReply:
        '\u0641\u064a \u0627\u0646\u062a\u0638\u0627\u0631 \u0627\u0644\u0631\u062f',
    WaridModel.followupStatusCompleted: 'تم الانتهاء من الموضوع',
  };

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

  bool _hasFollowupAttachment(WaridModel warid) {
    return (warid.followupFilePath != null &&
            warid.followupFilePath!.trim().isNotEmpty) ||
        (warid.followupFileName != null &&
            warid.followupFileName!.trim().isNotEmpty);
  }

  String _normalizeFollowupStatus(WaridModel warid) {
    final status = warid.followupStatus.trim().toLowerCase();
    if (_followupStatusLabels.containsKey(status)) {
      return status;
    }
    return warid.needsFollowup
        ? WaridModel.followupStatusWaitingReply
        : WaridModel.followupStatusCompleted;
  }

  Future<PlatformFile?> _pickFollowupFile() async {
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.isEmpty) {
      return null;
    }
    return picked.files.single;
  }

  Future<void> _saveWaridFollowup(WaridModel updated) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final docProvider = Provider.of<DocumentProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser?.id == null) {
      Helpers.showSnackBar(context, 'تعذر تحديد المستخدم الحالي', isError: true);
      return;
    }

    final success = await docProvider.updateWarid(
      updated,
      currentUser!.id!,
      currentUser.fullName,
    );

    if (!mounted || success) {
      return;
    }
    Helpers.showSnackBar(context, docProvider.error ?? 'حدث خطأ', isError: true);
  }

  Future<void> _updateFollowupStatus(
      WaridModel warid, String newStatusValue) async {
    final normalized = newStatusValue.trim().toLowerCase();
    if (!_followupStatusLabels.containsKey(normalized)) {
      return;
    }

    if (normalized == WaridModel.followupStatusCompleted &&
        !_hasFollowupAttachment(warid)) {
      final picked = await _pickFollowupFile();
      if (!mounted) {
        return;
      }
      if (picked == null) {
        Helpers.showSnackBar(
          context,
          '\u0639\u0646\u062f \u0627\u062e\u062a\u064a\u0627\u0631 "\u062a\u0645 \u0627\u0644\u0627\u0646\u062a\u0647\u0627\u0621 \u0645\u0646 \u0627\u0644\u0645\u0648\u0636\u0648\u0639" \u064a\u062c\u0628 \u0625\u0631\u0641\u0627\u0642 \u0645\u0644\u0641 \u0645\u062a\u0627\u0628\u0639\u0629',
          isError: true,
        );
        return;
      }

      await _saveWaridFollowup(
        warid.copyWith(
          needsFollowup: false,
          followupStatus: WaridModel.followupStatusCompleted,
          followupFileName: picked.name,
          followupFilePath: picked.path,
        ),
      );
      return;
    }

    await _saveWaridFollowup(
      warid.copyWith(
        needsFollowup: normalized == WaridModel.followupStatusWaitingReply,
        followupStatus: normalized,
      ),
    );
  }

  Future<void> _attachFollowupFile(WaridModel warid) async {
    final picked = await _pickFollowupFile();
    if (!mounted || picked == null) {
      return;
    }
    await _saveWaridFollowup(
      warid.copyWith(
        needsFollowup: false,
        followupStatus: WaridModel.followupStatusCompleted,
        followupFileName: picked.name,
        followupFilePath: picked.path,
      ),
    );
  }

  Future<void> _openFollowupAttachment(WaridModel warid) async {
    final path = warid.followupFilePath?.trim() ?? '';
    if (path.isEmpty) {
      Helpers.showSnackBar(context,
          '\u0644\u0627 \u064a\u0648\u062c\u062f \u0645\u0644\u0641 \u0645\u062a\u0627\u0628\u0639\u0629 \u0645\u0631\u0641\u0642 \u0644\u0647\u0630\u0627 \u0627\u0644\u0633\u062c\u0644',
          isError: true);
      return;
    }

    if (kIsWeb) {
      Helpers.showSnackBar(
        context,
        '\u0641\u062a\u062d \u0627\u0644\u0645\u0644\u0641\u0627\u062a \u0627\u0644\u0645\u062d\u0644\u064a\u0629 \u063a\u064a\u0631 \u0645\u062f\u0639\u0648\u0645 \u0645\u0646 \u0646\u0633\u062e\u0629 \u0627\u0644\u0648\u064a\u0628. \u0627\u0633\u062a\u062e\u062f\u0645 \u0646\u0633\u062e\u0629 Windows \u0623\u0648 Android.',
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
        '\u062a\u0639\u0630\u0631 \u0641\u062a\u062d \u0645\u0644\u0641 \u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0629: ${result.message}',
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
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _deleteWarid(WaridModel warid) async {
    final confirmed = await Helpers.showConfirmationDialog(
      context,
      title: 'تأكيد الحذف',
      message: 'هل أنت متأكد من حذف هذا السجل؟',
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
      Helpers.showSnackBar(context, 'تم الحذف بنجاح');
    } else {
      Helpers.showSnackBar(context, docProvider.error ?? 'حدث خطأ',
          isError: true);
    }
  }

  Future<void> _deleteSelectedWarid(List<WaridModel> waridList) async {
    final selected = _getSelectedWarid(waridList);
    if (selected.isEmpty) {
      Helpers.showSnackBar(context, 'يرجى تحديد سجل واحد على الأقل',
          isError: true);
      return;
    }

    final confirmed = await Helpers.showConfirmationDialog(
      context,
      title: 'تأكيد الحذف الجماعي',
      message: 'سيتم حذف ${selected.length} سجل(ات) من الوارد. هل تريد المتابعة؟',
      isDangerous: true,
    );

    if (!mounted || !confirmed) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final docProvider = Provider.of<DocumentProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser?.id == null) {
      Helpers.showSnackBar(context, 'تعذر تحديد المستخدم الحالي', isError: true);
      return;
    }

    final result = await docProvider.deleteWaridBatch(
      selected.map((warid) => warid.id).whereType<int>().toList(),
      currentUser!.id!,
      currentUser.fullName,
    );

    if (!mounted) {
      return;
    }

    final remainingIds = docProvider.waridList.map((warid) => warid.id).whereType<int>().toSet();
    setState(() {
      _selectedWaridIds.removeWhere((id) => !remainingIds.contains(id));
    });

    if (result.deletedCount > 0 && !result.hasFailures) {
      Helpers.showSnackBar(
          context, 'تم حذف ${result.deletedCount} سجل(ات) من الوارد');
      return;
    }

    if (result.deletedCount > 0 && result.hasFailures) {
      Helpers.showSnackBar(
        context,
        'تم حذف ${result.deletedCount} سجل(ات) وفشل حذف ${result.failedCount} سجل(ات)',
        isError: true,
      );
      return;
    }

    Helpers.showSnackBar(context, docProvider.error ?? 'حدث خطأ أثناء الحذف',
        isError: true);
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
          context, 'تعذر قراءة الملف. يرجى المحاولة مرة أخرى.',
          isError: true);
      return;
    }

    final docProvider = Provider.of<DocumentProvider>(context, listen: false);

    Helpers.showLoadingDialog(context, message: 'جاري استيراد ملف Excel...');
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
                Text('إجمالي الصفوف: ${result.totalRows}'),
                const SizedBox(height: 8),
                Text('تم الاستيراد: ${result.importedRows}'),
                const SizedBox(height: 8),
                Text('فشل: ${result.failedRows}'),
                const SizedBox(height: 12),
                const Text(
                  'ملاحظة: المرفقات لا تستورد من Excel ويجب رفعها يدويًا لكل سجل.',
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
        if ((authProvider.isAdmin || authProvider.canManageWarid) &&
            selectedCount > 0)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _deleteSelectedWarid(waridList),
            icon: const Icon(Icons.delete_sweep),
            label: const Text('حذف المحدد'),
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

  Widget _buildFollowupStatusField(WaridModel warid, {required bool compact}) {
    final status = _normalizeFollowupStatus(warid);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact ? 180 : 130,
        maxWidth: compact ? 320 : 190,
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: status,
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        items: _followupStatusLabels.entries
            .map(
              (entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) {
            return;
          }
          _updateFollowupStatus(warid, value);
        },
      ),
    );
  }

  Future<void> _handleFollowupFileAction(WaridModel warid) async {
    final hasFile = _hasFollowupAttachment(warid);
    if (!hasFile) {
      await _attachFollowupFile(warid);
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('فتح ملف المتابعة'),
                onTap: () => Navigator.of(sheetContext).pop('open'),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('استبدال ملف المتابعة'),
                onTap: () => Navigator.of(sheetContext).pop('replace'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }
    if (action == 'open') {
      await _openFollowupAttachment(warid);
    } else if (action == 'replace') {
      await _attachFollowupFile(warid);
    }
  }

  Widget _buildFollowupControl(WaridModel warid, {required bool compact}) {
    final status = _normalizeFollowupStatus(warid);
    final showFileActions = status == WaridModel.followupStatusCompleted;
    final hasFollowupFile = _hasFollowupAttachment(warid);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFollowupStatusField(warid, compact: compact),
        const SizedBox(width: 4),
        if (showFileActions)
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            onPressed: () => _handleFollowupFileAction(warid),
            icon: Icon(
              hasFollowupFile ? Icons.attach_file : Icons.upload_file,
              color: hasFollowupFile ? Colors.teal : Colors.indigo,
              size: 20,
            ),
            tooltip: hasFollowupFile ? 'ملف المتابعة' : 'إضافة ملف متابعة',
          ),
      ],
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
                  label: Text('المرفقات: ${warid.attachmentCount}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildFollowupControl(warid, compact: true),
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
                            : 'ملف مرفق',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openAttachment(warid),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('فتح'),
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
                    tooltip: 'فتح المرفق',
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth =
                constraints.maxWidth < 1400 ? 1400.0 : constraints.maxWidth;
            return Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Scrollbar(
                    controller: _verticalScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      child: DataTable2(
                        columnSpacing: 12,
                        horizontalMargin: 12,
                        minWidth: tableWidth,
                        onSelectAll: (selected) =>
                            _toggleSelectAllWarid(waridList, selected ?? false),
                        columns: const [
                          DataColumn2(label: Text('رقم القيد'), size: ColumnSize.S),
                          DataColumn2(label: Text('التاريخ'), size: ColumnSize.S),
                          DataColumn2(label: Text('الجهة'), size: ColumnSize.L),
                          DataColumn2(label: Text('الموضوع'), size: ColumnSize.L),
                          DataColumn2(label: Text('المرفقات'), size: ColumnSize.S),
                          DataColumn2(label: Text('الملف')),
                          DataColumn2(label: Text('متابعة'), size: ColumnSize.L),
                          DataColumn2(label: Text('إجراءات'), size: ColumnSize.S),
                        ],
                        rows: waridList.map((warid) {
                          return DataRow2(
                            specificRowHeight: 74,
                            selected: _isWaridSelected(warid),
                            color: WidgetStateProperty.resolveWith<Color?>((states) {
                              if (states.contains(WidgetState.hovered)) {
                                return const Color(0xFFE3F2FD);
                              }
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFFD9EEFF);
                              }
                              return null;
                            }),
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
                              DataCell(_buildFollowupControl(warid, compact: false)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_hasAttachment(warid))
                                      IconButton(
                                        icon:
                                            const Icon(Icons.attach_file, color: Colors.teal),
                                        onPressed: () => _openAttachment(warid),
                                        tooltip: 'فتح المرفق',
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
                  ),
                ),
              ),
            );
          },
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

