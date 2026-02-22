class SadirModel {
  static const String followupStatusWaitingReply = 'waiting_reply';
  static const String followupStatusCompleted = 'completed';

  final int? id;
  final String qaidNumber;
  final DateTime qaidDate;
  final String? destinationAdministration;
  final String? letterNumber;
  final DateTime? letterDate;
  final int attachmentCount;
  final String subject;
  final String? notes;

  // Signature status
  final String signatureStatus;
  final DateTime? signatureDate;

  // Sent to fields (up to 3)
  final String? sentTo1Name;
  final DateTime? sentTo1DeliveryDate;
  final String? sentTo2Name;
  final DateTime? sentTo2DeliveryDate;
  final String? sentTo3Name;
  final DateTime? sentTo3DeliveryDate;

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

  SadirModel({
    this.id,
    required this.qaidNumber,
    required this.qaidDate,
    this.destinationAdministration,
    this.letterNumber,
    this.letterDate,
    this.attachmentCount = 0,
    required this.subject,
    this.notes,
    this.signatureStatus = 'pending',
    this.signatureDate,
    this.sentTo1Name,
    this.sentTo1DeliveryDate,
    this.sentTo2Name,
    this.sentTo2DeliveryDate,
    this.sentTo3Name,
    this.sentTo3DeliveryDate,
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
      'destination_administration': destinationAdministration,
      'letter_number': letterNumber,
      'letter_date': letterDate?.toIso8601String(),
      'attachment_count': attachmentCount,
      'subject': subject,
      'notes': notes,
      'signature_status': signatureStatus,
      'signature_date': signatureDate?.toIso8601String(),
      'sent_to_1_name': sentTo1Name,
      'sent_to_1_delivery_date': sentTo1DeliveryDate?.toIso8601String(),
      'sent_to_2_name': sentTo2Name,
      'sent_to_2_delivery_date': sentTo2DeliveryDate?.toIso8601String(),
      'sent_to_3_name': sentTo3Name,
      'sent_to_3_delivery_date': sentTo3DeliveryDate?.toIso8601String(),
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

  factory SadirModel.fromMap(Map<String, dynamic> map) {
    final needsFollowup = map['needs_followup'] == 1;
    return SadirModel(
      id: map['id'],
      qaidNumber: map['qaid_number'],
      qaidDate: DateTime.parse(map['qaid_date']),
      destinationAdministration: map['destination_administration'],
      letterNumber: map['letter_number'],
      letterDate: map['letter_date'] != null
          ? DateTime.parse(map['letter_date'])
          : null,
      attachmentCount: map['attachment_count'] ?? 0,
      subject: map['subject'],
      notes: map['notes'],
      signatureStatus: map['signature_status'] ?? 'pending',
      signatureDate: map['signature_date'] != null
          ? DateTime.parse(map['signature_date'])
          : null,
      sentTo1Name: map['sent_to_1_name'],
      sentTo1DeliveryDate: map['sent_to_1_delivery_date'] != null
          ? DateTime.parse(map['sent_to_1_delivery_date'])
          : null,
      sentTo2Name: map['sent_to_2_name'],
      sentTo2DeliveryDate: map['sent_to_2_delivery_date'] != null
          ? DateTime.parse(map['sent_to_2_delivery_date'])
          : null,
      sentTo3Name: map['sent_to_3_name'],
      sentTo3DeliveryDate: map['sent_to_3_delivery_date'] != null
          ? DateTime.parse(map['sent_to_3_delivery_date'])
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
    if (value == followupStatusWaitingReply || value == followupStatusCompleted) {
      return value!;
    }
    return needsFollowup ? followupStatusWaitingReply : followupStatusCompleted;
  }

  SadirModel copyWith({
    int? id,
    String? qaidNumber,
    DateTime? qaidDate,
    String? destinationAdministration,
    String? letterNumber,
    DateTime? letterDate,
    int? attachmentCount,
    String? subject,
    String? notes,
    String? signatureStatus,
    DateTime? signatureDate,
    String? sentTo1Name,
    DateTime? sentTo1DeliveryDate,
    String? sentTo2Name,
    DateTime? sentTo2DeliveryDate,
    String? sentTo3Name,
    DateTime? sentTo3DeliveryDate,
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
    return SadirModel(
      id: id ?? this.id,
      qaidNumber: qaidNumber ?? this.qaidNumber,
      qaidDate: qaidDate ?? this.qaidDate,
      destinationAdministration:
          destinationAdministration ?? this.destinationAdministration,
      letterNumber: letterNumber ?? this.letterNumber,
      letterDate: letterDate ?? this.letterDate,
      attachmentCount: attachmentCount ?? this.attachmentCount,
      subject: subject ?? this.subject,
      notes: notes ?? this.notes,
      signatureStatus: signatureStatus ?? this.signatureStatus,
      signatureDate: signatureDate ?? this.signatureDate,
      sentTo1Name: sentTo1Name ?? this.sentTo1Name,
      sentTo1DeliveryDate: sentTo1DeliveryDate ?? this.sentTo1DeliveryDate,
      sentTo2Name: sentTo2Name ?? this.sentTo2Name,
      sentTo2DeliveryDate: sentTo2DeliveryDate ?? this.sentTo2DeliveryDate,
      sentTo3Name: sentTo3Name ?? this.sentTo3Name,
      sentTo3DeliveryDate: sentTo3DeliveryDate ?? this.sentTo3DeliveryDate,
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
