# نظام إدارة المراسلات - السكك الحديدية

## Railway Secretariat System - Flutter

تطبيق Flutter متكامل لإدارة المراسلات الواردة والصادرة للسكك الحديدية، يعمل على Desktop (Windows/Linux/Mac) و Mobile (Android/iOS).

يدعم النظام وضعين للتشغيل:
- **الوضع المحلي**: قاعدة بيانات SQLite مباشرة على الجهاز
- **وضع الخادم**: يتصل بخادم HTTP مركزي (مضمن في المشروع) يدعم عدة مستخدمين

---

## المميزات

- **إدارة الوارد (Warid)**: تسجيل وتتبع جميع المراسلات الواردة
- **إدارة الصادر (Sadir)**: تسجيل وتتبع جميع المراسلات الصادرة
- **نظام مصادقة آمن**: تسجيل دخول مع صلاحيات مختلفة (مدير، مستخدم، مشاهد)
- **تشفير بيانات الاعتماد**: كلمات المرور المحفوظة محلياً مشفرة
- **إعادة المصادقة التلقائية**: عند انتهاء الجلسة يتم تجديدها تلقائياً
- **بحث متقدم**: البحث في المراسلات حسب التاريخ والموضوع والجهة
- **دعم الملفات**: إرفاق ملفات PDF وصور بالمراسلات
- **استيراد Excel**: استيراد بيانات المراسلات من ملفات Excel
- **تقسيم PDF**: تقسيم ملفات PDF دفعة واحدة
- **OCR**: أتمتة التعرف الضوئي على الحروف مع قوالب قابلة للتخصيص
- **سجل التعديلات**: تتبع جميع التغييرات والحذف مع إمكانية الاستعادة
- **لوحة معلومات**: إحصائيات ومؤشرات أداء
- **مؤشر اتصال مباشر**: مراقبة حالة الاتصال بالخادم في الوقت الحقيقي
- **واجهة عربية**: كاملة الدعم للغة العربية (RTL)
- **وضع مظلم / فاتح**: دعم كامل للثيمات
- **دعم Desktop**: Windows, Linux, macOS
- **دعم Mobile**: Android, iOS

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

### 3. تشغيل التطبيق (وضع محلي)

```bash
# Windows
flutter run -d windows

# Linux / macOS
flutter run -d linux
flutter run -d macos
```

### 4. تشغيل التطبيق (وضع الخادم)

#### أ. تشغيل الخادم

```bash
dart run lib/server_main.dart
```

الخادم يعمل افتراضياً على `http://0.0.0.0:8080`. يمكنك تخصيصه:

| متغير البيئة | الوصف | القيمة الافتراضية |
|---|---|---|
| `SECRETARIAT_PORT` | منفذ الخادم | `8080` |
| `SECRETARIAT_HOST` | عنوان الاستماع | `0.0.0.0` |
| `SECRETARIAT_DB_PATH` | مسار قاعدة البيانات | `secretariat.db` |
| `SECRETARIAT_CORS_ORIGINS` | عناوين CORS المسموحة (فاصلة) | `*` |
| `SECRETARIAT_LOGIN_RATE_LIMIT` | حد محاولات الدخول لكل 5 دقائق | `10` |
| `SECRETARIAT_LOG_REQUESTS` | تسجيل الطلبات | `true` |

#### ب. تشغيل التطبيق مع عنوان الخادم

```bash
# عبر متغير بيئة
SECRETARIAT_API_BASE_URL=http://localhost:8080 flutter run -d windows

# عبر compile-time define
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
```

أو قم بتشغيل التطبيق بدون إعدادات مسبقة — سيظهر شاشة إعداد الخادم تلقائياً.

---

## نشر السيرفر للإنتاج (Docker / Ubuntu LAN)

يمكن تشغيل ثلاث خدمات Docker معاً (Dart server + Flutter Web + nginx + Cloudflare Tunnel اختياري) على أي Ubuntu LTS.

### الخيار 1: السكربت الجاهز

على سيرفر Ubuntu نظيف:

```bash
git clone https://github.com/aymank2020/Railways-Secretariat-System.git /tmp/railways
cd /tmp/railways
sudo bash deploy/scripts/bootstrap.sh
```

