class ImportRowError {
  final int rowNumber;
  final String message;

  const ImportRowError({
    required this.rowNumber,
    required this.message,
  });
}

class DocumentImportOutcome {
  final int totalRows;
  final int importedRows;
  final int failedRows;
  final List<ImportRowError> errors;

  const DocumentImportOutcome({
    required this.totalRows,
    required this.importedRows,
    required this.failedRows,
    required this.errors,
  });
}
