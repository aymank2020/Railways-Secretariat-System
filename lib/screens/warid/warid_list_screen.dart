import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/warid_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../utils/helpers.dart';
import 'warid_form_screen.dart';

class WaridListScreen extends StatefulWidget {
  const WaridListScreen({super.key});

  @override
  State<WaridListScreen> createState() => _WaridListScreenState();
}

class _WaridListScreenState extends State<WaridListScreen> {
  final _searchController = TextEditingController();

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
      Helpers.showSnackBar(context, 'تم الحذف بنجاح');
    } else {
      Helpers.showSnackBar(context, docProvider.error ?? 'حدث خطأ',
          isError: true);
    }
  }

  void _performSearch(DocumentProvider docProvider) {
    docProvider.loadWarid(search: _searchController.text.trim());
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
      Helpers.showSnackBar(context, 'تعذر قراءة الملف. يرجى المحاولة مرة أخرى.',
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
                  'ملاحظة: المرفقات لا تُستورد من Excel ويجب رفعها يدويًا لكل سجل.',
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
                  _searchController.clear();
                  setState(() {});
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

  Widget _buildActionButtons(
      AuthProvider authProvider, DocumentProvider docProvider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: () => _performSearch(docProvider),
          icon: const Icon(Icons.search),
          label: const Text('بحث'),
        ),
        if (authProvider.canImportExcel)
          ElevatedButton.icon(
            onPressed: _importWaridExcel,
            icon: const Icon(Icons.upload_file),
            label: const Text('رفع Excel'),
          ),
        if (authProvider.canManageWarid)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WaridFormScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('جديد'),
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
                Chip(
                  label: Text(
                      warid.needsFollowup ? 'يحتاج متابعة' : 'لا يحتاج متابعة'),
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    warid.needsFollowup ? Icons.priority_high : Icons.check,
                    size: 16,
                    color: warid.needsFollowup ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
          columns: const [
            DataColumn2(label: Text('رقم القيد'), size: ColumnSize.S),
            DataColumn2(label: Text('التاريخ'), size: ColumnSize.S),
            DataColumn2(label: Text('الجهة'), size: ColumnSize.L),
            DataColumn2(label: Text('الموضوع'), size: ColumnSize.L),
            DataColumn2(label: Text('المرفقات'), size: ColumnSize.S),
            DataColumn2(label: Text('متابعة'), size: ColumnSize.S),
            DataColumn2(label: Text('إجراءات'), size: ColumnSize.M),
          ],
          rows: waridList.map((warid) {
            return DataRow2(
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
                  warid.needsFollowup
                      ? const Icon(Icons.notification_important,
                          color: Colors.red)
                      : const Icon(Icons.check_circle, color: Colors.green),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                        child: _buildActionButtons(authProvider, docProvider),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildSearchField(docProvider)),
                      const SizedBox(width: 8),
                      _buildActionButtons(authProvider, docProvider),
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

