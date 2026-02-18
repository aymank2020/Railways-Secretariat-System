# نظام إدارة المراسلات - السكك الحديدية

## Railway Secretariat System - Flutter

تطبيق Flutter متكامل لإدارة المراسلات الواردة والصادرة للسكك الحديدية، يعمل على Desktop (Windows/Linux/Mac) و Mobile (Android/iOS).

---

## المميزات

- ✅ **إدارة الوارد**: تسجيل وتتبع جميع المراسلات الواردة
- ✅ **إدارة الصادر**: تسجيل وتتبع جميع المراسلات الصادرة
- ✅ **نظام تسجيل دخول آمن**: مع صلاحيات مختلفة (مدير، مستخدم، مشاهد)
- ✅ **قاعدة بيانات محلية**: SQLite للتخزين المحلي
- ✅ **بحث متقدم**: البحث في المراسلات حسب التاريخ والموضوع والجهة
- ✅ **دعم الملفات**: إرفاق ملفات PDF وصور بالمراسلات
- ✅ **سجل التعديلات**: تتبع جميع التغييرات على البيانات
- ✅ **واجهة عربية**: كاملة الدعم للغة العربية
- ✅ **دعم Desktop**: Windows, Linux, macOS
- ✅ **دعم Mobile**: Android, iOS

---

## المتطلبات

- Flutter SDK 3.0.0 أو أحدث
- Dart SDK 3.0.0 أو أحدث
- Android Studio / Xcode (للموبايل)
- Visual Studio 2019 أو أحدث (لـ Windows)

---

## التثبيت

### 1. استنساخ المشروع

```bash
git clone <repository-url>
cd railway_secretariat
```

### 2. تثبيت الاعتماديات

```bash
flutter pub get
```

### 3. تشغيل التطبيق

#### Desktop (Windows/Linux/Mac)

```bash
# Windows
flutter run -d windows

# Linux
flutter run -d linux

# macOS
flutter run -d macos
```

#### Mobile (Android/iOS)

```bash
# Android
flutter run -d android

# iOS (يتطلب macOS)
flutter run -d ios
```

---

## بناء الإصدار النهائي

### Windows

```bash
flutter build windows --release
```

الملف التنفيذي يكون في:
```
build/windows/x64/runner/Release/railway_secretariat.exe
```

### Linux

```bash
flutter build linux --release
```

### macOS

```bash
flutter build macos --release
```

### Android

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

---

## بيانات الدخول الافتراضية

| الدور | اسم المستخدم | كلمة المرور |
|-------|-------------|------------|
| مدير النظام | admin | admin123 |
| مستخدم | user | user123 |

---

## هيكل المشروع

```
lib/
├── main.dart                 # نقطة الدخول الرئيسية
├── models/                   # نماذج البيانات
│   ├── user_model.dart
│   ├── warid_model.dart
│   └── sadir_model.dart
├── providers/                # إدارة الحالة
│   ├── auth_provider.dart
│   ├── document_provider.dart
│   ├── user_provider.dart
│   └── theme_provider.dart
├── screens/                  # الشاشات
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── dashboard_screen.dart
│   ├── warid/
│   │   ├── warid_form_screen.dart
│   │   ├── warid_list_screen.dart
│   │   └── warid_search_screen.dart
│   ├── sadir/
│   │   ├── sadir_form_screen.dart
│   │   ├── sadir_list_screen.dart
│   │   └── sadir_search_screen.dart
│   ├── users/
│   │   └── users_list_screen.dart
│   └── documents/
│       └── documents_list_screen.dart
├── services/                 # الخدمات
│   └── database_service.dart
├── utils/                    # الأدوات المساعدة
│   ├── app_theme.dart
│   └── helpers.dart
└── widgets/                  # الويدجات المشتركة
```

---

## الاعتماديات الرئيسية

- `provider`: إدارة الحالة
- `sqflite` / `sqflite_common_ffi`: قاعدة البيانات
- `shared_preferences`: التخزين المؤقت
- `file_picker`: اختيار الملفات
- `window_manager`: إدارة نافذة Desktop
- `data_table_2`: جداول متقدمة
- `intl`: التعريب والتنسيق

---

## المساهمة

نرحب بمساهماتكم! يرجى اتباع الخطوات التالية:

1. Fork المشروع
2. إنشاء فرع جديد (`git checkout -b feature/amazing-feature`)
3. Commit التغييرات (`git commit -m 'Add amazing feature'`)
4. Push إلى الفرع (`git push origin feature/amazing-feature`)
5. فتح Pull Request

---

## الترخيص

هذا المشروع مرخص بموجب [MIT License](LICENSE).

---

## التواصل

للاستفسارات والدعم الفني، يرجى التواصل عبر:
- البريد الإلكتروني: support@railway.gov
- الهاتف: 0123456789

---

## شكر خاص

نشكر جميع المساهمين في تطوير هذا النظام.

**تم التطوير بواسطة فريق السكك الحديدية** 🚂
