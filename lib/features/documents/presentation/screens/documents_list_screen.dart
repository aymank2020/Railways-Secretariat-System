import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:railway_secretariat/core/di/app_dependencies.dart';
import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/documents/data/models/warid_model.dart';
import 'package:railway_secretariat/features/documents/presentation/providers/document_provider.dart';
import 'package:railway_secretariat/features/documents/data/datasources/attachment_storage_service.dart';
import 'package:railway_secretariat/features/documents/data/datasources/documents_export_service.dart';
import 'package:railway_secretariat/core/services/storage_location_service.dart';
import 'package:railway_secretariat/utils/helpers.dart';

enum _StoragePathAction { pickFolder, useDefault }

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  final _documentsExportService = DocumentsExportService();
  final _storageLocationService = StorageLocationService();
  final Set<int> _selectedWaridIds = <int>{};
  final Set<int> _selectedSadirIds = <int>{};
  String? _currentStorageRoot;

  @override
  void initState() {
    super.initState();
    _loadStorageRoot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DocumentProvider>(context, listen: false);
      provider.loadWarid();
    });
  }

  Future<void> _loadStorageRoot() async {
    if (kIsWeb) {
      return;
    }

    try {
      final root = await _storageLocationService.resolveStorageRoot();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentStorageRoot = root;
      });
    } catch (_) {
      // Ignore path-read failures; the main workflow still works.
    }
  }

  Future<void> _showStoragePathOptions() async {
    if (kIsWeb) {
      Helpers.showSnackBar(
        context,
        'تغيير مسار التخزين غير مدعوم في نسخة الويب',
        isError: true,
      );
      return;
    }

    final currentRoot = await _storageLocationService.resolveStorageRoot();
    final defaultRoot = await _storageLocationService.getDefaultStorageRoot();
    final customRoot = await _storageLocationService.getCustomStorageRoot();
    if (!mounted) {
      return;
    }

    final action = await showModalBottomSheet<_StoragePathAction>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text(
                  'مسار التخزين الحالي',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: SelectableText(
                  currentRoot,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('اختيار مسار جديد'),
                subtitle: const Text('يدعم المسار المحلي أو مسار الشبكة'),
                onTap: () => Navigator.of(sheetContext)
                    .pop(_StoragePathAction.pickFolder),
              ),
              if (customRoot != null)
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('العودة للمسار الافتراضي'),
                  subtitle: Text(defaultRoot),
                  onTap: () => Navigator.of(sheetContext)
                      .pop(_StoragePathAction.useDefault),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (action == null || !mounted) {
      return;
    }

    if (action == _StoragePathAction.pickFolder) {
      final selected = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مسار تخزين البيانات',
      );
      if (selected == null || selected.trim().isEmpty || !mounted) {
        return;
      }
      await _applyStorageRoot(selected);
      return;
    }

    await _applyStorageRoot(defaultRoot);
  }

  Future<void> _applyStorageRoot(String newRoot) async {
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    final systemUseCases = context.read<AppDependencies>().systemUseCases;
    Helpers.showLoadingDialog(context, message: 'جاري تحديث مسار التخزين...');

    try {
      final result =
          await _storageLocationService.configureStorageRoot(newRoot);

      await systemUseCases.resetDatabaseConnection();
      AttachmentStorageService().clearCache();

      await provider.loadWarid();
      await provider.loadSadir();
      await provider.loadStatistics();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentStorageRoot = result.newRoot;
      });

      final migrationNotes = <String>[];
      if (result.databaseCopied) {
        migrationNotes.add('تم نسخ قاعدة البيانات');
      }
      if (result.attachmentsCopied) {
        migrationNotes.add('تم نسخ المرفقات');
      }
      if (result.databaseAlreadyExists) {
        migrationNotes.add('قاعدة بيانات الهدف كانت موجودة مسبقًا');
      }

      final noteSuffix =
          migrationNotes.isEmpty ? '' : ' (${migrationNotes.join(' - ')})';
      Helpers.showSnackBar(
        context,
        'تم تحديث مسار التخزين بنجاح$noteSuffix',
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(context, 'تعذر تحديث مسار التخزين: $e',
          isError: true);
    } finally {
      if (mounted) {
        Helpers.hideLoadingDialog(context);
      }
    }
  }

  void _handleTabChanged(int index) {
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    if (index == 0) {
      if (provider.waridList.isEmpty) {
        provider.loadWarid();
      }
      return;
    }

    if (provider.sadirList.isEmpty) {
      provider.loadSadir();
    }
  }

  bool _isWaridSelected(WaridModel warid) {
    final id = warid.id;
    return id != null && _selectedWaridIds.contains(id);
  }

  bool _isSadirSelected(SadirModel sadir) {
    final id = sadir.id;
    return id != null && _selectedSadirIds.contains(id);
  }

  List<WaridModel> _getSelectedWarid(List<WaridModel> waridList) {
    return waridList.where(_isWaridSelected).toList();
  }

  List<SadirModel> _getSelectedSadir(List<SadirModel> sadirList) {
    return sadirList.where(_isSadirSelected).toList();
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

  Future<ExportFormat?> _pickExportFormat() async {
    return showModalBottomSheet<ExportFormat>(
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
  }

  Future<void> _showExportWaridOptions(List<WaridModel> waridList) async {
    final selected = _getSelectedWarid(waridList);
    if (selected.isEmpty) {
      Helpers.showSnackBar(context, 'يرجى تحديد سجل واحد على الأقل',
          isError: true);
      return;
    }

    final format = await _pickExportFormat();
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

  Future<void> _showExportSadirOptions(List<SadirModel> sadirList) async {
    final selected = _getSelectedSadir(sadirList);
    if (selected.isEmpty) {
      Helpers.showSnackBar(context, 'يرجى تحديد سجل واحد على الأقل',
          isError: true);
      return;
    }

    final format = await _pickExportFormat();
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

  Widget _buildLoadMoreWarid(DocumentProvider docProvider) {
    if (!docProvider.hasMoreWarid && !docProvider.isLoadingMoreWarid) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        child: OutlinedButton.icon(
          onPressed: docProvider.isLoadingMoreWarid
              ? null
              : () => docProvider.loadMoreWarid(),
          icon: docProvider.isLoadingMoreWarid
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more),
          label: Text(
            docProvider.isLoadingMoreWarid ? 'Loading more...' : 'Load more',
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreSadir(DocumentProvider docProvider) {
    if (!docProvider.hasMoreSadir && !docProvider.isLoadingMoreSadir) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('جميع المستندات'),
          actions: [
            IconButton(
              tooltip: _currentStorageRoot == null
                  ? 'مسار التخزين'
                  : 'مسار التخزين: $_currentStorageRoot',
              onPressed: _showStoragePathOptions,
              icon: const Icon(Icons.storage),
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            onTap: _handleTabChanged,
            tabs: const [
              Tab(icon: Icon(Icons.input), text: 'الوارد'),
              Tab(icon: Icon(Icons.output), text: 'الصادر'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildWaridTab(docProvider),
            _buildSadirTab(docProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildWaridTab(DocumentProvider docProvider) {
    final waridList = docProvider.waridList;
    if (docProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (waridList.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد بيانات وارد',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      );
    }

    final selectableCount = waridList.where((warid) => warid.id != null).length;
    final selectedCount = _getSelectedWarid(waridList).length;
    final allSelected = selectableCount > 0 && selectedCount == selectableCount;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: selectableCount == 0
                    ? null
                    : () => _toggleSelectAllWarid(waridList, !allSelected),
                icon: Icon(
                  allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                ),
                label: Text(allSelected ? 'إلغاء التحديد' : 'تحديد الكل'),
              ),
              ElevatedButton.icon(
                onPressed: selectedCount == 0
                    ? null
                    : () => _showExportWaridOptions(waridList),
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
          const SizedBox(height: 12),
          Expanded(
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
                  DataColumn2(
                      label: Text('الجهة الوارد منها'), size: ColumnSize.L),
                  DataColumn2(label: Text('الموضوع'), size: ColumnSize.L),
                  DataColumn2(label: Text('المرفقات'), size: ColumnSize.S),
                ],
                rows: waridList.map((warid) {
                  return DataRow2(
                    selected: _isWaridSelected(warid),
                    onSelectChanged: warid.id == null
                        ? null
                        : (selected) => _toggleWaridSelection(warid, selected),
                    cells: [
                      DataCell(Text(warid.qaidNumber)),
                      DataCell(Text(Helpers.formatDate(warid.qaidDate))),
                      DataCell(
                        Text(
                          warid.sourceAdministration,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Text(
                          warid.subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(Text(warid.attachmentCount.toString())),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          _buildLoadMoreWarid(docProvider),
        ],
      ),
    );
  }

  Widget _buildSadirTab(DocumentProvider docProvider) {
    final sadirList = docProvider.sadirList;
    if (docProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (sadirList.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد بيانات صادر',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      );
    }

    final selectableCount = sadirList.where((sadir) => sadir.id != null).length;
    final selectedCount = _getSelectedSadir(sadirList).length;
    final allSelected = selectableCount > 0 && selectedCount == selectableCount;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: selectableCount == 0
                    ? null
                    : () => _toggleSelectAllSadir(sadirList, !allSelected),
                icon: Icon(
                  allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                ),
                label: Text(allSelected ? 'إلغاء التحديد' : 'تحديد الكل'),
              ),
              ElevatedButton.icon(
                onPressed: selectedCount == 0
                    ? null
                    : () => _showExportSadirOptions(sadirList),
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
          const SizedBox(height: 12),
          Expanded(
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
                  DataColumn2(
                      label: Text('الجهة المرسل إليها'), size: ColumnSize.L),
                  DataColumn2(label: Text('الموضوع'), size: ColumnSize.L),
                  DataColumn2(label: Text('التوقيع'), size: ColumnSize.S),
                ],
                rows: sadirList.map((sadir) {
                  final isSaved = sadir.signatureStatus == 'saved';
                  return DataRow2(
                    selected: _isSadirSelected(sadir),
                    onSelectChanged: sadir.id == null
                        ? null
                        : (selected) => _toggleSadirSelection(sadir, selected),
                    cells: [
                      DataCell(Text(sadir.qaidNumber)),
                      DataCell(Text(Helpers.formatDate(sadir.qaidDate))),
                      DataCell(
                        Text(
                          sadir.destinationAdministration ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Text(
                          sadir.subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSaved
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            Helpers.getSignatureStatusName(
                                sadir.signatureStatus),
                            style: TextStyle(
                              color: isSaved ? Colors.green : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          _buildLoadMoreSadir(docProvider),
        ],
      ),
    );
  }
}
