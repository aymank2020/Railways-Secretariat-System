import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../providers/document_provider.dart';
import '../../utils/helpers.dart';
import 'warid_form_screen.dart';

class WaridSearchScreen extends StatefulWidget {
  const WaridSearchScreen({super.key});

  @override
  State<WaridSearchScreen> createState() => _WaridSearchScreenState();
}

class _WaridSearchScreenState extends State<WaridSearchScreen> {
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
    docProvider.loadWarid(
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
    docProvider.loadWarid();
  }

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context);
    final waridList = docProvider.waridList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث في الوارد'),
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
                : waridList.isEmpty
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
                            rows: waridList.map((warid) {
                              return DataRow2(
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

  void _showDetails(dynamic warid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفاصيل الوارد'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('رقم القيد:', warid.qaidNumber),
              _buildDetailRow(
                  'تاريخ القيد:', Helpers.formatDate(warid.qaidDate)),
              _buildDetailRow('الجهة الوارد منها:', warid.sourceAdministration),
              _buildDetailRow('الموضوع:', warid.subject),
              _buildDetailRow(
                  'عدد المرفقات:', warid.attachmentCount.toString()),
              if (warid.recipient1Name != null)
                _buildDetailRow('المستلم 1:', warid.recipient1Name),
              if (warid.recipient2Name != null)
                _buildDetailRow('المستلم 2:', warid.recipient2Name),
              if (warid.recipient3Name != null)
                _buildDetailRow('المستلم 3:', warid.recipient3Name),
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

