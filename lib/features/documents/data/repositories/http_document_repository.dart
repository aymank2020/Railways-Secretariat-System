import 'dart:convert';
import 'dart:typed_data';

import 'package:railway_secretariat/core/network/api_client.dart';
import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/documents/data/models/warid_model.dart';
import 'package:railway_secretariat/features/history/data/models/deleted_record_model.dart';

import '../../domain/entities/document_import_outcome.dart';
import '../../domain/repositories/document_repository.dart';

class HttpDocumentRepository implements DocumentRepository {
  final ApiClient _apiClient;

  HttpDocumentRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  String? _toIso(DateTime? value) => value?.toIso8601String();

  Map<String, String> _query({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? externalNumber,
    DateTime? externalDate,
    String? chairmanIncomingNumber,
    DateTime? chairmanIncomingDate,
    String? chairmanReturnNumber,
    DateTime? chairmanReturnDate,
    int? limit,
    int? offset,
  }) {
    final map = <String, String>{};
    if ((search ?? '').trim().isNotEmpty) {
      map['search'] = search!.trim();
    }
    if (fromDate != null) {
      map['fromDate'] = _toIso(fromDate)!;
    }
    if (toDate != null) {
      map['toDate'] = _toIso(toDate)!;
    }
    if ((externalNumber ?? '').trim().isNotEmpty) {
      map['externalNumber'] = externalNumber!.trim();
    }
    if (externalDate != null) {
      map['externalDate'] = _toIso(externalDate)!;
    }
    if ((chairmanIncomingNumber ?? '').trim().isNotEmpty) {
      map['chairmanIncomingNumber'] = chairmanIncomingNumber!.trim();
    }
    if (chairmanIncomingDate != null) {
      map['chairmanIncomingDate'] = _toIso(chairmanIncomingDate)!;
    }
    if ((chairmanReturnNumber ?? '').trim().isNotEmpty) {
      map['chairmanReturnNumber'] = chairmanReturnNumber!.trim();
    }
    if (chairmanReturnDate != null) {
      map['chairmanReturnDate'] = _toIso(chairmanReturnDate)!;
    }
    if (limit != null) {
      map['limit'] = '$limit';
    }
    if (offset != null) {
      map['offset'] = '$offset';
    }
    return map;
  }

