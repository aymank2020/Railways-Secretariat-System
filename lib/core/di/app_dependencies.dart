import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:railway_secretariat/core/network/api_client.dart';
import 'package:railway_secretariat/features/auth/data/repositories/database_auth_repository.dart';
import 'package:railway_secretariat/features/auth/data/repositories/http_auth_repository.dart';
import 'package:railway_secretariat/features/auth/data/repositories/secure_storage_credentials_repository.dart';
import 'package:railway_secretariat/features/auth/domain/usecases/auth_use_cases.dart';
import 'package:railway_secretariat/features/documents/data/datasources/excel_import_service.dart';
import 'package:railway_secretariat/features/documents/data/repositories/database_document_repository.dart';
import 'package:railway_secretariat/features/documents/data/repositories/http_document_repository.dart';
import 'package:railway_secretariat/features/documents/domain/usecases/document_use_cases.dart';
import 'package:railway_secretariat/features/ocr/data/repositories/database_ocr_template_repository.dart';
import 'package:railway_secretariat/features/ocr/data/repositories/http_ocr_template_repository.dart';
import 'package:railway_secretariat/features/ocr/domain/usecases/ocr_template_use_cases.dart';
import 'package:railway_secretariat/features/system/data/repositories/database_system_repository.dart';
import 'package:railway_secretariat/features/system/data/repositories/http_system_repository.dart';
import 'package:railway_secretariat/features/system/domain/usecases/system_use_cases.dart';
import 'package:railway_secretariat/features/theme/data/repositories/shared_prefs_theme_repository.dart';
import 'package:railway_secretariat/features/theme/domain/usecases/theme_use_cases.dart';
import 'package:railway_secretariat/features/users/data/repositories/database_user_repository.dart';
import 'package:railway_secretariat/features/users/data/repositories/http_user_repository.dart';
import 'package:railway_secretariat/features/users/domain/usecases/user_use_cases.dart';
import 'package:railway_secretariat/core/services/database_service.dart';

class AppDependencies {
  late final AuthUseCases authUseCases;
  late final UserUseCases userUseCases;
  late final DocumentUseCases documentUseCases;
  late final OcrTemplateUseCases ocrTemplateUseCases;
  late final ThemeUseCases themeUseCases;
  late final SystemUseCases systemUseCases;

  final String? apiBaseUrl;
  final bool isRemoteMode;

  AppDependencies({String? overrideApiBaseUrl})
      : apiBaseUrl = _resolveApiBaseUrl(overrideApiBaseUrl),
        isRemoteMode = _resolveApiBaseUrl(overrideApiBaseUrl) != null {
    final dbService = DatabaseService();
    final excelImportService = ExcelImportService();
    // Use OS-keychain-backed storage for the saved username/password
    // pair (Keychain / Keystore / DPAPI / libsecret / IndexedDB-AES).
    // The repository transparently migrates any value left behind by
    // the legacy XOR-cipher [EncryptedCredentialsRepository] on first
    // read, so existing users do not get logged out by the upgrade.
    final credentialsRepository = SecureStorageCredentialsRepository();

    final remoteBaseUrl = apiBaseUrl;
    if (remoteBaseUrl != null && remoteBaseUrl.trim().isNotEmpty) {
      final apiClient = ApiClient(baseUrl: remoteBaseUrl);

      final httpAuthRepo = HttpAuthRepository(apiClient: apiClient);

      // Wire up automatic re-authentication on 401 responses.
      // When the server returns 401, the ApiClient will attempt to
      // re-login using saved credentials before failing.
      apiClient.onUnauthorized = () async {
        try {
          final saved = await credentialsRepository.loadCredentials();
          if (saved == null) return false;
          final user = await httpAuthRepo.authenticate(
            username: saved.username,
            password: saved.password,
          );
          return user != null;
        } catch (_) {
          return false;
        }
      };

      authUseCases = AuthUseCases(
        authRepository: httpAuthRepo,
        credentialsRepository: credentialsRepository,
      );

      userUseCases = UserUseCases(
        repository: HttpUserRepository(apiClient: apiClient),
      );

      documentUseCases = DocumentUseCases(
        repository: HttpDocumentRepository(apiClient: apiClient),
      );

      ocrTemplateUseCases = OcrTemplateUseCases(
        repository: HttpOcrTemplateRepository(apiClient: apiClient),
      );

      systemUseCases = SystemUseCases(
        repository: HttpSystemRepository(apiClient: apiClient),
      );
    } else {
      authUseCases = AuthUseCases(
        authRepository: DatabaseAuthRepository(databaseService: dbService),
        credentialsRepository: credentialsRepository,
      );

      userUseCases = UserUseCases(
        repository: DatabaseUserRepository(databaseService: dbService),
      );

      documentUseCases = DocumentUseCases(
        repository: DatabaseDocumentRepository(
          databaseService: dbService,
          excelImportService: excelImportService,
        ),
      );

      ocrTemplateUseCases = OcrTemplateUseCases(
        repository: DatabaseOcrTemplateRepository(databaseService: dbService),
      );

      systemUseCases = SystemUseCases(
        repository: DatabaseSystemRepository(databaseService: dbService),
      );
    }

    themeUseCases = ThemeUseCases(
      repository: SharedPreferencesThemeRepository(),
    );
  }

  static String? _resolveApiBaseUrl(String? overrideApiBaseUrl) {
    final override = overrideApiBaseUrl?.trim() ?? '';
    if (override.isNotEmpty) {
      return override;
    }

    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.trim().isNotEmpty) {
      return fromDefine.trim();
    }

    if (!kIsWeb) {
      final fromEnv = Platform.environment['SECRETARIAT_API_BASE_URL']?.trim();
      if (fromEnv != null && fromEnv.isNotEmpty) {
        return fromEnv;
      }
    }

    return null;
  }
}
