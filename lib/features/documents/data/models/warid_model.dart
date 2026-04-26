class WaridModel {
  static const String followupStatusWaitingReply = 'waiting_reply';
  static const String followupStatusCompleted = 'completed';

  final int? id;
  final String qaidNumber;
  final DateTime qaidDate;
  final String sourceAdministration;
  final String? letterNumber;
  final DateTime? letterDate;
  final String? chairmanIncomingNumber;
  final DateTime? chairmanIncomingDate;
  final String? chairmanReturnNumber;
  final DateTime? chairmanReturnDate;
  final int attachmentCount;
  final String subject;
  final String? notes;

  // Recipient fields (up to 3)
  final String? recipient1Name;
  final DateTime? recipient1DeliveryDate;
  final String? recipient2Name;
  final DateTime? recipient2DeliveryDate;
  final String? recipient3Name;
  final DateTime? recipient3DeliveryDate;

  // Classification
  final bool isMinistry;
  final bool isAuthority;
  final bool isOther;
  final String? otherDetails;

  // Primary attachment info
  final String? fileName;
  final String? filePath;

  // Follow-up
  final bool needsFollowup;
  final String? followupNotes;
  final String followupStatus;
  final String? followupFileName;
  final String? followupFilePath;

  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? createdBy;
  final String? createdByName;

  WaridModel({
    this.id,
    required this.qaidNumber,
    required this.qaidDate,
    required this.sourceAdministration,
    this.letterNumber,
    this.letterDate,
    this.chairmanIncomingNumber,
    this.chairmanIncomingDate,
    this.chairmanReturnNumber,
    this.chairmanReturnDate,
    this.attachmentCount = 0,
    required this.subject,
    this.notes,
    this.recipient1Name,
    this.recipient1DeliveryDate,
    this.recipient2Name,
    this.recipient2DeliveryDate,
    this.recipient3Name,
    this.recipient3DeliveryDate,
    this.isMinistry = false,
    this.isAuthority = false,
    this.isOther = false,
    this.otherDetails,
    this.fileName,
    this.filePath,
    this.needsFollowup = false,
    this.followupNotes,
    this.followupStatus = followupStatusWaitingReply,
    this.followupFileName,
    this.followupFilePath,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.createdByName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'qaid_number': qaidNumber,
      'qaid_date': qaidDate.toIso8601String(),
      'source_administration': sourceAdministration,
      'letter_number': letterNumber,
      'letter_date': letterDate?.toIso8601String(),
      'chairman_incoming_number': chairmanIncomingNumber,
      'chairman_incoming_date': chairmanIncomingDate?.toIso8601String(),
      'chairman_return_number': chairmanReturnNumber,
      'chairman_return_date': chairmanReturnDate?.toIso8601String(),
      'attachment_count': attachmentCount,
      'subject': subject,
      'notes': notes,
      'recipient_1_name': recipient1Name,
      'recipient_1_delivery_date': recipient1DeliveryDate?.toIso8601String(),
      'recipient_2_name': recipient2Name,
      'recipient_2_delivery_date': recipient2DeliveryDate?.toIso8601String(),
      'recipient_3_name': recipient3Name,
      'recipient_3_delivery_date': recipient3DeliveryDate?.toIso8601String(),
      'is_ministry': isMinistry ? 1 : 0,
      'is_authority': isAuthority ? 1 : 0,
      'is_other': isOther ? 1 : 0,
      'other_details': otherDetails,
      'file_name': fileName,
      'file_path': filePath,
      'needs_followup': needsFollowup ? 1 : 0,
      'followup_notes': followupNotes,
      'followup_status': followupStatus,
      'followup_file_name': followupFileName,
      'followup_file_path': followupFilePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'created_by_name': createdByName,
    };
  }

  factory WaridModel.fromMap(Map<String, dynamic> map) {
    final needsFollowup = map['needs_followup'] == 1;
    return WaridModel(
      id: map['id'],
      qaidNumber: map['qaid_number'],
      qaidDate: DateTime.parse(map['qaid_date']),
      sourceAdministration: map['source_administration'],
      letterNumber: map['letter_number'],
      letterDate: map['letter_date'] != null
          ? DateTime.parse(map['letter_date'])
          : null,
      chairmanIncomingNumber: map['chairman_incoming_number'],
      chairmanIncomingDate: map['chairman_incoming_date'] != null
          ? DateTime.parse(map['chairman_incoming_date'])
          : null,
      chairmanReturnNumber: map['chairman_return_number'],
      chairmanReturnDate: map['chairman_return_date'] != null
          ? DateTime.parse(map['chairman_return_date'])
          : null,
      attachmentCount: map['attachment_count'] ?? 0,
      subject: map['subject'],
      notes: map['notes'],
      recipient1Name: map['recipient_1_name'],
      recipient1DeliveryDate: map['recipient_1_delivery_date'] != null
          ? DateTime.parse(map['recipient_1_delivery_date'])
          : null,
      recipient2Name: map['recipient_2_name'],
      recipient2DeliveryDate: map['recipient_2_delivery_date'] != null
          ? DateTime.parse(map['recipient_2_delivery_date'])
          : null,
      recipient3Name: map['recipient_3_name'],
      recipient3DeliveryDate: map['recipient_3_delivery_date'] != null
          ? DateTime.parse(map['recipient_3_delivery_date'])
          : null,
      isMinistry: map['is_ministry'] == 1,
      isAuthority: map['is_authority'] == 1,
      isOther: map['is_other'] == 1,
      otherDetails: map['other_details'],
      fileName: map['file_name'],
      filePath: map['file_path'],
      needsFollowup: needsFollowup,
      followupNotes: map['followup_notes'],
      followupStatus: _normalizeFollowupStatus(
        map['followup_status']?.toString(),
        needsFollowup: needsFollowup,
      ),
      followupFileName: map['followup_file_name'],
      followupFilePath: map['followup_file_path'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      createdBy: map['created_by'],
      createdByName: map['created_by_name'],
    );
  }

  static String _normalizeFollowupStatus(
    String? status, {
    required bool needsFollowup,
  }) {
    final value = status?.trim().toLowerCase();
    if (value == followupStatusWaitingReply ||
        value == followupStatusCompleted) {
      return value!;
    }
    return needsFollowup ? followupStatusWaitingReply : followupStatusCompleted;
  }

  WaridModel copyWith({
    int? id,
    String? qaidNumber,
    DateTime? qaidDate,
    String? sourceAdministration,
    String? letterNumber,
    DateTime? letterDate,
    String? chairmanIncomingNumber,
    DateTime? chairmanIncomingDate,
    String? chairmanReturnNumber,
    DateTime? chairmanReturnDate,
    int? attachmentCount,
    String? subject,
    String? notes,
    String? recipient1Name,
    DateTime? recipient1DeliveryDate,
    String? recipient2Name,
    DateTime? recipient2DeliveryDate,
    String? recipient3Name,
    DateTime? recipient3DeliveryDate,
    bool? isMinistry,
    bool? isAuthority,
    bool? isOther,
    String? otherDetails,
    String? fileName,
    String? filePath,
    bool? needsFollowup,
    String? followupNotes,
    String? followupStatus,
    String? followupFileName,
    String? followupFilePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? createdBy,
    String? createdByName,
  }) {
    return WaridModel(
      id: id ?? this.id,
      qaidNumber: qaidNumber ?? this.qaidNumber,
      qaidDate: qaidDate ?? this.qaidDate,
      sourceAdministration: sourceAdministration ?? this.sourceAdministration,
      letterNumber: letterNumber ?? this.letterNumber,
      letterDate: letterDate ?? this.letterDate,
      chairmanIncomingNumber:
          chairmanIncomingNumber ?? this.chairmanIncomingNumber,
      chairmanIncomingDate: chairmanIncomingDate ?? this.chairmanIncomingDate,
      chairmanReturnNumber: chairmanReturnNumber ?? this.chairmanReturnNumber,
      chairmanReturnDate: chairmanReturnDate ?? this.chairmanReturnDate,
      attachmentCount: attachmentCount ?? this.attachmentCount,
      subject: subject ?? this.subject,
      notes: notes ?? this.notes,
      recipient1Name: recipient1Name ?? this.recipient1Name,
      recipient1DeliveryDate:
          recipient1DeliveryDate ?? this.recipient1DeliveryDate,
      recipient2Name: recipient2Name ?? this.recipient2Name,
      recipient2DeliveryDate:
          recipient2DeliveryDate ?? this.recipient2DeliveryDate,
      recipient3Name: recipient3Name ?? this.recipient3Name,
      recipient3DeliveryDate:
          recipient3DeliveryDate ?? this.recipient3DeliveryDate,
      isMinistry: isMinistry ?? this.isMinistry,
      isAuthority: isAuthority ?? this.isAuthority,
      isOther: isOther ?? this.isOther,
      otherDetails: otherDetails ?? this.otherDetails,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      needsFollowup: needsFollowup ?? this.needsFollowup,
      followupNotes: followupNotes ?? this.followupNotes,
      followupStatus: followupStatus ?? this.followupStatus,
      followupFileName: followupFileName ?? this.followupFileName,
      followupFilePath: followupFilePath ?? this.followupFilePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
    );
  }
}
