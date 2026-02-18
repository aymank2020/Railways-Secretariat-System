import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';

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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryDarkColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (isDesktop)
                Container(
                  height: 40,
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white),
                        onPressed: () => windowManager.minimize(),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.crop_square, color: Colors.white),
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
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.admin_panel_settings,
                                      size: 40, color: Colors.white),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'نظام إدارة المراسلات',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'تسجيل دخول آمن',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
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
                                      icon: Icon(_obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility),
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
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.red.shade200),
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
                                                color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (authProvider.error != null)
                                  const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed:
                                        authProvider.isLoading ? null : _login,
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Text('تسجيل الدخول',
                                            style: TextStyle(fontSize: 16)),
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
      ),
    );
  }
}
