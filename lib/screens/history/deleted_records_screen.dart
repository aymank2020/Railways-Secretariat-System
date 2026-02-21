import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/deleted_record_model.dart';
import '../../models/sadir_model.dart';
import '../../models/warid_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../utils/helpers.dart';
import '../sadir/sadir_form_screen.dart';
import '../warid/warid_form_screen.dart';

class DeletedRecordsScreen extends StatefulWidget {
  const DeletedRecordsScreen({super.key});

  @override
  State<DeletedRecordsScreen> createState() => _DeletedRecordsScreenState();
}

class _DeletedRecordsScreenState extends State<DeletedRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'all';
  bool _includeRestored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeletedRecords();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadDeletedRecords() {
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    provider.loadDeletedRecords(
      documentType: _selectedType == 'all' ? null : _selectedType,
      includeRestored: _includeRestored,
      search: _searchController.text.trim(),
    );
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int? _toIntOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  bool _toBool(dynamic value) {
    return _toInt(value) == 1;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  String? _toNullableText(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  WaridModel _buildWaridFromDeleted(DeletedRecordModel record) {
    final payload = record.archivedPayload;
    return WaridModel(
      qaidNumber: '',
      qaidDate: _parseDate(payload['qaid_date']) ?? DateTime.now(),
      sourceAdministration:
          (payload['source_administration'] ?? '').toString().trim(),
      letterNumber: _toNullableText(payload['letter_number']),
      letterDate: _parseDate(payload['letter_date']),
      attachmentCount: _toInt(payload['attachment_count']),
      subject: (payload['subject'] ?? '').toString().trim(),
      notes: _toNullableText(payload['notes']),
      recipient1Name: _toNullableText(payload['recipient_1_name']),
      recipient1DeliveryDate: _parseDate(payload['recipient_1_delivery_date']),
      recipient2Name: _toNullableText(payload['recipient_2_name']),
      recipient2DeliveryDate: _parseDate(payload['recipient_2_delivery_date']),
      recipient3Name: _toNullableText(payload['recipient_3_name']),
      recipient3DeliveryDate: _parseDate(payload['recipient_3_delivery_date']),
      isMinistry: _toBool(payload['is_ministry']),
      isAuthority: _toBool(payload['is_authority']),
      isOther: _toBool(payload['is_other']),
      otherDetails: _toNullableText(payload['other_details']),
      fileName: _toNullableText(payload['file_name']),
      filePath: _toNullableText(payload['file_path']),
      needsFollowup: _toBool(payload['needs_followup']),
      followupNotes: _toNullableText(payload['followup_notes']),
      createdAt: _parseDate(payload['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(payload['updated_at']),
      createdBy: _toIntOrNull(payload['created_by']),
      createdByName: _toNullableText(payload['created_by_name']),
    );
  }

  SadirModel _buildSadirFromDeleted(DeletedRecordModel record) {
    final payload = record.archivedPayload;
    return SadirModel(
      qaidNumber: '',
      qaidDate: _parseDate(payload['qaid_date']) ?? DateTime.now(),
      destinationAdministration:
          _toNullableText(payload['destination_administration']),
      letterNumber: _toNullableText(payload['letter_number']),
      letterDate: _parseDate(payload['letter_date']),
      attachmentCount: _toInt(payload['attachment_count']),
      subject: (payload['subject'] ?? '').toString().trim(),
      notes: _toNullableText(payload['notes']),
      signatureStatus:
          _toNullableText(payload['signature_status']) ?? 'pending',
      signatureDate: _parseDate(payload['signature_date']),
      sentTo1Name: _toNullableText(payload['sent_to_1_name']),
      sentTo1DeliveryDate: _parseDate(payload['sent_to_1_delivery_date']),
      sentTo2Name: _toNullableText(payload['sent_to_2_name']),
      sentTo2DeliveryDate: _parseDate(payload['sent_to_2_delivery_date']),
      sentTo3Name: _toNullableText(payload['sent_to_3_name']),
      sentTo3DeliveryDate: _parseDate(payload['sent_to_3_delivery_date']),
      isMinistry: _toBool(payload['is_ministry']),
      isAuthority: _toBool(payload['is_authority']),
      isOther: _toBool(payload['is_other']),
      otherDetails: _toNullableText(payload['other_details']),
      fileName: _toNullableText(payload['file_name']),
      filePath: _toNullableText(payload['file_path']),
      needsFollowup: _toBool(payload['needs_followup']),
      followupNotes: _toNullableText(payload['followup_notes']),
      createdAt: _parseDate(payload['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(payload['updated_at']),
      createdBy: _toIntOrNull(payload['created_by']),
      createdByName: _toNullableText(payload['created_by_name']),
    );
  }

  Future<void> _showDetails(DeletedRecordModel record) async {
    final summaryRows = <(String, String)>[
      ('النوع', record.displayType),
      ('تاريخ القيد', Helpers.formatDate(record.qaidDate)),
      ('الجهة', record.administration),
      ('الموضوع', record.subject.isEmpty ? '-' : record.subject),
      ('عدد المرفقات', record.attachmentCount.toString()),
      ('المتابعة', record.needsFollowup ? 'يحتاج متابعة' : 'لا يحتاج متابعة'),
      ('حالة الاسترجاع', record.isRestored ? 'تم الاسترجاع' : 'محذوف'),
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ملخص السجل المحذوف'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final row in summaryRows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(dialogContext).style,
                          children: [
                            TextSpan(
                              text: '${row.$1}: ',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: row.$2),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'ملاحظة: رقم القيد الأصلي غير محفوظ في السجل المحذوف لتفادي التكرار.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
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

  Future<void> _restoreRecord(DeletedRecordModel record) async {
    if (record.isRestored) {
      Helpers.showSnackBar(context, 'تم استرجاع هذا السجل مسبقًا',
          isError: true);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) {
      Helpers.showSnackBar(context, 'يجب تسجيل الدخول أولًا', isError: true);
      return;
    }

    Widget? page;
    if (record.documentType == 'warid') {
      page = WaridFormScreen(
        initialWarid: _buildWaridFromDeleted(record),
        restoreDeletedRecordId: record.id,
      );
    } else if (record.documentType == 'sadir') {
      page = SadirFormScreen(
        initialSadir: _buildSadirFromDeleted(record),
        restoreDeletedRecordId: record.id,
      );
    }

    if (page == null) {
      Helpers.showSnackBar(
        context,
        'نوع سجل غير مدعوم للاسترجاع',
        isError: true,
      );
      return;
    }

    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => page!),
    );

    if (!mounted) {
      return;
    }
    if (restored == true) {
      _loadDeletedRecords();
    }
  }

  Widget _buildFilters() {
    final isCompact = MediaQuery.of(context).size.width < 980;

    final typeDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedType,
      items: const [
        DropdownMenuItem(value: 'all', child: Text('الكل')),
        DropdownMenuItem(value: 'warid', child: Text('الوارد')),
        DropdownMenuItem(value: 'sadir', child: Text('الصادر')),
      ],
      decoration: const InputDecoration(
        labelText: 'نوع السجل',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() {
          _selectedType = value;
        });
        _loadDeletedRecords();
      },
    );

    final searchField = TextField(
      controller: _searchController,
      onSubmitted: (_) => _loadDeletedRecords(),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'بحث في الموضوع أو الجهة أو الملاحظات...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                  _loadDeletedRecords();
                },
              ),
        border: const OutlineInputBorder(),
      ),
    );

    final includeRestored = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _includeRestored,
          onChanged: (value) {
            setState(() {
              _includeRestored = value ?? false;
            });
            _loadDeletedRecords();
          },
        ),
        const Text('عرض المسترجع'),
      ],
    );

    final searchButton = ElevatedButton.icon(
      onPressed: _loadDeletedRecords,
      icon: const Icon(Icons.search),
      label: const Text('بحث'),
    );

    if (isCompact) {
      return Column(
        children: [
          searchField,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: typeDropdown),
              const SizedBox(width: 8),
              searchButton,
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: includeRestored,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: searchField),
        const SizedBox(width: 8),
        SizedBox(width: 180, child: typeDropdown),
        const SizedBox(width: 8),
        includeRestored,
        const SizedBox(width: 8),
        searchButton,
      ],
    );
  }

  Widget _buildStatusChip(DeletedRecordModel record) {
    final isRestored = record.isRestored;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isRestored
            ? Colors.green.withValues(alpha: 0.16)
            : Colors.orange.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isRestored ? 'مسترجع' : 'محذوف',
        style: TextStyle(
          color: isRestored ? Colors.green.shade700 : Colors.orange.shade800,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCompactCard(DeletedRecordModel record) {
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
                    record.subject.isEmpty ? '-' : record.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(record),
              ],
            ),
            const SizedBox(height: 10),
            Text('النوع: ${record.displayType}'),
            Text('الجهة: ${record.administration}'),
            Text(
              'تاريخ الحذف: ${Helpers.formatDate(record.deletedAt, includeTime: true)}',
            ),
            Text(
              'المحذوف بواسطة: ${record.deletedByName?.trim().isNotEmpty == true ? record.deletedByName : '-'}',
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _showDetails(record),
                  icon: const Icon(Icons.visibility, color: Colors.blue),
                  tooltip: 'عرض',
                ),
                if (!record.isRestored)
                  IconButton(
                    onPressed: () => _restoreRecord(record),
                    icon: const Icon(Icons.edit_note, color: Colors.green),
                    tooltip: 'استرجاع مع تعديل',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideTable(List<DeletedRecordModel> records) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: DataTable2(
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: 1280,
          columns: const [
            DataColumn2(label: Text('النوع'), size: ColumnSize.S),
            DataColumn2(label: Text('تاريخ الحذف')),
            DataColumn2(label: Text('الجهة'), size: ColumnSize.L),
            DataColumn2(label: Text('الموضوع'), size: ColumnSize.L),
            DataColumn2(label: Text('مرفقات'), size: ColumnSize.S),
            DataColumn2(label: Text('متابعة'), size: ColumnSize.S),
            DataColumn2(label: Text('الحالة'), size: ColumnSize.S),
            DataColumn2(label: Text('إجراءات')),
          ],
          rows: records.map((record) {
            return DataRow2(
              cells: [
                DataCell(Text(record.displayType)),
                DataCell(
                  Text(Helpers.formatDate(record.deletedAt, includeTime: true)),
                ),
                DataCell(
                  Text(
                    record.administration,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(
                  Text(
                    record.subject.isEmpty ? '-' : record.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(Text(record.attachmentCount.toString())),
                DataCell(Text(record.needsFollowup ? 'نعم' : 'لا')),
                DataCell(_buildStatusChip(record)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showDetails(record),
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        tooltip: 'عرض',
                      ),
                      if (!record.isRestored)
                        IconButton(
                          onPressed: () => _restoreRecord(record),
                          icon:
                              const Icon(Icons.edit_note, color: Colors.green),
                          tooltip: 'استرجاع مع تعديل',
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
    final authProvider = Provider.of<AuthProvider>(context);
    final documentProvider = Provider.of<DocumentProvider>(context);
    final records = documentProvider.deletedRecords;
    final isCompact = MediaQuery.of(context).size.width < 1100;

    if (!authProvider.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text(
            'هذا القسم متاح لمدير النظام فقط',
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
            child: _buildFilters(),
          ),
          Expanded(
            child: documentProvider.isLoading && records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : records.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد سجلات محذوفة مطابقة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : isCompact
                        ? ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: records.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _buildCompactCard(records[index]),
                          )
                        : _buildWideTable(records),
          ),
        ],
      ),
    );
  }
}
