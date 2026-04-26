import 'dart:typed_data';

import 'package:railway_secretariat/features/history/data/models/deleted_record_model.dart';
import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/documents/data/models/warid_model.dart';
import '../entities/document_import_outcome.dart';

abstract class DocumentRepository {
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
  });

  Future<void> insertWarid(WaridModel warid);

  Future<void> updateWarid(WaridModel warid, int userId, String userName);

  Future<void> deleteWarid(int id, int userId, String userName);

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
  });

  Future<void> insertSadir(SadirModel sadir);

  Future<void> updateSadir(SadirModel sadir, int userId, String userName);

  Future<void> deleteSadir(int id, int userId, String userName);

  Future<List<DeletedRecordModel>> getDeletedRecords({
    String? documentType,
    bool includeRestored = false,
    String? search,
    int? limit,
    int? offset,
  });

  Future<void> restoreDeletedRecord({
    required int deletedRecordId,
    required String qaidNumber,
    required int userId,
    required String userName,
  });

  Future<void> restoreDeletedRecordWithPayload({
    required int deletedRecordId,
    required String documentType,
    required Map<String, dynamic> payload,
    required String qaidNumber,
    required int userId,
    required String userName,
  });

  Future<Map<String, dynamic>> getStatistics();

  Future<List<String>> getClassificationOptions(String documentType);

  Future<void> addClassificationOption({
    required String documentType,
    required String optionName,
  });

  Future<DocumentImportOutcome> importWaridFromExcel({
    required Uint8List fileBytes,
    required String fileName,
    String? filePath,
    int? userId,
    String? userName,
  });

  Future<DocumentImportOutcome> importSadirFromExcel({
    required Uint8List fileBytes,
    required String fileName,
    String? filePath,
    int? userId,
    String? userName,
  });
}
