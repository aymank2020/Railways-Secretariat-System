import 'package:railway_secretariat/features/ocr/data/models/ocr_template_model.dart';
import '../repositories/ocr_template_repository.dart';

class OcrTemplateUseCases {
  final OcrTemplateRepository _repository;

  OcrTemplateUseCases({required OcrTemplateRepository repository})
      : _repository = repository;

  Future<List<OcrTemplateModel>> getTemplates({String? documentType}) {
    return _repository.getTemplates(documentType: documentType);
  }

  Future<int> saveTemplate(OcrTemplateModel template) {
    return _repository.saveTemplate(template);
  }

  Future<void> deleteTemplate(int id) {
    return _repository.deleteTemplate(id);
  }
}