السكربت يعمل التالي بالترتيب:
1. ينصّب Docker Engine + Compose v2 + UFW.
2. ينشئ مستخدم النظام `railways`.
3. يستنسخ الريبو إلى `/opt/railways-secretariat-flutter`.
4. ينشئ `.env` آمن (port 80، CORS مغلق افتراضياً).
5. يضبط UFW: SSH مفتوح، port 80 مفتوح للـ LAN فقط (`192.168.0.0/16`، `10.0.0.0/8`، `172.16.0.0/12`).
6. يبني ويشغّل الـ stack.
7. يتأكد من صحة الخدمات عبر `/healthz` و `/api/health`.
8. يدوّر كلمة سر admin من `admin123` إلى كلمة عشوائية ويحفظها في `INITIAL_CREDENTIALS.txt` (mode 600).

### الخيار 2: يدوي

```bash
git clone https://github.com/aymank2020/Railways-Secretariat-System.git
cd Railways-Secretariat-System
cp .env.example .env
# عدّل .env حسب رغبتك (port، CORS، tunnel token...)
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d
```

### الخدمات

| الخدمة | المنفذ | الوصف |
|---|---|---|
| `web` | 80 (host) | nginx يخدّم Flutter Web ويعمل reverse-proxy لـ `/api/*` |
| `server` | 8080 (داخلي) | Dart server (نفس الـ binary من `dart compile exe`) |
| `cloudflared` | n/a | اختياري: Cloudflare Tunnel للوصول عن بُعد عبر WARP |

### تفعيل Cloudflare Tunnel (اختياري)

```bash
# على جهاز الإدارة
cloudflared tunnel create secretariat
# انسخ الـ Token من cloudflare dashboard ولصّقه في .env كـ CLOUDFLARE_TUNNEL_TOKEN

# ثم على السيرفر:
cd /opt/railways-secretariat-flutter
sudo -u railways docker compose -f docker-compose.prod.yml --profile tunnel up -d cloudflared
```

### العمليات اليومية

```bash
# عرض السجلات
sudo -u railways docker compose -f docker-compose.prod.yml logs -f

# تحديث آخر إصدار من main
sudo -u railways bash -c "cd /opt/railways-secretariat-flutter && \
  git pull --ff-only origin main && \
  docker compose -f docker-compose.prod.yml build && \
  docker compose -f docker-compose.prod.yml up -d --force-recreate"

# نسخة احتياطية من قاعدة البيانات
docker run --rm -v railways_secretariat_data:/data -v $PWD:/backup alpine \
  tar -czf /backup/secretariat-backup-$(date +%Y%m%d).tgz /data
```

---

## بناء الإصدار النهائي

### Windows

```bash
flutter build windows --release
```

الملف التنفيذي:
```
build/windows/x64/runner/Release/railway_secretariat.exe
```

### Linux / macOS

```bash
flutter build linux --release
flutter build macos --release
```

### Android / iOS

```bash
flutter build apk --release
flutter build ios --release
```

---

## بيانات الدخول الافتراضية

| الدور | اسم المستخدم | كلمة المرور |
|-------|-------------|------------|
| مدير النظام | admin | admin123 |
| مستخدم | user | user123 |

> **تنبيه**: قم بتغيير كلمات المرور الافتراضية فوراً بعد أول تسجيل دخول.

---

## هيكل المشروع (Clean Architecture)

