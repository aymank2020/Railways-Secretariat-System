import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:railway_secretariat/features/documents/domain/entities/document_import_outcome.dart';
import 'package:railway_secretariat/features/documents/domain/usecases/document_use_cases.dart';
import 'package:railway_secretariat/features/history/data/models/deleted_record_model.dart';
import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/documents/data/models/warid_model.dart';

class DocumentImportResult {
  final int totalRows;
  final int importedRows;
  final int failedRows;
  final List<ImportRowError> errors;

  const DocumentImportResult({
    required this.totalRows,
    required this.importedRows,
    required this.failedRows,
    required this.errors,
  });
}

class BatchDeleteResult {
  final int deletedCount;
  final int failedCount;

  const BatchDeleteResult({
    required this.deletedCount,
    required this.failedCount,
  });

  bool get hasFailures => failedCount > 0;
}

class DocumentProvider extends ChangeNotifier {
  final DocumentUseCases _documentUseCases;
  static const int _pageSize = 80;
  static const int _deletedPageSize = 80;

  List<WaridModel> _waridList = [];
  List<SadirModel> _sadirList = [];
  List<DeletedRecordModel> _deletedRecords = [];
  WaridModel? _selectedWarid;
  SadirModel? _selectedSadir;
  Map<String, dynamic> _statistics = {};

  String? _waridSearchTerm;
  DateTime? _waridFromDate;
  DateTime? _waridToDate;
  String? _waridExternalNumber;
  DateTime? _waridExternalDate;
  String? _waridChairmanIncomingNumber;
  DateTime? _waridChairmanIncomingDate;
  String? _waridChairmanReturnNumber;
  DateTime? _waridChairmanReturnDate;
  int _waridOffset = 0;
  bool _hasMoreWarid = true;
  bool _isLoadingMoreWarid = false;

  String? _sadirSearchTerm;
  DateTime? _sadirFromDate;
  DateTime? _sadirToDate;
  String? _sadirExternalNumber;
  DateTime? _sadirExternalDate;
  String? _sadirChairmanIncomingNumber;
  DateTime? _sadirChairmanIncomingDate;
  String? _sadirChairmanReturnNumber;
  DateTime? _sadirChairmanReturnDate;
  int _sadirOffset = 0;
  bool _hasMoreSadir = true;
  bool _isLoadingMoreSadir = false;

  String? _deletedDocumentType;
  bool _deletedIncludeRestored = false;
  String? _deletedSearchTerm;
  int _deletedOffset = 0;
  bool _hasMoreDeletedRecords = true;
  bool _isLoadingMoreDeletedRecords = false;

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
  bool get hasMoreWarid => _hasMoreWarid;
  bool get isLoadingMoreWarid => _isLoadingMoreWarid;
  bool get hasMoreSadir => _hasMoreSadir;
  bool get isLoadingMoreSadir => _isLoadingMoreSadir;
  bool get hasMoreDeletedRecords => _hasMoreDeletedRecords;
  bool get isLoadingMoreDeletedRecords => _isLoadingMoreDeletedRecords;

  DocumentProvider({
    required DocumentUseCases documentUseCases,
  }) : _documentUseCases = documentUseCases;

