import 'package:railway_secretariat/features/ocr/data/models/ocr_template_model.dart';
import 'package:railway_secretariat/core/services/database_service.dart';
import '../../domain/repositories/ocr_template_repository.dart';

class DatabaseOcrTemplateRepository implements OcrTemplateRepository {
  final DatabaseService _databaseService;

  DatabaseOcrTemplateRepository({required DatabaseService databaseService})
      : _databaseService = databaseService;

  @override
  Future<List<OcrTemplateModel>> getTemplates({String? documentType}) {
    return _databaseService.getOcrTemplates(documentType: documentType);
  }

  @override
  Future<int> saveTemplate(OcrTemplateModel template) {
    return _databaseService.saveOcrTemplate(template);
  }

  @override
  Future<void> deleteTemplate(int id) {
    return _databaseService.deleteOcrTemplate(id);
  }
}
