class WaridModel {
  final int? id;
  final String qaidNumber; // رقم القيد
  final DateTime qaidDate; // تاريخ القيد
  final String sourceAdministration; // الإدارة الوارد منها
  final String? letterNumber; // رقم الخطاب
  final DateTime? letterDate; // تاريخ الخطاب
  final int attachmentCount; // عدد المرفقات
  final String subject; // الموضوع
  final String? notes; // ملاحظات

  // Recipient fields (up to 3)
  final String? recipient1Name;
  final DateTime? recipient1DeliveryDate;
  final String? recipient2Name;
  final DateTime? recipient2DeliveryDate;
  final String? recipient3Name;
  final DateTime? recipient3DeliveryDate;

  // Classification
  final bool isMinistry; // الوزارة
  final bool isAuthority; // الهيئة
  final bool isOther; // جهة أخرى
  final String? otherDetails; // تفاصيل الجهة الأخرى

  // File info
  final String? fileName; // اسم ملف الحفظ
  final String? filePath; // مسار الملف المرفق

  // Follow up
  final bool needsFollowup; // يحتاج لمتابعة
  final String? followupNotes; // ملاحظات المتابعة

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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'created_by_name': createdByName,
    };
  }

  factory WaridModel.fromMap(Map<String, dynamic> map) {
    return WaridModel(
      id: map['id'],
      qaidNumber: map['qaid_number'],
      qaidDate: DateTime.parse(map['qaid_date']),
      sourceAdministration: map['source_administration'],
      letterNumber: map['letter_number'],
      letterDate: map['letter_date'] != null
          ? DateTime.parse(map['letter_date'])
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
      needsFollowup: map['needs_followup'] == 1,
      followupNotes: map['followup_notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      createdBy: map['created_by'],
      createdByName: map['created_by_name'],
    );
  }

  WaridModel copyWith({
    int? id,
    String? qaidNumber,
    DateTime? qaidDate,
    String? sourceAdministration,
    String? letterNumber,
    DateTime? letterDate,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
    );
  }
}
