import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sadir_model.dart';
import '../../models/warid_model.dart';
import '../../providers/document_provider.dart';
import '../../services/documents_export_service.dart';
import '../../utils/helpers.dart';

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  final _documentsExportService = DocumentsExportService();
  final Set<int> _selectedWaridIds = <int>{};
  final Set<int> _selectedSadirIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DocumentProvider>(context, listen: false);
      provider.loadWarid();
      provider.loadSadir();
    });
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

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('جميع المستندات'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: [
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
        ],
      ),
    );
  }
}
