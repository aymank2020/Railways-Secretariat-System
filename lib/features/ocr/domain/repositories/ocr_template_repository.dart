import 'package:railway_secretariat/features/ocr/data/models/ocr_template_model.dart';

abstract class OcrTemplateRepository {
  Future<List<OcrTemplateModel>> getTemplates({String? documentType});

  Future<int> saveTemplate(OcrTemplateModel template);

  Future<void> deleteTemplate(int id);
}
