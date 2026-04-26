import 'dart:typed_data';

import 'package:railway_secretariat/features/history/data/models/deleted_record_model.dart';
import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/documents/data/models/warid_model.dart';
import 'package:railway_secretariat/core/services/database_service.dart';
import 'package:railway_secretariat/features/documents/data/datasources/excel_import_service.dart';
import '../../domain/entities/document_import_outcome.dart';
import '../../domain/repositories/document_repository.dart';

class DatabaseDocumentRepository implements DocumentRepository {
  final DatabaseService _databaseService;
  final ExcelImportService _excelImportService;

  DatabaseDocumentRepository({
    required DatabaseService databaseService,
    required ExcelImportService excelImportService,
  })  : _databaseService = databaseService,
        _excelImportService = excelImportService;

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
  }) {
    return _databaseService.getAllWarid(
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

  @override
  Future<void> insertWarid(WaridModel warid) async {
    await _databaseService.insertWarid(warid);
  }

  @override
  Future<void> updateWarid(
      WaridModel warid, int userId, String userName) async {
    await _databaseService.updateWarid(warid, userId, userName);
  }

  @override
  Future<void> deleteWarid(int id, int userId, String userName) async {
    await _databaseService.deleteWarid(id, userId, userName);
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
  }) {
    return _databaseService.getAllSadir(
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

  @override
  Future<void> insertSadir(SadirModel sadir) async {
    await _databaseService.insertSadir(sadir);
  }

  @override
  Future<void> updateSadir(
      SadirModel sadir, int userId, String userName) async {
    await _databaseService.updateSadir(sadir, userId, userName);
  }

  @override
  Future<void> deleteSadir(int id, int userId, String userName) async {
    await _databaseService.deleteSadir(id, userId, userName);
  }

  @override
  Future<List<DeletedRecordModel>> getDeletedRecords({
    String? documentType,
    bool includeRestored = false,
    String? search,
    int? limit,
    int? offset,
  }) {
    return _databaseService.getDeletedRecords(
      documentType: documentType,
      includeRestored: includeRestored,
      search: search,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<void> restoreDeletedRecord({
    required int deletedRecordId,
    required String qaidNumber,
    required int userId,
    required String userName,
  }) async {
    await _databaseService.restoreDeletedRecord(
      deletedRecordId: deletedRecordId,
      qaidNumber: qaidNumber,
      userId: userId,
      userName: userName,
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
    await _databaseService.restoreDeletedRecordWithPayload(
      deletedRecordId: deletedRecordId,
      documentType: documentType,
      payload: payload,
      qaidNumber: qaidNumber,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<Map<String, dynamic>> getStatistics() {
    return _databaseService.getStatistics();
  }

  @override
  Future<List<String>> getClassificationOptions(String documentType) {
    return _databaseService.getClassificationOptions(documentType);
  }

  @override
  Future<void> addClassificationOption({
    required String documentType,
    required String optionName,
  }) {
    return _databaseService.addClassificationOption(
      documentType: documentType,
      optionName: optionName,
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
    final parseResult = _excelImportService.parseWarid(
      fileBytes: fileBytes,
      createdBy: userId,
      createdByName: userName,
    );

    if (parseResult.totalRows == 0 && parseResult.validRows.isEmpty) {
      return DocumentImportOutcome(
        totalRows: 0,
        importedRows: 0,
        failedRows: 0,
        errors: _mapErrors(parseResult.errors),
      );
    }

    final importFileId = await _databaseService.createImportFileRecord(
      documentType: 'warid',
      fileName: fileName,
      filePath: filePath,
      fileBytes: fileBytes,
      totalRows: parseResult.totalRows,
      importedBy: userId,
      importedByName: userName,
    );

    var importedRows = 0;
    final allErrors = <ImportRowError>[..._mapErrors(parseResult.errors)];

    for (final row in parseResult.validRows) {
      try {
        await _databaseService.insertWaridFromImport(
          row.data,
          importFileId: importFileId,
        );
        importedRows++;
      } catch (e) {
        allErrors.add(
          ImportRowError(
            rowNumber: row.rowNumber,
            message: 'فشل حفظ السطر في قاعدة البيانات: $e',
          ),
        );
      }
    }

    final failedRows = parseResult.totalRows - importedRows;
    await _databaseService.finalizeImportFileRecord(
      importFileId,
      importedRows: importedRows,
      failedRows: failedRows,
    );

    return DocumentImportOutcome(
      totalRows: parseResult.totalRows,
      importedRows: importedRows,
      failedRows: failedRows,
      errors: allErrors,
    );
  }

  @override
  Future<DocumentImportOutcome> importSadirFromExcel({
    required Uint8List fileBytes,
    required String fileName,
    String? filePath,
    int? userId,
    String? userName,
  }) async {
    final parseResult = _excelImportService.parseSadir(
      fileBytes: fileBytes,
      createdBy: userId,
      createdByName: userName,
    );

    if (parseResult.totalRows == 0 && parseResult.validRows.isEmpty) {
      return DocumentImportOutcome(
        totalRows: 0,
        importedRows: 0,
        failedRows: 0,
        errors: _mapErrors(parseResult.errors),
      );
    }

    final importFileId = await _databaseService.createImportFileRecord(
      documentType: 'sadir',
      fileName: fileName,
      filePath: filePath,
      fileBytes: fileBytes,
      totalRows: parseResult.totalRows,
      importedBy: userId,
      importedByName: userName,
    );

    var importedRows = 0;
    final allErrors = <ImportRowError>[..._mapErrors(parseResult.errors)];

    for (final row in parseResult.validRows) {
      try {
        await _databaseService.insertSadirFromImport(
          row.data,
          importFileId: importFileId,
        );
        importedRows++;
      } catch (e) {
        allErrors.add(
          ImportRowError(
            rowNumber: row.rowNumber,
            message: 'فشل حفظ السطر في قاعدة البيانات: $e',
          ),
        );
      }
    }

    final failedRows = parseResult.totalRows - importedRows;
    await _databaseService.finalizeImportFileRecord(
      importFileId,
      importedRows: importedRows,
      failedRows: failedRows,
    );

    return DocumentImportOutcome(
      totalRows: parseResult.totalRows,
      importedRows: importedRows,
      failedRows: failedRows,
      errors: allErrors,
    );
  }

  List<ImportRowError> _mapErrors(List<ExcelImportRowError> errors) {
    return errors
        .map(
          (error) => ImportRowError(
            rowNumber: error.rowNumber,
            message: error.message,
          ),
        )
        .toList(growable: false);
  }
}
