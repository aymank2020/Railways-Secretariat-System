import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'dashboard_screen.dart';
import 'documents/documents_list_screen.dart';
import 'history/deleted_records_screen.dart';
import 'sadir/sadir_form_screen.dart';
import 'sadir/sadir_list_screen.dart';
import 'users/users_list_screen.dart';
import 'warid/warid_form_screen.dart';
import 'warid/warid_list_screen.dart';

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
        icon: Icons.dashboard,
        screen: DashboardScreen(),
      ),
      const _NavItem(
        key: 'warid',
        title: 'الوارد',
        icon: Icons.input,
        screen: WaridListScreen(),
      ),
      const _NavItem(
        key: 'sadir',
        title: 'الصادر',
        icon: Icons.output,
        screen: SadirListScreen(),
      ),
      const _NavItem(
        key: 'documents',
        title: 'المستندات',
        icon: Icons.folder,
        screen: DocumentsListScreen(),
      ),
    ];

    if (auth.canManageUsers) {
      items.add(
        const _NavItem(
          key: 'users',
          title: 'المستخدمون',
          icon: Icons.people,
          screen: UsersListScreen(),
        ),
      );
    }

    if (auth.isAdmin) {
      items.add(
        const _NavItem(
          key: 'deleted_records',
          title: 'سجل المحذوفات',
          icon: Icons.history,
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
              centerTitle: true,
              title: Text(selectedItem.title),
              actions: [
                IconButton(
                  icon: Icon(themeProvider.isDarkMode
                      ? Icons.light_mode
                      : Icons.dark_mode),
                  onPressed: () => themeProvider.toggleTheme(),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => authProvider.logout(),
                ),
              ],
            ),
      body: Row(
        children: [
          if (showRail)
            NavigationRail(
              extended: isWideRail,
              minExtendedWidth: 220,
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
                  const SizedBox(height: 16),
                  const Icon(Icons.train, size: 40, color: Colors.blue),
                  if (isWideRail) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'السكك الحديدية',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                ],
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(),
                  IconButton(
                    icon: Icon(themeProvider.isDarkMode
                        ? Icons.light_mode
                        : Icons.dark_mode),
                    onPressed: () => themeProvider.toggleTheme(),
                    tooltip: themeProvider.isDarkMode
                        ? 'الوضع النهاري'
                        : 'الوضع الليلي',
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => authProvider.logout(),
                    tooltip: 'تسجيل الخروج',
                  ),
                  const SizedBox(height: 16),
                  if (isWideRail)
                    SizedBox(
                      width: 200,
                      child: ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        leading: CircleAvatar(
                          child: Text(user.fullName.isNotEmpty
                              ? user.fullName[0]
                              : 'U'),
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
                      child: Text(
                          user.fullName.isNotEmpty ? user.fullName[0] : 'U'),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
              destinations: [
                for (final item in navItems)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.icon, color: Colors.blue),
                    label: Text(item.title),
                  ),
              ],
            ),
          Expanded(child: selectedItem.screen),
        ],
      ),
      bottomNavigationBar: showRail
          ? null
          : BottomNavigationBar(
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
            ),
      floatingActionButton: _buildFab(selectedItem.key, authProvider),
    );
  }

  Widget? _buildFab(String selectedKey, AuthProvider authProvider) {
    if (selectedKey == 'warid' && authProvider.canManageWarid) {
      return FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WaridFormScreen()),
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
            MaterialPageRoute(builder: (_) => const SadirFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('صادر جديد'),
      );
    }

    return null;
  }
}
