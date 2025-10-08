#!/bin/bash
# Скрипт автоматической очистки Docker-ресурсов и ротации логов

# --- Настройки ---
LOGFILE="var/logs/docker-cleanup.log"
QUARTZ_UPDATE_LOG="var/logs/quartz-update.log"
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10 МБ в байтах (уменьшил с 50 МБ)
LOCKFILE="var/quartz-update.lock"

# Создать директории при необходимости
mkdir -p "$(dirname "$LOGFILE")" "$(dirname "$LOCKFILE")"

# Функция ротации логов
rotate_log() {
    local log_file="$1"
    local max_size="$2"
    
    if [ -f "$log_file" ] && [ $(stat -c%s "$log_file") -gt $max_size ]; then
        echo "$(date '+%F %T') Ротация лога $log_file (размер >$(($max_size / 1024 / 1024))MB)"
        
        # Сохраняем последние 1000 строк в .old файл
        tail -n 1000 "$log_file" > "${log_file}.old"
        
        # Очищаем основной лог
        echo "$(date '+%F %T') === Лог очищен (старые записи сохранены в ${log_file}.old) ===" > "$log_file"
        
        echo "$(date '+%F %T') Лог $log_file ротирован успешно"
    fi
}

# Ротация логов перед началом работы
rotate_log "$LOGFILE" $MAX_LOG_SIZE
rotate_log "$QUARTZ_UPDATE_LOG" $MAX_LOG_SIZE

# Блокировка: предотвращаем одновременный запуск
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

echo "$(date '+%F %T') === Начало очистки Docker ===" >> "$LOGFILE"

# Показываем состояние диска перед очисткой
echo "$(date '+%F %T') Состояние диска перед очисткой:" >> "$LOGFILE"
df -h / >> "$LOGFILE" 2>&1

# Удаляем остановленные контейнеры
echo "$(date '+%F %T') Удаление остановленных контейнеров..." >> "$LOGFILE"
REMOVED_CONTAINERS=$(docker container prune -f --filter "until=24h" 2>/dev/null || echo "0")
echo "$(date '+%F %T') Результат: $REMOVED_CONTAINERS" >> "$LOGFILE"

# Удаляем неиспользуемые образы (включая dangling)
echo "$(date '+%F %T') Удаление неиспользуемых образов..." >> "$LOGFILE"
REMOVED_IMAGES=$(docker image prune -f 2>/dev/null || echo "0")
echo "$(date '+%F %T') Результат: $REMOVED_IMAGES" >> "$LOGFILE"

# Удаляем неиспользуемые тома
echo "$(date '+%F %T') Удаление неиспользуемых томов..." >> "$LOGFILE"
REMOVED_VOLUMES=$(docker volume prune -f 2>/dev/null || echo "0")
echo "$(date '+%F %T') Результат: $REMOVED_VOLUMES" >> "$LOGFILE"

# Удаляем неиспользуемые сети
echo "$(date '+%F %T') Удаление неиспользуемых сетей..." >> "$LOGFILE"
REMOVED_NETWORKS=$(docker network prune -f 2>/dev/null || echo "0")
echo "$(date '+%F %T') Результат: $REMOVED_NETWORKS" >> "$LOGFILE"

# Очистка логов Docker контейнеров (если они больше 100MB)
echo "$(date '+%F %T') Проверка размера Docker логов..." >> "$LOGFILE"
for container in $(docker ps -a --format "{{.Names}}" 2>/dev/null); do
    LOG_PATH=$(docker inspect --format='{{.LogPath}}' "$container" 2>/dev/null)
    if [ -f "$LOG_PATH" ]; then
        LOG_SIZE=$(stat -c%s "$LOG_PATH" 2>/dev/null || echo "0")
        if [ $LOG_SIZE -gt $((100 * 1024 * 1024)) ]; then  # Больше 100MB
            echo "$(date '+%F %T') Очистка лога контейнера $container (размер: $(($LOG_SIZE / 1024 / 1024))MB)" >> "$LOGFILE"
            truncate -s 0 "$LOG_PATH" 2>/dev/null || true
        fi
    fi
done

# Удаление старых .old логов (старше 7 дней)
echo "$(date '+%F %T') Удаление старых .old логов..." >> "$LOGFILE"
find var/logs/ -name "*.old" -type f -mtime +7 -delete 2>/dev/null || true

# Показываем состояние диска после очисткой
echo "$(date '+%F %T') Состояние диска после очистки:" >> "$LOGFILE"
df -h / >> "$LOGFILE" 2>&1

echo "$(date '+%F %T') === Очистка завершена ===" >> "$LOGFILE"