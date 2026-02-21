import 'dart:convert';

class DeletedRecordModel {
  final int id;
  final String documentType;
  final int? originalRecordId;
  final Map<String, dynamic> archivedPayload;
  final DateTime deletedAt;
  final int? deletedBy;
  final String? deletedByName;
  final bool isRestored;
  final DateTime? restoredAt;
  final int? restoredBy;
  final String? restoredByName;
  final int? restoredRecordId;

  const DeletedRecordModel({
    required this.id,
    required this.documentType,
    required this.originalRecordId,
    required this.archivedPayload,
    required this.deletedAt,
    this.deletedBy,
    this.deletedByName,
    this.isRestored = false,
    this.restoredAt,
    this.restoredBy,
    this.restoredByName,
    this.restoredRecordId,
  });

  String get displayType => documentType == 'warid' ? 'وارد' : 'صادر';

  String get subject => (archivedPayload['subject'] ?? '').toString().trim();

  String get administration {
    if (documentType == 'warid') {
      return (archivedPayload['source_administration'] ?? '-')
          .toString()
          .trim();
    }
    return (archivedPayload['destination_administration'] ?? '-')
        .toString()
        .trim();
  }

  int get attachmentCount {
    return _toInt(archivedPayload['attachment_count']) ?? 0;
  }

  bool get needsFollowup {
    return (_toInt(archivedPayload['needs_followup']) ?? 0) == 1;
  }

  DateTime? get qaidDate {
    final rawValue = archivedPayload['qaid_date'];
    if (rawValue == null) {
      return null;
    }
    return DateTime.tryParse(rawValue.toString());
  }

  bool matchesSearch(String normalizedQuery) {
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final values = <String>[
      subject,
      administration,
      (archivedPayload['notes'] ?? '').toString(),
      (archivedPayload['letter_number'] ?? '').toString(),
      (archivedPayload['created_by_name'] ?? '').toString(),
      deletedByName ?? '',
      displayType,
    ];

    for (final value in values) {
      if (value.toLowerCase().contains(normalizedQuery)) {
        return true;
      }
    }
    return false;
  }

  factory DeletedRecordModel.fromMap(Map<String, dynamic> map) {
    final payloadRaw = (map['archived_payload'] ?? '{}').toString();
    final payload = _decodePayload(payloadRaw);

    return DeletedRecordModel(
      id: _toInt(map['id']) ?? 0,
      documentType:
          (map['document_type'] ?? '').toString().trim().toLowerCase(),
      originalRecordId: _toInt(map['original_record_id']),
      archivedPayload: payload,
      deletedAt: DateTime.tryParse((map['deleted_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deletedBy: _toInt(map['deleted_by']),
      deletedByName: map['deleted_by_name']?.toString(),
      isRestored: (_toInt(map['is_restored']) ?? 0) == 1,
      restoredAt: _tryParseDate(map['restored_at']),
      restoredBy: _toInt(map['restored_by']),
      restoredByName: map['restored_by_name']?.toString(),
      restoredRecordId: _toInt(map['restored_record_id']),
    );
  }

  static Map<String, dynamic> _decodePayload(String payloadRaw) {
    try {
      final decoded = jsonDecode(payloadRaw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      // Ignore invalid payload and return empty map.
    }
    return <String, dynamic>{};
  }

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
