import 'package:flutter/material.dart';

import 'package:railway_secretariat/core/services/server_settings_service.dart';
import 'package:railway_secretariat/utils/app_theme.dart';

/// Screen that allows the user to configure — or skip — a remote server URL.
///
/// After the user either saves a server URL or chooses local mode, the
/// [onComplete] callback fires with the resolved URL (or `null` for local).
class ServerSettingsScreen extends StatefulWidget {
  final void Function(String? serverUrl) onComplete;

  /// When `true` the screen is shown as a first-run setup and offers a
  /// "local mode" button. When `false` it is opened from within the app
  /// settings and shows a "back" affordance instead.
  final bool isInitialSetup;

  const ServerSettingsScreen({
    super.key,
    required this.onComplete,
    this.isInitialSetup = true,
  });

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _serverSettingsService = ServerSettingsService();

  bool _isTesting = false;
  ServerHealthResult? _lastResult;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final url = await _serverSettingsService.getSavedServerUrl();
    if (url != null && url.isNotEmpty && mounted) {
      _urlController.text = url;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isTesting = true;
      _lastResult = null;
    });

    _pulseController.repeat(reverse: true);

    final result =
        await _serverSettingsService.testConnection(_urlController.text.trim());

    if (!mounted) return;

    _pulseController.stop();
    _pulseController.reset();

    setState(() {
      _isTesting = false;
      _lastResult = result;
    });
  }

  Future<void> _saveAndConnect() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Test first
    await _testConnection();

    if (_lastResult == null || !_lastResult!.success) {
      return;
    }

    await _serverSettingsService.saveServerUrl(_urlController.text.trim());
    final saved = await _serverSettingsService.getSavedServerUrl();
    widget.onComplete(saved);
  }

  Future<void> _useLocalMode() async {
    await _serverSettingsService.clearServerUrl();
    widget.onComplete(null);
  }

  Widget _buildGlowOrb({
    required double size,
    required Alignment alignment,
    required Color color,
  }) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.14),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 64,
                spreadRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.loginGradient),
        child: Stack(
          children: [
            _buildGlowOrb(
              size: 260,
              alignment: const Alignment(-0.92, -0.82),
              color: AppTheme.primaryLightColor,
            ),
            _buildGlowOrb(
              size: 200,
              alignment: const Alignment(0.95, 0.75),
              color: AppTheme.accentColor,
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      elevation: 0,
                      color: scheme.surface.withValues(alpha: 0.92),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color:
                              AppTheme.primaryLightColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon
                              ScaleTransition(
                                scale: _isTesting
                                    ? _pulseAnimation
                                    : const AlwaysStoppedAnimation(1.0),
                                child: Container(
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: _isTesting
                                          ? [
                                              AppTheme.warningColor,
                                              AppTheme.accentColor,
                                            ]
                                          : [
                                              AppTheme.primaryColor,
                                              AppTheme.accentColor,
                                            ],
                                    ),
                                  ),
                                  child: Icon(
                                    _isTesting
                                        ? Icons.sync
                                        : Icons.dns_outlined,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Title
                              const Text(
                                'إعدادات السيرفر',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isInitialSetup
                                    ? 'اتصل بسيرفر لمشاركة البيانات أو اعمل محلياً'
                                    : 'تغيير إعدادات الاتصال بالسيرفر',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Server URL input
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: TextFormField(
                                  controller: _urlController,
                                  textInputAction: TextInputAction.done,
                                  keyboardType: TextInputType.url,
                                  textDirection: TextDirection.ltr,
                                  onFieldSubmitted: (_) => _testConnection(),
                                  decoration: const InputDecoration(
                                    labelText: 'عنوان السيرفر (Server URL)',
                                    prefixIcon: Icon(Icons.link),
                                    hintText: 'https://xyz.trycloudflare.com',
                                    hintStyle:
                                        TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                  validator: (value) {
                                    final v = value?.trim() ?? '';
                                    if (v.isEmpty) {
                                      return 'يرجى إدخال عنوان السيرفر';
                                    }
                                    // Basic URL validation
                                    final withScheme =
                                        v.startsWith('http://') ||
                                                v.startsWith('https://')
                                            ? v
                                            : 'http://$v';
                                    final uri = Uri.tryParse(withScheme);
                                    if (uri == null ||
                                        !uri.hasScheme ||
                                        uri.host.isEmpty) {
                                      return 'عنوان غير صالح — مثال: https://xyz.trycloudflare.com';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Test result
                              if (_lastResult != null)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _lastResult!.success
                                        ? AppTheme.successColor
                                            .withValues(alpha: 0.12)
                                        : AppTheme.errorColor
                                            .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _lastResult!.success
                                          ? AppTheme.successColor
                                              .withValues(alpha: 0.4)
                                          : AppTheme.errorColor
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _lastResult!.success
                                            ? Icons.check_circle
                                            : Icons.error,
                                        color: _lastResult!.success
                                            ? AppTheme.successColor
                                            : AppTheme.errorColor,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _lastResult!.message,
                                          style: TextStyle(
                                            color: _lastResult!.success
                                                ? AppTheme.successColor
                                                : AppTheme.errorColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_lastResult != null) const SizedBox(height: 16),

                              // Test button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _isTesting ? null : _testConnection,
                                  icon: _isTesting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.wifi_find),
                                  label: Text(
                                    _isTesting
                                        ? 'جاري الاختبار...'
                                        : 'اختبار الاتصال',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Save & connect button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _isTesting ? null : _saveAndConnect,
                                  icon: const Icon(Icons.cloud_done_outlined),
                                  label: const Text(
                                    'حفظ والاتصال بالسيرفر',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Divider with "or"
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      'أو',
                                      style: TextStyle(
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Local mode button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: TextButton.icon(
                                  onPressed: _useLocalMode,
                                  icon: const Icon(Icons.smartphone),
                                  label: Text(
                                    widget.isInitialSetup
                                        ? 'العمل بدون سيرفر (تخزين محلي)'
                                        : 'قطع الاتصال والعمل محلياً',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Help text
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.infoColor
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.infoColor
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: AppTheme.infoColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'من داخل الشبكة: http://192.168.1.15:8080\n'
                                        'من خارج الشبكة (Cloudflare Tunnel): https://xyz.trycloudflare.com',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.7),
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