  @override
  Future<List<WaridModel>> getAllWarid({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? externalNumber,
    DateTime? externalDate,
    String? chairmanIncomingNumber,
    DateTime? chairmanIncomingDate,
    String? chairmanReturnNumber,
    DateTime? chairmanReturnDate,
    int? limit,
    int? offset,
  }) async {
    final list = await _apiClient.getList(
      '/api/documents/warid',
      query: _query(
        search: search,
        fromDate: fromDate,
        toDate: toDate,
        externalNumber: externalNumber,
        externalDate: externalDate,
        chairmanIncomingNumber: chairmanIncomingNumber,
        chairmanIncomingDate: chairmanIncomingDate,
        chairmanReturnNumber: chairmanReturnNumber,
        chairmanReturnDate: chairmanReturnDate,
        limit: limit,
        offset: offset,
      ),
    );

    return list
        .whereType<Map>()
        .map(
          (item) => WaridModel.fromMap(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> insertWarid(WaridModel warid) async {
    await _apiClient.postMap(
      '/api/documents/warid',
      body: <String, dynamic>{'warid': warid.toMap()},
    );
  }

  @override
  Future<void> updateWarid(WaridModel warid, int userId, String userName) async {
    final id = warid.id;
    if (id == null) {
      throw StateError('Warid ID is required for update.');
    }
    await _apiClient.putMap(
      '/api/documents/warid/$id',
      body: <String, dynamic>{
        'warid': warid.toMap(),
        'userId': userId,
        'userName': userName,
      },
    );
  }

  @override
  Future<void> deleteWarid(int id, int userId, String userName) async {
    await _apiClient.postMap(
      '/api/documents/warid/$id/delete',
      body: <String, dynamic>{
        'userId': userId,
        'userName': userName,
      },
    );
  }

  @override
  Future<List<SadirModel>> getAllSadir({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? externalNumber,
    DateTime? externalDate,
    String? chairmanIncomingNumber,
    DateTime? chairmanIncomingDate,
    String? chairmanReturnNumber,
    DateTime? chairmanReturnDate,
    int? limit,
    int? offset,
  }) async {
    final list = await _apiClient.getList(
      '/api/documents/sadir',
      query: _query(
        search: search,
        fromDate: fromDate,
        toDate: toDate,
        externalNumber: externalNumber,
        externalDate: externalDate,
        chairmanIncomingNumber: chairmanIncomingNumber,
        chairmanIncomingDate: chairmanIncomingDate,
        chairmanReturnNumber: chairmanReturnNumber,
        chairmanReturnDate: chairmanReturnDate,
        limit: limit,
        offset: offset,
      ),
    );

    return list
        .whereType<Map>()
        .map(
          (item) => SadirModel.fromMap(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> insertSadir(SadirModel sadir) async {
    await _apiClient.postMap(
      '/api/documents/sadir',
      body: <String, dynamic>{'sadir': sadir.toMap()},
    );
  }

  @override
  Future<void> updateSadir(SadirModel sadir, int userId, String userName) async {
    final id = sadir.id;
    if (id == null) {
      throw StateError('Sadir ID is required for update.');
    }
    await _apiClient.putMap(
      '/api/documents/sadir/$id',
      body: <String, dynamic>{
        'sadir': sadir.toMap(),
        'userId': userId,
        'userName': userName,
      },
    );
  }

  @override
  Future<void> deleteSadir(int id, int userId, String userName) async {
    await _apiClient.postMap(
      '/api/documents/sadir/$id/delete',
      body: <String, dynamic>{
        'userId': userId,
        'userName': userName,
      },
    );
  }

  @override
  Future<List<DeletedRecordModel>> getDeletedRecords({
    String? documentType,
    bool includeRestored = false,
    String? search,
    int? limit,
    int? offset,
  }) async {
    final query = <String, String>{
      'includeRestored': includeRestored ? '1' : '0',
    };
    if ((documentType ?? '').trim().isNotEmpty) {
      query['documentType'] = documentType!.trim();
    }
    if ((search ?? '').trim().isNotEmpty) {
      query['search'] = search!.trim();
    }
    if (limit != null) {
      query['limit'] = '$limit';
    }
    if (offset != null) {
      query['offset'] = '$offset';
    }

    final list = await _apiClient.getList(
      '/api/documents/deleted',
      query: query,
    );

    return list
        .whereType<Map>()
        .map(
          (item) => DeletedRecordModel.fromMap(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> restoreDeletedRecord({
    required int deletedRecordId,
    required String qaidNumber,
    required int userId,
    required String userName,
  }) async {
    await _apiClient.postMap(
      '/api/documents/deleted/restore',
      body: <String, dynamic>{
        'deletedRecordId': deletedRecordId,
        'qaidNumber': qaidNumber,
        'userId': userId,
        'userName': userName,
      },
    );
  }

  @override
  Future<void> restoreDeletedRecordWithPayload({
    required int deletedRecordId,
    required String documentType,
    required Map<String, dynamic> payload,
    required String qaidNumber,
    required int userId,
    required String userName,
  }) async {
    await _apiClient.postMap(
      '/api/documents/deleted/restore-with-payload',
      body: <String, dynamic>{
        'deletedRecordId': deletedRecordId,
        'documentType': documentType,
        'payload': payload,
        'qaidNumber': qaidNumber,
        'userId': userId,
        'userName': userName,
      },
    );
  }

  @override
  Future<Map<String, dynamic>> getStatistics() {
    return _apiClient.getMap('/api/documents/statistics');
  }

  @override
  Future<List<String>> getClassificationOptions(String documentType) async {
    final list = await _apiClient.getList(
      '/api/documents/classification/$documentType',
    );
    return list.map((item) => item.toString()).toList(growable: false);
  }

  @override
  Future<void> addClassificationOption({
    required String documentType,
    required String optionName,
  }) async {
    await _apiClient.postMap(
      '/api/documents/classification',
      body: <String, dynamic>{
        'documentType': documentType,
        'optionName': optionName,
      },
    );
  }

  DocumentImportOutcome _parseImportOutcome(Map<String, dynamic> map) {
    final rawErrors = (map['errors'] is List) ? map['errors'] as List : <dynamic>[];
    final errors = rawErrors
        .whereType<Map>()
        .map((item) {
          final row = int.tryParse(item['rowNumber']?.toString() ?? '') ?? 0;
          final message = item['message']?.toString() ?? '';
          return ImportRowError(rowNumber: row, message: message);
        })
        .toList(growable: false);

    return DocumentImportOutcome(
      totalRows: int.tryParse(map['totalRows']?.toString() ?? '') ?? 0,
      importedRows: int.tryParse(map['importedRows']?.toString() ?? '') ?? 0,
      failedRows: int.tryParse(map['failedRows']?.toString() ?? '') ?? 0,
      errors: errors,
    );
  }

  @override
  Future<DocumentImportOutcome> importWaridFromExcel({
    required Uint8List fileBytes,
    required String fileName,
    String? filePath,
    int? userId,
    String? userName,
  }) async {
    final response = await _apiClient.postMap(
      '/api/documents/import/warid',
      body: <String, dynamic>{
        'fileName': fileName,
        'filePath': filePath,
        'fileBytesBase64': base64Encode(fileBytes),
        'userId': userId,
        'userName': userName,
      },
    );
    return _parseImportOutcome(response);
  }

  @override
  Future<DocumentImportOutcome> importSadirFromExcel({
    required Uint8List fileBytes,
    required String fileName,
    String? filePath,
    int? userId,
    String? userName,
  }) async {
    final response = await _apiClient.postMap(
      '/api/documents/import/sadir',
      body: <String, dynamic>{
        'fileName': fileName,
        'filePath': filePath,
        'fileBytesBase64': base64Encode(fileBytes),
        'userId': userId,
        'userName': userName,
      },
    );
    return _parseImportOutcome(response);
  }
}
