#!/bin/bash
# سكريبت نشر السيرفر على Ubuntu 24.04 LTS

echo "======================================"
echo "    نشر سيرفر نظام السكرتارية         "
echo "======================================"

if [ "$EUID" -ne 0 ]; then
  echo "الرجاء تشغيل السكريبت بصلاحيات root (sudo bash deploy.sh)"
  exit 1
fi

echo "[1/6] تحديث النظام وتجهيزه..."
apt-get update

echo "[2/6] إنشاء مستخدم النظام ومجلداته..."
if ! id "secretariat" &>/dev/null; then
    useradd -r -s /bin/false secretariat
fi
mkdir -p /opt/secretariat
mkdir -p /opt/secretariat/secretariat_data
mkdir -p /opt/secretariat/backups
mkdir -p /opt/secretariat/logs

echo "[3/6] إعداد الصلاحيات..."
chown -R secretariat:secretariat /opt/secretariat
# نعطي السيرفر صلاحية التنفيذ لو موجود
if [ -f "/opt/secretariat/server_main" ]; then
    chmod +x /opt/secretariat/server_main
fi
# تأكد أن سكريبت الباك اب قابل للتنفيذ
if [ -f "/opt/secretariat/tool/backup.sh" ]; then
    chmod +x /opt/secretariat/tool/backup.sh
fi

echo "[4/6] تثبيت وتفعيل Systemd Service..."
if [ -f "secretariat.service" ]; then
    cp secretariat.service /etc/systemd/system/
elif [ -f "tool/secretariat.service" ]; then
    cp tool/secretariat.service /etc/systemd/system/
else
    echo "تحذير: ملف secretariat.service غير موجود!"
fi

systemctl daemon-reload

echo "[5/6] تسجيل وبدء الخدمة..."
systemctl enable secretariat
systemctl restart secretariat

echo "[6/6] إعداد النسخ الاحتياطي التلقائي (Cron)..."
# تشغيل كل يوم الساعة 2 فجراً
CRON_JOB="0 2 * * * /opt/secretariat/tool/backup.sh >> /opt/secretariat/logs/backup.log 2>&1"
(crontab -l 2>/dev/null | grep -v "/opt/secretariat/tool/backup.sh"; echo "$CRON_JOB") | crontab -

echo "======================================"
echo "تم النشر بنجاح!"
echo "يمكنك فحص حالة السيرفر بـ:"
echo "sudo systemctl status secretariat"
echo "لرؤية السجلات (Logs):"
echo "tail -f /opt/secretariat/logs/server.log"
echo "======================================"