  Future<void> loadWarid({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? externalNumber,
    DateTime? externalDate,
    String? chairmanIncomingNumber,
    DateTime? chairmanIncomingDate,
    String? chairmanReturnNumber,
    DateTime? chairmanReturnDate,
    bool append = false,
  }) async {
    if (append) {
      if (_isLoadingMoreWarid || !_hasMoreWarid) {
        return;
      }
      _isLoadingMoreWarid = true;
    } else {
      _isLoading = true;
      _waridSearchTerm = search;
      _waridFromDate = fromDate;
      _waridToDate = toDate;
      _waridExternalNumber = externalNumber;
      _waridExternalDate = externalDate;
      _waridChairmanIncomingNumber = chairmanIncomingNumber;
      _waridChairmanIncomingDate = chairmanIncomingDate;
      _waridChairmanReturnNumber = chairmanReturnNumber;
      _waridChairmanReturnDate = chairmanReturnDate;
      _waridOffset = 0;
      _hasMoreWarid = true;
    }
    notifyListeners();

    try {
      final waridChunk = await _documentUseCases.getAllWarid(
        search: _waridSearchTerm,
        fromDate: _waridFromDate,
        toDate: _waridToDate,
        externalNumber: _waridExternalNumber,
        externalDate: _waridExternalDate,
        chairmanIncomingNumber: _waridChairmanIncomingNumber,
        chairmanIncomingDate: _waridChairmanIncomingDate,
        chairmanReturnNumber: _waridChairmanReturnNumber,
        chairmanReturnDate: _waridChairmanReturnDate,
        limit: _pageSize,
        offset: _waridOffset,
      );
      _waridList = append ? [..._waridList, ...waridChunk] : waridChunk;
      _waridOffset += waridChunk.length;
      _hasMoreWarid = waridChunk.length == _pageSize;
      _error = null;
    } catch (e) {
      _error = 'Error loading warid records: $e';
    } finally {
      if (append) {
        _isLoadingMoreWarid = false;
      } else {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> loadMoreWarid() async {
    await loadWarid(append: true);
  }

  Future<void> _refreshWaridWithCurrentFilters() async {
    await loadWarid(
      search: _waridSearchTerm,
      fromDate: _waridFromDate,
      toDate: _waridToDate,
      externalNumber: _waridExternalNumber,
      externalDate: _waridExternalDate,
      chairmanIncomingNumber: _waridChairmanIncomingNumber,
      chairmanIncomingDate: _waridChairmanIncomingDate,
      chairmanReturnNumber: _waridChairmanReturnNumber,
      chairmanReturnDate: _waridChairmanReturnDate,
    );
  }

  Future<bool> addWarid(WaridModel warid) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _documentUseCases.insertWarid(warid);
      await _refreshWaridWithCurrentFilters();
      _error = null;
      return true;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u0625\u0636\u0627\u0641\u0629 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0648\u0627\u0631\u062f: $e';
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
      await _documentUseCases.updateWarid(warid, userId, userName);
      await _refreshWaridWithCurrentFilters();
      _error = null;
      return true;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u062a\u062d\u062f\u064a\u062b \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0648\u0627\u0631\u062f: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteWarid(int id, int userId, String userName) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _documentUseCases.deleteWarid(id, userId, userName);
      await _refreshWaridWithCurrentFilters();
      _error = null;
      return true;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u062d\u0630\u0641 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0648\u0627\u0631\u062f: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<BatchDeleteResult> deleteWaridBatch(
      List<int> ids, int userId, String userName) async {
    final uniqueIds = ids.toSet().toList();
    if (uniqueIds.isEmpty) {
      return const BatchDeleteResult(deletedCount: 0, failedCount: 0);
    }

    _isLoading = true;
    notifyListeners();

    var deletedCount = 0;
    var failedCount = 0;

    try {
      for (final id in uniqueIds) {
        try {
          await _documentUseCases.deleteWarid(id, userId, userName);
          deletedCount++;
        } catch (_) {
          failedCount++;
        }
      }

      await _refreshWaridWithCurrentFilters();
      _error = failedCount > 0
          ? '\u062a\u0645 \u062d\u0630\u0641 $deletedCount \u0633\u062c\u0644(\u0627\u062a) \u0648\u0641\u0634\u0644 \u062d\u0630\u0641 $failedCount \u0633\u062c\u0644(\u0627\u062a) \u0645\u0646 \u0627\u0644\u0648\u0627\u0631\u062f'
          : null;

      return BatchDeleteResult(
        deletedCount: deletedCount,
        failedCount: failedCount,
      );
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u0627\u0644\u062d\u0630\u0641 \u0627\u0644\u062c\u0645\u0627\u0639\u064a \u0644\u0644\u0648\u0627\u0631\u062f: $e';
      return BatchDeleteResult(
        deletedCount: deletedCount,
        failedCount: uniqueIds.length - deletedCount,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectWarid(WaridModel? warid) {
    _selectedWarid = warid;
    notifyListeners();
  }

  Future<void> loadSadir({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? externalNumber,
    DateTime? externalDate,
    String? chairmanIncomingNumber,
    DateTime? chairmanIncomingDate,
    String? chairmanReturnNumber,
    DateTime? chairmanReturnDate,
    bool append = false,
  }) async {
    if (append) {
      if (_isLoadingMoreSadir || !_hasMoreSadir) {
        return;
      }
      _isLoadingMoreSadir = true;
    } else {
      _isLoading = true;
      _sadirSearchTerm = search;
      _sadirFromDate = fromDate;
      _sadirToDate = toDate;
      _sadirExternalNumber = externalNumber;
      _sadirExternalDate = externalDate;
      _sadirChairmanIncomingNumber = chairmanIncomingNumber;
      _sadirChairmanIncomingDate = chairmanIncomingDate;
      _sadirChairmanReturnNumber = chairmanReturnNumber;
      _sadirChairmanReturnDate = chairmanReturnDate;
      _sadirOffset = 0;
      _hasMoreSadir = true;
    }
    notifyListeners();

    try {
      final sadirChunk = await _documentUseCases.getAllSadir(
        search: _sadirSearchTerm,
        fromDate: _sadirFromDate,
        toDate: _sadirToDate,
        externalNumber: _sadirExternalNumber,
        externalDate: _sadirExternalDate,
        chairmanIncomingNumber: _sadirChairmanIncomingNumber,
        chairmanIncomingDate: _sadirChairmanIncomingDate,
        chairmanReturnNumber: _sadirChairmanReturnNumber,
        chairmanReturnDate: _sadirChairmanReturnDate,
        limit: _pageSize,
        offset: _sadirOffset,
      );
      _sadirList = append ? [..._sadirList, ...sadirChunk] : sadirChunk;
      _sadirOffset += sadirChunk.length;
      _hasMoreSadir = sadirChunk.length == _pageSize;
      _error = null;
    } catch (e) {
      _error = 'Error loading sadir records: $e';
    } finally {
      if (append) {
        _isLoadingMoreSadir = false;
      } else {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> loadMoreSadir() async {
    await loadSadir(append: true);
  }

  Future<void> _refreshSadirWithCurrentFilters() async {
    await loadSadir(
      search: _sadirSearchTerm,
      fromDate: _sadirFromDate,
      toDate: _sadirToDate,
      externalNumber: _sadirExternalNumber,
      externalDate: _sadirExternalDate,
      chairmanIncomingNumber: _sadirChairmanIncomingNumber,
      chairmanIncomingDate: _sadirChairmanIncomingDate,
      chairmanReturnNumber: _sadirChairmanReturnNumber,
      chairmanReturnDate: _sadirChairmanReturnDate,
    );
  }

  Future<bool> addSadir(SadirModel sadir) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _documentUseCases.insertSadir(sadir);
      await _refreshSadirWithCurrentFilters();
      _error = null;
      return true;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u0625\u0636\u0627\u0641\u0629 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0635\u0627\u062f\u0631: $e';
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
      await _documentUseCases.updateSadir(sadir, userId, userName);
      await _refreshSadirWithCurrentFilters();
      _error = null;
      return true;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u062a\u062d\u062f\u064a\u062b \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0635\u0627\u062f\u0631: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSadir(int id, int userId, String userName) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _documentUseCases.deleteSadir(id, userId, userName);
      await _refreshSadirWithCurrentFilters();
      _error = null;
      return true;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u062d\u0630\u0641 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0635\u0627\u062f\u0631: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<BatchDeleteResult> deleteSadirBatch(
      List<int> ids, int userId, String userName) async {
    final uniqueIds = ids.toSet().toList();
    if (uniqueIds.isEmpty) {
      return const BatchDeleteResult(deletedCount: 0, failedCount: 0);
    }

    _isLoading = true;
    notifyListeners();

    var deletedCount = 0;
    var failedCount = 0;

    try {
      for (final id in uniqueIds) {
        try {
          await _documentUseCases.deleteSadir(id, userId, userName);
          deletedCount++;
        } catch (_) {
          failedCount++;
        }
      }

      await _refreshSadirWithCurrentFilters();
      _error = failedCount > 0
          ? '\u062a\u0645 \u062d\u0630\u0641 $deletedCount \u0633\u062c\u0644(\u0627\u062a) \u0648\u0641\u0634\u0644 \u062d\u0630\u0641 $failedCount \u0633\u062c\u0644(\u0627\u062a) \u0645\u0646 \u0627\u0644\u0635\u0627\u062f\u0631'
          : null;

      return BatchDeleteResult(
        deletedCount: deletedCount,
        failedCount: failedCount,
      );
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u0627\u0644\u062d\u0630\u0641 \u0627\u0644\u062c\u0645\u0627\u0639\u064a \u0644\u0644\u0635\u0627\u062f\u0631: $e';
      return BatchDeleteResult(
        deletedCount: deletedCount,
        failedCount: uniqueIds.length - deletedCount,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDeletedRecords({
    String? documentType,
    bool includeRestored = false,
    String? search,
    bool append = false,
  }) async {
    if (append) {
      if (_isLoadingMoreDeletedRecords || !_hasMoreDeletedRecords) {
        return;
      }
      _isLoadingMoreDeletedRecords = true;
    } else {
      _isLoading = true;
      _deletedDocumentType = documentType;
      _deletedIncludeRestored = includeRestored;
      _deletedSearchTerm = search;
      _deletedOffset = 0;
      _hasMoreDeletedRecords = true;
    }
    notifyListeners();

    try {
      final recordsChunk = await _documentUseCases.getDeletedRecords(
        documentType: _deletedDocumentType,
        includeRestored: _deletedIncludeRestored,
        search: _deletedSearchTerm,
        limit: _deletedPageSize,
        offset: _deletedOffset,
      );
      _deletedRecords =
          append ? [..._deletedRecords, ...recordsChunk] : recordsChunk;
      _deletedOffset += recordsChunk.length;
      _hasMoreDeletedRecords = recordsChunk.length == _deletedPageSize;
      _error = null;
    } catch (e) {
      _error = 'Error loading deleted records: $e';
    } finally {
      if (append) {
        _isLoadingMoreDeletedRecords = false;
      } else {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> loadMoreDeletedRecords() async {
    await loadDeletedRecords(append: true);
  }

  Future<void> _refreshDeletedRecordsWithCurrentFilters() async {
    await loadDeletedRecords(
      documentType: _deletedDocumentType,
      includeRestored: _deletedIncludeRestored,
      search: _deletedSearchTerm,
    );
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
      await _documentUseCases.restoreDeletedRecord(
        deletedRecordId: deletedRecordId,
        qaidNumber: qaidNumber,
        userId: userId,
        userName: userName,
      );
      await _refreshWaridWithCurrentFilters();
      await _refreshSadirWithCurrentFilters();
      await _refreshDeletedRecordsWithCurrentFilters();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u0627\u0633\u062a\u0631\u062c\u0627\u0639 \u0627\u0644\u0633\u062c\u0644 \u0627\u0644\u0645\u062d\u0630\u0648\u0641: $e';
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
      await _documentUseCases.restoreDeletedRecordWithPayload(
        deletedRecordId: deletedRecordId,
        documentType: 'warid',
        payload: warid.toMap(),
        qaidNumber: warid.qaidNumber,
        userId: userId,
        userName: userName,
      );
      await _refreshWaridWithCurrentFilters();
      await _refreshDeletedRecordsWithCurrentFilters();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u0627\u0633\u062a\u0631\u062c\u0627\u0639 \u0627\u0644\u0648\u0627\u0631\u062f \u0628\u0639\u062f \u0627\u0644\u062a\u0639\u062f\u064a\u0644: $e';
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
      await _documentUseCases.restoreDeletedRecordWithPayload(
        deletedRecordId: deletedRecordId,
        documentType: 'sadir',
        payload: sadir.toMap(),
        qaidNumber: sadir.qaidNumber,
        userId: userId,
        userName: userName,
      );
      await _refreshSadirWithCurrentFilters();
      await _refreshDeletedRecordsWithCurrentFilters();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u0627\u0633\u062a\u0631\u062c\u0627\u0639 \u0627\u0644\u0635\u0627\u062f\u0631 \u0628\u0639\u062f \u0627\u0644\u062a\u0639\u062f\u064a\u0644: $e';
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
      _statistics = await _documentUseCases.getStatistics();
      _error = null;
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0625\u062d\u0635\u0627\u0626\u064a\u0627\u062a: $e';
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
      final options =
          await _documentUseCases.getClassificationOptions(documentType);
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
      await _documentUseCases.addClassificationOption(
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
      final outcome = await _documentUseCases.importWaridFromExcel(
        fileBytes: fileBytes,
        fileName: fileName,
        filePath: filePath,
        userId: userId,
        userName: userName,
      );

      await _refreshWaridWithCurrentFilters();
      _error = outcome.errors.isNotEmpty && outcome.importedRows == 0
          ? outcome.errors.first.message
          : null;

      return DocumentImportResult(
        totalRows: outcome.totalRows,
        importedRows: outcome.importedRows,
        failedRows: outcome.failedRows,
        errors: outcome.errors,
      );
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u0627\u0633\u062a\u064a\u0631\u0627\u062f \u0645\u0644\u0641 \u0627\u0644\u0648\u0627\u0631\u062f: $e';
      return DocumentImportResult(
        totalRows: 0,
        importedRows: 0,
        failedRows: 0,
        errors: [ImportRowError(rowNumber: 0, message: _error!)],
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
      final outcome = await _documentUseCases.importSadirFromExcel(
        fileBytes: fileBytes,
        fileName: fileName,
        filePath: filePath,
        userId: userId,
        userName: userName,
      );

      await _refreshSadirWithCurrentFilters();
      _error = outcome.errors.isNotEmpty && outcome.importedRows == 0
          ? outcome.errors.first.message
          : null;

      return DocumentImportResult(
        totalRows: outcome.totalRows,
        importedRows: outcome.importedRows,
        failedRows: outcome.failedRows,
        errors: outcome.errors,
      );
    } catch (e) {
      _error =
          '\u062d\u062f\u062b \u062e\u0637\u0623 \u0623\u062b\u0646\u0627\u0621 \u0627\u0633\u062a\u064a\u0631\u0627\u062f \u0645\u0644\u0641 \u0627\u0644\u0635\u0627\u062f\u0631: $e';
      return DocumentImportResult(
        totalRows: 0,
        importedRows: 0,
        failedRows: 0,
        errors: [ImportRowError(rowNumber: 0, message: _error!)],
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
