#!/bin/bash
# 清理临时文件脚本

TEMP_DIR="/tmp"
LOG_FILE="/var/www/api/logs/cleanup.log"

echo "[$(date)] 开始清理临时文件..." | tee -a "$LOG_FILE"

# 清理超过 7 天的临时文件
find "$TEMP_DIR" -type f -name "*.tmp" -mtime +7 -delete 2>/dev/null

echo "[$(date)] 清理完成" | tee -a "$LOG_FILE"
exit 0
