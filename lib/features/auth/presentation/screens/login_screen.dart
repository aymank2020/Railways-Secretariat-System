import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:railway_secretariat/features/auth/presentation/providers/auth_provider.dart';
import 'package:railway_secretariat/utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_clearErrorOnInput);
    _passwordController.addListener(_clearErrorOnInput);
  }

  void _clearErrorOnInput() {
    if (!mounted) {
      return;
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.error != null) {
      authProvider.clearError();
    }
  }

  @override
  void dispose() {
    _usernameController.removeListener(_clearErrorOnInput);
    _passwordController.removeListener(_clearErrorOnInput);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
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
    final authProvider = Provider.of<AuthProvider>(context);
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    if (authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/home');
      });
      return const SizedBox.shrink();
    }

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
              size: 220,
              alignment: const Alignment(0.98, -0.52),
              color: AppTheme.accentColor,
            ),
            _buildGlowOrb(
              size: 240,
              alignment: const Alignment(0.88, 0.84),
              color: AppTheme.infoColor,
            ),
            SafeArea(
              child: Column(
                children: [
                  if (isDesktop)
                    SizedBox(
                      height: 40,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          children: [
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.white),
                              onPressed: () => windowManager.minimize(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.crop_square, color: Colors.white),
                              onPressed: () async {
                                if (await windowManager.isMaximized()) {
                                  await windowManager.unmaximize();
                                } else {
                                  await windowManager.maximize();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => windowManager.close(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Card(
                            elevation: 0,
                            color: scheme.surface.withValues(alpha: 0.92),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(
                                color: AppTheme.primaryLightColor
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 82,
                                      height: 82,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryColor,
                                            AppTheme.accentColor,
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.admin_panel_settings,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'نظام إدارة المراسلات',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'تسجيل دخول آمن',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            scheme.onSurface.withValues(alpha: 0.72),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    TextFormField(
                                      controller: _usernameController,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'اسم المستخدم',
                                        prefixIcon: Icon(Icons.person),
                                        hintText: 'أدخل اسم المستخدم',
                                      ),
                                      validator: (value) {
                                        final v = value?.trim() ?? '';
                                        if (v.isEmpty) {
                                          return 'يرجى إدخال اسم المستخدم';
                                        }
                                        if (v.length < 4) {
                                          return 'اسم المستخدم قصير';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _passwordController,
                                      textInputAction: TextInputAction.done,
                                      obscureText: _obscurePassword,
                                      onFieldSubmitted: (_) => _login(),
                                      decoration: InputDecoration(
                                        labelText: 'كلمة المرور',
                                        prefixIcon: const Icon(Icons.lock),
                                        hintText: 'أدخل كلمة المرور',
                                        suffixIcon: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if ((value ?? '').isEmpty) {
                                          return 'يرجى إدخال كلمة المرور';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    CheckboxListTile(
                                      value: _rememberMe,
                                      onChanged: (v) {
                                        setState(() {
                                          _rememberMe = v ?? false;
                                        });
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('تذكرني'),
                                    ),
                                    const SizedBox(height: 12),
                                    if (authProvider.error != null)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error,
                                                color: Colors.red),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                authProvider.error!,
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (authProvider.error != null)
                                      const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: authProvider.isLoading
                                            ? null
                                            : _login,
                                        child: authProvider.isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                'تسجيل الدخول',
                                                style: TextStyle(fontSize: 16),
                                              ),
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
          ],
        ),
      ),
    );
  }
}
