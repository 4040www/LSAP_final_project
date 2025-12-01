#!/bin/bash

CONFIG_FILE="/var/lib/gitea/data/repo_quotas.conf"

REPO_PATH=$(pwd)
REPO_NAME=$(basename $(dirname "$REPO_PATH"))/$(basename "$REPO_PATH" .git)

CURRENT_SIZE_KB=$(du -s "$REPO_PATH" | cut -f1)
CURRENT_SIZE_MB=$((CURRENT_SIZE_KB / 1024))

LIMIT_STR=$(grep "^$REPO_NAME=" "$CONFIG_FILE" | cut -d'=' -f2)
if [ -z "$LIMIT_STR" ]; then
    LIMIT_STR=$(grep "^DEFAULT=" "$CONFIG_FILE" | cut -d'=' -f2)
fi
if [ -z "$LIMIT_STR" ]; then LIMIT_STR="100M"; fi
LIMIT_MB=$(echo $LIMIT_STR | sed 's/M//')

if [ "$CURRENT_SIZE_MB" -ge "$LIMIT_MB" ]; then
    echo "===================================================="
    echo "🛑 [Quota Exceeded] 儲存庫容量已達上限!"
    echo "📦 Repository: $REPO_NAME"
    echo "📊 Usage: ${CURRENT_SIZE_MB}MB / Limit: ${LIMIT_MB}MB"
    echo "===================================================="
    exit 1
fi
exit 0