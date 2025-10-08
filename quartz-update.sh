#!/bin/bash
set -e
cd "$(dirname "$0")"

# Загружаем переменные окружения из .env файла
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "$(date '+%F %T') ПРЕДУПРЕЖДЕНИЕ: .env файл не найден, используется DOMAIN_NAME=localhost"
fi

LOGFILE="var/logs/quartz-update.log"
mkdir -p "$(dirname "$LOGFILE")"
exec 200>"var/quartz-update.lock"
flock -n 200 || exit 0

git fetch origin
if git rev-list HEAD..origin/main -- content/ | grep -q .; then
    echo "$(date '+%F %T') Обновление: изменения в content/ найдены (DOMAIN_NAME=${DOMAIN_NAME:-localhost})" >> "$LOGFILE" 2>&1
    git merge origin/main
    docker-compose up -d --build >> "$LOGFILE" 2>&1
    echo "$(date '+%F %T') Обновление завершено успешно" >> "$LOGFILE" 2>&1
else
    echo "$(date '+%F %T') Нет изменений в content/ (DOMAIN_NAME=${DOMAIN_NAME:-localhost})" >> "$LOGFILE" 2>&1
fi