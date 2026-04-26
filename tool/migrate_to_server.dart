import 'dart:io';

import 'package:path/path.dart' as p;

void main(List<String> args) {
  print('================================================');
  print('  أداة المساعدة في ترحيل البيانات إلى السيرفر');
  print('================================================\n');

  print('بما أن التطبيق المحلي والسيرفر يستخدمان نفس قاعدة البيانات (SQLite)،');
  print('لا داعي لبرمجة سكريبت معقد لنقل البيانات عبر الشبكة.');
  print('أسهل وآمن طريقة هي "نسخ" مجلد البيانات بالكامل من جهازك إلى السيرفر.\n');

  final currentDir = Directory.current.path;
  final localDataFolder = p.join(currentDir, 'secretariat_data');

  print('1. ابحث عن مجلد البيانات المحلي على جهازك:');
  print('   المسار المتوقع: $localDataFolder');

  final folderExists = Directory(localDataFolder).existsSync();
  if (folderExists) {
    print('   (✅ المجلد موجود وجاهز للنسخ!)');
  } else {
    print('   (⚠️ المجلد غير موجود في هذا المسار. قد يكون بجوار ملف .exe النهائي)');
  }

  print('\n2. انسخ المجلد إلى السيرفر (Ubuntu) الذي أعددته:');
  print('   إذا كنت تستخدم Windows، يمكنك استخدام أمر SCP في PowerShell:');
  print('   scp -r "$localDataFolder\\*" root@192.168.1.100:/opt/secretariat/secretariat_data/');
  
  print('\n3. تأكد من إعطاء الصلاحيات للمستخدم على السيرفر بعد النسخ:');
  print('   ssh root@192.168.1.100 "chown -R secretariat:secretariat /opt/secretariat/secretariat_data"');
  
  print('\n4. أعد تشغيل السيرفر:');
  print('   ssh root@192.168.1.100 "systemctl restart secretariat"');

  print('\n================================================');
  print('بعد ذلك، افتح التطبيق في الأجهزة واذهب إلى الإعدادات وأدخل عنوان السيرفر.');
}
