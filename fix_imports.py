import os
import re

mapping = {
    '../features/theme/domain/usecases/theme_use_cases.dart': 'features/theme/domain/usecases/theme_use_cases.dart',
    '../features/auth/domain/usecases/auth_use_cases.dart': 'features/auth/domain/usecases/auth_use_cases.dart',
    '../features/users/domain/usecases/user_use_cases.dart': 'features/users/domain/usecases/user_use_cases.dart',
    '../features/documents/domain/entities/document_import_outcome.dart': 'features/documents/domain/entities/document_import_outcome.dart',
    '../features/documents/domain/usecases/document_use_cases.dart': 'features/documents/domain/usecases/document_use_cases.dart',
    '../../features/ocr/domain/usecases/ocr_template_use_cases.dart': 'features/ocr/domain/usecases/ocr_template_use_cases.dart',
    '../../core/di/app_dependencies.dart': 'core/di/app_dependencies.dart',
    '../utils/helpers.dart': 'utils/helpers.dart',
    '../../utils/helpers.dart': 'utils/helpers.dart',
    '../utils/app_theme.dart': 'utils/app_theme.dart',
    'documents/documents_list_screen.dart': 'features/documents/presentation/screens/documents_list_screen.dart',
    'documents/pdf_batch_split_screen.dart': 'features/documents/presentation/screens/pdf_batch_split_screen.dart',
    'history/deleted_records_screen.dart': 'features/history/presentation/screens/deleted_records_screen.dart',
    'ocr/ocr_automation_screen.dart': 'features/ocr/presentation/screens/ocr_automation_screen.dart',
    'sadir/sadir_form_screen.dart': 'features/documents/presentation/screens/sadir_form_screen.dart',
    'sadir/sadir_list_screen.dart': 'features/documents/presentation/screens/sadir_list_screen.dart',
    'users/users_list_screen.dart': 'features/users/presentation/screens/users_list_screen.dart',
    'warid/warid_form_screen.dart': 'features/documents/presentation/screens/warid_form_screen.dart',
    'warid/warid_list_screen.dart': 'features/documents/presentation/screens/warid_list_screen.dart',
    '../sadir/sadir_form_screen.dart': 'features/documents/presentation/screens/sadir_form_screen.dart',
    '../warid/warid_form_screen.dart': 'features/documents/presentation/screens/warid_form_screen.dart',
    'models/deleted_record_model.dart': 'features/history/data/models/deleted_record_model.dart',
    'models/sadir_model.dart': 'features/documents/data/models/sadir_model.dart',
    'models/warid_model.dart': 'features/documents/data/models/warid_model.dart',
    'models/ocr_template_model.dart': 'features/ocr/data/models/ocr_template_model.dart',
    'models/ocr_field_definitions.dart': 'features/ocr/data/models/ocr_field_definitions.dart',
    'models/document_model.dart': 'features/documents/data/models/document_model.dart',
    'models/user_model.dart': 'features/users/data/models/user_model.dart',
    'screens/ocr/ocr_automation_screen.dart': 'features/ocr/presentation/screens/ocr_automation_screen.dart',
    'providers/theme_provider.dart': 'core/providers/theme_provider.dart',
    'providers/auth_provider.dart': 'features/auth/presentation/providers/auth_provider.dart',
    'providers/document_provider.dart': 'features/documents/presentation/providers/document_provider.dart',
    'providers/user_provider.dart': 'features/users/presentation/providers/user_provider.dart',
    'services/a3_print_service.dart': 'features/documents/data/datasources/a3_print_service.dart',
    'services/attachment_storage_service.dart': 'features/documents/data/datasources/attachment_storage_service.dart',
    'services/database_service.dart': 'core/services/database_service.dart',
    'services/documents_export_service.dart': 'features/documents/data/datasources/documents_export_service.dart',
    'services/excel_import_service.dart': 'features/documents/data/datasources/excel_import_service.dart',
    'services/ocr_service.dart': 'features/ocr/data/datasources/ocr_service.dart',
    'services/password_service.dart': 'features/auth/data/datasources/password_service.dart',
    'services/pdf_batch_split_service.dart': 'features/documents/data/datasources/pdf_batch_split_service.dart',
    'services/storage_location_service.dart': 'core/services/storage_location_service.dart',
    'screens/login_screen.dart': 'features/auth/presentation/screens/login_screen.dart',
    'screens/dashboard_screen.dart': 'features/dashboard/presentation/screens/dashboard_screen.dart',
    'screens/home_screen.dart': 'features/dashboard/presentation/screens/home_screen.dart',
    'screens/warid/warid_form_screen.dart': 'features/documents/presentation/screens/warid_form_screen.dart',
    'screens/warid/warid_list_screen.dart': 'features/documents/presentation/screens/warid_list_screen.dart',
    'screens/warid/warid_search_screen.dart': 'features/documents/presentation/screens/warid_search_screen.dart',
    'screens/sadir/sadir_form_screen.dart': 'features/documents/presentation/screens/sadir_form_screen.dart',
    'screens/sadir/sadir_list_screen.dart': 'features/documents/presentation/screens/sadir_list_screen.dart',
    'screens/sadir/sadir_search_screen.dart': 'features/documents/presentation/screens/sadir_search_screen.dart',
    'screens/documents/documents_list_screen.dart': 'features/documents/presentation/screens/documents_list_screen.dart',
    'screens/documents/pdf_batch_split_screen.dart': 'features/documents/presentation/screens/pdf_batch_split_screen.dart',
    'screens/users/users_list_screen.dart': 'features/users/presentation/screens/users_list_screen.dart',
    'screens/history/deleted_records_screen.dart': 'features/history/presentation/screens/deleted_records_screen.dart',
}

pkg_name = 'railway_secretariat'

def fix_imports_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    
    for old_path, new_path in mapping.items():
        base_name = old_path.split('/')[-1]
        
        # Replace occurrences of base_name or relative path with package import
        # We need to make sure we don't double replace.
        
        # Matches forms like:
        # import '../models/sadir_model.dart';
        # import 'models/sadir_model.dart';
        # import '../../../../models/sadir_model.dart';
        pattern = r"import\s+['\"](?:package:" + pkg_name + r"/)?(?:[\.\/]*)*" + re.escape(old_path) + r"['\"];"
        replacement = f"import 'package:{pkg_name}/{new_path}';"
        content = re.sub(pattern, replacement, content)
        
        # fallback for basename:
        pattern_base = r"import\s+['\"](?:(?:[\.\/]*)*)*" + re.escape(base_name) + r"['\"];"
        content = re.sub(pattern_base, replacement, content)
        
    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Fixed: {filepath}')

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_imports_in_file(os.path.join(root, file))

print('Import replacement complete.')
