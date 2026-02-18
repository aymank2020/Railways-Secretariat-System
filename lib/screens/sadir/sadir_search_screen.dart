import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../providers/document_provider.dart';
import '../../utils/helpers.dart';
import 'sadir_form_screen.dart';

class SadirSearchScreen extends StatefulWidget {
  const SadirSearchScreen({super.key});

  @override
  State<SadirSearchScreen> createState() => _SadirSearchScreenState();
}

class _SadirSearchScreenState extends State<SadirSearchScreen> {
  final _searchController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

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
    docProvider.loadSadir(
      search: _searchController.text.isEmpty ? null : _searchController.text,
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  void _clear() {
    _searchController.clear();
    _fromDate = null;
    _toDate = null;
    final docProvider = Provider.of<DocumentProvider>(context, listen: false);
    docProvider.loadSadir();
  }

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context);
    final sadirList = docProvider.sadirList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث في الصادر'),
      ),
      body: Column(
        children: [
          // Search filters
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
                  ],
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: docProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : sadirList.isEmpty
                    ? const Center(child: Text('لا توجد نتائج'))
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          child: DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            minWidth: 1000,
                            columns: const [
                              DataColumn2(
                                  label: Text('رقم القيد'), size: ColumnSize.S),
                              DataColumn2(
                                  label: Text('التاريخ'), size: ColumnSize.S),
                              DataColumn2(
                                  label: Text('الجهة'), size: ColumnSize.L),
                              DataColumn2(
                                  label: Text('الموضوع'), size: ColumnSize.L),
                              DataColumn2(
                                  label: Text('إجراءات'), size: ColumnSize.S),
                            ],
                            rows: sadirList.map((sadir) {
                              return DataRow2(
                                cells: [
                                  DataCell(Text(sadir.qaidNumber)),
                                  DataCell(
                                      Text(Helpers.formatDate(sadir.qaidDate))),
                                  DataCell(Text(
                                      sadir.destinationAdministration ?? '-')),
                                  DataCell(Text(sadir.subject)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => SadirFormScreen(
                                                    editSadir: sadir),
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.visibility,
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
        ],
      ),
    );
  }

  void _showDetails(dynamic sadir) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفاصيل الصادر'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('رقم القيد:', sadir.qaidNumber),
              _buildDetailRow(
                  'تاريخ القيد:', Helpers.formatDate(sadir.qaidDate)),
              _buildDetailRow('الجهة المرسل إليها:',
                  sadir.destinationAdministration ?? '-'),
              _buildDetailRow('الموضوع:', sadir.subject),
              _buildDetailRow('حالة التوقيع:',
                  Helpers.getSignatureStatusName(sadir.signatureStatus)),
              _buildDetailRow(
                  'عدد المرفقات:', sadir.attachmentCount.toString()),
              if (sadir.sentTo1Name != null)
                _buildDetailRow('المرسل إليه 1:', sadir.sentTo1Name),
              if (sadir.sentTo2Name != null)
                _buildDetailRow('المرسل إليه 2:', sadir.sentTo2Name),
              if (sadir.sentTo3Name != null)
                _buildDetailRow('المرسل إليه 3:', sadir.sentTo3Name),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
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
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

