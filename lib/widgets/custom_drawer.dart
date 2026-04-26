import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:railway_secretariat/features/auth/presentation/providers/auth_provider.dart';

class CustomDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Drawer(
      child: Column(
        children: [
          // Header
          UserAccountsDrawerHeader(
            currentAccountPicture: CircleAvatar(
              child: Text(user?.fullName.substring(0, 1) ?? 'U'),
            ),
            accountName: Text(user?.fullName ?? ''),
            accountEmail: Text(user?.email ?? ''),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
          ),

          // Menu items
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('لوحة التحكم'),
            selected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),
          ListTile(
            leading: const Icon(Icons.input),
            title: const Text('الوارد'),
            selected: selectedIndex == 1,
            onTap: () => onItemSelected(1),
          ),
          ListTile(
            leading: const Icon(Icons.output),
            title: const Text('الصادر'),
            selected: selectedIndex == 2,
            onTap: () => onItemSelected(2),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('المستندات'),
            selected: selectedIndex == 3,
            onTap: () => onItemSelected(3),
          ),
          if (user?.role == 'admin')
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('المستخدمين'),
              selected: selectedIndex == 4,
              onTap: () => onItemSelected(4),
            ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('الإعدادات'),
            onTap: () {
              // TODO: Navigate to settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('المساعدة'),
            onTap: () {
              // TODO: Show help
            },
          ),

          const Spacer(),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title:
                const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
            onTap: () => authProvider.logout(),
          ),
        ],
      ),
    );
  }
}

