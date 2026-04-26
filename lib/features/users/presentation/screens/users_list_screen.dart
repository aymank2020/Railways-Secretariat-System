import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:railway_secretariat/features/users/data/models/user_model.dart';
import 'package:railway_secretariat/features/auth/presentation/providers/auth_provider.dart';
import 'package:railway_secretariat/features/users/presentation/providers/user_provider.dart';
import 'package:railway_secretariat/utils/helpers.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).loadUsers();
    });
  }

  Map<String, bool> _defaultsByRole(String role) {
    switch (role) {
      case 'admin':
        return {
          'can_manage_users': true,
          'can_manage_warid': true,
          'can_manage_sadir': true,
          'can_import_excel': true,
        };
      case 'viewer':
        return {
          'can_manage_users': false,
          'can_manage_warid': false,
          'can_manage_sadir': false,
          'can_import_excel': false,
        };
      default:
        return {
          'can_manage_users': false,
          'can_manage_warid': true,
          'can_manage_sadir': true,
          'can_import_excel': false,
        };
    }
  }

  bool _isStrongPassword(String password) {
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    return password.length >= 8 &&
        hasUpper &&
        hasLower &&
        hasNumber &&
        hasSpecial;
  }

  Future<void> _showUserDialog({UserModel? user}) async {
    final isEditing = user != null;
    final formKey = GlobalKey<FormState>();

    final usernameController =
        TextEditingController(text: user?.username ?? '');
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final fullNameController =
        TextEditingController(text: user?.fullName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');

    String role = user?.role ?? 'user';
    bool isActive = user?.isActive ?? true;
    bool isPasswordVisible = false;
    bool isConfirmPasswordVisible = false;

    bool canManageUsers =
        user?.canManageUsers ?? _defaultsByRole(role)['can_manage_users']!;
    bool canManageWarid =
        user?.canManageWarid ?? _defaultsByRole(role)['can_manage_warid']!;
    bool canManageSadir =
        user?.canManageSadir ?? _defaultsByRole(role)['can_manage_sadir']!;
    bool canImportExcel =
        user?.canImportExcel ?? _defaultsByRole(role)['can_import_excel']!;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'تعديل مستخدم' : 'مستخدم جديد'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم *',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !isEditing,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'مطلوب';
                          }
                          if (v.trim().length < 4) {
                            return 'الحد الأدنى 4 أحرف';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      if (isEditing)
                        TextFormField(
                          initialValue: '********',
                          readOnly: true,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'كلمة المرور المسجلة',
                            helperText: 'محفوظة بشكل مشفر ولا يمكن عرضها نصًا.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      if (isEditing) const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: isEditing
                              ? 'كلمة مرور جديدة (اختياري)'
                              : 'كلمة المرور *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                            icon: Icon(isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility),
                          ),
                        ),
                        obscureText: !isPasswordVisible,
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (!isEditing && value.isEmpty) {
                            return 'مطلوب';
                          }
                          if (value.isNotEmpty && !_isStrongPassword(value)) {
                            return '8+ أحرف مع كبير/صغير/رقم/رمز';
                          }
                          return null;
                        },
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: isEditing
                              ? 'تأكيد كلمة المرور الجديدة'
                              : 'تأكيد كلمة المرور *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                isConfirmPasswordVisible =
                                    !isConfirmPasswordVisible;
                              });
                            },
                            icon: Icon(isConfirmPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility),
                          ),
                        ),
                        obscureText: !isConfirmPasswordVisible,
                        validator: (v) {
                          final passwordValue = passwordController.text.trim();
                          final confirmValue = (v ?? '').trim();

                          if (!isEditing || passwordValue.isNotEmpty) {
                            if (confirmValue.isEmpty) {
                              return 'يرجى تأكيد كلمة المرور';
                            }
                            if (confirmValue != passwordValue) {
                              return 'كلمتا المرور غير متطابقتين';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'مطلوب';
                          }
                          if (!Helpers.isValidEmail(v.trim())) {
                            return 'بريد غير صالح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(
                          labelText: 'الدور',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'admin', child: Text('مدير النظام')),
                          DropdownMenuItem(
                              value: 'user', child: Text('مستخدم')),
                          DropdownMenuItem(
                              value: 'viewer', child: Text('مشاهد')),
                        ],
                        onChanged: (v) {
                          if (v == null) {
                            return;
                          }
                          setDialogState(() {
                            role = v;
                            final defaults = _defaultsByRole(v);
                            canManageUsers = defaults['can_manage_users']!;
                            canManageWarid = defaults['can_manage_warid']!;
                            canManageSadir = defaults['can_manage_sadir']!;
                            canImportExcel = defaults['can_import_excel']!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('نشط'),
                        value: isActive,
                        onChanged: (v) => setDialogState(() => isActive = v),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'الصلاحيات',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('إدارة المستخدمين'),
                        value: canManageUsers,
                        onChanged: (v) =>
                            setDialogState(() => canManageUsers = v),
                      ),
                      SwitchListTile(
                        title: const Text('إدارة الوارد'),
                        value: canManageWarid,
                        onChanged: (v) =>
                            setDialogState(() => canManageWarid = v),
                      ),
                      SwitchListTile(
                        title: const Text('إدارة الصادر'),
                        value: canManageSadir,
                        onChanged: (v) =>
                            setDialogState(() => canManageSadir = v),
                      ),
                      SwitchListTile(
                        title: const Text('استيراد Excel'),
                        value: canImportExcel,
                        onChanged: (v) =>
                            setDialogState(() => canImportExcel = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    final userProvider =
                        Provider.of<UserProvider>(context, listen: false);
                    final passwordInput = passwordController.text.trim();

                    final newUser = UserModel(
                      id: user?.id,
                      username: usernameController.text.trim(),
                      password: passwordInput,
                      fullName: fullNameController.text.trim(),
                      email: emailController.text.trim(),
                      phone: phoneController.text.trim(),
                      role: role,
                      isActive: isActive,
                      createdAt: user?.createdAt ?? DateTime.now(),
                      canManageUsers: canManageUsers,
                      canManageWarid: canManageWarid,
                      canManageSadir: canManageSadir,
                      canImportExcel: canImportExcel,
                    );

                    final success = isEditing
                        ? await userProvider.updateUser(
                            newUser,
                            newPassword:
                                passwordInput.isEmpty ? null : passwordInput,
                          )
                        : await userProvider.addUser(newUser);

                    if (!mounted || !dialogContext.mounted) {
                      return;
                    }

                    if (success) {
                      Navigator.of(dialogContext).pop();
                      Helpers.showSnackBar(
                        context,
                        isEditing ? 'تم التحديث بنجاح' : 'تمت الإضافة بنجاح',
                      );
                    } else {
                      Helpers.showSnackBar(
                        context,
                        userProvider.error ?? 'حدث خطأ',
                        isError: true,
                      );
                    }
                  },
                  child: Text(isEditing ? 'تحديث' : 'إضافة'),
                ),
              ],
            );
          },
        );
      },
    );

    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }

  Future<void> _deleteUser(UserModel user) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (user.id == authProvider.currentUser?.id) {
      Helpers.showSnackBar(context, 'لا يمكنك حذف حسابك الحالي', isError: true);
      return;
    }

    final confirmed = await Helpers.showConfirmationDialog(
      context,
      title: 'تأكيد الحذف',
      message: 'هل أنت متأكد من حذف هذا المستخدم؟',
      isDangerous: true,
    );

    if (!mounted || !confirmed) {
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final success = await userProvider.deleteUser(user.id!);

    if (!mounted) {
      return;
    }

    if (success) {
      Helpers.showSnackBar(context, 'تم الحذف بنجاح');
    } else {
      Helpers.showSnackBar(context, userProvider.error ?? 'حدث خطأ',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final users = userProvider.users;

    if (!authProvider.canManageUsers) {
      return const Scaffold(
        body: Center(
          child: Text(
            'غير مصرح لك بالوصول لهذه الصفحة',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'إدارة المستخدمين',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showUserDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('مستخدم جديد'),
                ),
              ],
            ),
          ),
          Expanded(
            child: userProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? const Center(child: Text('لا يوجد مستخدمون'))
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          child: DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            minWidth: 1250,
                            columns: const [
                              DataColumn2(
                                  label: Text('الاسم'), size: ColumnSize.L),
                              DataColumn2(
                                  label: Text('اسم المستخدم')),
                              DataColumn2(
                                  label: Text('البريد'), size: ColumnSize.L),
                              DataColumn2(
                                  label: Text('الدور'), size: ColumnSize.S),
                              DataColumn2(
                                  label: Text('الصلاحيات'), size: ColumnSize.L),
                              DataColumn2(
                                  label: Text('الحالة'), size: ColumnSize.S),
                              DataColumn2(
                                  label: Text('إجراءات')),
                            ],
                            rows: users.map((user) {
                              final permissions = <String>[];
                              if (user.canManageUsers) {
                                permissions.add('مستخدمين');
                              }
                              if (user.canManageWarid) {
                                permissions.add('وارد');
                              }
                              if (user.canManageSadir) {
                                permissions.add('صادر');
                              }
                              if (user.canImportExcel) {
                                permissions.add('Excel');
                              }

                              return DataRow2(
                                cells: [
                                  DataCell(Text(user.fullName)),
                                  DataCell(Text(user.username)),
                                  DataCell(Text(user.email)),
                                  DataCell(
                                      Text(Helpers.getRoleName(user.role))),
                                  DataCell(Text(permissions.isEmpty
                                      ? '-'
                                      : permissions.join(' | '))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: user.isActive
                                            ? Colors.green
                                                .withValues(alpha: 0.2)
                                            : Colors.red.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        user.isActive ? 'نشط' : 'معطل',
                                        style: TextStyle(
                                          color: user.isActive
                                              ? Colors.green
                                              : Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          onPressed: () =>
                                              _showUserDialog(user: user),
                                        ),
                                        if (user.id !=
                                            authProvider.currentUser?.id)
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () => _deleteUser(user),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
