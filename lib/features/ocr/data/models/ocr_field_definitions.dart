class OcrFieldKeys {
  static const String qaidNumber = 'qaid_number';
  static const String qaidDate = 'qaid_date';
  static const String entity = 'entity';
  static const String externalNumber = 'external_number';
  static const String externalDate = 'external_date';
  static const String chairmanIncomingNumber = 'chairman_incoming_number';
  static const String chairmanIncomingDate = 'chairman_incoming_date';
  static const String chairmanReturnNumber = 'chairman_return_number';
  static const String chairmanReturnDate = 'chairman_return_date';
  static const String subject = 'subject';

  static const List<String> allKeys = <String>[
    qaidNumber,
    qaidDate,
    entity,
    externalNumber,
    externalDate,
    chairmanIncomingNumber,
    chairmanIncomingDate,
    chairmanReturnNumber,
    chairmanReturnDate,
    subject,
  ];
}

class OcrFieldDefinition {
  final String key;
  final String label;
  final bool isDate;

  const OcrFieldDefinition({
    required this.key,
    required this.label,
    this.isDate = false,
  });
}

const List<OcrFieldDefinition> ocrFieldDefinitions = <OcrFieldDefinition>[
  OcrFieldDefinition(key: OcrFieldKeys.qaidNumber, label: 'رقم القيد'),
  OcrFieldDefinition(
      key: OcrFieldKeys.qaidDate, label: 'تاريخ القيد', isDate: true),
  OcrFieldDefinition(key: OcrFieldKeys.entity, label: 'الجهة'),
  OcrFieldDefinition(
      key: OcrFieldKeys.externalNumber, label: 'رقم الوزارة / الجهة الخارجية'),
  OcrFieldDefinition(
      key: OcrFieldKeys.externalDate,
      label: 'تاريخ الوزارة / الجهة الخارجية',
      isDate: true),
  OcrFieldDefinition(
      key: OcrFieldKeys.chairmanIncomingNumber, label: 'رقم وارد رئيس الهيئة'),
  OcrFieldDefinition(
      key: OcrFieldKeys.chairmanIncomingDate,
      label: 'تاريخ وارد رئيس الهيئة',
      isDate: true),
  OcrFieldDefinition(
      key: OcrFieldKeys.chairmanReturnNumber,
      label: 'رقم عائد رئيس الهيئة بعد التوقيع'),
  OcrFieldDefinition(
      key: OcrFieldKeys.chairmanReturnDate,
      label: 'تاريخ عائد رئيس الهيئة بعد التوقيع',
      isDate: true),
  OcrFieldDefinition(key: OcrFieldKeys.subject, label: 'الموضوع'),
];

Map<String, List<String>> defaultOcrFieldAliases(String documentType) {
  final normalizedType = documentType.trim().toLowerCase();
  final isWarid = normalizedType == 'warid';
  final entityAliases = isWarid
      ? <String>[
          'الجهة الوارد منها الخطاب',
          'الوارد من',
          'الجهة',
        ]
      : <String>[
          'الجهة المرسل إليها',
          'المرسل إليها',
          'الجهة',
        ];

  return <String, List<String>>{
    OcrFieldKeys.qaidNumber: <String>[
      'رقم القيد',
      'قيد رقم',
    ],
    OcrFieldKeys.qaidDate: <String>[
      'تاريخ القيد',
      'تاريخ القيد الوارد',
    ],
    OcrFieldKeys.entity: entityAliases,
    OcrFieldKeys.externalNumber: <String>[
      'رقم الوزارة / الجهة الخارجية',
      'رقم الخطاب',
      'رقم الوزارة',
      'رقم الجهة الخارجية',
    ],
    OcrFieldKeys.externalDate: <String>[
      'تاريخ الوزارة / الجهة الخارجية',
      'تاريخ الخطاب',
      'تاريخ الوزارة',
      'تاريخ الجهة الخارجية',
    ],
    OcrFieldKeys.chairmanIncomingNumber: <String>[
      'رقم وارد رئيس الهيئة',
      'رقم رئيس الهيئة',
      'وارد رئيس الهيئة',
    ],
    OcrFieldKeys.chairmanIncomingDate: <String>[
      'تاريخ وارد رئيس الهيئة',
      'تاريخ رئيس الهيئة',
    ],
    OcrFieldKeys.chairmanReturnNumber: <String>[
      'رقم عائد رئيس الهيئة بعد التوقيع',
      'عائد رئيس الهيئة',
      'رقم العائد بعد التوقيع',
    ],
    OcrFieldKeys.chairmanReturnDate: <String>[
      'تاريخ عائد رئيس الهيئة بعد التوقيع',
      'تاريخ العائد بعد التوقيع',
    ],
    OcrFieldKeys.subject: <String>[
      'الموضوع',
      'موضوع الخطاب',
    ],
  };
}
