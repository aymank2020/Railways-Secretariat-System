#!/bin/bash
# سكريبت النسخ الاحتياطي لنظام السكرتارية

BACKUP_DIR="/opt/secretariat/backups"
DATA_DIR="/opt/secretariat/secretariat_data"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Starting backup at $DATE"

# إنشاء مجلد النسخ الاحتياطي إذا لم يكن موجوداً
mkdir -p "$BACKUP_DIR"

# 1. نسخ قاعدة البيانات (آمن حتى مع SQLite، ويمكن استخدام .backup لاحقاً)
if [ -f "$DATA_DIR/secretariat.db" ]; then
    cp "$DATA_DIR/secretariat.db" "$BACKUP_DIR/secretariat_${DATE}.db"
    echo "Database backed up successfully."
else
    echo "Warning: Database not found at $DATA_DIR/secretariat.db"
fi

# 2. ضغط مجلد المرفقات
if [ -d "$DATA_DIR/attachments" ]; then
    tar -czf "$BACKUP_DIR/attachments_${DATE}.tar.gz" -C "$DATA_DIR" attachments/
    echo "Attachments backed up successfully."
else
    echo "Warning: Attachments directory not found."
fi

# 3. حذف النسخ القديمة (أقدم من 30 يوم للحفاظ على المساحة)
find "$BACKUP_DIR" -name "secretariat_*.db" -mtime +30 -exec rm {} \;
find "$BACKUP_DIR" -name "attachments_*.tar.gz" -mtime +30 -exec rm {} \;

echo "Backup process completed."
