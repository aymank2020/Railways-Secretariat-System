import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/deleted_record_model.dart';
import '../models/sadir_model.dart';
import '../models/warid_model.dart';
import '../services/database_service.dart';
import '../services/excel_import_service.dart';

class DocumentImportResult {
  final int totalRows;
  final int importedRows;
  final int failedRows;
  final List<ExcelImportRowError> errors;

  const DocumentImportResult({
    required this.totalRows,
    required this.importedRows,
    required this.failedRows,
    required this.errors,
  });
}

class DocumentProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final ExcelImportService _excelImportService = ExcelImportService();

  List<WaridModel> _waridList = [];
  List<SadirModel> _sadirList = [];
  List<DeletedRecordModel> _deletedRecords = [];
  WaridModel? _selectedWarid;
  SadirModel? _selectedSadir;
  Map<String, dynamic> _statistics = {};

  bool _isLoading = false;
  String? _error;

  List<WaridModel> get waridList => _waridList;
  List<SadirModel> get sadirList => _sadirList;
  List<DeletedRecordModel> get deletedRecords => _deletedRecords;
  WaridModel? get selectedWarid => _selectedWarid;
  SadirModel? get selectedSadir => _selectedSadir;
  Map<String, dynamic> get statistics => _statistics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadWarid(
      {String? search, DateTime? fromDate, DateTime? toDate}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _waridList = await _db.getAllWarid(
          search: search, fromDate: fromDate, toDate: toDate);
      _error = null;
    } catch (e) {
      _error = 'حدث خطأ أثناء تحميل بيانات الوارد: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addWarid(WaridModel warid) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.insertWarid(warid);
      await loadWarid();
      _error = null;
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء إضافة بيانات الوارد: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateWarid(
      WaridModel warid, int userId, String userName) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.updateWarid(warid, userId, userName);
      await loadWarid();
      _error = null;
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء تحديث بيانات الوارد: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteWarid(int id, int userId, String userName) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.deleteWarid(id, userId, userName);
      await loadWarid();
      _error = null;
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء حذف بيانات الوارد: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void selectWarid(WaridModel? warid) {
    _selectedWarid = warid;
    notifyListeners();
  }

  Future<void> loadSadir(
      {String? search, DateTime? fromDate, DateTime? toDate}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _sadirList = await _db.getAllSadir(
          search: search, fromDate: fromDate, toDate: toDate);
      _error = null;
    } catch (e) {
      _error = 'حدث خطأ أثناء تحميل بيانات الصادر: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addSadir(SadirModel sadir) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.insertSadir(sadir);
      await loadSadir();
      _error = null;
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء إضافة بيانات الصادر: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSadir(
      SadirModel sadir, int userId, String userName) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.updateSadir(sadir, userId, userName);
      await loadSadir();
      _error = null;
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء تحديث بيانات الصادر: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSadir(int id, int userId, String userName) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.deleteSadir(id, userId, userName);
      await loadSadir();
      _error = null;
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء حذف بيانات الصادر: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadDeletedRecords({
    String? documentType,
    bool includeRestored = false,
    String? search,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _deletedRecords = await _db.getDeletedRecords(
        documentType: documentType,
        includeRestored: includeRestored,
        search: search,
      );
      _error = null;
    } catch (e) {
      _error = 'حدث خطأ أثناء تحميل سجل المحذوفات: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restoreDeletedRecord({
    required int deletedRecordId,
    required String qaidNumber,
    required int userId,
    required String userName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.restoreDeletedRecord(
        deletedRecordId: deletedRecordId,
        qaidNumber: qaidNumber,
        userId: userId,
        userName: userName,
      );
      _waridList = await _db.getAllWarid();
      _sadirList = await _db.getAllSadir();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء استرجاع السجل المحذوف: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreWaridFromDeletedWithEdits({
    required int deletedRecordId,
    required WaridModel warid,
    required int userId,
    required String userName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.restoreDeletedRecordWithPayload(
        deletedRecordId: deletedRecordId,
        documentType: 'warid',
        payload: warid.toMap(),
        qaidNumber: warid.qaidNumber,
        userId: userId,
        userName: userName,
      );
      _waridList = await _db.getAllWarid();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء استرجاع الوارد بعد التعديل: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreSadirFromDeletedWithEdits({
    required int deletedRecordId,
    required SadirModel sadir,
    required int userId,
    required String userName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.restoreDeletedRecordWithPayload(
        deletedRecordId: deletedRecordId,
        documentType: 'sadir',
        payload: sadir.toMap(),
        qaidNumber: sadir.qaidNumber,
        userId: userId,
        userName: userName,
      );
      _sadirList = await _db.getAllSadir();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء استرجاع الصادر بعد التعديل: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void selectSadir(SadirModel? sadir) {
    _selectedSadir = sadir;
    notifyListeners();
  }

  Future<void> loadStatistics() async {
    _isLoading = true;
    notifyListeners();

    try {
      _statistics = await _db.getStatistics();
      _error = null;
    } catch (e) {
      _error = 'حدث خطأ أثناء تحميل الإحصائيات: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<List<String>> getClassificationOptions(String documentType) async {
    try {
      final options = await _db.getClassificationOptions(documentType);
      _error = null;
      return options;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u062a\u0635\u0646\u064a\u0641\u0627\u062a: $e';
      notifyListeners();
      return <String>[];
    }
  }

  Future<bool> addClassificationOption({
    required String documentType,
    required String optionName,
  }) async {
    try {
      await _db.addClassificationOption(
        documentType: documentType,
        optionName: optionName,
      );
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u0625\u0636\u0627\u0641\u0629 \u062c\u0647\u0629 \u062c\u062f\u064a\u062f\u0629: $e';
      notifyListeners();
      return false;
    }
  }

  Future<DocumentImportResult> importWaridFromExcel({
    required Uint8List fileBytes,
    required String fileName,
    String? filePath,
    int? userId,
    String? userName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final parseResult = _excelImportService.parseWarid(
        fileBytes: fileBytes,
        createdBy: userId,
        createdByName: userName,
      );

      if (parseResult.totalRows == 0 && parseResult.validRows.isEmpty) {
        _error = parseResult.errors.isNotEmpty
            ? parseResult.errors.first.message
            : 'لا توجد بيانات صالحة للاستيراد.';
        return DocumentImportResult(
          totalRows: 0,
          importedRows: 0,
          failedRows: 0,
          errors: parseResult.errors,
        );
      }

      final importFileId = await _db.createImportFileRecord(
        documentType: 'warid',
        fileName: fileName,
        filePath: filePath,
        fileBytes: fileBytes,
        totalRows: parseResult.totalRows,
        importedBy: userId,
        importedByName: userName,
      );

      var importedRows = 0;
      final allErrors = <ExcelImportRowError>[...parseResult.errors];

      for (final row in parseResult.validRows) {
        try {
          await _db.insertWaridFromImport(row.data, importFileId: importFileId);
          importedRows++;
        } catch (e) {
          allErrors.add(
            ExcelImportRowError(
              rowNumber: row.rowNumber,
              message: 'فشل حفظ السطر في قاعدة البيانات: $e',
            ),
          );
        }
      }

      final failedRows = parseResult.totalRows - importedRows;
      await _db.finalizeImportFileRecord(importFileId,
          importedRows: importedRows, failedRows: failedRows);

      await loadWarid();
      _error = null;

      return DocumentImportResult(
        totalRows: parseResult.totalRows,
        importedRows: importedRows,
        failedRows: failedRows,
        errors: allErrors,
      );
    } catch (e) {
      _error = 'حدث خطأ أثناء استيراد ملف الوارد: $e';
      return DocumentImportResult(
        totalRows: 0,
        importedRows: 0,
        failedRows: 0,
        errors: [ExcelImportRowError(rowNumber: 0, message: _error!)],
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DocumentImportResult> importSadirFromExcel({
    required Uint8List fileBytes,
    required String fileName,
    String? filePath,
    int? userId,
    String? userName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final parseResult = _excelImportService.parseSadir(
        fileBytes: fileBytes,
        createdBy: userId,
        createdByName: userName,
      );

      if (parseResult.totalRows == 0 && parseResult.validRows.isEmpty) {
        _error = parseResult.errors.isNotEmpty
            ? parseResult.errors.first.message
            : 'لا توجد بيانات صالحة للاستيراد.';
        return DocumentImportResult(
          totalRows: 0,
          importedRows: 0,
          failedRows: 0,
          errors: parseResult.errors,
        );
      }

      final importFileId = await _db.createImportFileRecord(
        documentType: 'sadir',
        fileName: fileName,
        filePath: filePath,
        fileBytes: fileBytes,
        totalRows: parseResult.totalRows,
        importedBy: userId,
        importedByName: userName,
      );

      var importedRows = 0;
      final allErrors = <ExcelImportRowError>[...parseResult.errors];

      for (final row in parseResult.validRows) {
        try {
          await _db.insertSadirFromImport(row.data, importFileId: importFileId);
          importedRows++;
        } catch (e) {
          allErrors.add(
            ExcelImportRowError(
              rowNumber: row.rowNumber,
              message: 'فشل حفظ السطر في قاعدة البيانات: $e',
            ),
          );
        }
      }

      final failedRows = parseResult.totalRows - importedRows;
      await _db.finalizeImportFileRecord(importFileId,
          importedRows: importedRows, failedRows: failedRows);

      await loadSadir();
      _error = null;

      return DocumentImportResult(
        totalRows: parseResult.totalRows,
        importedRows: importedRows,
        failedRows: failedRows,
        errors: allErrors,
      );
    } catch (e) {
      _error = 'حدث خطأ أثناء استيراد ملف الصادر: $e';
      return DocumentImportResult(
        totalRows: 0,
        importedRows: 0,
        failedRows: 0,
        errors: [ExcelImportRowError(rowNumber: 0, message: _error!)],
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
