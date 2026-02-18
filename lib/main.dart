import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'providers/auth_provider.dart';
import 'providers/document_provider.dart';
import 'providers/user_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/warid/warid_form_screen.dart';
import 'screens/warid/warid_list_screen.dart';
import 'screens/warid/warid_search_screen.dart';
import 'screens/sadir/sadir_form_screen.dart';
import 'screens/sadir/sadir_list_screen.dart';
import 'screens/sadir/sadir_search_screen.dart';
import 'screens/users/users_list_screen.dart';
import 'screens/documents/documents_list_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    final WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(960, 640),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.maximize();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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
            },
          );
        },
      ),
    );
  }
}
