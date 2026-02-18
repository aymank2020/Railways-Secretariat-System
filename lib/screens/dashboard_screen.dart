import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';
import '../utils/helpers.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DocumentProvider>(context, listen: false).loadStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final docProvider = Provider.of<DocumentProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final stats = docProvider.statistics;
    final user = authProvider.currentUser;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => docProvider.loadStatistics(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final statCardWidth = _responsiveItemWidth(
              maxWidth,
              minItemWidth: 220,
              maxColumns: 3,
            );
            final quickActionWidth = _responsiveItemWidth(
              maxWidth,
              minItemWidth: 160,
              maxColumns: 4,
            );
            final isNarrowWelcome = maxWidth < 600;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(maxWidth < 600 ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: isNarrowWelcome
                          ? Column(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  child: Text(
                                    user?.fullName.substring(0, 1) ?? 'U',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'مرحباً، ${user?.fullName ?? ''}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Helpers.getRoleName(user?.role ?? 'user'),
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  child: Text(
                                    user?.fullName.substring(0, 1) ?? 'U',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'مرحباً، ${user?.fullName ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        Helpers.getRoleName(
                                            user?.role ?? 'user'),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'إحصائيات النظام',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (docProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: statCardWidth,
                          child: _buildStatCard(
                            context,
                            title: 'إجمالي المراسلات',
                            value: Helpers.formatNumber(
                                stats['total_documents'] ?? 0),
                            icon: Icons.folder_copy,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(
                          width: statCardWidth,
                          child: _buildStatCard(
                            context,
                            title: 'الوارد',
                            value:
                                Helpers.formatNumber(stats['warid_total'] ?? 0),
                            icon: Icons.input,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(
                          width: statCardWidth,
                          child: _buildStatCard(
                            context,
                            title: 'الصادر',
                            value:
                                Helpers.formatNumber(stats['sadir_total'] ?? 0),
                            icon: Icons.output,
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(
                          width: statCardWidth,
                          child: _buildStatCard(
                            context,
                            title: 'وارد يحتاج متابعة',
                            value: Helpers.formatNumber(
                                stats['warid_followup'] ?? 0),
                            icon: Icons.notification_important,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(
                          width: statCardWidth,
                          child: _buildStatCard(
                            context,
                            title: 'صادر يحتاج متابعة',
                            value: Helpers.formatNumber(
                                stats['sadir_followup'] ?? 0),
                            icon: Icons.notification_important,
                            color: Colors.purple,
                          ),
                        ),
                        SizedBox(
                          width: statCardWidth,
                          child: _buildStatCard(
                            context,
                            title: 'هذا الشهر',
                            value: Helpers.formatNumber(
                              (stats['warid_this_month'] ?? 0) +
                                  (stats['sadir_this_month'] ?? 0),
                            ),
                            icon: Icons.calendar_month,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'إجراءات سريعة',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: quickActionWidth,
                        child: _buildQuickActionButton(
                          context,
                          title: 'وارد جديد',
                          icon: Icons.add_circle,
                          color: Colors.green,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/warid/form'),
                        ),
                      ),
                      SizedBox(
                        width: quickActionWidth,
                        child: _buildQuickActionButton(
                          context,
                          title: 'صادر جديد',
                          icon: Icons.add_circle,
                          color: Colors.orange,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/sadir/form'),
                        ),
                      ),
                      SizedBox(
                        width: quickActionWidth,
                        child: _buildQuickActionButton(
                          context,
                          title: 'بحث في الوارد',
                          icon: Icons.search,
                          color: Colors.blue,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/warid/search'),
                        ),
                      ),
                      SizedBox(
                        width: quickActionWidth,
                        child: _buildQuickActionButton(
                          context,
                          title: 'بحث في الصادر',
                          icon: Icons.search,
                          color: Colors.purple,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/sadir/search'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'النشاط الأخير',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info, color: Colors.blue),
                      title: const Text('النظام جاهز للاستخدام'),
                      subtitle: Text(
                        'تم تسجيل الدخول في ${Helpers.formatDate(DateTime.now(), includeTime: true)}',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _responsiveItemWidth(
    double maxWidth, {
    required double minItemWidth,
    required int maxColumns,
    double spacing = 16,
  }) {
    final safeWidth = maxWidth < 320 ? 320 : maxWidth;
    final estimated =
        ((safeWidth + spacing) / (minItemWidth + spacing)).floor();
    final columns = estimated.clamp(1, maxColumns);
    return (safeWidth - (spacing * (columns - 1))) / columns;
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
