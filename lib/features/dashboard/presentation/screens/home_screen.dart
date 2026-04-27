import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:railway_secretariat/core/providers/theme_provider.dart';
import 'package:railway_secretariat/features/auth/presentation/providers/auth_provider.dart';
import 'package:railway_secretariat/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/documents_list_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/pdf_batch_split_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/sadir_form_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/sadir_list_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/warid_form_screen.dart';
import 'package:railway_secretariat/features/documents/presentation/screens/warid_list_screen.dart';
import 'package:railway_secretariat/features/history/presentation/screens/deleted_records_screen.dart';
import 'package:railway_secretariat/features/ocr/presentation/screens/ocr_automation_screen.dart';
import 'package:railway_secretariat/features/users/presentation/screens/users_list_screen.dart';
import 'package:railway_secretariat/core/providers/connection_status_provider.dart';
import 'package:railway_secretariat/widgets/connection_status_indicator.dart';

class _NavItem {
  final String key;
  final String title;
  final IconData icon;
  final Widget screen;

  const _NavItem({
    required this.key,
    required this.title,
    required this.icon,
    required this.screen,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<_NavItem> _buildNavItems(AuthProvider auth) {
    final items = <_NavItem>[
      const _NavItem(
        key: 'dashboard',
        title: 'لوحة التحكم',
        icon: Icons.dashboard_outlined,
        screen: DashboardScreen(),
      ),
      const _NavItem(
        key: 'warid',
        title: 'الوارد',
        icon: Icons.move_to_inbox_outlined,
        screen: WaridListScreen(),
      ),
      const _NavItem(
        key: 'sadir',
        title: 'الصادر',
        icon: Icons.outbox_outlined,
        screen: SadirListScreen(),
      ),
      const _NavItem(
        key: 'documents',
        title: 'المستندات',
        icon: Icons.folder_copy_outlined,
        screen: DocumentsListScreen(),
      ),
    ];

    if (auth.canManageWarid || auth.canManageSadir || auth.isAdmin) {
      items.add(
        const _NavItem(
          key: 'pdf_split',
          title: 'فصل PDF',
          icon: Icons.content_cut_outlined,
          screen: PdfBatchSplitScreen(),
        ),
      );
      items.add(
        const _NavItem(
          key: 'ocr',
          title: 'OCR',
          icon: Icons.document_scanner_outlined,
          screen: OcrAutomationScreen(),
        ),
      );
    }

    if (auth.canManageUsers) {
      items.add(
        const _NavItem(
          key: 'users',
          title: 'المستخدمون',
          icon: Icons.people_alt_outlined,
          screen: UsersListScreen(),
        ),
      );
    }

    if (auth.isAdmin) {
      items.add(
        const _NavItem(
          key: 'deleted_records',
          title: 'سجل المحذوفات',
          icon: Icons.history_toggle_off,
          screen: DeletedRecordsScreen(),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.currentUser;
    final scheme = Theme.of(context).colorScheme;

    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final screenWidth = MediaQuery.of(context).size.width;
    final showRail = screenWidth >= 960;
    final isWideRail = screenWidth >= 1400;
    final isCompactScreen = screenWidth < 620;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
      return const SizedBox.shrink();
    }

    final navItems = _buildNavItems(authProvider);
    if (_selectedIndex >= navItems.length) {
      _selectedIndex = 0;
    }

    final selectedItem = navItems[_selectedIndex];

    return Scaffold(
      appBar: showRail
          ? null
          : AppBar(
              title: Text(selectedItem.title),
              actions: [
                const ConnectionStatusIndicator(),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'إعدادات السيرفر',
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/server-settings'),
                ),
                IconButton(
                  icon: Icon(
                    themeProvider.isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_outlined),
                  onPressed: () => authProvider.logout(),
                ),
              ],
            ),
      body: Column(
        children: [
          // Disconnection banner — shown when server is unreachable
          Consumer<ConnectionStatusProvider>(
            builder: (context, conn, _) {
              if (conn.state != ServerConnectionState.disconnected) {
                return const SizedBox.shrink();
              }
              return MaterialBanner(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                content: const Text(
                  'تعذر الاتصال بالسيرفر — تحقق من عنوان السيرفر أو حالة الشبكة',
                  style: TextStyle(fontSize: 13),
                ),
                leading: const Icon(Icons.cloud_off_outlined, color: Color(0xFFD6456A)),
                backgroundColor: const Color(0xFFFFEBEE),
                actions: [
                  TextButton(
                    onPressed: () => conn.checkNow(),
                    child: const Text('إعادة المحاولة'),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/server-settings'),
                    child: const Text('إعدادات السيرفر'),
                  ),
                ],
              );
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.08),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: Row(
          children: [
            if (showRail)
              NavigationRail(
                extended: isWideRail,
                minExtendedWidth: 230,
                labelType: isWideRail ? null : NavigationRailLabelType.selected,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                leading: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDesktop)
                      SizedBox(
                        height: 40,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                onPressed: () => windowManager.minimize(),
                              ),
                              IconButton(
                                icon: const Icon(Icons.crop_square, size: 18),
                                onPressed: () async {
                                  if (await windowManager.isMaximized()) {
                                    await windowManager.unmaximize();
                                  } else {
                                    await windowManager.maximize();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => windowManager.close(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Icon(Icons.train, size: 40, color: scheme.primary),
                    if (isWideRail) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'السكك الحديدية',
                        style:
                            TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ConnectionStatusIndicator(),
                    const Divider(),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'إعدادات السيرفر',
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/server-settings'),
                    ),
                    IconButton(
                      icon: Icon(
                        themeProvider.isDarkMode
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                      onPressed: () => themeProvider.toggleTheme(),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.logout_outlined),
                      onPressed: () => authProvider.logout(),
                    ),
                    const SizedBox(height: 12),
                    if (isWideRail)
                      SizedBox(
                        width: 210,
                        child: ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          leading: CircleAvatar(
                            backgroundColor: scheme.primary.withValues(alpha: 0.18),
                            child: Text(
                              user.fullName.isNotEmpty ? user.fullName[0] : 'U',
                            ),
                          ),
                          title: Text(
                            user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            user.role == 'admin' ? 'مدير النظام' : 'مستخدم',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                    else
                      CircleAvatar(
                        backgroundColor: scheme.primary.withValues(alpha: 0.18),
                        child: Text(
                          user.fullName.isNotEmpty ? user.fullName[0] : 'U',
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
                destinations: [
                  for (final item in navItems)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.icon, color: scheme.primary),
                      label: Text(item.title),
                    ),
                ],
              ),
            Expanded(child: selectedItem.screen),
          ],
        ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: showRail
          ? null
          : navItems.length <= 5
              ? BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  type: BottomNavigationBarType.fixed,
                  showUnselectedLabels: !isCompactScreen,
                  items: [
                    for (final item in navItems)
                      BottomNavigationBarItem(
                        icon: Icon(item.icon),
                        label: item.title,
                      ),
                  ],
                )
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelBehavior: isCompactScreen
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: [
                    for (final item in navItems)
                      NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.title,
                      ),
                  ],
                ),
      floatingActionButton: _buildFab(selectedItem.key, authProvider),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Widget? _buildFab(String selectedKey, AuthProvider authProvider) {
    if (selectedKey == 'warid' && authProvider.canManageWarid) {
      return FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WaridFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('وارد جديد'),
      );
    }

    if (selectedKey == 'sadir' && authProvider.canManageSadir) {
      return FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SadirFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('صادر جديد'),
      );
    }

    return null;
  }
}
