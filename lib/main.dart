import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'core/di/app_dependencies.dart';
import 'core/services/server_settings_service.dart';
import 'package:railway_secretariat/features/auth/presentation/providers/auth_provider.dart';
import 'package:railway_secretariat/features/documents/presentation/providers/document_provider.dart';
import 'package:railway_secretariat/features/users/presentation/providers/user_provider.dart';
import 'package:railway_secretariat/core/providers/theme_provider.dart';
import 'package:railway_secretariat/core/providers/connection_status_provider.dart';
import 'package:railway_secretariat/features/auth/presentation/screens/login_screen.dart';
import 'package:railway_secretariat/features/dashboard/presentation/screens/home_screen.dart';
import 'package:railway_secretariat/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/warid_form_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/warid_list_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/warid_search_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/sadir_form_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/sadir_list_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/sadir_search_screen.dart';
import 'package:railway_secretariat/features/users/presentation/screens/users_list_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/documents_list_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/pdf_batch_split_screen.dart';
import 'package:railway_secretariat/features/history/presentation/screens/deleted_records_screen.dart';
import 'package:railway_secretariat/features/ocr/presentation/screens/ocr_automation_screen.dart';
import 'package:railway_secretariat/features/system/presentation/screens/server_settings_screen.dart';
import 'utils/app_theme.dart';

/// Singleton connection status provider reused across full app restarts
/// (e.g. when the user changes the server URL).  Keeping a single instance
/// ensures there is only ever one health-check timer running.
ConnectionStatusProvider? _connectionStatusProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    final WindowOptions windowOptions = const WindowOptions(
      size: Size(1100, 700),
      minimumSize: Size(840, 560),
      center: true,
      backgroundColor: Colors.white,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // SharedPreferences wins over the compile-time URL so end-users who change
  // the server address from the Settings screen aren't permanently locked
  // to whatever URL was baked into the binary at build time.  The
  // compile-time URL is then used as a sensible default on first launch
  // (or after the user clears the saved URL).
  final savedUrl = await ServerSettingsService().getSavedServerUrl();
  if (savedUrl != null && savedUrl.isNotEmpty) {
    final dependencies = AppDependencies(overrideApiBaseUrl: savedUrl);
    runApp(MyApp(dependencies: dependencies));
    return;
  }

  final compileTimeUrl = _resolveCompileTimeApiUrl();
  if (compileTimeUrl != null) {
    final dependencies = AppDependencies(overrideApiBaseUrl: compileTimeUrl);
    runApp(MyApp(dependencies: dependencies));
    return;
  }

  // On the web, default to the same origin that served the app: the API
  // is reverse-proxied at /api/* by the same nginx that serves the bundle.
  // This avoids forcing the user through the server-setup screen.
  if (kIsWeb) {
    final origin = Uri.base.origin;
    final dependencies = AppDependencies(overrideApiBaseUrl: origin);
    runApp(MyApp(dependencies: dependencies));
    return;
  }

  // No URL configured — show the setup/bootstrap screen.
  runApp(const ServerSetupApp());
}

/// Resolves the API base URL from compile-time defines or environment
/// variables, *excluding* SharedPreferences (which requires async).
String? _resolveCompileTimeApiUrl() {
  const fromDefine = String.fromEnvironment('API_BASE_URL');
  if (fromDefine.trim().isNotEmpty) {
    return fromDefine.trim();
  }

  if (!kIsWeb) {
    final fromEnv =
        Platform.environment['SECRETARIAT_API_BASE_URL']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }
  }

  return null;
}

/// Shown on first launch when no server URL is configured yet.
/// Lets the user choose between remote (server) or local mode.
class ServerSetupApp extends StatelessWidget {
  const ServerSetupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام إدارة المراسلات - السكك الحديدية',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: ServerSettingsScreen(
        isInitialSetup: true,
        onComplete: (serverUrl) {
          final dependencies = AppDependencies(overrideApiBaseUrl: serverUrl);
          runApp(MyApp(dependencies: dependencies));
        },
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final AppDependencies dependencies;

  const MyApp({
    super.key,
    required this.dependencies,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDependencies>.value(value: dependencies),
        ChangeNotifierProvider<ConnectionStatusProvider>(
          create: (_) {
            // Reuse the singleton provider so there is only ever one
            // health-check timer even when runApp() is called again after
            // a server URL change.
            final existing = _connectionStatusProvider;
            if (existing != null) {
              existing.updateServerUrl(dependencies.apiBaseUrl);
              return existing;
            }
            final provider = ConnectionStatusProvider(
              serverUrl: dependencies.apiBaseUrl,
            );
            _connectionStatusProvider = provider;
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authUseCases: dependencies.authUseCases,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => DocumentProvider(
            documentUseCases: dependencies.documentUseCases,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProvider(
            userUseCases: dependencies.userUseCases,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(
            themeUseCases: dependencies.themeUseCases,
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'نظام إدارة المراسلات - السكك الحديدية',
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar', 'SA'),
            supportedLocales: const [
              Locale('ar', 'SA'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/warid/form': (context) => const WaridFormScreen(),
              '/warid/list': (context) => const WaridListScreen(),
              '/warid/search': (context) => const WaridSearchScreen(),
              '/sadir/form': (context) => const SadirFormScreen(),
              '/sadir/list': (context) => const SadirListScreen(),
              '/sadir/search': (context) => const SadirSearchScreen(),
              '/users': (context) => const UsersListScreen(),
              '/documents': (context) => const DocumentsListScreen(),
              '/documents/pdf-split': (context) => const PdfBatchSplitScreen(),
              '/history/deleted': (context) => const DeletedRecordsScreen(),
              '/ocr': (context) => const OcrAutomationScreen(),
              '/server-settings': (context) => ServerSettingsScreen(
                    isInitialSetup: false,
                    onComplete: (serverUrl) {
                      // Restart the app with new dependencies
                      final deps =
                          AppDependencies(overrideApiBaseUrl: serverUrl);
                      runApp(MyApp(dependencies: deps));
                    },
                  ),
            },
          );
        },
      ),
    );
  }
}
