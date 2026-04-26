import 'package:railway_secretariat/core/network/api_client.dart';
import 'package:railway_secretariat/features/ocr/data/models/ocr_template_model.dart';

import '../../domain/repositories/ocr_template_repository.dart';

class HttpOcrTemplateRepository implements OcrTemplateRepository {
  final ApiClient _apiClient;

  HttpOcrTemplateRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<OcrTemplateModel>> getTemplates({String? documentType}) async {
    final list = await _apiClient.getList(
      '/api/ocr/templates',
      query: <String, String>{
        if ((documentType ?? '').trim().isNotEmpty)
          'documentType': documentType!.trim(),
      },
    );

    return list
        .whereType<Map>()
        .map(
          (item) => OcrTemplateModel.fromMap(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<int> saveTemplate(OcrTemplateModel template) async {
    final response = await _apiClient.postMap(
      '/api/ocr/templates',
      body: <String, dynamic>{'template': template.toMap()},
    );
    return int.tryParse(response['id']?.toString() ?? '') ?? 0;
  }

  @override
  Future<void> deleteTemplate(int id) async {
    await _apiClient.delete('/api/ocr/templates/$id');
  }
}
