#!/bin/bash

REPO_ROOT="/var/lib/gitea/data/gitea-repositories"
CONFIG_FILE="/var/lib/gitea/data/repo_quotas.conf"
LOG_FILE="/var/lib/gitea/log/quota_alert.log"
METRICS_FILE="/var/lib/gitea/data/metrics/gitea_quotas.prom"

TEMP_METRICS="${METRICS_FILE}.tmp"
echo "# HELP gitea_repo_usage_bytes Current size in bytes" > "$TEMP_METRICS"
echo "# TYPE gitea_repo_usage_bytes gauge" >> "$TEMP_METRICS"
echo "# HELP gitea_repo_limit_bytes Limit in bytes" >> "$TEMP_METRICS"
echo "# TYPE gitea_repo_limit_bytes gauge" >> "$TEMP_METRICS"
echo "# HELP gitea_repo_quota_exceeded 1 if exceeded" >> "$TEMP_METRICS"
echo "# TYPE gitea_repo_quota_exceeded gauge" >> "$TEMP_METRICS"

DEFAULT_LIMIT_MB=$(grep "^DEFAULT=" "$CONFIG_FILE" | cut -d'=' -f2 | sed 's/M//')
if [ -z "$DEFAULT_LIMIT_MB" ]; then DEFAULT_LIMIT_MB=100; fi
DEFAULT_LIMIT_BYTES=$((DEFAULT_LIMIT_MB * 1024 * 1024))

find "$REPO_ROOT" -maxdepth 2 -name "*.git" | while read REPO_PATH; do
    REPO_NAME=$(basename $(dirname "$REPO_PATH"))/$(basename "$REPO_PATH" .git)
    
    SIZE_BYTES=$(du -s -B1 "$REPO_PATH" | cut -f1)
    SIZE_MB=$((SIZE_BYTES / 1024 / 1024))
    
    LIMIT_STR=$(grep "^$REPO_NAME=" "$CONFIG_FILE" | cut -d'=' -f2 | sed 's/M//')
    if [ -z "$LIMIT_STR" ]; then
        LIMIT_BYTES=$DEFAULT_LIMIT_BYTES; LIMIT_MB=$DEFAULT_LIMIT_MB
    else
        LIMIT_BYTES=$((LIMIT_STR * 1024 * 1024)); LIMIT_MB=$LIMIT_STR
    fi
    
    IS_EXCEEDED=0
    if [ "$SIZE_BYTES" -ge "$LIMIT_BYTES" ]; then
        IS_EXCEEDED=1
        echo "[警告] $REPO_NAME 超標! ${SIZE_MB}MB / ${LIMIT_MB}MB" >> "$LOG_FILE"
    fi

    echo "gitea_repo_usage_bytes{repo=\"$REPO_NAME\"} $SIZE_BYTES" >> "$TEMP_METRICS"
    echo "gitea_repo_limit_bytes{repo=\"$REPO_NAME\"} $LIMIT_BYTES" >> "$TEMP_METRICS"
    echo "gitea_repo_quota_exceeded{repo=\"$REPO_NAME\"} $IS_EXCEEDED" >> "$TEMP_METRICS"
done

mv "$TEMP_METRICS" "$METRICS_FILE"