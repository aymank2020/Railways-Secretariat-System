import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Helpers {
  static String formatDate(DateTime? date, {bool includeTime = false}) {
    if (date == null) {
      return '-';
    }

    final formatter = includeTime
        ? DateFormat('yyyy/MM/dd HH:mm', 'ar')
        : DateFormat('yyyy/MM/dd', 'ar');
    return formatter.format(date);
  }

  static String formatNumber(int number) {
    final formatter = NumberFormat('#,###', 'ar');
    return formatter.format(number);
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration? duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: duration ?? Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'تأكيد',
    String cancelText = 'إلغاء',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: isDangerous
                  ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                  : null,
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  static void showLoadingDialog(BuildContext context,
      {String message = 'جاري التحميل...'}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );
  }

  static void hideLoadingDialog(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  static String getRoleName(String role) {
    switch (role) {
      case 'admin':
        return 'مدير النظام';
      case 'user':
        return 'مستخدم';
      case 'viewer':
        return 'مشاهد';
      default:
        return role;
    }
  }

  static String getSignatureStatusName(String status) {
    switch (status) {
      case 'pending':
        return 'انتظار';
      case 'saved':
        return 'حفظ';
      default:
        return status;
    }
  }

  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^[0-9]{10,11}$');
    return phoneRegex.hasMatch(phone);
  }

  static String generateDocumentNumber(String prefix, int sequence) {
    final year = DateTime.now().year;
    return '$prefix-$year-${sequence.toString().padLeft(5, '0')}';
  }
}