```
lib/
├── main.dart                         # نقطة الدخول الرئيسية
├── server_main.dart                  # خادم HTTP المدمج
│
├── core/                             # مكونات مشتركة
│   ├── di/
│   │   └── app_dependencies.dart     # حقن الاعتماديات (Local/Remote)
│   ├── network/
│   │   └── api_client.dart           # عميل HTTP مع retry وre-auth
│   ├── providers/
│   │   ├── theme_provider.dart       # إدارة الثيم
│   │   └── connection_status_provider.dart  # مراقبة حالة الاتصال
│   └── services/
│       ├── database_service.dart     # خدمة SQLite
│       └── server_settings_service.dart
│
├── features/                         # الميزات (Feature-based)
│   ├── auth/
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       ├── database_auth_repository.dart
│   │   │       ├── http_auth_repository.dart
│   │   │       ├── encrypted_credentials_repository.dart
│   │   │       └── shared_prefs_credentials_repository.dart
│   │   ├── domain/
│   │   │   ├── repositories/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── credentials_repository.dart
│   │   │   └── usecases/
│   │   │       └── auth_use_cases.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── auth_provider.dart
│   │       └── screens/
│   │           └── login_screen.dart
│   │
│   ├── documents/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── excel_import_service.dart
│   │   │   └── repositories/
│   │   │       ├── database_document_repository.dart
│   │   │       └── http_document_repository.dart
│   │   ├── domain/
│   │   │   ├── models/
│   │   │   │   ├── warid_model.dart
│   │   │   │   └── sadir_model.dart
│   │   │   ├── repositories/
│   │   │   │   └── document_repository.dart
│   │   │   └── usecases/
│   │   │       └── document_use_cases.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── document_provider.dart
│   │       └── screens/
│   │           ├── warid_form_screen.dart
│   │           ├── warid_list_screen.dart
│   │           ├── sadir_form_screen.dart
│   │           ├── sadir_list_screen.dart
│   │           └── ...
│   │
│   ├── users/                        # (نفس البنية)
│   ├── ocr/                          # أتمتة OCR
│   ├── system/                       # إعدادات النظام
│   ├── theme/                        # إدارة الثيم
│   ├── history/                      # سجل الحذف والتعديل
│   └── dashboard/                    # لوحة المعلومات
│
├── server/                           # وحدات الخادم
│   ├── session_store.dart            # جلسات مستمرة (SQLite-backed)
│   ├── middleware.dart               # تسجيل طلبات، تحديد معدل، CORS
│   └── helpers.dart                  # أدوات مساعدة للخادم
│
├── widgets/                          # ويدجات مشتركة
│   └── connection_status_indicator.dart
│
└── utils/
    └── app_theme.dart
```

---

## البنية المعمارية

### نمط التصميم

يتبع المشروع **Clean Architecture** مع فصل طبقات:

```
Presentation (Screens + Providers)
        ↓
Domain (Use Cases + Repository Interfaces + Models)
        ↓
Data (Repository Implementations + Data Sources)
```

### إدارة الحالة

- **Provider + ChangeNotifier**: لإدارة حالة التطبيق
- `AuthProvider`: المصادقة وإدارة الجلسة
- `DocumentProvider`: المراسلات الواردة والصادرة
- `UserProvider`: إدارة المستخدمين
- `ThemeProvider`: الوضع المظلم/الفاتح
- `ConnectionStatusProvider`: مراقبة الاتصال بالخادم

### وضع التشغيل المزدوج

`AppDependencies` يختار تلقائياً بين:
- **`Database*Repository`**: يستخدم SQLite مباشرة (الوضع المحلي)
- **`Http*Repository`**: يتصل بالخادم عبر `ApiClient` (وضع الخادم)

### ميزات ApiClient

- **مهلة زمنية**: 30 ثانية لكل طلب (قابلة للتخصيص)
- **إعادة المحاولة**: 3 محاولات مع تأخير أسي + jitter
- **إعادة مصادقة تلقائية**: عند 401 يحاول تجديد الجلسة بالبيانات المحفوظة

### ميزات الخادم

- **WAL mode**: أداء أفضل للقراءة/الكتابة المتزامنة
- **جلسات مستمرة**: تنجو من إعادة التشغيل (SQLite-backed، TTL 8 ساعات)
- **تحديد المعدل**: حماية نقطة تسجيل الدخول من محاولات القوة الغاشمة
- **CORS قابل للتخصيص**: عبر متغير بيئة
- **تسجيل الطلبات**: مع الطريقة والمسار ورمز الحالة والمدة
- **حذف دفعات**: نقاط نهاية لحذف عدة سجلات دفعة واحدة
- **تجديد الرمز**: نقطة نهاية `/api/auth/refresh`
- **إيقاف رشيق**: يغلق الاتصالات بشكل نظيف عند SIGINT/SIGTERM

---

## الاعتماديات الرئيسية

| الحزمة | الاستخدام |
|---|---|
| `provider` | إدارة الحالة |
| `sqflite` / `sqflite_common_ffi` | قاعدة بيانات SQLite |
| `shared_preferences` | التخزين المؤقت والإعدادات |
| `crypto` | تشفير بيانات الاعتماد المحفوظة |
| `http` | طلبات HTTP |
| `file_picker` | اختيار الملفات |
| `window_manager` | إدارة نافذة Desktop |
| `data_table_2` | جداول متقدمة |
| `intl` | التعريب والتنسيق |
| `shelf` | خادم HTTP (الخادم المدمج) |

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

**تم التطوير بواسطة فريق السكك الحديدية**
