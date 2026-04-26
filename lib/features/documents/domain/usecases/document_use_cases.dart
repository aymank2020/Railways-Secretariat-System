import 'dart:typed_data';

import 'package:railway_secretariat/features/history/data/models/deleted_record_model.dart';
import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/documents/data/models/warid_model.dart';
import '../entities/document_import_outcome.dart';
import '../repositories/document_repository.dart';

class DocumentUseCases {
  final DocumentRepository _repository;

  DocumentUseCases({required DocumentRepository repository})
      : _repository = repository;

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
  }) {
    return _repository.getAllWarid(
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
    );
  }

  Future<void> insertWarid(WaridModel warid) {
    return _repository.insertWarid(warid);
  }

  Future<void> updateWarid(WaridModel warid, int userId, String userName) {
    return _repository.updateWarid(warid, userId, userName);
  }

  Future<void> deleteWarid(int id, int userId, String userName) {
    return _repository.deleteWarid(id, userId, userName);
  }

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
  }) {
    return _repository.getAllSadir(
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
    );
  }

  Future<void> insertSadir(SadirModel sadir) {
    return _repository.insertSadir(sadir);
  }

  Future<void> updateSadir(SadirModel sadir, int userId, String userName) {
    return _repository.updateSadir(sadir, userId, userName);
  }

  Future<void> deleteSadir(int id, int userId, String userName) {
    return _repository.deleteSadir(id, userId, userName);
  }

  Future<List<DeletedRecordModel>> getDeletedRecords({
    String? documentType,
    bool includeRestored = false,
    String? search,
    int? limit,
    int? offset,
  }) {
    return _repository.getDeletedRecords(
      documentType: documentType,
      includeRestored: includeRestored,
      search: search,
      limit: limit,
      offset: offset,
    );
  }

  Future<void> restoreDeletedRecord({
    required int deletedRecordId,
    required String qaidNumber,
    required int userId,
    required String userName,
  }) {
    return _repository.restoreDeletedRecord(
      deletedRecordId: deletedRecordId,
      qaidNumber: qaidNumber,
      userId: userId,
      userName: userName,
    );
  }

  Future<void> restoreDeletedRecordWithPayload({
    required int deletedRecordId,
    required String documentType,
    required Map<String, dynamic> payload,
    required String qaidNumber,
    required int userId,
    required String userName,
  }) {
    return _repository.restoreDeletedRecordWithPayload(
      deletedRecordId: deletedRecordId,
      documentType: documentType,
      payload: payload,
      qaidNumber: qaidNumber,
      userId: userId,
      userName: userName,
    );
  }

  Future<Map<String, dynamic>> getStatistics() {
    return _repository.getStatistics();
  }

  Future<List<String>> getClassificationOptions(String documentType) {
    return _repository.getClassificationOptions(documentType);
  }

  Future<void> addClassificationOption({
    required String documentType,
    required String optionName,
  }) {
    return _repository.addClassificationOption(
      documentType: documentType,
      optionName: optionName,
    );
  }

  Future<DocumentImportOutcome> importWaridFromExcel({
    required Uint8List fileBytes,
    required String fileName,
    String? filePath,
    int? userId,
    String? userName,
  }) {
    return _repository.importWaridFromExcel(
      fileBytes: fileBytes,
      fileName: fileName,
      filePath: filePath,
      userId: userId,
      userName: userName,
    );
  }

  Future<DocumentImportOutcome> importSadirFromExcel({
    required Uint8List fileBytes,
    required String fileName,
    String? filePath,
    int? userId,
    String? userName,
  }) {
    return _repository.importSadirFromExcel(
      fileBytes: fileBytes,
      fileName: fileName,
      filePath: filePath,
      userId: userId,
      userName: userName,
    );
  }
}
