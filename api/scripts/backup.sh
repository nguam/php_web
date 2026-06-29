#!/bin/bash
# MongoDB 备份脚本

BACKUP_DIR="/var/backups/mongodb"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "开始备份 MongoDB..."
mongodump --out "$BACKUP_DIR/backup_$TIMESTAMP"

if [ $? -eq 0 ]; then
    echo "备份完成: $BACKUP_DIR/backup_$TIMESTAMP"
    exit 0
else
    echo "备份失败"
    exit 1
fi
