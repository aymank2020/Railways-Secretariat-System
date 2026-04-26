import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:railway_secretariat/features/auth/presentation/providers/auth_provider.dart';
import 'package:railway_secretariat/features/documents/presentation/providers/document_provider.dart';
import 'package:railway_secretariat/utils/helpers.dart';

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
    final scheme = Theme.of(context).colorScheme;

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

            final statItems = <_DashboardStat>[
              _DashboardStat(
                title: 'إجمالي المراسلات',
                value: Helpers.formatNumber(stats['total_documents'] ?? 0),
                icon: Icons.folder_copy_outlined,
                color: scheme.primary,
              ),
              _DashboardStat(
                title: 'الوارد',
                value: Helpers.formatNumber(stats['warid_total'] ?? 0),
                icon: Icons.move_to_inbox_outlined,
                color: scheme.secondary,
              ),
              _DashboardStat(
                title: 'الصادر',
                value: Helpers.formatNumber(stats['sadir_total'] ?? 0),
                icon: Icons.outbox_outlined,
                color: scheme.tertiary,
              ),
              _DashboardStat(
                title: 'وارد يحتاج متابعة',
                value: Helpers.formatNumber(stats['warid_followup'] ?? 0),
                icon: Icons.notification_important_outlined,
                color: scheme.error,
              ),
              _DashboardStat(
                title: 'صادر يحتاج متابعة',
                value: Helpers.formatNumber(stats['sadir_followup'] ?? 0),
                icon: Icons.priority_high_outlined,
                color: scheme.primary.withValues(alpha: 0.85),
              ),
              _DashboardStat(
                title: 'هذا الشهر',
                value: Helpers.formatNumber(
                  (stats['warid_this_month'] ?? 0) +
                      (stats['sadir_this_month'] ?? 0),
                ),
                icon: Icons.calendar_month_outlined,
                color: scheme.secondary.withValues(alpha: 0.9),
              ),
            ];

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(maxWidth < 600 ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeCard(
                    context,
                    userName: user?.fullName ?? '',
                    roleName: Helpers.getRoleName(user?.role ?? 'user'),
                    isNarrow: isNarrowWelcome,
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
                        for (final item in statItems)
                          SizedBox(
                            width: statCardWidth,
                            child: _buildStatCard(
                              context,
                              title: item.title,
                              value: item.value,
                              icon: item.icon,
                              color: item.color,
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
                          icon: Icons.add_circle_outline,
                          color: scheme.secondary,
                          onTap: () =>
                              Navigator.of(context).pushNamed('/warid/form'),
                        ),
                      ),
                      SizedBox(
                        width: quickActionWidth,
                        child: _buildQuickActionButton(
                          context,
                          title: 'صادر جديد',
                          icon: Icons.add_circle_outline,
                          color: scheme.tertiary,
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
                          color: scheme.primary,
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
                          color: scheme.primary.withValues(alpha: 0.8),
                          onTap: () =>
                              Navigator.of(context).pushNamed('/sadir/search'),
                        ),
                      ),
                      SizedBox(
                        width: quickActionWidth,
                        child: _buildQuickActionButton(
                          context,
                          title: 'OCR تلقائي',
                          icon: Icons.document_scanner_outlined,
                          color: scheme.secondary.withValues(alpha: 0.85),
                          onTap: () => Navigator.of(context).pushNamed('/ocr'),
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
                      leading: Icon(Icons.info_outline, color: scheme.primary),
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

  Widget _buildWelcomeCard(
    BuildContext context, {
    required String userName,
    required String roleName,
    required bool isNarrow,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final initial = userName.trim().isNotEmpty ? userName.trim()[0] : 'U';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isNarrow
            ? Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primary,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 22,
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'مرحبًا، $userName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roleName,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.primary,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 24,
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحبًا، $userName',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          roleName,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
    final estimated = ((safeWidth + spacing) / (minItemWidth + spacing)).floor();
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
      elevation: 0,
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.32)),
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

class _DashboardStat {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
