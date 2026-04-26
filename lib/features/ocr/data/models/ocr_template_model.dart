import 'dart:convert';

import 'package:railway_secretariat/features/ocr/data/models/ocr_field_definitions.dart';

class OcrTemplateModel {
  final int? id;
  final String name;
  final String documentType;
  final String tesseractLanguage;
  final Map<String, List<String>> fieldAliases;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OcrTemplateModel({
    this.id,
    required this.name,
    required this.documentType,
    required this.tesseractLanguage,
    required Map<String, List<String>> fieldAliases,
    required this.createdAt,
    this.updatedAt,
  }) : fieldAliases = _normalizeFieldAliases(fieldAliases);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'document_type': documentType,
      'tesseract_language': tesseractLanguage,
      'field_aliases': jsonEncode(fieldAliases),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory OcrTemplateModel.fromMap(Map<String, dynamic> map) {
    final rawAliases = map['field_aliases'];
    Map<String, dynamic> decodedAliases = <String, dynamic>{};

    if (rawAliases is String && rawAliases.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(rawAliases);
        if (parsed is Map<String, dynamic>) {
          decodedAliases = parsed;
        }
      } catch (_) {
        decodedAliases = <String, dynamic>{};
      }
    } else if (rawAliases is Map<String, dynamic>) {
      decodedAliases = rawAliases;
    }

    final aliases = <String, List<String>>{};
    for (final key in OcrFieldKeys.allKeys) {
      final value = decodedAliases[key];
      if (value is List) {
        aliases[key] = value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }

    final normalizedType = (map['document_type'] ?? 'warid').toString();
    final mergedAliases = defaultOcrFieldAliases(normalizedType);
    aliases.forEach((key, value) {
      if (value.isNotEmpty) {
        mergedAliases[key] = value;
      }
    });

    return OcrTemplateModel(
      id: map['id'] as int?,
      name: (map['name'] ?? '').toString().trim(),
      documentType: normalizedType,
      tesseractLanguage:
          (map['tesseract_language'] ?? 'ara+eng').toString().trim(),
      fieldAliases: mergedAliases,
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  OcrTemplateModel copyWith({
    int? id,
    String? name,
    String? documentType,
    String? tesseractLanguage,
    Map<String, List<String>>? fieldAliases,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OcrTemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      documentType: documentType ?? this.documentType,
      tesseractLanguage: tesseractLanguage ?? this.tesseractLanguage,
      fieldAliases: fieldAliases ?? this.fieldAliases,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static Map<String, List<String>> _normalizeFieldAliases(
      Map<String, List<String>> aliases) {
    final normalized = <String, List<String>>{};
    for (final key in OcrFieldKeys.allKeys) {
      final values = aliases[key] ?? const <String>[];
      normalized[key] = values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
    }
    return normalized;
  }
}
