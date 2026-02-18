import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:provider/provider.dart';

import '../../providers/document_provider.dart';
import '../../utils/helpers.dart';

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DocumentProvider>(context, listen: false);
      provider.loadWarid();
      provider.loadSadir();
    });
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
            DataColumn2(label: Text('الجهة الوارد منها'), size: ColumnSize.L),
            DataColumn2(label: Text('الموضوع'), size: ColumnSize.L),
            DataColumn2(label: Text('المرفقات'), size: ColumnSize.S),
          ],
          rows: waridList.map((warid) {
            return DataRow2(
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
            DataColumn2(label: Text('الجهة المرسل إليها'), size: ColumnSize.L),
            DataColumn2(label: Text('الموضوع'), size: ColumnSize.L),
            DataColumn2(label: Text('التوقيع'), size: ColumnSize.S),
          ],
          rows: sadirList.map((sadir) {
            final isSaved = sadir.signatureStatus == 'saved';
            return DataRow2(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSaved
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      Helpers.getSignatureStatusName(sadir.signatureStatus),
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
    );
  }
}

